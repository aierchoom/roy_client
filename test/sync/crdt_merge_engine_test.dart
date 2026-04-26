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
}
