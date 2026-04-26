import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
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
  String templateId = 'web_account',
  int createdAt = 1,
}) {
  return AccountItem(
    id: id,
    name: name,
    email: email,
    templateId: templateId,
    data: data,
    createdAt: createdAt,
    nameHlc: nameHlc,
    emailHlc: emailHlc,
    dataHlc: dataHlc,
    syncStatus: syncStatus,
    isDeleted: isDeleted,
    deleteHlc: deleteHlc,
    serverVersion: serverVersion,
  );
}

Map<String, Object?> _normalizedResult(MergeResult result) {
  return {
    'item': result.mergedItem.toJson(),
    'logs': result.conflictLogs
        .map(
          (log) => {
            'accountId': log.accountId,
            'fieldKey': log.fieldKey,
            'fieldValue': log.fieldValue,
            'hlc': log.hlc.toString(),
          },
        )
        .toList(),
  };
}

void main() {
  test('merge is deterministic for the same pair of inputs', () {
    final local = _item(
      id: 'account_deterministic',
      name: 'Local Name',
      email: 'local@example.com',
      nameHlc: const Hlc(40, 0, 'local'),
      emailHlc: const Hlc(20, 0, 'local'),
      data: {'password': 'local-secret', 'note': 'keep-me'},
      dataHlc: {
        'password': const Hlc(20, 0, 'local'),
        'note': const Hlc(40, 0, 'local'),
      },
      serverVersion: 2,
    );

    final remote = _item(
      id: 'account_deterministic',
      name: 'Remote Name',
      email: 'remote@example.com',
      nameHlc: const Hlc(30, 0, 'remote'),
      emailHlc: const Hlc(50, 0, 'remote'),
      data: {'password': 'remote-secret', 'phone': '123'},
      dataHlc: {
        'password': const Hlc(50, 0, 'remote'),
        'phone': const Hlc(50, 0, 'remote'),
      },
      syncStatus: SyncStatus.synchronized,
      serverVersion: 3,
    );

    final first = CrdtMergeEngine.merge(local, remote);
    final second = CrdtMergeEngine.merge(local, remote);

    expect(_normalizedResult(first), _normalizedResult(second));
  });

  test(
    'merged data keys always equal the union of both inputs and keep matching HLC entries',
    () {
      final local = _item(
        id: 'account_union',
        name: 'Local',
        email: 'local@example.com',
        nameHlc: const Hlc(10, 0, 'local'),
        emailHlc: const Hlc(10, 1, 'local'),
        data: {'password': 'local-secret', 'note': 'keep'},
        dataHlc: {
          'password': const Hlc(10, 2, 'local'),
          'note': const Hlc(10, 3, 'local'),
        },
        serverVersion: 1,
      );

      final remote = _item(
        id: 'account_union',
        name: 'Remote',
        email: 'remote@example.com',
        nameHlc: const Hlc(20, 0, 'remote'),
        emailHlc: const Hlc(20, 1, 'remote'),
        data: {'password': 'remote-secret', 'phone': '123', 'url': 'https://x'},
        dataHlc: {
          'password': const Hlc(20, 2, 'remote'),
          'phone': const Hlc(20, 3, 'remote'),
          'url': const Hlc(20, 4, 'remote'),
        },
        syncStatus: SyncStatus.synchronized,
        serverVersion: 2,
      );

      final result = CrdtMergeEngine.merge(local, remote);
      final mergedKeys = result.mergedItem.data.keys.toSet();
      final mergedHlcKeys = result.mergedItem.dataHlc.keys.toSet();
      final expectedKeys = {...local.data.keys, ...remote.data.keys};

      expect(mergedKeys, expectedKeys);
      expect(mergedHlcKeys, expectedKeys);
      expect(
        result.mergedItem.data.values.any((value) => value.isEmpty),
        isFalse,
      );
    },
  );

  test(
    'older remote updates cannot resurrect over a newer local tombstone',
    () {
      final local = _item(
        id: 'account_tombstone',
        name: 'Deleted Local',
        email: 'local@example.com',
        nameHlc: const Hlc(10, 0, 'local'),
        emailHlc: const Hlc(10, 1, 'local'),
        data: {'password': 'local-secret'},
        dataHlc: {'password': const Hlc(10, 2, 'local')},
        isDeleted: true,
        deleteHlc: const Hlc(100, 0, 'local'),
        syncStatus: SyncStatus.pendingPush,
        serverVersion: 4,
      );

      final remote = _item(
        id: 'account_tombstone',
        name: 'Older Remote',
        email: 'remote@example.com',
        nameHlc: const Hlc(80, 0, 'remote'),
        emailHlc: const Hlc(80, 1, 'remote'),
        data: {'password': 'remote-secret'},
        dataHlc: {'password': const Hlc(80, 2, 'remote')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 5,
      );

      final result = CrdtMergeEngine.merge(local, remote);

      expect(result.mergedItem.isDeleted, isTrue);
      expect(result.mergedItem.deleteHlc, const Hlc(100, 0, 'local'));
      expect(result.conflictLogs, isEmpty);
    },
  );

  test(
    'fast-forward merge keeps synchronized status and adopts remote server version',
    () {
      final local = _item(
        id: 'account_fast_forward',
        name: 'Local',
        email: 'local@example.com',
        nameHlc: const Hlc(10, 0, 'local'),
        emailHlc: const Hlc(10, 1, 'local'),
        data: {'password': 'old-secret'},
        dataHlc: {'password': const Hlc(10, 2, 'local')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 1,
      );

      final remote = _item(
        id: 'account_fast_forward',
        name: 'Remote',
        email: 'remote@example.com',
        nameHlc: const Hlc(20, 0, 'remote'),
        emailHlc: const Hlc(20, 1, 'remote'),
        data: {'password': 'new-secret'},
        dataHlc: {'password': const Hlc(20, 2, 'remote')},
        syncStatus: SyncStatus.synchronized,
        serverVersion: 9,
      );

      final result = CrdtMergeEngine.merge(local, remote);

      expect(result.mergedItem.syncStatus, SyncStatus.synchronized);
      expect(result.mergedItem.serverVersion, 9);
      expect(result.mergedItem.name, 'Remote');
      expect(result.mergedItem.email, 'remote@example.com');
      expect(result.mergedItem.data['password'], 'new-secret');
    },
  );

  test(
    'cross-device merge only emits conflict logs for fields that actually diverge',
    () {
      final local = _item(
        id: 'account_logs',
        name: 'Shared Name',
        email: 'local@example.com',
        nameHlc: const Hlc(40, 0, 'local'),
        emailHlc: const Hlc(20, 0, 'local'),
        data: {'password': 'local-secret', 'note': 'same-note'},
        dataHlc: {
          'password': const Hlc(20, 0, 'local'),
          'note': const Hlc(40, 0, 'local'),
        },
        serverVersion: 2,
      );

      final remote = _item(
        id: 'account_logs',
        name: 'Shared Name',
        email: 'remote@example.com',
        nameHlc: const Hlc(40, 0, 'local'),
        emailHlc: const Hlc(50, 0, 'remote'),
        data: {'password': 'remote-secret', 'note': 'same-note'},
        dataHlc: {
          'password': const Hlc(50, 0, 'remote'),
          'note': const Hlc(40, 0, 'local'),
        },
        syncStatus: SyncStatus.synchronized,
        serverVersion: 3,
      );

      final result = CrdtMergeEngine.merge(local, remote);
      final fieldKeys = result.conflictLogs.map((log) => log.fieldKey).toSet();

      expect(fieldKeys, {'email', 'data.password'});
      expect(fieldKeys.contains('name'), isFalse);
      expect(fieldKeys.contains('data.note'), isFalse);
      expect(
        result.conflictLogs.every((log) => log.accountId == 'account_logs'),
        isTrue,
      );
    },
  );
}
