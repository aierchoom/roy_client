import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/hlc.dart';

/// Encodes a list of accounts into a CSV string.
///
/// Columns: id, name, template, email, then all unique field keys from
/// all accounts' data maps, sorted alphabetically.
String encodeAccountsToCsv(
  List<AccountItem> accounts,
  List<AccountTemplate> allTemplates,
) {
  final templateById = <String, String>{};
  for (final t in allTemplates) {
    templateById[t.templateId] = t.title;
  }

  // Collect all unique field keys from all accounts.
  final allKeys = <String>{};
  for (final a in accounts) {
    allKeys.addAll(a.data.keys);
  }
  final keys = allKeys.toList()..sort();

  // Header row.
  final header = ['id', 'name', 'template', 'email', ...keys];

  final buf = StringBuffer();
  buf.writeln(header.map(_escapeCsv).join(','));

  // Data rows.
  for (final a in accounts) {
    final row = <String>[
      a.id,
      a.name,
      templateById[a.templateId] ?? a.templateId,
      a.email,
      ...keys.map((k) => (a.data[k] ?? '').toString()),
    ];
    buf.writeln(row.map(_escapeCsv).join(','));
  }

  return buf.toString();
}

/// Parses a CSV string into a list of raw account maps.
///
/// Returns a list of maps with keys matching the CSV header row.
/// The first row must be a header.
List<Map<String, String>> parseCsv(String csv) {
  final lines = _splitCsvLines(csv);
  if (lines.isEmpty) return [];

  final headers = _parseCsvRow(lines.first);
  final result = <Map<String, String>>[];

  for (var i = 1; i < lines.length; i++) {
    final values = _parseCsvRow(lines[i]);
    final row = <String, String>{};
    for (var j = 0; j < headers.length && j < values.length; j++) {
      row[headers[j]] = values[j];
    }
    if (row.isNotEmpty) result.add(row);
  }

  return result;
}

/// Imports parsed CSV rows into accounts.
///
/// [existingAccounts] is used to detect duplicates (by id or name+template).
/// [allTemplates] is used to resolve template names to IDs.
/// Returns the list of newly created accounts and a list of skipped row messages.
AccountCsvImportResult importAccountsFromCsv({
  required List<Map<String, String>> rows,
  required List<AccountItem> existingAccounts,
  required List<AccountTemplate> allTemplates,
}) {
  final templateByName = <String, String>{};
  for (final t in allTemplates) {
    templateByName[t.title.toLowerCase()] = t.templateId;
  }

  final existingIds = existingAccounts.map((a) => a.id).toSet();
  // Also track name+template combos for duplicate detection.
  final existingNameTemplate = <String>{};
  for (final a in existingAccounts) {
    final t = templateByTitle(allTemplates, a.templateId);
    existingNameTemplate.add('${a.name.toLowerCase()}|${t.toLowerCase()}');
  }

  final imported = <AccountItem>[];
  final skipped = <String>[];
  final now = DateTime.now().millisecondsSinceEpoch;

  for (final row in rows) {
    final id = row['id']?.trim();
    final name = row['name']?.trim() ?? '';
    final templateName = row['template']?.trim() ?? '';
    final email = row['email']?.trim() ?? '';

    if (name.isEmpty) {
      skipped.add('Skipped row: empty name');
      continue;
    }

    // Resolve template.
    final templateId = templateByName[templateName.toLowerCase()];
    if (templateId == null) {
      skipped.add('Skipped "$name": template "$templateName" not found');
      continue;
    }

    // Duplicate detection.
    if (id != null && id.isNotEmpty && existingIds.contains(id)) {
      skipped.add('Skipped "$name": duplicate ID $id');
      continue;
    }
    final nameTemplateKey = '${name.toLowerCase()}|${templateName.toLowerCase()}';
    if (existingNameTemplate.contains(nameTemplateKey)) {
      skipped.add('Skipped "$name": duplicate name+template');
      continue;
    }

    // Build data map from remaining columns.
    final data = <String, String>{};
    for (final entry in row.entries) {
      if (entry.key == 'id' ||
          entry.key == 'name' ||
          entry.key == 'template' ||
          entry.key == 'email') {
        continue;
      }
      if (entry.value.trim().isNotEmpty) {
        data[entry.key] = entry.value.trim();
      }
    }

    final localHlc = Hlc.zero('local');
    final account = AccountItem(
      id: id != null && id.isNotEmpty
          ? id
          : 'acc_${now}_${imported.length}',
      name: name,
      email: email,
      templateId: templateId,
      data: data,
      createdAt: now,
      modifiedAt: now,
      nameHlc: localHlc,
      emailHlc: localHlc,
      dataHlc: {},
    );

    imported.add(account);
    existingIds.add(account.id);
    existingNameTemplate.add(nameTemplateKey);
  }

  return AccountCsvImportResult(imported: imported, skipped: skipped);
}

String templateByTitle(List<AccountTemplate> templates, String templateId) {
  for (final t in templates) {
    if (t.templateId == templateId) return t.title;
  }
  return templateId;
}

/// Escapes a CSV field value.
String _escapeCsv(String value) {
  if (value.contains(',') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Splits CSV text into logical lines, handling quoted newlines.
List<String> _splitCsvLines(String csv) {
  final lines = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < csv.length; i++) {
    final ch = csv[i];
    if (ch == '"') {
      inQuotes = !inQuotes;
      buf.write(ch);
    } else if (ch == '\n' && !inQuotes) {
      lines.add(buf.toString());
      buf.clear();
    } else if (ch == '\r' && !inQuotes) {
      // Skip \r
    } else {
      buf.write(ch);
    }
  }
  if (buf.isNotEmpty) lines.add(buf.toString());

  return lines;
}

/// Parses a single CSV row into its field values.
List<String> _parseCsvRow(String row) {
  final fields = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < row.length; i++) {
    final ch = row[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < row.length && row[i + 1] == '"') {
        buf.write('"');
        i++; // skip the escaped quote
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      fields.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  fields.add(buf.toString());

  return fields;
}

class AccountCsvImportResult {
  final List<AccountItem> imported;
  final List<String> skipped;

  const AccountCsvImportResult({
    required this.imported,
    required this.skipped,
  });
}
