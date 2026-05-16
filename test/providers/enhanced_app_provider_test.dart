import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/providers/enhanced_app_provider.dart';
import 'package:secret_roy/services/service_manager.dart';
import 'package:secret_roy/services/totp_service.dart';

import '../fakes/fake_auto_lock_service.dart';
import '../fakes/fake_biometric_auth_service.dart';
import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

void main() {
  group('EnhancedAppProvider', () {
    late FakeSecureStorageService storage;
    late FakeIdentityService identity;
    late FakeAutoLockService autoLock;
    late FakeBiometricAuthService biometric;
    late FakeSyncService sync;
    late ServiceManager manager;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      storage = FakeSecureStorageService();
      identity = FakeIdentityService();
      autoLock = FakeAutoLockService();
      biometric = FakeBiometricAuthService();
      sync = FakeSyncService();
      manager = ServiceManager.testable(
        secureStorageService: storage,
        identityService: identity,
        autoLockService: autoLock,
        biometricService: biometric,
        syncService: sync,
        initialState: ServiceManagerState.unlocked,
      );
    });

    tearDown(() {
      ServiceManager.resetInstance();
    });

    Future<void> _pumpInit(EnhancedAppProvider provider) async {
      // Allow async _init() to complete across multiple microtask turns.
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
    }

    AccountItem _makeAccount({
      required String id,
      required String name,
      String email = '',
      required String templateId,
      Map<String, dynamic>? data,
    }) {
      return AccountItem(
        id: id,
        name: name,
        email: email,
        templateId: templateId,
        data: data ?? const {},
        createdAt: 0,
        modifiedAt: 0,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
      );
    }

    test('initializes with empty data', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.isLoading, false);
      expect(provider.allAccounts, isEmpty);
      expect(provider.customTemplates, isEmpty);
      expect(provider.totpCredentials, isEmpty);
      expect(provider.conflictCount, 0);
      provider.dispose();
    });

    test('loads accounts from storage', () async {
      final account = _makeAccount(id: 'a1', name: 'GitHub', templateId: 'login');
      await storage.saveAccount(account);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.allAccounts.length, 1);
      expect(provider.allAccounts.first.name, 'GitHub');
      provider.dispose();
    });

    test('getAccount returns correct account', () async {
      final account = _makeAccount(id: 'a2', name: 'GitLab', templateId: 'login');
      await storage.saveAccount(account);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.getAccount('a2')?.name, 'GitLab');
      expect(provider.getAccount('missing'), null);
      provider.dispose();
    });

    test('accounts getter filters by search query', () async {
      final a1 = _makeAccount(id: 'a1', name: 'Alpha', templateId: 'login');
      final a2 = _makeAccount(id: 'a2', name: 'Beta', templateId: 'login');
      await storage.saveAccount(a1);
      await storage.saveAccount(a2);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      provider.setSearchQuery('alp');
      expect(provider.accounts.length, 1);
      expect(provider.accounts.first.name, 'Alpha');
      provider.clearSearch();
      expect(provider.accounts.length, 2);
      provider.dispose();
    });

    test('accounts getter filters by selected tags', () async {
      final a1 = _makeAccount(id: 'a1', name: 'A', templateId: 't1');
      final a2 = _makeAccount(id: 'a2', name: 'B', templateId: 't2');
      await storage.saveAccount(a1);
      await storage.saveAccount(a2);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      provider.toggleTag('t1');
      expect(provider.accounts.length, 1);
      expect(provider.accounts.first.id, 'a1');
      provider.clearFilters();
      expect(provider.accounts.length, 2);
      provider.dispose();
    });

    test('getTemplate finds custom and basic templates', () async {
      final custom = AccountTemplate(
        templateId: 'custom1',
        title: 'Custom',
        subTitle: 'sub',
        category: TemplateCategory.custom,
        fields: const [],
        isCustom: true,
      );
      await storage.saveTemplate(custom);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.getTemplate('custom1')?.title, 'Custom');
      // Basic templates are hardcoded and always available.
      expect(provider.getTemplate('builtin_generic_info')?.title, isNotNull);
      expect(provider.getTemplate('missing'), null);
      provider.dispose();
    });

    test('totpCredentialsForAccount filters by account link', () async {
      final cred1 = TotpCredential(
        id: 'c1',
        label: 'GitHub',
        config: const TotpConfig(secret: 'SECRET'),
        linkedAccountIds: ['acc1'],
        createdAt: 0,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );
      final cred2 = TotpCredential(
        id: 'c2',
        label: 'GitLab',
        config: const TotpConfig(secret: 'SECRET2'),
        linkedAccountIds: ['acc2'],
        createdAt: 0,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );
      await storage.saveTotpCredential(cred1);
      await storage.saveTotpCredential(cred2);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.totpCredentialsForAccount('acc1').length, 1);
      expect(provider.totpCredentialsForAccount('acc1').first.id, 'c1');
      expect(provider.totpCredentialsForAccount('none'), isEmpty);
      provider.dispose();
    });

    test('accountsLinkedTo finds references', () async {
      final a1 = _makeAccount(
        id: 'a1',
        name: 'Primary',
        templateId: 'login',
      );
      final a2 = _makeAccount(
        id: 'a2',
        name: 'Linked',
        templateId: 'login',
        data: {'ref': 'a1'},
      );
      await storage.saveAccount(a1);
      await storage.saveAccount(a2);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final linked = provider.accountsLinkedTo('a1');
      expect(linked.length, 1);
      expect(linked.first.id, 'a2');
      provider.dispose();
    });

    test('refresh clears and reloads data', () async {
      final account = _makeAccount(id: 'a1', name: 'X', templateId: 'login');
      await storage.saveAccount(account);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.allAccounts.length, 1);
      await storage.deleteAccount('a1');
      await provider.refresh();
      expect(provider.allAccounts, isEmpty);
      provider.dispose();
    });

    test('addAccount inserts at top', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final account = _makeAccount(id: 'a1', name: 'New', templateId: 'login');
      await provider.addAccount(account);
      expect(provider.allAccounts.length, 1);
      expect(provider.allAccounts.first.name, 'New');
      provider.dispose();
    });

    test('updateAccount mutates local list', () async {
      final account = _makeAccount(id: 'a1', name: 'Old', templateId: 'login');
      await storage.saveAccount(account);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final updated = _makeAccount(id: 'a1', name: 'New', templateId: 'login');
      await provider.updateAccount(updated);
      expect(provider.getAccount('a1')?.name, 'New');
      provider.dispose();
    });

    test('deleteAccount removes from local list', () async {
      final account = _makeAccount(id: 'a1', name: 'X', templateId: 'login');
      await storage.saveAccount(account);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      await provider.deleteAccount('a1');
      expect(provider.allAccounts, isEmpty);
      provider.dispose();
    });

    test('addTotpCredential inserts at top', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final cred = TotpCredential(
        id: 'c1',
        label: 'GitHub',
        config: const TotpConfig(secret: 'S'),
        linkedAccountIds: const [],
        createdAt: 0,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );
      await provider.addTotpCredential(cred);
      expect(provider.totpCredentials.length, 1);
      provider.dispose();
    });

    test('updateTotpCredential mutates or inserts', () async {
      final cred = TotpCredential(
        id: 'c1',
        label: 'GitHub',
        config: const TotpConfig(secret: 'S'),
        linkedAccountIds: const [],
        createdAt: 0,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );
      await storage.saveTotpCredential(cred);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final updated = TotpCredential(
        id: 'c1',
        label: 'GitLab',
        config: const TotpConfig(secret: 'S2'),
        linkedAccountIds: const [],
        createdAt: 0,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );
      await provider.updateTotpCredential(updated);
      expect(provider.totpCredentials.first.label, 'GitLab');
      provider.dispose();
    });

    test('deleteTotpCredential removes', () async {
      final cred = TotpCredential(
        id: 'c1',
        label: 'GitHub',
        config: const TotpConfig(secret: 'S'),
        linkedAccountIds: const [],
        createdAt: 0,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );
      await storage.saveTotpCredential(cred);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      await provider.deleteTotpCredential('c1');
      expect(provider.totpCredentials, isEmpty);
      provider.dispose();
    });

    test('addCustomTemplate inserts at top', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final template = AccountTemplate(
        templateId: 'ct1',
        title: 'Custom',
        subTitle: 'sub',
        category: TemplateCategory.custom,
        fields: const [],
        isCustom: true,
      );
      await provider.addCustomTemplate(template);
      expect(provider.customTemplates.length, 1);
      provider.dispose();
    });

    test('updateCustomTemplate mutates', () async {
      final template = AccountTemplate(
        templateId: 'ct1',
        title: 'Old',
        subTitle: 'sub',
        category: TemplateCategory.custom,
        fields: const [],
        isCustom: true,
      );
      await storage.saveTemplate(template);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final updated = AccountTemplate(
        templateId: 'ct1',
        title: 'New',
        subTitle: 'sub',
        category: TemplateCategory.custom,
        fields: const [],
        isCustom: true,
      );
      await provider.updateCustomTemplate(updated);
      expect(provider.customTemplates.first.title, 'New');
      provider.dispose();
    });

    test('deleteCustomTemplate removes', () async {
      final template = AccountTemplate(
        templateId: 'ct1',
        title: 'Custom',
        subTitle: 'sub',
        category: TemplateCategory.custom,
        fields: const [],
        isCustom: true,
      );
      await storage.saveTemplate(template);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      await provider.deleteCustomTemplate('ct1');
      expect(provider.customTemplates, isEmpty);
      provider.dispose();
    });

    test('countAccountsByTemplate returns correct count', () async {
      await storage.saveAccount(
        _makeAccount(id: 'a1', name: 'A', templateId: 'login'),
      );
      await storage.saveAccount(
        _makeAccount(id: 'a2', name: 'B', templateId: 'login'),
      );
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.countAccountsByTemplate('login'), 2);
      expect(provider.countAccountsByTemplate('none'), 0);
      provider.dispose();
    });

    test('syncState and isSyncConnected delegate to ServiceManager', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.syncState, manager.syncState);
      expect(provider.isSyncConnected, manager.isSyncConnected);
      provider.dispose();
    });

    test('generatePassword returns non-empty string', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final password = provider.generatePassword();
      expect(password, isNotEmpty);
      expect(password.length, 16); // default
      provider.dispose();
    });

    test('calculatePasswordStrength returns score', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.calculatePasswordStrength('weak'), lessThan(40));
      expect(
        provider.calculatePasswordStrength('Tr0ub4dor&3xcellent!'),
        greaterThan(60),
      );
      provider.dispose();
    });

    test('getPasswordStrengthLevel returns label', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.getPasswordStrengthLevel(10), isNotEmpty);
      provider.dispose();
    });

    test('pushAllLocalSyncChanges delegates and reloads', () async {
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      final result = await provider.pushAllLocalSyncChanges();
      expect(result.success, true);
      provider.dispose();
    });

    test('conflictCount includes account and template conflicts', () async {
      final account = _makeAccount(id: 'a1', name: 'X', templateId: 'login');
      await storage.saveAccount(account);
      // Fake returns empty conflict lists by default.
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.conflictCount, 0);
      provider.dispose();
    });

    test('resolveAccountName returns account name', () async {
      final account = _makeAccount(id: 'a1', name: 'Resolved', templateId: 'login');
      await storage.saveAccount(account);
      final provider = EnhancedAppProvider(storage, manager);
      await _pumpInit(provider);
      expect(provider.resolveAccountName('a1'), 'Resolved');
      expect(provider.resolveAccountName('none'), null);
      provider.dispose();
    });
  });
}
