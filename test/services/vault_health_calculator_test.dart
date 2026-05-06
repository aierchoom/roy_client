import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/models/vault_health_report.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/services/vault_health_calculator.dart';

AccountItem _makeAccount({
  required String id,
  String name = 'Account',
  String templateId = 'generic_info',
  Map<String, String> data = const {},
  int? createdAt,
  bool isDeleted = false,
}) {
  return AccountItem(
    id: id,
    name: name,
    email: '',
    templateId: templateId,
    data: data,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
    nameHlc: Hlc.zero('local'),
    emailHlc: Hlc.zero('local'),
    dataHlc: const {},
    isDeleted: isDeleted,
  );
}

AccountTemplate _makeTemplate({
  required String templateId,
  List<AccountField> fields = const [],
}) {
  return AccountTemplate(
    templateId: templateId,
    title: 'Test',
    subTitle: '',
    category: TemplateCategory.custom,
    fields: fields,
  );
}

TotpCredential _makeTotp({
  required String id,
  List<String> linkedAccountIds = const [],
}) {
  return TotpCredential(
    id: id,
    label: 'Test',
    config: const TotpConfig(secret: 'JBSWY3DPEHPK3PXP'),
    linkedAccountIds: linkedAccountIds,
    createdAt: 0,
    labelHlc: Hlc.zero('local'),
    configHlc: Hlc.zero('local'),
    linksHlc: Hlc.zero('local'),
  );
}

void main() {
  group('VaultHealthCalculator.calculateScore', () {
    test('returns 100 for all passing items', () {
      final items = [
        const VaultHealthItem(
          id: 'a',
          title: 'A',
          riskLevel: VaultHealthRiskLevel.high,
          isPass: true,
          description: '',
        ),
      ];
      expect(VaultHealthCalculator.calculateScore(items), 100);
    });

    test('subtracts 15 for a failed high-risk item', () {
      final items = [
        const VaultHealthItem(
          id: 'a',
          title: 'A',
          riskLevel: VaultHealthRiskLevel.high,
          isPass: false,
          description: '',
        ),
      ];
      expect(VaultHealthCalculator.calculateScore(items), 85);
    });

    test('subtracts 8 for a failed medium-risk item', () {
      final items = [
        const VaultHealthItem(
          id: 'a',
          title: 'A',
          riskLevel: VaultHealthRiskLevel.medium,
          isPass: false,
          description: '',
        ),
      ];
      expect(VaultHealthCalculator.calculateScore(items), 92);
    });

    test('subtracts 3 for a failed low-risk item', () {
      final items = [
        const VaultHealthItem(
          id: 'a',
          title: 'A',
          riskLevel: VaultHealthRiskLevel.low,
          isPass: false,
          description: '',
        ),
      ];
      expect(VaultHealthCalculator.calculateScore(items), 97);
    });

    test('combines multiple deductions', () {
      final items = [
        const VaultHealthItem(
          id: 'a',
          title: 'A',
          riskLevel: VaultHealthRiskLevel.high,
          isPass: false,
          description: '',
        ),
        const VaultHealthItem(
          id: 'b',
          title: 'B',
          riskLevel: VaultHealthRiskLevel.medium,
          isPass: false,
          description: '',
        ),
        const VaultHealthItem(
          id: 'c',
          title: 'C',
          riskLevel: VaultHealthRiskLevel.low,
          isPass: false,
          description: '',
        ),
      ];
      expect(VaultHealthCalculator.calculateScore(items), 74); // 100-15-8-3
    });

    test('clamps at 0', () {
      final items = List.generate(10, (i) {
        return VaultHealthItem(
          id: 'item_$i',
          title: 'Item $i',
          riskLevel: VaultHealthRiskLevel.high,
          isPass: false,
          description: '',
        );
      });
      expect(VaultHealthCalculator.calculateScore(items), 0);
    });
  });

  group('VaultHealthCalculator.scoreToGrade', () {
    test('excellent for 90-100', () {
      expect(VaultHealthCalculator.scoreToGrade(100), VaultHealthGrade.excellent);
      expect(VaultHealthCalculator.scoreToGrade(90), VaultHealthGrade.excellent);
    });

    test('good for 70-89', () {
      expect(VaultHealthCalculator.scoreToGrade(89), VaultHealthGrade.good);
      expect(VaultHealthCalculator.scoreToGrade(70), VaultHealthGrade.good);
    });

    test('warning for 50-69', () {
      expect(VaultHealthCalculator.scoreToGrade(69), VaultHealthGrade.warning);
      expect(VaultHealthCalculator.scoreToGrade(50), VaultHealthGrade.warning);
    });

    test('critical for 0-49', () {
      expect(VaultHealthCalculator.scoreToGrade(49), VaultHealthGrade.critical);
      expect(VaultHealthCalculator.scoreToGrade(0), VaultHealthGrade.critical);
    });
  });

  group('VaultHealthCalculator.checkWeakPasswords', () {
    test('passes when no accounts', () {
      final result = VaultHealthCalculator.checkWeakPasswords([]);
      expect(result.isPass, isTrue);
    });

    test('ignores empty passwords', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'password': ''}),
      ];
      final result = VaultHealthCalculator.checkWeakPasswords(accounts);
      expect(result.isPass, isTrue);
    });

    test('ignores deleted accounts', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'password': 'abc'}, isDeleted: true),
      ];
      final result = VaultHealthCalculator.checkWeakPasswords(accounts);
      expect(result.isPass, isTrue);
    });

    test('fails for weak password (strength < 40)', () {
      final accounts = [
        _makeAccount(id: 'a', name: 'Weak', data: {'password': 'abc'}),
      ];
      final result = VaultHealthCalculator.checkWeakPasswords(accounts);
      expect(result.isPass, isFalse);
      expect(result.description, contains('1'));
    });

    test('passes for strong password (strength >= 40)', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'password': 'Abcdefg1'}),
      ];
      final result = VaultHealthCalculator.checkWeakPasswords(accounts);
      expect(result.isPass, isTrue);
    });
  });

  group('VaultHealthCalculator.checkReusedPasswords', () {
    test('passes when no reuse', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'password': 'secret1'}),
        _makeAccount(id: 'b', data: {'password': 'secret2'}),
      ];
      final result = VaultHealthCalculator.checkReusedPasswords(accounts);
      expect(result.isPass, isTrue);
    });

    test('fails when passwords are reused', () {
      final accounts = [
        _makeAccount(id: 'a', name: 'A', data: {'password': 'same'}),
        _makeAccount(id: 'b', name: 'B', data: {'password': 'same'}),
      ];
      final result = VaultHealthCalculator.checkReusedPasswords(accounts);
      expect(result.isPass, isFalse);
      expect(result.description, contains('1'));
    });

    test('ignores empty passwords', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'password': ''}),
        _makeAccount(id: 'b', data: {'password': ''}),
      ];
      final result = VaultHealthCalculator.checkReusedPasswords(accounts);
      expect(result.isPass, isTrue);
    });

    test('ignores deleted accounts', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'password': 'same'}, isDeleted: true),
        _makeAccount(id: 'b', data: {'password': 'same'}, isDeleted: true),
      ];
      final result = VaultHealthCalculator.checkReusedPasswords(accounts);
      expect(result.isPass, isTrue);
    });
  });

  group('VaultHealthCalculator.checkStaleRecords', () {
    test('passes for recent accounts', () {
      final accounts = [
        _makeAccount(id: 'a', createdAt: DateTime.now().millisecondsSinceEpoch),
      ];
      final result = VaultHealthCalculator.checkStaleRecords(accounts);
      expect(result.isPass, isTrue);
    });

    test('fails for accounts older than 180 days', () {
      final old = DateTime.now().subtract(const Duration(days: 181));
      final accounts = [
        _makeAccount(id: 'a', name: 'Old', createdAt: old.millisecondsSinceEpoch),
      ];
      final result = VaultHealthCalculator.checkStaleRecords(accounts);
      expect(result.isPass, isFalse);
      expect(result.description, contains('1'));
    });

    test('ignores deleted accounts', () {
      final old = DateTime.now().subtract(const Duration(days: 200));
      final accounts = [
        _makeAccount(
          id: 'a',
          createdAt: old.millisecondsSinceEpoch,
          isDeleted: true,
        ),
      ];
      final result = VaultHealthCalculator.checkStaleRecords(accounts);
      expect(result.isPass, isTrue);
    });
  });

  group('VaultHealthCalculator.checkIncompleteRecords', () {
    test('passes when all accounts have URL', () {
      final accounts = [
        _makeAccount(id: 'a', data: {'url': 'https://example.com'}),
      ];
      final result = VaultHealthCalculator.checkIncompleteRecords(accounts, []);
      expect(result.isPass, isTrue);
    });

    test('fails when URL is missing', () {
      final accounts = [
        _makeAccount(id: 'a', name: 'NoUrl', data: {}),
      ];
      final result = VaultHealthCalculator.checkIncompleteRecords(accounts, []);
      expect(result.isPass, isFalse);
      expect(result.description, contains('1'));
    });

    test('ignores deleted accounts', () {
      final accounts = [
        _makeAccount(id: 'a', data: {}, isDeleted: true),
      ];
      final result = VaultHealthCalculator.checkIncompleteRecords(accounts, []);
      expect(result.isPass, isTrue);
    });
  });

  group('VaultHealthCalculator.checkMissing2FA', () {
    final templateWithTotp = _makeTemplate(
      templateId: 'totp_template',
      fields: [
        const AccountField(
          fieldKey: 'totp',
          label: '2FA',
          attributes: AccountFieldAttributes(type: AccountFieldType.custom, isReference: true),
        ),
      ],
    );

    final templateWithoutTotp = _makeTemplate(
      templateId: 'plain_template',
      fields: [
        const AccountField(
          fieldKey: 'username',
          label: 'Username',
          attributes: AccountFieldAttributes(type: AccountFieldType.text),
        ),
      ],
    );

    test('ignores templates without TOTP field', () {
      final accounts = [
        _makeAccount(id: 'a', templateId: 'plain_template'),
      ];
      final result = VaultHealthCalculator.checkMissing2FA(
        accounts,
        [templateWithoutTotp],
        [],
      );
      expect(result.isPass, isTrue);
    });

    test('passes when TOTP is linked', () {
      final accounts = [
        _makeAccount(id: 'a', name: 'Linked', templateId: 'totp_template'),
      ];
      final totps = [
        _makeTotp(id: 't1', linkedAccountIds: ['a']),
      ];
      final result = VaultHealthCalculator.checkMissing2FA(
        accounts,
        [templateWithTotp],
        totps,
      );
      expect(result.isPass, isTrue);
    });

    test('fails when TOTP is not linked', () {
      final accounts = [
        _makeAccount(id: 'a', name: 'Unlinked', templateId: 'totp_template'),
      ];
      final result = VaultHealthCalculator.checkMissing2FA(
        accounts,
        [templateWithTotp],
        [],
      );
      expect(result.isPass, isFalse);
      expect(result.description, contains('1'));
    });

    test('ignores deleted accounts', () {
      final accounts = [
        _makeAccount(
          id: 'a',
          templateId: 'totp_template',
          isDeleted: true,
        ),
      ];
      final result = VaultHealthCalculator.checkMissing2FA(
        accounts,
        [templateWithTotp],
        [],
      );
      expect(result.isPass, isTrue);
    });
  });
}
