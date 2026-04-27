import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/hlc.dart';
import '../sync/crdt_merge_engine.dart';
import 'database_file_cipher.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

enum StorageItemType { account, template, setting }

class SecureStorageService {
  static const String _databaseName = 'secret_roy_vault.db';
  static const String _encryptedDatabaseName = 'secret_roy_vault.db.enc';
  static const String _workingDatabaseName = 'secret_roy_vault.runtime.db';
  static const int _databaseVersion = 4;

  DatabaseFileCipher? _databaseCipher;

  dynamic _database;
  StreamController<StorageChangeEvent> _changeController =
      StreamController<StorageChangeEvent>.broadcast();

  String _deviceId = 'local';
  String? _encryptedDatabasePath;
  String? _workingDatabasePath;
  String? _legacyDatabasePath;

  SecureStorageService({DatabaseFileCipher? databaseCipher})
    : _databaseCipher = databaseCipher;

  Stream<StorageChangeEvent> get onChange => _changeController.stream;
  bool get isOpen => _database?.isOpen ?? false;

  void setDatabaseCipher(DatabaseFileCipher cipher) {
    _databaseCipher = cipher;
  }

  void clearDatabaseCipher() {
    _databaseCipher = null;
  }

  Future<void> rotateDatabaseCipher(DatabaseFileCipher cipher) async {
    _databaseCipher = cipher;
    if (isOpen) {
      await _persistEncryptedDatabase();
    }
  }

  Future<void> initialize({String deviceId = 'local'}) async {
    _deviceId = deviceId;
    if (_changeController.isClosed) {
      _changeController = StreamController<StorageChangeEvent>.broadcast();
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final temporaryDirectory = await getTemporaryDirectory();
    _legacyDatabasePath = join(documentsDirectory.path, _databaseName);
    _encryptedDatabasePath = join(
      documentsDirectory.path,
      _encryptedDatabaseName,
    );
    _workingDatabasePath = join(
      temporaryDirectory.path,
      'secret_roy',
      _workingDatabaseName,
    );

    if (_databaseCipher == null) {
      throw StateError('Database file cipher is not configured.');
    }

    if (isOpen) {
      await _persistEncryptedDatabase();
      return;
    }

    try {
      await _prepareWorkingDatabase();
      await _openAndInitialize(_workingDatabasePath!);
      await _setRuntimePragmas();
      await _persistEncryptedDatabase();
      await _deleteLegacyPlaintextDatabase();
    } catch (e) {
      final backupPath = await _backupUnreadableDatabase(
        _encryptedDatabasePath!,
      );
      await _deleteWorkingDatabase();
      if (kDebugMode) {
        debugPrint('Failed to open database safely: $e');
      }
      throw StorageOpenException(
        originalError: e.toString(),
        backupPath: backupPath,
      );
    }
  }

  Future<void> _openAndInitialize(String databasePath) async {
    if (_isDesktop) {
      ffi.sqfliteFfiInit();
      _database = await ffi.databaseFactoryFfi.openDatabase(
        databasePath,
        options: ffi.OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: (db, version) => _onCreate(db, version),
          onUpgrade: (db, oldVersion, newVersion) =>
              _onUpgrade(db, oldVersion, newVersion),
        ),
      );
      return;
    }

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close({bool dispose = false}) async {
    final hadOpenDatabase = isOpen;
    if (hadOpenDatabase) {
      await _checkpointRuntimeDatabase();
    }

    await _database?.close();
    _database = null;

    if (hadOpenDatabase) {
      await _persistEncryptedDatabase(databaseIsOpen: false);
      await _deleteWorkingDatabase();
    }

    if (dispose && !_changeController.isClosed) {
      await _changeController.close();
    }
  }

  Future<bool> isDatabaseInitialized() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = join(documentsDirectory.path, _encryptedDatabaseName);
    return File(databasePath).existsSync();
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final temporaryDirectory = await getTemporaryDirectory();
    _legacyDatabasePath = join(documentsDirectory.path, _databaseName);
    _encryptedDatabasePath = join(
      documentsDirectory.path,
      _encryptedDatabaseName,
    );
    _workingDatabasePath = join(
      temporaryDirectory.path,
      'secret_roy',
      _workingDatabaseName,
    );

    try {
      await _deleteDatabaseFamily(_encryptedDatabasePath!);
      await _deleteDatabaseFamily(_legacyDatabasePath!);
      await _deleteWorkingDatabase();
      await _deleteCorruptBackups(_encryptedDatabasePath!);
      await _deleteCorruptBackups(_legacyDatabasePath!);
      clearDatabaseCipher();
      debugPrint('[Storage] Encrypted database files deleted manually.');
    } catch (e) {
      debugPrint('[Storage] Failed to delete database file: $e');
    }
  }

  Future<void> clearAllData() async {
    if (!isOpen) return;
    try {
      await _database!.execute('DELETE FROM accounts');
      await _database!.execute('DELETE FROM templates WHERE is_custom = 1');
      await _database!.execute('DELETE FROM conflict_logs');
      await _persistAfterMutation();
      _notifyChange(
        StorageChangeEvent(
          type: StorageItemType.account,
          action: StorageAction.delete,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to clear all data: $e');
      }
    }
  }

  Future<String> getDatabaseFilePath() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return join(documentsDirectory.path, _encryptedDatabaseName);
  }

  Future<String?> _backupUnreadableDatabase(String databasePath) async {
    final dbFile = File(databasePath);
    if (!dbFile.existsSync()) {
      return null;
    }

    final backupPath =
        '$databasePath.corrupt.${DateTime.now().millisecondsSinceEpoch}.bak';
    try {
      await dbFile.copy(backupPath);
      return backupPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to back up unreadable database: $e');
      }
      return null;
    }
  }

  Future<void> replaceDatabase(Uint8List newDbBytes) async {
    final databasePath = await getDatabaseFilePath();

    await _database?.close();
    _database = null;

    _encryptedDatabasePath = databasePath;
    final cipher = _requireDatabaseCipher();
    final encryptedBytes = await cipher.encrypt(newDbBytes);
    await _writeFileAtomically(databasePath, encryptedBytes);
    await _deleteWorkingDatabase();
    await _deleteLegacyPlaintextDatabase();
  }

  DatabaseFileCipher _requireDatabaseCipher() {
    final cipher = _databaseCipher;
    if (cipher == null) {
      throw StateError('Database file cipher is not configured.');
    }
    return cipher;
  }

  Future<void> _prepareWorkingDatabase() async {
    final workingPath = _workingDatabasePath!;
    await _deleteWorkingDatabase();
    await Directory(dirname(workingPath)).create(recursive: true);

    final encryptedFile = File(_encryptedDatabasePath!);
    if (!encryptedFile.existsSync()) {
      return;
    }

    final encryptedBytes = Uint8List.fromList(
      await encryptedFile.readAsBytes(),
    );
    final plaintextBytes = await _requireDatabaseCipher().decrypt(
      encryptedBytes,
    );
    await _writeFileAtomically(workingPath, plaintextBytes);
  }

  Future<void> _setRuntimePragmas() async {
    await _executePragmaSafely('PRAGMA journal_mode = DELETE');
    await _executePragmaSafely('PRAGMA synchronous = FULL');
  }

  Future<void> _executePragmaSafely(String sql) async {
    if (!isOpen) return;
    try {
      await _database!.execute(sql);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to apply SQLite pragma "$sql": $e');
      }
    }
  }

  Future<void> _checkpointRuntimeDatabase() async {
    if (!isOpen) return;
    try {
      await _database!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to checkpoint runtime database: $e');
      }
    }
  }

  Future<void> _persistEncryptedDatabase({bool databaseIsOpen = true}) async {
    final encryptedPath = _encryptedDatabasePath;
    final workingPath = _workingDatabasePath;
    if (encryptedPath == null || workingPath == null) {
      return;
    }

    if (databaseIsOpen && isOpen) {
      await _checkpointRuntimeDatabase();
    }

    final workingFile = File(workingPath);
    if (!workingFile.existsSync()) {
      return;
    }

    final plaintextBytes = Uint8List.fromList(await workingFile.readAsBytes());
    final encryptedBytes = await _requireDatabaseCipher().encrypt(
      plaintextBytes,
    );
    await _writeFileAtomically(encryptedPath, encryptedBytes);
  }

  Future<void> _persistAfterMutation() async {
    await _persistEncryptedDatabase();
  }

  Future<void> _writeFileAtomically(String targetPath, Uint8List bytes) async {
    await Directory(dirname(targetPath)).create(recursive: true);

    final targetFile = File(targetPath);
    final tempFile = File('$targetPath.tmp');
    final backupFile = File('$targetPath.bak');

    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await tempFile.writeAsBytes(bytes, flush: true);

    if (backupFile.existsSync()) {
      await backupFile.delete();
    }
    if (targetFile.existsSync()) {
      await targetFile.rename(backupFile.path);
    }

    try {
      await tempFile.rename(targetPath);
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (backupFile.existsSync() && !targetFile.existsSync()) {
        await backupFile.rename(targetPath);
      }
      rethrow;
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }

  Future<void> _deleteWorkingDatabase() async {
    final workingPath = _workingDatabasePath;
    if (workingPath == null) {
      return;
    }
    await _deleteDatabaseFamily(workingPath);
  }

  Future<void> _deleteLegacyPlaintextDatabase() async {
    final legacyPath = _legacyDatabasePath;
    if (legacyPath == null) {
      return;
    }
    await _deleteDatabaseFamily(legacyPath);
  }

  Future<void> _deleteDatabaseFamily(String basePath) async {
    final paths = [
      basePath,
      '$basePath-journal',
      '$basePath-wal',
      '$basePath-shm',
      '$basePath.tmp',
      '$basePath.bak',
    ];

    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> _deleteCorruptBackups(String basePath) async {
    final parent = Directory(dirname(basePath));
    if (!parent.existsSync()) {
      return;
    }
    final baseFileName = basename(basePath);
    await for (final entity in parent.list()) {
      if (entity is! File) {
        continue;
      }
      final name = basename(entity.path);
      if (name.startsWith('$baseFileName.corrupt.')) {
        await entity.delete();
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        template_id TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        name_hlc TEXT,
        email_hlc TEXT,
        data_hlc TEXT,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE conflict_logs (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        hlc TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT,
        icon_code_point INTEGER,
        category TEXT,
        fields TEXT NOT NULL,
        is_custom INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        hlc TEXT,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_accounts_template ON accounts(template_id)',
    );
    await db.execute(
      'CREATE INDEX idx_accounts_modified ON accounts(modified_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE templates ADD COLUMN category TEXT');
    }

    if (oldVersion < 3) {
      // Data Migration for Phase 2 HLC Structure
      await db.execute('ALTER TABLE accounts ADD COLUMN name_hlc TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN email_hlc TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN data_hlc TEXT');
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      // sync_status 1 = pendingPush (since migration changes the data, push it up)
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN sync_status INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE accounts ADD COLUMN delete_hlc TEXT');

      await db.execute('''
        CREATE TABLE conflict_logs (
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT,
          hlc TEXT NOT NULL,
          saved_at INTEGER NOT NULL
        )
      ''');

      // Populate default HLCs for old accounts so they don't break the new model
      final stamp = '${DateTime.now().millisecondsSinceEpoch}-0-migration';
      await db.execute(
        'UPDATE accounts SET name_hlc = ?, email_hlc = ?, data_hlc = ?, sync_status = 1',
        [stamp, stamp, '{}'],
      );
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE templates ADD COLUMN hlc TEXT');
      await db.execute(
        'ALTER TABLE templates ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE templates ADD COLUMN sync_status INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE templates ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE templates ADD COLUMN delete_hlc TEXT');
    }
  }

  Future<List<Map<String, dynamic>>> _query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final raw = await _database!.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Future<List<AccountItem>> loadAccounts({bool includeDeleted = false}) async {
    if (!isOpen) return [];

    try {
      final rows = await _query(
        'accounts',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'modified_at DESC',
      );
      return rows.map(_mapToAccountItem).whereType<AccountItem>().toList();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('Failed to load accounts: $e');
        debugPrint(stack.toString());
      }
      return [];
    }
  }

  Future<List<AccountItem>> loadPendingSyncAccounts() async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'accounts',
        where: 'sync_status = ?',
        whereArgs: [SyncStatus.pendingPush.index],
        orderBy: 'modified_at DESC',
      );
      return rows.map(_mapToAccountItem).whereType<AccountItem>().toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load pending sync accounts: $e');
      }
      return [];
    }
  }

  Future<AccountItem?> getAccountById(
    String id, {
    bool includeDeleted = false,
  }) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'accounts',
        where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return _mapToAccountItem(rows.first);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to load account by id: $e');
      }
      return null;
    }
  }

  Future<void> saveAccount(
    AccountItem account, {
    bool isSyncMerge = false,
  }) async {
    if (!isOpen) return;

    AccountItem itemToSave = account;

    if (!isSyncMerge) {
      // Local Save logic: Stamp HLCs on explicitly modified fields
      final existingRows = await _query(
        'accounts',
        where: 'id = ?',
        whereArgs: [account.id],
      );
      Hlc newStamp = Hlc.now(_deviceId);

      if (existingRows.isNotEmpty) {
        final old = _mapToAccountItem(existingRows.first);
        if (old != null) {
          final nHlc = account.name != old.name ? newStamp : old.nameHlc;
          final eHlc = account.email != old.email ? newStamp : old.emailHlc;

          Map<String, Hlc> dHlc = Map.from(old.dataHlc);
          account.data.forEach((k, v) {
            if (old.data[k] != v) {
              dHlc[k] = newStamp;
            }
          });

          itemToSave = account.copyWith(
            nameHlc: nHlc,
            emailHlc: eHlc,
            dataHlc: dHlc,
            syncStatus: SyncStatus.pendingPush,
            isDeleted: false,
            serverVersion: old.serverVersion,
          );
        }
      } else {
        // Completely new account being saved
        Map<String, Hlc> dHlc = {};
        account.data.forEach((k, v) {
          dHlc[k] = newStamp;
        });
        itemToSave = account.copyWith(
          nameHlc: newStamp,
          emailHlc: newStamp,
          dataHlc: dHlc,
          syncStatus: SyncStatus.pendingPush,
          isDeleted: false,
        );
      }
    }

    await _database!.insert('accounts', {
      'id': itemToSave.id,
      'name': itemToSave.name,
      'email': itemToSave.email,
      'template_id': itemToSave.templateId,
      'data': jsonEncode(itemToSave.data),
      'created_at': itemToSave.createdAt,
      'modified_at': DateTime.now().millisecondsSinceEpoch,
      'name_hlc': itemToSave.nameHlc.toString(),
      'email_hlc': itemToSave.emailHlc.toString(),
      'data_hlc': jsonEncode(
        itemToSave.dataHlc.map((k, v) => MapEntry(k, v.toString())),
      ),
      'server_version': itemToSave.serverVersion,
      'sync_status': itemToSave.syncStatus.index,
      'is_deleted': itemToSave.isDeleted ? 1 : 0,
      'delete_hlc': itemToSave.deleteHlc?.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.save,
        id: itemToSave.id,
      ),
    );
  }

  Future<void> deleteAccount(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen) return;

    Hlc stamp = syncDeleteHlc ?? Hlc.now(_deviceId);

    // Apply Soft Delete (Tombstone)
    await _database!.update(
      'accounts',
      {
        'is_deleted': 1,
        'delete_hlc': stamp.toString(),
        'sync_status': SyncStatus.pendingPush.index,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<int> countAccountsByTemplate(String templateId) async {
    if (!isOpen) return 0;
    try {
      final rows = await _database!.rawQuery(
        'SELECT COUNT(*) AS count FROM accounts WHERE template_id = ? AND is_deleted = 0',
        [templateId],
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to count accounts by template: $e');
      return 0;
    }
  }

  Future<void> saveConflictLogs(List<ConflictLog> logs) async {
    if (!isOpen || logs.isEmpty) return;
    final batch = _database!.batch();
    for (final log in logs) {
      batch.insert(
        'conflict_logs',
        log.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.save,
        id: logs.first.accountId,
      ),
    );
  }

  Future<List<ConflictLog>> getConflictLogs(String accountId) async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'conflict_logs',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'saved_at DESC',
      );
      return rows.map((r) => ConflictLog.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteConflictLog(String logId) async {
    if (!isOpen) return;
    await _database!.delete(
      'conflict_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
    await _persistAfterMutation();
  }

  AccountItem? _mapToAccountItem(Map<String, dynamic> row) {
    try {
      final dataStr = row['data'] as String;
      final parsedData = jsonDecode(dataStr);
      final mapData = parsedData is Map
          ? parsedData.map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
            )
          : <String, String>{};

      Map<String, dynamic> dataHlcMap = {};
      if (row['data_hlc'] != null && row['data_hlc'].toString().isNotEmpty) {
        final parsedHlcStr = jsonDecode(row['data_hlc'] as String);
        if (parsedHlcStr is Map) {
          dataHlcMap = Map<String, dynamic>.from(parsedHlcStr);
        }
      }

      final dummyHlc = Hlc.zero('local');

      return AccountItem(
        id: row['id'] as String,
        name: row['name'] as String,
        email: row['email'] as String? ?? '',
        templateId: row['template_id'] as String,
        data: Map<String, String>.from(mapData),
        createdAt: row['created_at'] as int,
        nameHlc: row['name_hlc'] != null
            ? Hlc.parse(row['name_hlc'])
            : dummyHlc,
        emailHlc: row['email_hlc'] != null
            ? Hlc.parse(row['email_hlc'])
            : dummyHlc,
        dataHlc: dataHlcMap.map((k, v) => MapEntry(k, Hlc.parse(v.toString()))),
        serverVersion: row['server_version'] as int? ?? 0,
        syncStatus:
            SyncStatus.values[(row['sync_status'] as int? ?? 1).clamp(0, 2)],
        isDeleted: row['is_deleted'] == 1,
        deleteHlc: row['delete_hlc'] != null
            ? Hlc.parse(row['delete_hlc'])
            : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Skipping unreadable account row: $e');
      return null;
    }
  }

  Future<List<AccountTemplate>> loadCustomTemplates({
    bool includeDeleted = false,
  }) async {
    if (!isOpen) return [];
    try {
      final where = includeDeleted
          ? 'is_custom = ?'
          : 'is_custom = ? AND is_deleted = 0';
      final rows = await _query(
        'templates',
        where: where,
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );
      return rows
          .map((row) => _mapToAccountTemplate(row, isCustom: true))
          .whereType<AccountTemplate>()
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load templates: $e');
      return [];
    }
  }

  Future<List<AccountTemplate>> loadDirtyTemplates() async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'templates',
        where: 'sync_status != ? AND is_custom = 1',
        whereArgs: [SyncStatus.synchronized.index],
      );
      return rows
          .map((row) => _mapToAccountTemplate(row, isCustom: true))
          .whereType<AccountTemplate>()
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to load dirty templates: $e');
      return [];
    }
  }

  Future<AccountTemplate?> loadTemplateById(String id) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'templates',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapToAccountTemplate(
        rows.first,
        isCustom: rows.first['is_custom'] == 1,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> saveTemplate(
    AccountTemplate template, {
    bool isSyncMerge = false,
  }) async {
    if (!isOpen) return;

    AccountTemplate itemToSave;
    if (isSyncMerge) {
      final existing = await loadTemplateById(template.templateId);
      if (existing != null) {
        itemToSave = CrdtMergeEngine.mergeTemplate(existing, template);
      } else {
        itemToSave = template;
      }
    } else {
      Hlc newStamp = Hlc.now(_deviceId);
      final existing = await loadTemplateById(template.templateId);
      if (existing != null) {
        itemToSave = template.copyWith(
          hlc: newStamp,
          syncStatus: SyncStatus.pendingPush,
          serverVersion: existing.serverVersion,
        );
      } else {
        itemToSave = template.copyWith(
          hlc: newStamp,
          syncStatus: SyncStatus.pendingPush,
        );
      }
    }

    await _database!.insert('templates', {
      'id': itemToSave.templateId,
      'title': itemToSave.title,
      'subtitle': itemToSave.subTitle,
      'icon_code_point': templateIconStorageValue(itemToSave.icon),
      'category': itemToSave.category.name,
      'fields': jsonEncode(itemToSave.fields.map((f) => f.toJson()).toList()),
      'is_custom': itemToSave.isCustom ? 1 : 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'hlc': itemToSave.hlc?.toString(),
      'server_version': itemToSave.serverVersion,
      'sync_status': itemToSave.syncStatus.index,
      'is_deleted': itemToSave.isDeleted ? 1 : 0,
      'delete_hlc': itemToSave.deleteHlc?.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.template,
        action: StorageAction.save,
        id: itemToSave.templateId,
      ),
    );
  }

  Future<void> deleteTemplate(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen) return;

    if (!isSyncMerge) {
      final usageCount = await countAccountsByTemplate(id);
      if (usageCount > 0) {
        throw TemplateInUseException(templateId: id, usageCount: usageCount);
      }
    }

    Hlc stamp = syncDeleteHlc ?? Hlc.now(_deviceId);

    await _database!.update(
      'templates',
      {
        'is_deleted': 1,
        'delete_hlc': stamp.toString(),
        'sync_status': SyncStatus.pendingPush.index,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.template,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  AccountTemplate? _mapToAccountTemplate(
    Map<String, dynamic> row, {
    required bool isCustom,
  }) {
    try {
      final iconCodePoint = row['icon_code_point'] as int?;
      return AccountTemplate(
        templateId: row['id'] as String,
        title: row['title'] as String,
        subTitle: row['subtitle'] as String? ?? '',
        icon: templateIconFromStorageValue(iconCodePoint),
        category: templateCategoryFromString(row['category'] as String?),
        fields: (jsonDecode(row['fields'] as String) as List)
            .map(
              (field) => AccountField.fromJson(field as Map<String, dynamic>),
            )
            .toList(),
        isCustom: isCustom,
        hlc: row['hlc'] != null ? Hlc.parse(row['hlc'] as String) : null,
        serverVersion: row['server_version'] as int? ?? 0,
        syncStatus:
            SyncStatus.values[row['sync_status'] as int? ??
                SyncStatus.synchronized.index],
        isDeleted: row['is_deleted'] == 1,
        deleteHlc: row['delete_hlc'] != null
            ? Hlc.parse(row['delete_hlc'] as String)
            : null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Skipping unreadable template row: $e');
      return null;
    }
  }

  Future<String?> getSetting(String key) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    if (!isOpen) return;
    await _database!.insert('settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.setting,
        action: StorageAction.save,
        id: key,
      ),
    );
  }

  void _notifyChange(StorageChangeEvent event) {
    _changeController.add(event);
  }
}

class StorageChangeEvent {
  final StorageItemType type;
  final StorageAction action;
  final String? id;

  StorageChangeEvent({required this.type, required this.action, this.id});
}

enum StorageAction { save, delete }

class StorageOpenException implements Exception {
  final String originalError;
  final String? backupPath;

  const StorageOpenException({required this.originalError, this.backupPath});

  @override
  String toString() {
    if (backupPath == null) {
      return 'StorageOpenException(originalError: $originalError)';
    }
    return 'StorageOpenException(originalError: $originalError, backupPath: $backupPath)';
  }
}

class TemplateInUseException implements Exception {
  final String templateId;
  final int usageCount;

  const TemplateInUseException({
    required this.templateId,
    required this.usageCount,
  });

  @override
  String toString() =>
      'TemplateInUseException(templateId: $templateId, usageCount: $usageCount)';
}
