import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/services/totp_service.dart';
import 'package:secret_roy/widgets/account_list_tile.dart';

void main() {
  String localeText(BuildContext context, String zh, String en) => zh;

  AccountTemplate templateWithTotp() {
    return const AccountTemplate(
      templateId: 'website',
      title: '网站',
      subTitle: '登录信息',
      category: TemplateCategory.login,
      fields: [
        AccountField(
          fieldKey: 'username',
          label: '用户名',
          attributes: AccountFieldAttributes(
            type: AccountFieldType.text,
            isPrimary: true,
          ),
        ),
        AccountField(
          fieldKey: 'totp_secret',
          label: '2FA 密钥',
          attributes: AccountFieldAttributes.totpDefaults,
        ),
      ],
    );
  }

  AccountItem accountWithTotp(String totpConfig) {
    return AccountItem(
      id: 'account_1',
      name: 'Example',
      email: 'alice@example.com',
      templateId: 'website',
      data: {'username': 'alice', 'totp_secret': totpConfig},
      createdAt: 1,
      nameHlc: Hlc.zero('local'),
      emailHlc: Hlc.zero('local'),
      dataHlc: {'totp_secret': Hlc.zero('local')},
      syncStatus: SyncStatus.synchronized,
    );
  }

  testWidgets('shows only configured 2FA state in account list rows', (
    tester,
  ) async {
    final totpConfig = TotpService.encodeConfig(
      'otpauth://totp/Example:alice@example.com?'
      'secret=JBSWY3DPEHPK3PXP&issuer=Example',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountListTile(
            account: accountWithTotp(totpConfig),
            template: templateWithTotp(),
            hasMissingTemplate: false,
            legacyFieldCount: 0,
            onEdit: () {},
            onDelete: () {},
            localeText: localeText,
          ),
        ),
      ),
    );

    expect(find.text('已配置 2FA'), findsOneWidget);
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsNothing);
    expect(find.textContaining('otpauth://'), findsNothing);

    await tester.tap(find.byTooltip('切换详情'));
    await tester.pumpAndSettle();

    expect(find.text('2FA 密钥'), findsOneWidget);
    expect(find.text('已配置 2FA'), findsNWidgets(2));
    expect(find.byTooltip('显示密码'), findsNothing);
    expect(find.byTooltip('复制 2FA 密钥'), findsNothing);
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsNothing);
  });
}
