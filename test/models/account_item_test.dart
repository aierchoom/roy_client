import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';

void main() {
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
