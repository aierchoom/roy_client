import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';

void main() {
  group('AccountFieldMeta', () {
    test('copyWith returns same values when no args provided', () {
      const meta = AccountFieldMeta(
        type: 'password',
        label: 'Password',
        sourceTemplateId: 't1',
        sourceTemplateVersion: 2,
      );
      final copied = meta.copyWith();
      expect(copied.type, meta.type);
      expect(copied.label, meta.label);
      expect(copied.sourceTemplateId, meta.sourceTemplateId);
      expect(copied.sourceTemplateVersion, meta.sourceTemplateVersion);
    });

    test('copyWith overrides specified fields', () {
      const meta = AccountFieldMeta(
        type: 'text',
        label: 'Old Label',
      );
      final copied = meta.copyWith(
        type: 'email',
        label: 'New Label',
        sourceTemplateId: 't2',
        sourceTemplateVersion: 3,
      );
      expect(copied.type, 'email');
      expect(copied.label, 'New Label');
      expect(copied.sourceTemplateId, 't2');
      expect(copied.sourceTemplateVersion, 3);
    });

    test('copyWith preserves null fields when not overridden', () {
      const meta = AccountFieldMeta(
        type: 'text',
        label: 'Label',
      );
      final copied = meta.copyWith(type: 'number');
      expect(copied.type, 'number');
      expect(copied.label, 'Label');
      expect(copied.sourceTemplateId, isNull);
      expect(copied.sourceTemplateVersion, isNull);
    });
  });

  group('sync status parsing', () {
    test('falls back when json status index is out of range', () {
      final item = AccountItem.fromJson({
        'id': 'account-1',
        'name': 'Account',
        'templateId': 'generic_info',
        'data': const <String, String>{},
        'syncStatus': 99,
      });

      expect(item.syncStatus, SyncStatus.pendingPush);
    });

    test('accepts numeric and named status values', () {
      expect(syncStatusFromJson('2'), SyncStatus.conflict);
      expect(syncStatusFromJson('synchronized'), SyncStatus.synchronized);
    });
  });
}
