import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/local_sync_change.dart';

void main() {
  group('LocalSyncChange', () {
    test('constructs with required fields', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.create,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.id, 'id1');
      expect(change.vaultId, 'vault1');
      expect(change.entityType, LocalSyncEntityType.account);
      expect(change.action, LocalSyncAction.create);
      expect(change.status, LocalSyncStatus.pendingReview);
      expect(change.isDelete, isFalse);
      expect(change.isAccount, isTrue);
      expect(change.isTotpCredential, isFalse);
      expect(change.canPush, isTrue);
    });

    test('isDelete returns true for delete action', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.delete,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.isDelete, isTrue);
    });

    test('canPush returns false for pushed status', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.create,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pushed,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.canPush, isFalse);
    });

    test('fromDatabaseRow maps snake_case columns', () {
      final change = LocalSyncChange.fromDatabaseRow({
        'id': 'row1',
        'vault_id': 'vault_a',
        'entity_type': 'totpCredential',
        'entity_id': 'totp1',
        'action': 'update',
        'title': 'TOTP Update',
        'before_json': '{"name":"old"}',
        'after_json': '{"name":"new"}',
        'diff_json': '{"changed_fields":["name"]}',
        'base_server_version': 3,
        'status': 'approved',
        'created_at': 1000,
        'updated_at': 2000,
        'approved_at': 2500,
        'pushed_at': null,
        'error_message': null,
      });
      expect(change.id, 'row1');
      expect(change.vaultId, 'vault_a');
      expect(change.entityType, LocalSyncEntityType.totpCredential);
      expect(change.action, LocalSyncAction.update);
      expect(change.title, 'TOTP Update');
      expect(change.beforeJson, '{"name":"old"}');
      expect(change.afterJson, '{"name":"new"}');
      expect(change.baseServerVersion, 3);
      expect(change.status, LocalSyncStatus.approved);
      expect(change.createdAt, 1000);
      expect(change.updatedAt, 2000);
      expect(change.approvedAt, 2500);
      expect(change.pushedAt, isNull);
      expect(change.errorMessage, isNull);
    });

    test('fromDatabaseRow handles null optional fields', () {
      final change = LocalSyncChange.fromDatabaseRow({
        'id': 'row1',
        'vault_id': null,
        'entity_type': 'account',
        'entity_id': null,
        'action': 'create',
        'title': null,
        'before_json': null,
        'after_json': null,
        'diff_json': null,
        'base_server_version': null,
        'status': null,
        'created_at': null,
        'updated_at': null,
        'approved_at': null,
        'pushed_at': null,
        'error_message': null,
      });
      expect(change.vaultId, '');
      expect(change.entityId, '');
      expect(change.title, '');
      expect(change.diff, isEmpty);
      expect(change.baseServerVersion, 0);
      expect(change.status, LocalSyncStatus.pendingReview);
      expect(change.createdAt, 0);
      expect(change.updatedAt, 0);
    });

    test('changedFields extracts from diff', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.update,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {
          'changed_fields': ['name', 'email'],
        },
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.changedFields, ['name', 'email']);
    });

    test('changedFields returns empty when missing', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.update,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.changedFields, isEmpty);
    });

    test('beforeSnapshot and afterSnapshot decode JSON', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.update,
        title: 'Test',
        beforeJson: '{"name":"old"}',
        afterJson: '{"name":"new"}',
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.beforeSnapshot, {'name': 'old'});
      expect(change.afterSnapshot, {'name': 'new'});
    });

    test('snapshot getters return null for null json', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.create,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      expect(change.beforeSnapshot, isNull);
      expect(change.afterSnapshot, isNull);
    });

    test('copyWith updates status and timestamps', () {
      const change = LocalSyncChange(
        id: 'id1',
        vaultId: 'vault1',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.create,
        title: 'Test',
        beforeJson: null,
        afterJson: null,
        diff: {},
        baseServerVersion: 0,
        status: LocalSyncStatus.pendingReview,
        createdAt: 1000,
        updatedAt: 1000,
      );
      final updated = change.copyWith(
        status: LocalSyncStatus.approved,
        approvedAt: 3000,
        pushedAt: 4000,
        errorMessage: 'ok',
      );
      expect(updated.status, LocalSyncStatus.approved);
      expect(updated.approvedAt, 3000);
      expect(updated.pushedAt, 4000);
      expect(updated.errorMessage, 'ok');
      expect(updated.id, change.id);
      expect(updated.createdAt, change.createdAt);
    });

    test('toDatabaseRow round-trips with fromDatabaseRow', () {
      const original = LocalSyncChange(
        id: 'row1',
        vaultId: 'vault_a',
        entityType: LocalSyncEntityType.account,
        entityId: 'entity1',
        action: LocalSyncAction.update,
        title: 'Update Title',
        beforeJson: '{"a":1}',
        afterJson: '{"a":2}',
        diff: {
          'changed_fields': ['a'],
        },
        baseServerVersion: 5,
        status: LocalSyncStatus.approved,
        createdAt: 1000,
        updatedAt: 2000,
        approvedAt: 2500,
        pushedAt: 3000,
        errorMessage: 'none',
      );
      final row = original.toDatabaseRow();
      final recovered = LocalSyncChange.fromDatabaseRow(row);
      expect(recovered.id, original.id);
      expect(recovered.vaultId, original.vaultId);
      expect(recovered.entityType, original.entityType);
      expect(recovered.entityId, original.entityId);
      expect(recovered.action, original.action);
      expect(recovered.title, original.title);
      expect(recovered.beforeJson, original.beforeJson);
      expect(recovered.afterJson, original.afterJson);
      expect(recovered.baseServerVersion, original.baseServerVersion);
      expect(recovered.status, original.status);
      expect(recovered.createdAt, original.createdAt);
      expect(recovered.updatedAt, original.updatedAt);
      expect(recovered.approvedAt, original.approvedAt);
      expect(recovered.pushedAt, original.pushedAt);
      expect(recovered.errorMessage, original.errorMessage);
    });

    test('encodeSnapshot produces valid JSON', () {
      final json = LocalSyncChange.encodeSnapshot({'key': 'value'});
      expect(jsonDecode(json), {'key': 'value'});
    });
  });

  group('enum fromString helpers', () {
    test('localSyncEntityTypeFromString parses valid names', () {
      expect(
        localSyncEntityTypeFromString('totpCredential'),
        LocalSyncEntityType.totpCredential,
      );
      expect(
        localSyncEntityTypeFromString('template'),
        LocalSyncEntityType.template,
      );
    });

    test('localSyncActionFromString falls back to update', () {
      expect(localSyncActionFromString('invalid'), LocalSyncAction.update);
    });

    test('localSyncStatusFromString falls back to pendingReview', () {
      expect(
        localSyncStatusFromString('invalid'),
        LocalSyncStatus.pendingReview,
      );
    });
  });
}
