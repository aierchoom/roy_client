import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_server_test_harness.dart';

void main() {
  const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const privateKey =
      'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const symmetricKey =
      'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('device B pulls an account created and pushed by device A', () async {
    final server = await InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final clientA = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final clientB = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_bbbbbb222222',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    clientA.storage.accounts['account_1'] = baseItem(
      id: 'account_1',
      name: 'Primary Account',
      email: 'owner@example.com',
      password: 'super-secret',
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
      emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
      passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
    );

    final pushResult = await clientA.syncService.syncNow();
    final pullResult = await clientB.syncService.syncNow();
    final pulledItem = clientB.storage.accounts['account_1'];

    expect(pushResult.success, isTrue);
    expect(pushResult.pushed, isTrue);
    expect(server.currentVersion, 1);
    expect(pullResult.success, isTrue);
    expect(pullResult.pulled, isTrue);
    expect(pulledItem, isNotNull);
    expect(pulledItem!.name, 'Primary Account');
    expect(pulledItem.email, 'owner@example.com');
    expect(pulledItem.data['password'], 'super-secret');
    expect(pulledItem.syncStatus, SyncStatus.synchronized);
    expect(pulledItem.serverVersion, 1);
  });

  test('trusted devices sync independent 2FA credentials', () async {
    final server = await InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final clientA = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final clientB = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_bbbbbb222222',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    final totpConfigStr = totpConfig();
    clientA.storage.totpCredentials['totp_1'] = baseTotpCredential(
      id: 'totp_1',
      label: 'Example 2FA',
      config: totpConfigStr,
      linkedAccountIds: const ['account_1'],
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      labelHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
      configHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
      linksHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
    );

    final pushResult = await clientA.syncService.syncNow();
    final pullResult = await clientB.syncService.syncNow();
    final pushedCredential = clientA.storage.totpCredentials['totp_1']!;
    final pulledCredential = clientB.storage.totpCredentials['totp_1']!;
    final fixedTime = DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true);
    final pushedCode = const TotpService()
        .generate(pushedCredential.config, at: fixedTime)
        .value;
    final pulledCode = const TotpService()
        .generate(pulledCredential.config, at: fixedTime)
        .value;
    final serverPayload =
        server.getItem('totp_1')?['encrypted_signed_payload'] as String?;

    expect(pushResult.success, isTrue);
    expect(pushResult.pushed, isTrue);
    expect(pullResult.success, isTrue);
    expect(pullResult.pulled, isTrue);
    expect(pulledCredential.config.secret, pushedCredential.config.secret);
    expect(pulledCredential.linkedAccountIds, ['account_1']);
    expect(pushedCode, '287082');
    expect(pulledCode, pushedCode);
    expect(pulledCredential.syncStatus, SyncStatus.synchronized);
    expect(serverPayload, isNotNull);
    expect(serverPayload, contains('sroy-sync:'));
    expect(serverPayload, isNot(contains('GEZDGNBVGY3TQOJQ')));
    expect(serverPayload, isNot(contains('otpauth://')));
  });

  test(
    'concurrent edits on two devices merge into a reviewable conflict state',
    () async {
      final server = await InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final clientA = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final clientB = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_bbbbbb222222',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      clientA.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      await clientA.syncService.syncNow();
      await clientB.syncService.syncNow();

      clientA.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Updated By A',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(20, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      clientB.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'b@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(30, 0, 'device_bbbbbb222222'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );

      final pushAResult = await clientA.syncService.syncNow();
      final mergeBResult = await clientB.syncService.syncNow();
      final mergedItem = clientB.storage.accounts['account_1']!;
      final conflictLogs =
          clientB.storage.conflictLogs['account_1'] ?? const [];

      expect(pushAResult.success, isTrue);
      expect(pushAResult.pushed, isTrue);
      expect(server.currentVersion, 2);
      expect(mergeBResult.success, isTrue);
      expect(mergeBResult.pulled, isTrue);
      expect(mergedItem.name, 'Updated By A');
      expect(mergedItem.email, 'b@example.com');
      expect(mergedItem.syncStatus, SyncStatus.conflict);
      expect(conflictLogs, isNotEmpty);
      expect(
        conflictLogs.map((log) => log.fieldKey).toSet().contains('email'),
        isTrue,
      );
    },
  );

  test('concurrent 2FA credential edits merge by HLC', () async {
    final server = await InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final clientA = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );
    final clientB = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_bbbbbb222222',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    final initialTotp = totpConfig(account: 'initial@example.com');
    clientA.storage.totpCredentials['totp_1'] = baseTotpCredential(
      id: 'totp_1',
      label: 'Original 2FA',
      config: initialTotp,
      linkedAccountIds: const ['account_1'],
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      labelHlc: const Hlc(10, 0, 'base'),
      configHlc: const Hlc(10, 1, 'base'),
      linksHlc: const Hlc(10, 2, 'base'),
    );
    await clientA.syncService.syncNow();
    await clientB.syncService.syncNow();

    final totpFromB = totpConfig(
      account: 'b@example.com',
      secret: 'JBSWY3DPEHPK3PXQ',
    );
    clientA.storage.totpCredentials['totp_1'] = baseTotpCredential(
      id: 'totp_1',
      label: 'Updated By A',
      config: initialTotp,
      linkedAccountIds: const ['account_1'],
      version: 1,
      syncStatus: SyncStatus.pendingPush,
      labelHlc: const Hlc(20, 0, 'device_aaaaaa111111'),
      configHlc: const Hlc(10, 1, 'base'),
      linksHlc: const Hlc(10, 2, 'base'),
    );
    clientB.storage.totpCredentials['totp_1'] = baseTotpCredential(
      id: 'totp_1',
      label: 'Original 2FA',
      config: totpFromB,
      linkedAccountIds: const ['account_1'],
      version: 1,
      syncStatus: SyncStatus.pendingPush,
      labelHlc: const Hlc(10, 0, 'base'),
      configHlc: const Hlc(30, 0, 'device_bbbbbb222222'),
      linksHlc: const Hlc(10, 2, 'base'),
    );

    final pushAResult = await clientA.syncService.syncNow();
    final mergeBResult = await clientB.syncService.syncNow();
    final mergedCredential = clientB.storage.totpCredentials['totp_1']!;

    expect(pushAResult.success, isTrue);
    expect(pushAResult.pushed, isTrue);
    expect(mergeBResult.success, isTrue);
    expect(mergeBResult.pulled, isTrue);
    expect(mergedCredential.label, 'Updated By A');
    expect(
      mergedCredential.config.secret,
      TotpService.parseConfig(totpFromB).secret,
    );
    expect(mergedCredential.serverVersion, 3);
    expect(mergedCredential.syncStatus, SyncStatus.synchronized);
  });

  test(
    'remote delete wins over an older local modification on another device',
    () async {
      final server = await InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final clientA = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final clientB = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_bbbbbb222222',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      clientA.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      await clientA.syncService.syncNow();
      await clientB.syncService.syncNow();

      clientB.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Edited By B',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(20, 0, 'device_bbbbbb222222'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
      );
      clientA.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'base'),
        emailHlc: const Hlc(10, 1, 'base'),
        passwordHlc: const Hlc(10, 2, 'base'),
        isDeleted: true,
        deleteHlc: const Hlc(30, 0, 'device_aaaaaa111111'),
      );

      final deleteResult = await clientA.syncService.syncNow();
      final reconcileResult = await clientB.syncService.syncNow();
      final finalItem = clientB.storage.accounts['account_1']!;

      expect(deleteResult.success, isTrue);
      expect(deleteResult.pushed, isTrue);
      expect(server.currentVersion, 2);
      expect(reconcileResult.success, isTrue);
      expect(reconcileResult.pulled, isTrue);
      expect(finalItem.isDeleted, isTrue);
      expect(finalItem.deleteHlc, const Hlc(30, 0, 'device_aaaaaa111111'));
      expect(finalItem.syncStatus, SyncStatus.synchronized);
    },
  );

  test(
    'device A keeps an offline edit pending and pushes it after recovery',
    () async {
      final server = await InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final clientA = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );
      final clientB = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_bbbbbb222222',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      clientA.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Original',
        email: 'owner@example.com',
        password: 'super-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
        passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
      );
      final initialPush = await clientA.syncService.syncNow();
      final initialPull = await clientB.syncService.syncNow();

      expect(initialPush.success, isTrue, reason: 'seed push from A');
      expect(initialPull.success, isTrue, reason: 'seed pull into B');
      expect(server.currentVersion, 1, reason: 'seed server version');

      server.isUnavailable = true;
      final postCountBeforeOfflineEdit = server.postCount;
      clientA.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Offline Edit By A',
        email: 'owner@example.com',
        password: 'offline-secret',
        version: 1,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(40, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
        passwordHlc: const Hlc(45, 0, 'device_aaaaaa111111'),
      );

      final pendingOfflineEdit = clientA.storage.accounts['account_1']!;

      expect(server.currentVersion, 1, reason: 'server did not accept edit');
      expect(
        server.postCount,
        postCountBeforeOfflineEdit,
        reason: 'offline local edit does not contact the server',
      );
      expect(pendingOfflineEdit.syncStatus, SyncStatus.pendingPush);
      expect(pendingOfflineEdit.serverVersion, 1);

      server.isUnavailable = false;
      final recoveryPush = await clientA.syncService.syncNow();
      final recoveredLocal = clientA.storage.accounts['account_1']!;
      final pullAfterRecovery = await clientB.syncService.syncNow();
      final pulledByB = clientB.storage.accounts['account_1']!;

      expect(recoveryPush.success, isTrue, reason: 'A recovery push');
      expect(recoveryPush.pushed, isTrue);
      expect(recoveredLocal.syncStatus, SyncStatus.synchronized);
      expect(recoveredLocal.serverVersion, 2);
      expect(
        server.currentVersion,
        2,
        reason: 'server accepted recovered edit',
      );

      expect(
        pullAfterRecovery.success,
        isTrue,
        reason: 'B pulls recovered edit',
      );
      expect(pullAfterRecovery.pulled, isTrue);
      expect(pulledByB.name, 'Offline Edit By A');
      expect(pulledByB.data['password'], 'offline-secret');
      expect(pulledByB.syncStatus, SyncStatus.synchronized);
      expect(pulledByB.serverVersion, 2);
      expect(clientA.storage.conflictLogs['account_1'], isNull);
      expect(clientB.storage.conflictLogs['account_1'], isNull);
    },
  );
}
