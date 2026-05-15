import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/system/service_manager/vault_data_repository.dart';

import '../fakes/fake_identity_service.dart';
import '../fakes/fake_sync_service.dart';
import '../sync/sync_server_test_harness.dart';

void main() {
  group('VaultDataRepository', () {
    late FakeSecureStorageService storage;
    late FakeIdentityService identity;
    late FakeSyncService sync;
    late VaultDataRepository repo;

    setUp(() {
      storage = FakeSecureStorageService();
      identity = FakeIdentityService();
      sync = FakeSyncService();
      repo = VaultDataRepository(
        storage: storage,
        identity: identity,
        sync: sync,
      );
    });

    test('saveAccount records create sync change for new account', () async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test',
        email: 'test@test.com',
        templateId: 'builtin_website',
        data: const {'url': 'https://example.com'},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );

      await repo.saveAccount(account);

      expect(storage.accounts['acc_1'], isNotNull);
      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.action, LocalSyncAction.create);
      expect(changes.first.entityType, LocalSyncEntityType.account);
      expect(changes.first.entityId, 'acc_1');
    });

    test('saveAccount records update sync change for existing account', () async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Old',
        email: 'old@test.com',
        templateId: 'builtin_website',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      storage.accounts['acc_1'] = account;

      final updated = account.copyWith(name: 'New');
      await repo.saveAccount(updated);

      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.action, LocalSyncAction.update);
    });

    test('deleteAccount records delete sync change', () async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test',
        email: 'test@test.com',
        templateId: 'builtin_website',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      storage.accounts['acc_1'] = account;

      await repo.deleteAccount('acc_1');

      expect(storage.accounts['acc_1']?.isDeleted, true);
      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.action, LocalSyncAction.delete);
    });

    test('togglePin records update sync change', () async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test',
        email: 'test@test.com',
        templateId: 'builtin_website',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      storage.accounts['acc_1'] = account;

      await repo.togglePin('acc_1');

      expect(storage.accounts['acc_1']?.isPinned, true);
      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.action, LocalSyncAction.update);
    });

    test('saveTotpCredential records create sync change', () async {
      final credential = TotpCredential(
        id: 'totp_1',
        label: 'GitHub',
        config: const TotpConfig(
          issuer: 'GitHub',
          account: 'user@example.com',
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          algorithm: TotpAlgorithm.sha1,
          digits: 6,
          period: 30,
        ),
        linkedAccountIds: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
        syncStatus: SyncStatus.synchronized,
      );

      await repo.saveTotpCredential(credential);

      expect(storage.totpCredentials['totp_1'], isNotNull);
      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.action, LocalSyncAction.create);
      expect(changes.first.entityType, LocalSyncEntityType.totpCredential);
    });

    test('deleteTotpCredential records delete sync change', () async {
      final credential = TotpCredential(
        id: 'totp_1',
        label: 'GitHub',
        config: const TotpConfig(
          issuer: 'GitHub',
          account: 'user@example.com',
          secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
          algorithm: TotpAlgorithm.sha1,
          digits: 6,
          period: 30,
        ),
        linkedAccountIds: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
        syncStatus: SyncStatus.synchronized,
      );
      storage.totpCredentials['totp_1'] = credential;

      await repo.deleteTotpCredential('totp_1');

      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.action, LocalSyncAction.delete);
    });

    test('saveTemplate records create sync change for custom template', () async {
      final template = AccountTemplate(
        templateId: 'custom_1',
        title: 'Custom',
        subTitle: 'Custom template',
        category: TemplateCategory.custom,
        iconCodePoint: 0,
        fields: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: SyncStatus.synchronized,
        isCustom: true,
      );

      await repo.saveTemplate(template);

      expect(storage.templates['custom_1'], isNotNull);
      final changes = await storage.loadOpenLocalSyncChanges(
        vaultId: identity.vaultId,
      );
      expect(changes.length, 1);
      expect(changes.first.entityType, LocalSyncEntityType.template);
    });

    test('deleteTemplate throws when template is in use', () async {
      final template = AccountTemplate(
        templateId: 'custom_1',
        title: 'Custom',
        subTitle: 'Custom template',
        category: TemplateCategory.custom,
        iconCodePoint: 0,
        fields: const [],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        syncStatus: SyncStatus.synchronized,
        isCustom: true,
      );
      storage.templates['custom_1'] = template;
      storage.accounts['acc_1'] = AccountItem(
        id: 'acc_1',
        name: 'Test',
        email: 'test@test.com',
        templateId: 'custom_1',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );

      expect(
        () => repo.deleteTemplate('custom_1'),
        throwsA(isA<TemplateInUseException>()),
      );
    });

    test('getAccountById returns account', () async {
      final account = AccountItem(
        id: 'acc_1',
        name: 'Test',
        email: 'test@test.com',
        templateId: 'builtin_website',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      storage.accounts['acc_1'] = account;

      final result = await repo.getAccountById('acc_1');
      expect(result?.id, 'acc_1');
    });

    test('countAccountsByTemplate returns correct count', () async {
      storage.accounts['acc_1'] = AccountItem(
        id: 'acc_1',
        name: 'A',
        email: 'a@test.com',
        templateId: 'builtin_website',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );
      storage.accounts['acc_2'] = AccountItem(
        id: 'acc_2',
        name: 'B',
        email: 'b@test.com',
        templateId: 'builtin_website',
        data: const {},
        createdAt: DateTime.now().millisecondsSinceEpoch,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
        syncStatus: SyncStatus.synchronized,
      );

      final count = await repo.countAccountsByTemplate('builtin_website');
      expect(count, 2);
    });
  });
}
