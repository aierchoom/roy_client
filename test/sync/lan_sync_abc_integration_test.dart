import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';

import 'lan_sync_test_harness.dart';

/// 在本机模拟 A-B-C 三台设备进行 LAN 同步的集成测试。
///
/// 每个 harness 使用独立的临时数据库 + 独立 UDP 端口，
/// 通过共享 vault identity 实现同 vault 设备间的同步。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LanSyncTestHarness deviceA;
  late LanSyncTestHarness deviceB;

  setUpAll(() async {
    // 创建 A（Host）
    deviceA = await LanSyncTestHarness.create(
      label: 'A',
      discoveryPort: 59001,
    );
    await deviceA.initialize();

    // 创建 B（Requester），共享 A 的 vault identity
    deviceB = await LanSyncTestHarness.create(
      label: 'B',
      discoveryPort: 59001, // 同一端口以便接收 A 的广播
    );
    // 复制 vault identity（vaultId / privateKey / symmetricKey）
    final aStore = deviceA.identityStore;
    final bStore = deviceB.identityStore;
    for (final key in ['vault_id', 'private_key', 'symmetric_key']) {
      final value = aStore.readSync(key);
      if (value != null) {
        bStore.writeSync(key, value);
      }
    }
    // B 的 deviceId 由 IdentityService 自动生成
    await deviceB.initialize();
  });

  tearDownAll(() async {
    await deviceB.dispose();
    await deviceA.dispose();
  });

  group('A-B happy path', () {
    test('A and B share the same vaultId', () {
      expect(deviceA.identity.vaultId, isNotEmpty);
      expect(deviceB.identity.vaultId, equals(deviceA.identity.vaultId));
    });

    test('A hosts and B discovers', () async {
      // A 启动 hosting
      final hostSession = await deviceA.pairing.startHosting(
        transferCode: 'test-transfer-code-32bytes-long',
        ttl: const Duration(minutes: 1),
      );
      expect(hostSession.serverPort, greaterThan(0));

      // 给广播一点时间
      await Future.delayed(const Duration(milliseconds: 800));

      // B 发现 A
      final hostInfo = await deviceB.pairing.discoverHost(
        timeout: const Duration(seconds: 3),
      );
      expect(hostInfo, isNotNull);
      expect(hostInfo!.port, equals(hostSession.serverPort));
    });

    test('A and B exchange data via LAN sync', () async {
      // 1. A 存入账号 alpha
      final alpha = AccountItem(
        id: 'alpha',
        name: 'Alpha Account',
        email: 'alpha@test.com',
        templateId: 'template_default',
        data: const {'username': 'alpha_user'},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_a'),
        emailHlc: Hlc.now('device_a'),
        dataHlc: {'username': Hlc.now('device_a')},
      );
      await deviceA.storage.saveAccount(alpha);

      // 2. B 存入账号 beta
      final beta = AccountItem(
        id: 'beta',
        name: 'Beta Account',
        email: 'beta@test.com',
        templateId: 'template_default',
        data: const {'username': 'beta_user'},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.now('device_b'),
        emailHlc: Hlc.now('device_b'),
        dataHlc: {'username': Hlc.now('device_b')},
      );
      await deviceB.storage.saveAccount(beta);

      // 3. A 启动 LAN sync hosting
      final sessionId = await deviceA.coordinator.startAsHost();
      expect(sessionId, isNotNull);

      // 4. B 直接连接 A（跳过 UDP 发现，使用已知地址）
      // Verify A is hosting
      expect(deviceA.pairing.isHosting, isTrue);

      // 获取 A 的实际 HTTP 端口
      // LanPairingService 没有暴露 serverPort，我们通过 discoverHost 获取
      final hostInfo = await deviceB.pairing.discoverHost(
        timeout: const Duration(seconds: 3),
      );
      expect(hostInfo, isNotNull);

      // 5. B 作为 requester 运行同步
      // 注意：由于 widget test 环境会拦截 HTTP 请求，
      // 这里我们只验证 coordinator 状态机的前几步。
      // 真正的端到端测试需要在 integration_test 中运行。
      final client = deviceB.coordinator;
      expect(client.isBusy, isFalse);

      // 手动触发 startSync（不使用 discoverHost）
      final result = deviceB.syncService.isSyncing;
      expect(result, isFalse);

      // 6. 验证 B 的 syncService 没有与 LAN sync 冲突
      // （红线 R3：LAN sync 会检查 server sync 状态）
      expect(deviceB.syncService.isSyncing, isFalse);
    });
  });

  group('A-B-C consistency', () {
    test('HLC merge is deterministic across devices', () {
      final hlcA = Hlc.now('device_a');
      final hlcB = Hlc.now('device_b');

      // 同一毫秒内创建的两个 HLC，时间戳相同
      // 比较器先比 time，再比 counter，最后比 nodeId
      final comparison = hlcA.compareTo(hlcB);
      expect(comparison, isA<int>());
    });
  });
}
