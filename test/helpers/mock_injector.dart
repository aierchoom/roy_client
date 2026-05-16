// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/service_manager.dart';

import '../sync/sync_server_test_harness.dart';
import 'mock_scenarios.dart';

// ---------------------------------------------------------------------------
// MockInjector — 将 Mock 数据注入测试环境
// ---------------------------------------------------------------------------

/// 将 [MockScenarioData] 一键注入到测试基础设施中。
///
/// 支持两种注入目标：
/// 1. [FakeSecureStorageService] — 纯内存，最快，适合单元测试和 Widget 测试
/// 2. [ServiceManager] — 走完整业务门面，适合集成测试和端到端测试
///
/// 用法示例：
/// ```dart
/// // 单元测试：直接注入 FakeStorage
/// final storage = FakeSecureStorageService();
/// final data = MockDataFactory.scenario.standardUser();
/// MockInjector.intoFakeStorage(data, storage);
/// expect(storage.accounts.length, 6);
///
/// // Widget 测试：注入 ServiceManager（需先解锁）
/// final sm = createFakeServiceManager();
/// await sm.unlockWithPassword('test');
/// MockInjector.intoServiceManager(data, sm);
/// ```
class MockInjector {
  MockInjector._();

  // ====== 注入 FakeSecureStorageService ======

  /// 将场景数据全部注入 [FakeSecureStorageService]。
  ///
  /// 注入顺序：templates → accounts → totps → syncChanges → notifications
  /// 确保外键关系（如 account 引用的 templateId）先存在。
  ///
  /// **注意**：此方法直接操作 FakeStorage 的内部 Map/List，不会触发
  /// `onChange` Stream 事件。如需 Provider 刷新，请在注入后手动
  /// `pump()` 或使用 `intoServiceManager`。
  static void intoFakeStorage(
    MockScenarioData data,
    FakeSecureStorageService storage, {
    bool clearExisting = false,
  }) {
    if (clearExisting) {
      storage.accounts.clear();
      storage.templates.clear();
      storage.totpCredentials.clear();
      storage.syncChanges.clear();
      storage.notifications.clear();
    }

    for (final t in data.templates) {
      storage.templates[t.templateId] = t;
    }
    for (final a in data.accounts) {
      storage.accounts[a.id] = a;
    }
    for (final t in data.totps) {
      storage.totpCredentials[t.id] = t;
    }
    for (final c in data.syncChanges) {
      storage.syncChanges.add(c);
    }
    for (final n in data.notifications) {
      storage.notifications.add(n);
    }
  }

  /// 仅注入账户列表。
  static void accountsIntoFakeStorage(
    List<AccountItem> accounts,
    FakeSecureStorageService storage, {
    bool clearExisting = false,
  }) {
    if (clearExisting) storage.accounts.clear();
    for (final a in accounts) {
      storage.accounts[a.id] = a;
    }
  }

  /// 仅注入模板列表。
  static void templatesIntoFakeStorage(
    List<AccountTemplate> templates,
    FakeSecureStorageService storage, {
    bool clearExisting = false,
  }) {
    if (clearExisting) storage.templates.clear();
    for (final t in templates) {
      storage.templates[t.templateId] = t;
    }
  }

  /// 仅注入 TOTP 列表。
  static void totpsIntoFakeStorage(
    List<TotpCredential> totps,
    FakeSecureStorageService storage, {
    bool clearExisting = false,
  }) {
    if (clearExisting) storage.totpCredentials.clear();
    for (final t in totps) {
      storage.totpCredentials[t.id] = t;
    }
  }

  // ====== 注入 ServiceManager ======

  /// 将场景数据通过 [ServiceManager] 的业务方法注入。
  ///
  /// **前置条件**：ServiceManager 必须处于 `unlocked` 状态。
  ///
  /// 此方法走完整 saveAccount / saveTemplate / saveTotpCredential 门面，
  /// 会触发 Provider 通知、HLC 自动标记、同步 dirty 状态等副作用，
  /// 最接近真实用户操作。
  static Future<void> intoServiceManager(
    MockScenarioData data,
    ServiceManager manager, {
    bool clearExisting = false,
  }) async {
    assert(
      manager.isUnlocked,
      'MockInjector.intoServiceManager requires unlocked ServiceManager. '
      'Call unlockWithPassword() or unlockWithBiometric() first.',
    );

    if (clearExisting) {
      // 通过 ServiceManager 删除所有数据（走完整门面）
      final allAccounts = await manager.storageService.loadAccounts();
      for (final a in allAccounts) {
        await manager.deleteAccount(a.id);
      }
      final allTemplates = await manager.storageService.loadCustomTemplates();
      for (final t in allTemplates) {
        await manager.deleteTemplate(t.templateId);
      }
      final allTotps = await manager.storageService.loadTotpCredentials();
      for (final t in allTotps) {
        await manager.deleteTotpCredential(t.id);
      }
    }

    // 先注入模板（账户可能引用模板）
    for (final t in data.templates) {
      await manager.saveTemplate(t);
    }

    // 注入账户
    for (final a in data.accounts) {
      await manager.saveAccount(a);
    }

    // 注入 TOTP
    for (final t in data.totps) {
      await manager.saveTotpCredential(t);
    }
  }

  /// 仅通过 ServiceManager 注入账户。
  static Future<void> accountsIntoServiceManager(
    List<AccountItem> accounts,
    ServiceManager manager, {
    bool clearExisting = false,
  }) async {
    assert(manager.isUnlocked, 'ServiceManager must be unlocked');

    if (clearExisting) {
      final all = await manager.storageService.loadAccounts();
      for (final a in all) {
        await manager.deleteAccount(a.id);
      }
    }

    for (final a in accounts) {
      await manager.saveAccount(a);
    }
  }
}
