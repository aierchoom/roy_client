import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/widgets/account_list_tile.dart';

void main() {
  String localeText(BuildContext context, String zh, String en) => en;

  AccountTemplate websiteTemplate() {
    return const AccountTemplate(
      templateId: 'website',
      title: 'Website',
      subTitle: 'Login',
      category: TemplateCategory.login,
      fields: [
        AccountField(
          fieldKey: 'username',
          label: 'Username',
          attributes: AccountFieldAttributes(
            type: AccountFieldType.text,
            isPrimary: true,
          ),
        ),
        AccountField(
          fieldKey: 'password',
          label: 'Password',
          attributes: AccountFieldAttributes(
            type: AccountFieldType.password,
            isSecret: true,
          ),
        ),
      ],
    );
  }

  AccountItem account() {
    return AccountItem(
      id: 'account_1',
      name: 'Example',
      email: 'alice@example.com',
      templateId: 'website',
      data: {'username': 'alice', 'password': 'secret-value'},
      createdAt: 1,
      nameHlc: Hlc.zero('local'),
      emailHlc: Hlc.zero('local'),
      dataHlc: {'password': Hlc.zero('local')},
      syncStatus: SyncStatus.synchronized,
    );
  }

  testWidgets('shows linked 2FA state without exposing a TOTP secret', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountListTile(
            account: account(),
            template: websiteTemplate(),
            hasMissingTemplate: false,
            legacyFieldCount: 0,
            linkedTotpCredentialCount: 1,
            onEdit: () {},
            onDelete: () {},
            localeText: localeText,
          ),
        ),
      ),
    );

    expect(find.text('2FA enabled'), findsOneWidget);
    expect(find.textContaining('otpauth://'), findsNothing);
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsNothing);

    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();

    expect(find.text('Field Details'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('2FA enabled'), findsOneWidget);
    expect(find.textContaining('otpauth://'), findsNothing);
    expect(find.textContaining('JBSWY3DPEHPK3PXP'), findsNothing);
  });

  testWidgets('collapsed summary shows slash-separated fields with masked secrets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountListTile(
            account: account(),
            template: websiteTemplate(),
            hasMissingTemplate: false,
            legacyFieldCount: 0,
            onEdit: () {},
            onDelete: () {},
            localeText: localeText,
          ),
        ),
      ),
    );

    // Account badge shows template badge text.
    expect(find.text('WE'), findsOneWidget);

    // Collapsed summary contains labelled fields joined by ' / '.
    expect(
      find.textContaining('Email: alice@example.com / Username: alice / Password: ••••'),
      findsOneWidget,
    );

    // Field count tag shows '3 fields' in the test locale.
    expect(find.text('3 fields'), findsOneWidget);

    // Expand to reveal field details.
    await tester.tap(find.byTooltip('Details'));
    await tester.pumpAndSettle();

    // Collapsed summary should disappear.
    expect(
      find.textContaining('Email: alice@example.com / Username: alice / Password: ••••'),
      findsNothing,
    );
  });
}
