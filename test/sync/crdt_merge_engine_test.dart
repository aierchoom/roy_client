import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/sync/crdt_merge_engine.dart';

AccountItem _item({
  required String id,
  required String name,
  required String email,
  required Hlc nameHlc,
  required Hlc emailHlc,
  required Map<String, String> data,
  required Map<String, Hlc> dataHlc,
  bool isDeleted = false,
  Hlc? deleteHlc,
  SyncStatus syncStatus = SyncStatus.pendingPush,
  int serverVersion = 0,
}) {
  return AccountItem(
    id: id,
    name: name,
    email: email,
    templateId: 'web_account',
    data: data,
    createdAt: 1,
    nameHlc: nameHlc,
    emailHlc: emailHlc,
    dataHlc: dataHlc,
    syncStatus: syncStatus,
    isDeleted: isDeleted,
    deleteHlc: deleteHlc,
    serverVersion: serverVersion,
  );
}

void main() {
  test('newer remote tombstone wins over older local edits', () {
    final local = _item(
      id: 'account_1',
      name: 'Local Name',
      email: 'local@example.com',
      nameHlc: const Hlc(10, 0, 'local'),
      emailHlc: const Hlc(10, 0, 'local'),
      data: {'password': 'local-secret'},
      dataHlc: {'password': const Hlc(10, 0, 'local')},
    );

    final remote = _item(
      id: 'account_1',
      name: 'Remote Name',
      email: 'remote@example.com',
      nameHlc: const Hlc(11, 0, 'remote'),
      emailHlc: const Hlc(11, 0, 'remote'),
      data: {'password': 'remote-secret'},
      dataHlc: {'password': const Hlc(11, 0, 'remote')},
      isDeleted: true,
      deleteHlc: const Hlc(20, 0, 'remote'),
      syncStatus: SyncStatus.synchronized,
      serverVersion: 3,
    );

    final result = CrdtMergeEngine.merge(local, remote);

    expect(result.mergedItem.isDeleted, isTrue);
    expect(result.mergedItem.deleteHlc, const Hlc(20, 0, 'remote'));
    expect(result.mergedItem.syncStatus, SyncStatus.synchronized);
  });

  test(
    'cross-device field merge enters conflict state and preserves conflicts',
    () {
      final local = _item(
        id: 'account_2',
        name: 'Local Name',
        email: 'old@example.com',
        nameHlc: const Hlc(40, 0, 'local'),
        emailHlc: const Hlc(20, 0, 'local'),
        data: {'password': 'local-secret'},
        dataHlc: {'password': const Hlc(20, 0, 'local')},
        serverVersion: 2,
      );

      final remote = _item(
        id: 'account_2',
        name: 'Remote Name',
        email: 'remote@example.com',
        nameHlc: const Hlc(30, 0, 'remote'),
        emailHlc: const Hlc(50, 0, 'remote'),
        data: {'password': 'remote-secret'},
        dataHlc: {'password': const Hlc(50, 0, 'remote')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 3,
      );

      final result = CrdtMergeEngine.merge(local, remote);

      expect(result.mergedItem.name, 'Local Name');
      expect(result.mergedItem.email, 'remote@example.com');
      expect(result.mergedItem.data['password'], 'remote-secret');
      expect(result.mergedItem.syncStatus, SyncStatus.conflict);
      expect(result.conflictLogs, isNotEmpty);
    },
  );

  group('CrdtMergeEngine.mergeTemplate', () {
    AccountTemplate buildTemplate({
      required String templateId,
      required Hlc hlc,
      String title = 'Template',
      String subTitle = '',
      List<AccountField> fields = const [],
      Map<String, Hlc> fieldHlc = const {},
      SyncStatus syncStatus = SyncStatus.synchronized,
      int serverVersion = 0,
      bool isDeleted = false,
      Hlc? deleteHlc,
    }) {
      return AccountTemplate(
        templateId: templateId,
        title: title,
        subTitle: subTitle,
        category: TemplateCategory.custom,
        fields: fields,
        hlc: hlc,
        fieldHlc: fieldHlc,
        syncStatus: syncStatus,
        serverVersion: serverVersion,
        isDeleted: isDeleted,
        deleteHlc: deleteHlc,
      );
    }

    AccountField buildField(String key, String label) {
      return AccountField(
        fieldKey: key,
        label: label,
        attributes: const AccountFieldAttributes(type: AccountFieldType.text),
      );
    }

    test('fast-forward when remote is newer for all fields', () {
      final local = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(10, 0, 'local'),
        title: 'Old',
        fields: [buildField('a', 'A')],
        fieldHlc: {'a': const Hlc(10, 0, 'local')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 1,
      );

      final remote = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(20, 0, 'remote'),
        title: 'New',
        fields: [buildField('a', 'A Changed')],
        fieldHlc: {'a': const Hlc(20, 0, 'remote')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 2,
      );

      final merged = CrdtMergeEngine.mergeTemplate(local, remote);

      expect(merged.title, 'New');
      expect(merged.fields.first.label, 'A Changed');
      expect(merged.syncStatus, SyncStatus.synchronized);
      expect(merged.serverVersion, 2);
    });

    test('local wins top-level, remote wins field definition', () {
      final local = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(30, 0, 'local'),
        title: 'Local Title',
        fields: [buildField('a', 'Local A')],
        fieldHlc: {'a': const Hlc(10, 0, 'local')},
      );

      final remote = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(20, 0, 'remote'),
        title: 'Remote Title',
        fields: [buildField('a', 'Remote A')],
        fieldHlc: {'a': const Hlc(25, 0, 'remote')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 2,
      );

      final merged = CrdtMergeEngine.mergeTemplate(local, remote);

      expect(merged.title, 'Local Title');
      expect(merged.fields.first.label, 'Remote A');
      expect(merged.syncStatus, SyncStatus.pendingPush);
      expect(merged.serverVersion, 2);
    });

    test('preserves fields from both sides with per-field LWW', () {
      final local = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(20, 0, 'local'),
        title: 'Local',
        fields: [buildField('a', 'A Local'), buildField('b', 'B Local')],
        fieldHlc: {
          'a': const Hlc(20, 0, 'local'),
          'b': const Hlc(5, 0, 'local'),
        },
      );

      final remote = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(15, 0, 'remote'),
        title: 'Remote',
        fields: [buildField('a', 'A Remote'), buildField('c', 'C Remote')],
        fieldHlc: {
          'a': const Hlc(10, 0, 'remote'),
          'c': const Hlc(15, 0, 'remote'),
        },
        syncStatus: SyncStatus.synchronized,
        serverVersion: 3,
      );

      final merged = CrdtMergeEngine.mergeTemplate(local, remote);

      expect(merged.title, 'Local');
      final labels = {for (final f in merged.fields) f.fieldKey: f.label};
      expect(labels, {'a': 'A Local', 'b': 'B Local', 'c': 'C Remote'});
      expect(merged.fieldHlc['a'], const Hlc(20, 0, 'local'));
      expect(merged.fieldHlc['b'], const Hlc(5, 0, 'local'));
      expect(merged.fieldHlc['c'], const Hlc(15, 0, 'remote'));
    });

    test('same payload returns remote with max server version', () {
      final local = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(10, 0, 'local'),
        title: 'Same',
        fields: [buildField('a', 'A')],
        fieldHlc: {'a': const Hlc(10, 0, 'local')},
        serverVersion: 5,
      );

      final remote = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(10, 0, 'local'),
        title: 'Same',
        fields: [buildField('a', 'A')],
        fieldHlc: {'a': const Hlc(10, 0, 'local')},
        serverVersion: 3,
      );

      final merged = CrdtMergeEngine.mergeTemplate(local, remote);

      expect(merged.serverVersion, 5);
      expect(merged.syncStatus, SyncStatus.synchronized);
    });

    test('marks conflict when local had pending push', () {
      final local = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(20, 0, 'local'),
        title: 'Local',
        fields: [buildField('a', 'A Local')],
        fieldHlc: {'a': const Hlc(20, 0, 'local')},
        syncStatus: SyncStatus.pendingPush,
        serverVersion: 1,
      );

      final remote = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(15, 0, 'remote'),
        title: 'Remote',
        fields: [buildField('a', 'A Remote')],
        fieldHlc: {'a': const Hlc(15, 0, 'remote')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 2,
      );

      final merged = CrdtMergeEngine.mergeTemplate(local, remote);

      expect(merged.syncStatus, SyncStatus.conflict);
    });

    test('newer remote tombstone wins', () {
      final local = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(10, 0, 'local'),
        title: 'Local',
        fields: [buildField('a', 'A')],
        fieldHlc: {'a': const Hlc(10, 0, 'local')},
      );

      final remote = buildTemplate(
        templateId: 't1',
        hlc: const Hlc(20, 0, 'remote'),
        title: 'Remote',
        isDeleted: true,
        deleteHlc: const Hlc(30, 0, 'remote'),
        syncStatus: SyncStatus.synchronized,
        serverVersion: 2,
      );

      final merged = CrdtMergeEngine.mergeTemplate(local, remote);

      expect(merged.isDeleted, isTrue);
      expect(merged.deleteHlc, const Hlc(30, 0, 'remote'));
      expect(merged.syncStatus, SyncStatus.synchronized);
    });
  });
}
