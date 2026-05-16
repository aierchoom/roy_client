import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'mock_data_factory.dart';
import 'mock_scenarios.dart';

void main() {
  group('MockDataFactory', () {
    test('websiteAccount returns AccountItem with correct fields', () {
      final item = MockDataFactory.websiteAccount(
        id: 'acc_test',
        name: 'Test Site',
        username: 'testuser',
        password: 'secret',
      );

      expect(item.id, 'acc_test');
      expect(item.name, 'Test Site');
      expect(item.templateId, 'builtin_generic_info');
      expect(item.data['username'], 'testuser');
      expect(item.data['password'], 'secret');
      expect(item.isDeleted, false);
    });

    test('AccountItemBuilder builds with chain calls', () {
      final item = MockDataFactory.account(id: 'acc_1', name: 'Builder Test')
          .withEmail('test@example.com')
          .withPassword('pass123')
          .withPinned(true)
          .withSyncStatus(SyncStatus.synchronized)
          .build();

      expect(item.id, 'acc_1');
      expect(item.name, 'Builder Test');
      expect(item.email, 'test@example.com');
      expect(item.data['password'], 'pass123');
      expect(item.isPinned, true);
      expect(item.syncStatus, SyncStatus.synchronized);
    });

    test('batchWebsiteAccounts generates correct count', () {
      final items = MockDataFactory.batchWebsiteAccounts(count: 50);
      expect(items.length, 50);
      expect(items.first.id, 'acc_000');
      expect(items.last.id, 'acc_049');
    });

    test('conflictAccountPair produces local and remote', () {
      final pair = MockDataFactory.conflictAccountPair(
        id: 'acc_conflict',
        localName: 'Local',
        remoteName: 'Remote',
      );

      expect(pair.local.name, 'Local');
      expect(pair.remote.name, 'Remote');
      expect(pair.local.id, pair.remote.id);
      expect(pair.local.serverVersion, 1);
      expect(pair.remote.serverVersion, 2);
    });

    test('AccountTemplateBuilder fromPreset works', () {
      final t = AccountTemplateBuilder.fromPreset('wifi')
          .withTitle('我的WiFi')
          .build();

      expect(t.templateId, 'wifi');
      expect(t.title, '我的WiFi');
      expect(t.fields.any((f) => f.fieldKey == 'ssid'), true);
    });

    test('TotpCredentialBuilder builds from URI', () {
      final totp = MockDataFactory.totp(id: 'totp_1', label: 'GitHub')
          .fromOtpAuthUri('otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub')
          .linkToAccount('acc_1')
          .build();

      expect(totp.id, 'totp_1');
      expect(totp.label, 'GitHub');
      expect(totp.config.issuer, 'GitHub');
      expect(totp.linkedAccountIds, contains('acc_1'));
    });
  });

  group('MockScenario', () {
    test('standardUser has expected counts', () {
      final data = MockScenario.standardUser();
      expect(data.totalAccounts, 6);
      expect(data.totalTemplates, 2);
      expect(data.totalTotps, 2);
      expect(data.pendingSyncCount, 0);
    });

    test('largeDataset generates requested count', () {
      final data = MockScenario.largeDataset(accountCount: 200);
      expect(data.totalAccounts, 200);
      expect(data.totalTemplates, 10);
      expect(data.totalTotps, 20);
    });

    test('emptyVault has zero data', () {
      final data = MockScenario.emptyVault();
      expect(data.totalAccounts, 0);
      expect(data.totalTemplates, 0);
      expect(data.totalTotps, 0);
    });

    test('conflictPair has 4 accounts', () {
      final data = MockScenario.conflictPair();
      expect(data.totalAccounts, 4);
    });

    test('pendingSync has changes', () {
      final data = MockScenario.pendingSync(pendingCount: 15);
      expect(data.totalAccounts, 15);
      expect(data.pendingSyncCount, 15);
    });

    test('mixedRealWorld has notifications and health report', () {
      final data = MockScenario.mixedRealWorld();
      expect(data.notifications.length, 2);
      expect(data.healthReport, isNotNull);
      expect(data.healthReport!.score, 72);
    });
  });

  group('MockInjector intoFakeStorage', () {
    test('injects standard user scenario', () {
      // 使用 sync_server_test_harness 中的 FakeSecureStorageService
      // 由于该文件在 test/sync/ 中，这里只验证场景数据本身
      final data = MockScenario.standardUser();
      expect(data.accounts.first.name, 'GitHub');
      expect(data.templates.first.title, '社交媒体');
    });
  });
}
