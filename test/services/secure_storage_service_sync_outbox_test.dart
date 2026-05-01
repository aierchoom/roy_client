import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/secure_storage_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String documentsPath;
  final String temporaryPath;

  _FakePathProviderPlatform({
    required this.documentsPath,
    required this.temporaryPath,
  });

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory rootDirectory;
  late Directory documentsDirectory;
  late Directory temporaryDirectory;
  late DatabaseFileCipher cipher;

  setUp(() {
    rootDirectory = Directory.systemTemp.createTempSync(
      'secret_roy_sync_outbox_',
    );
    documentsDirectory = Directory(p.join(rootDirectory.path, 'documents'))
      ..createSync(recursive: true);
    temporaryDirectory = Directory(p.join(rootDirectory.path, 'temp'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsDirectory.path,
      temporaryPath: temporaryDirectory.path,
    );
    cipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, 21)),
    );
  });

  tearDown(() {
    if (rootDirectory.existsSync()) {
      rootDirectory.deleteSync(recursive: true);
    }
  });

  test('recordLocalSyncChange does not coalesce into pushing rows', () async {
    final storage = SecureStorageService(databaseCipher: cipher);
    await storage.initialize(deviceId: 'device_test');
    addTearDown(() => storage.close(dispose: true));

    await _recordAccountChange(storage, afterSnapshot: const {'name': 'first'});
    final first = (await storage.loadOpenLocalSyncChanges(
      vaultId: _vaultId,
    )).single;
    await storage.approveLocalSyncChanges(vaultId: _vaultId, ids: [first.id]);
    await storage.markLocalSyncChangesPushing([first.id]);

    await _recordAccountChange(
      storage,
      afterSnapshot: const {'name': 'second'},
    );

    final changes = await storage.loadOpenLocalSyncChanges(vaultId: _vaultId);
    expect(
      changes.map((change) => change.status),
      contains(LocalSyncStatus.pushing),
    );
    expect(
      changes.map((change) => change.status),
      contains(LocalSyncStatus.pendingReview),
    );
    final pending = changes.singleWhere(
      (change) => change.status == LocalSyncStatus.pendingReview,
    );
    expect(pending.id, isNot(first.id));
    expect(pending.afterSnapshot?['name'], 'second');
  });

  test('terminal outbox updates are guarded to pushing rows', () async {
    final storage = SecureStorageService(databaseCipher: cipher);
    await storage.initialize(deviceId: 'device_test');
    addTearDown(() => storage.close(dispose: true));

    await _recordAccountChange(storage, afterSnapshot: const {'name': 'first'});
    var change = (await storage.loadOpenLocalSyncChanges(
      vaultId: _vaultId,
    )).single;

    await storage.markLocalSyncChangesPushed([change.id]);
    change = (await storage.loadOpenLocalSyncChanges(vaultId: _vaultId)).single;
    expect(change.status, LocalSyncStatus.pendingReview);

    await storage.approveLocalSyncChanges(vaultId: _vaultId, ids: [change.id]);
    await storage.markLocalSyncChangesPushing([change.id]);
    await storage.markLocalSyncChangesPushed([change.id]);

    expect(await storage.loadOpenLocalSyncChanges(vaultId: _vaultId), isEmpty);
  });

  test(
    'ensurePendingSyncOutboxEntries recovers interrupted pushing rows',
    () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      addTearDown(() => storage.close(dispose: true));

      await _recordAccountChange(
        storage,
        afterSnapshot: const {'name': 'first'},
      );
      final change = (await storage.loadOpenLocalSyncChanges(
        vaultId: _vaultId,
      )).single;
      await storage.approveLocalSyncChanges(
        vaultId: _vaultId,
        ids: [change.id],
      );
      await storage.markLocalSyncChangesPushing([change.id]);

      await storage.ensurePendingSyncOutboxEntries(_vaultId);

      final recovered = (await storage.loadOpenLocalSyncChanges(
        vaultId: _vaultId,
      )).single;
      expect(recovered.status, LocalSyncStatus.failed);
      expect(recovered.errorMessage, contains('Push was interrupted'));
    },
  );
}

const _vaultId = 'vault_test';
const _accountId = 'account_1';

Future<void> _recordAccountChange(
  SecureStorageService storage, {
  required Map<String, dynamic> afterSnapshot,
}) {
  return storage.recordLocalSyncChange(
    vaultId: _vaultId,
    entityType: LocalSyncEntityType.account,
    entityId: _accountId,
    action: LocalSyncAction.update,
    title: 'Account',
    beforeSnapshot: const {'name': 'before'},
    afterSnapshot: afterSnapshot,
    baseServerVersion: 1,
  );
}
