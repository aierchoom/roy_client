import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/totp_service.dart';

void main() {
  group('TotpCredential', () {
    test('serializes independent 2FA data with account links', () {
      final credential = TotpCredential(
        id: 'totp_1',
        label: 'GitHub',
        config: TotpService.parseConfig(
          'otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP&issuer=GitHub',
        ),
        linkedAccountIds: const ['account_1', 'account_1', 'account_2'],
        createdAt: 10,
        labelHlc: const Hlc(11, 0, 'device_a'),
        configHlc: const Hlc(12, 0, 'device_a'),
        linksHlc: const Hlc(13, 0, 'device_a'),
        syncStatus: SyncStatus.pendingPush,
      );

      final decoded = TotpCredential.fromJson(credential.toJson());

      expect(decoded.id, 'totp_1');
      expect(decoded.displayLabel, 'GitHub');
      expect(decoded.linkedAccountIds, ['account_1', 'account_2']);
      expect(decoded.config.issuer, 'GitHub');
      expect(decoded.syncStatus, SyncStatus.pendingPush);
      expect(decoded.isLinkedToAccount('account_2'), isTrue);
    });

    test('uses issuer and account as fallback display label', () {
      final credential = TotpCredential(
        id: 'totp_2',
        label: '',
        config: TotpService.parseConfig(
          'otpauth://totp/Example:bob?secret=JBSWY3DPEHPK3PXP&issuer=Example',
        ),
        linkedAccountIds: const [],
        createdAt: 10,
        labelHlc: Hlc.zero('local'),
        configHlc: Hlc.zero('local'),
        linksHlc: Hlc.zero('local'),
      );

      expect(credential.displayLabel, 'Example · bob');
    });
  });
}
