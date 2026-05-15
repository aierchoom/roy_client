import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/app_notification.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/services/notification_service.dart';

import '../sync/sync_server_test_harness.dart';

void main() {
  group('NotificationService', () {
    late FakeSecureStorageService storage;
    late NotificationService service;

    setUp(() {
      storage = FakeSecureStorageService();
      service = NotificationService(storage);
    });

    final passwordTemplate = AccountTemplate(
      templateId: 'login',
      title: 'Login',
      subTitle: 'Website',
      category: TemplateCategory.login,
      fields: [
        const AccountField(
          fieldKey: 'password',
          label: 'Password',
          attributes: AccountFieldAttributes(
            type: AccountFieldType.password,
            isPrimary: false,
            isRequired: true,
            isSecret: true,
            isEditable: true,
            isSearchable: false,
            isCopyable: true,
          ),
        ),
      ],
    );

    final plainTemplate = AccountTemplate(
      templateId: 'note',
      title: 'Note',
      subTitle: 'Plain text',
      category: TemplateCategory.custom,
      fields: [
        const AccountField(
          fieldKey: 'content',
          label: 'Content',
          attributes: AccountFieldAttributes(
            type: AccountFieldType.text,
            isPrimary: false,
            isRequired: true,
            isSecret: false,
            isEditable: true,
            isSearchable: true,
            isCopyable: true,
          ),
        ),
      ],
    );

    AccountItem _makeAccount({
      required String id,
      required String name,
      required String templateId,
      required int modifiedAt,
      Map<String, dynamic>? data,
    }) {
      return AccountItem(
        id: id,
        name: name,
        email: '',
        templateId: templateId,
        data: data ?? const {},
        createdAt: modifiedAt,
        modifiedAt: modifiedAt,
        nameHlc: Hlc.zero('local'),
        emailHlc: Hlc.zero('local'),
        dataHlc: const {},
      );
    }

    test('generatePasswordExpiryNotifications creates for old passwords', () async {
      final oldTime = DateTime.now().subtract(const Duration(days: 100)).millisecondsSinceEpoch;
      final account = _makeAccount(
        id: 'acc1',
        name: 'Old Site',
        templateId: 'login',
        modifiedAt: oldTime,
      );

      final created = await service.generatePasswordExpiryNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        expiryDays: 90,
      );

      expect(created.length, 1);
      expect(created.first.type, AppNotificationType.passwordExpiry);
      expect(created.first.accountId, 'acc1');
      expect(created.first.params['accountName'], 'Old Site');
    });

    test('generatePasswordExpiryNotifications skips recent passwords', () async {
      final recentTime = DateTime.now().subtract(const Duration(days: 10)).millisecondsSinceEpoch;
      final account = _makeAccount(
        id: 'acc2',
        name: 'Recent Site',
        templateId: 'login',
        modifiedAt: recentTime,
      );

      final created = await service.generatePasswordExpiryNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        expiryDays: 90,
      );

      expect(created, isEmpty);
    });

    test('generatePasswordExpiryNotifications skips non-password templates', () async {
      final oldTime = DateTime.now().subtract(const Duration(days: 100)).millisecondsSinceEpoch;
      final account = _makeAccount(
        id: 'acc3',
        name: 'Note',
        templateId: 'note',
        modifiedAt: oldTime,
      );

      final created = await service.generatePasswordExpiryNotifications(
        accounts: [account],
        templates: [plainTemplate],
        expiryDays: 90,
      );

      expect(created, isEmpty);
    });

    test('generatePasswordExpiryNotifications skips duplicates', () async {
      final oldTime = DateTime.now().subtract(const Duration(days: 100)).millisecondsSinceEpoch;
      final account = _makeAccount(
        id: 'acc4',
        name: 'Dup Site',
        templateId: 'login',
        modifiedAt: oldTime,
      );

      await service.generatePasswordExpiryNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        expiryDays: 90,
      );

      final second = await service.generatePasswordExpiryNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        expiryDays: 90,
      );

      expect(second, isEmpty);
    });

    test('generateWeakPasswordNotifications creates for weak passwords', () async {
      final account = _makeAccount(
        id: 'acc5',
        name: 'Weak Site',
        templateId: 'login',
        modifiedAt: DateTime.now().millisecondsSinceEpoch,
        data: {'password': '123'},
      );

      final created = await service.generateWeakPasswordNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        strengthThreshold: 40,
      );

      expect(created.length, 1);
      expect(created.first.type, AppNotificationType.weakPassword);
      expect(created.first.accountId, 'acc5');
      expect(created.first.params['accountName'], 'Weak Site');
    });

    test('generateWeakPasswordNotifications skips strong passwords', () async {
      final account = _makeAccount(
        id: 'acc6',
        name: 'Strong Site',
        templateId: 'login',
        modifiedAt: DateTime.now().millisecondsSinceEpoch,
        data: {'password': 'Tr0ub4dor&3xcellent!'},
      );

      final created = await service.generateWeakPasswordNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        strengthThreshold: 40,
      );

      expect(created, isEmpty);
    });

    test('generateWeakPasswordNotifications skips non-password templates', () async {
      final account = _makeAccount(
        id: 'acc7',
        name: 'Note',
        templateId: 'note',
        modifiedAt: DateTime.now().millisecondsSinceEpoch,
        data: {'content': 'weak'},
      );

      final created = await service.generateWeakPasswordNotifications(
        accounts: [account],
        templates: [plainTemplate],
        strengthThreshold: 40,
      );

      expect(created, isEmpty);
    });

    test('generateWeakPasswordNotifications skips duplicates', () async {
      final account = _makeAccount(
        id: 'acc8',
        name: 'Dup Weak',
        templateId: 'login',
        modifiedAt: DateTime.now().millisecondsSinceEpoch,
        data: {'password': '123'},
      );

      await service.generateWeakPasswordNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        strengthThreshold: 40,
      );

      final second = await service.generateWeakPasswordNotifications(
        accounts: [account],
        templates: [passwordTemplate],
        strengthThreshold: 40,
      );

      expect(second, isEmpty);
    });
  });
}
