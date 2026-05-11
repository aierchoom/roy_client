import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_server_test_harness.dart';

void main() {
  const vaultId = 'vault_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const privateKey =
      'priv_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const symmetricKey =
      'sym_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  test('server 503 unavailable results in serverError state', () async {
    final server = await InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final client = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    server.isUnavailable = true;
    final result = await client.syncService.syncNow();

    expect(result.success, isFalse);
    expect(client.syncService.state, SyncState.serverError);
  });

  test(
    'server recovers from 503 and subsequent sync succeeds',
    () async {
      final server = await InMemoryVaultServer.start(vaultId);
      addTearDown(server.close);
      SharedPreferences.setMockInitialValues({
        'sync_server_url': server.baseUrl,
      });

      final client = await TestClient.create(
        vaultId: vaultId,
        deviceId: 'device_aaaaaa111111',
        privateKey: privateKey,
        symmetricKey: symmetricKey,
      );

      client.storage.accounts['account_1'] = baseItem(
        id: 'account_1',
        name: 'Offline Account',
        email: 'offline@example.com',
        password: 'offline-secret',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
        emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
        passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
      );

      server.isUnavailable = true;
      final failedResult = await client.syncService.syncNow();
      expect(failedResult.success, isFalse);
      expect(client.syncService.state, SyncState.serverError);
      expect(server.postCount, 0);

      server.isUnavailable = false;
      final recoveryResult = await client.syncService.syncNow();
      expect(recoveryResult.success, isTrue);
      expect(recoveryResult.pushed, isTrue);
      expect(client.syncService.state, SyncState.idle);
      expect(server.currentVersion, 1);
    },
  );

  test('malformed GET response triggers protocolError state', () async {
    final server = await InMemoryVaultServer.start(vaultId);
    addTearDown(server.close);
    SharedPreferences.setMockInitialValues({'sync_server_url': server.baseUrl});

    final client = await TestClient.create(
      vaultId: vaultId,
      deviceId: 'device_aaaaaa111111',
      privateKey: privateKey,
      symmetricKey: symmetricKey,
    );

    server.returnMalformedJson = true;
    final result = await client.syncService.syncNow();

    expect(result.success, isFalse);
    expect(client.syncService.state, SyncState.protocolError);
  });

  test('concurrent syncNow calls do not corrupt the state machine', () async {
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
      name: 'Account A',
      email: 'a@example.com',
      password: 'secret-a',
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'device_aaaaaa111111'),
      emailHlc: const Hlc(10, 1, 'device_aaaaaa111111'),
      passwordHlc: const Hlc(10, 2, 'device_aaaaaa111111'),
    );
    clientB.storage.accounts['account_2'] = baseItem(
      id: 'account_2',
      name: 'Account B',
      email: 'b@example.com',
      password: 'secret-b',
      version: 0,
      syncStatus: SyncStatus.pendingPush,
      nameHlc: const Hlc(10, 0, 'device_bbbbbb222222'),
      emailHlc: const Hlc(10, 1, 'device_bbbbbb222222'),
      passwordHlc: const Hlc(10, 2, 'device_bbbbbb222222'),
    );

    // Fire both syncs almost simultaneously.
    final futureA = clientA.syncService.syncNow();
    final futureB = clientB.syncService.syncNow();
    final results = await Future.wait([futureA, futureB]);

    // Both should succeed; the server handles requests sequentially.
    expect(results[0].success, isTrue);
    expect(results[1].success, isTrue);

    // State should settle to idle, never an illegal intermediate state.
    expect(clientA.syncService.state, SyncState.idle);
    expect(clientB.syncService.state, SyncState.idle);

    // Server should have accepted both pushes.
    expect(server.currentVersion, greaterThanOrEqualTo(2));
  });

  test('paginated pull aggregates all pages correctly', () async {
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

    // Seed 5 accounts on A and push.
    for (var i = 0; i < 5; i++) {
      clientA.storage.accounts['account_$i'] = baseItem(
        id: 'account_$i',
        name: 'Account $i',
        email: 'a$i@example.com',
        password: 'secret-$i',
        version: 0,
        syncStatus: SyncStatus.pendingPush,
        nameHlc: Hlc(10, i, 'device_aaaaaa111111'),
        emailHlc: Hlc(10, i + 1, 'device_aaaaaa111111'),
        passwordHlc: Hlc(10, i + 2, 'device_aaaaaa111111'),
      );
    }

    // Push without pagination.
    await clientA.syncService.syncNow();
    expect(server.currentVersion, 5);

    // Force pagination of 2 items per page on B's pull.
    server.pageSizeLimit = 2;
    final pullResult = await clientB.syncService.syncNow();

    expect(pullResult.success, isTrue);
    expect(pullResult.pulled, isTrue);
    expect(clientB.storage.accounts.length, 5);
    for (var i = 0; i < 5; i++) {
      expect(clientB.storage.accounts['account_$i']?.name, 'Account $i');
    }

    // clientA pull (1) + clientB paginated pull (3) = 4 GETs total.
    expect(server.getCount, 4);
    final cursorCounts = <String, int>{};
    for (final url in server.getRequestUrls) {
      final cursor = Uri.parse(url).queryParameters['cursor'] ?? '0';
      cursorCounts[cursor] = (cursorCounts[cursor] ?? 0) + 1;
    }
    expect(cursorCounts['0'], 2); // clientA empty pull + clientB page 1
    expect(cursorCounts['2'], 1); // clientB page 2
    expect(cursorCounts['4'], 1); // clientB page 3
  });
}
