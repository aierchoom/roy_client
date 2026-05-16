import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/enhanced_crypto_service.dart';

void main() {
  group('EnhancedCryptoService', () {
    final Map<String, String?> _mockStorage = {};
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map<dynamic, dynamic>;
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return key != null ? _mockStorage[key] : null;
          case 'write':
            if (key != null) {
              _mockStorage[key] = args['value'] as String?;
            }
            return null;
          case 'delete':
            if (key != null) {
              _mockStorage.remove(key);
            }
            return null;
          case 'deleteAll':
            _mockStorage.clear();
            return null;
        }
        return null;
      });
    });

    tearDown(() {
      _mockStorage.clear();
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('initMasterKey first time stores hash and unlocks', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      final result = await service.initMasterKey('password123');
      expect(result, true);
      expect(service.hasMasterKey, true);
    });

    test('initMasterKey verifies existing pbkdf2 hash', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('password123');
      // Re-create to simulate new session reading stored hash
      final service2 = EnhancedCryptoService(secureStorage: null);
      final result = await service2.initMasterKey('password123');
      expect(result, true);
      expect(service2.hasMasterKey, true);
    });

    test('initMasterKey rejects wrong password for existing hash', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('password123');
      final service2 = EnhancedCryptoService(secureStorage: null);
      final result = await service2.initMasterKey('wrong');
      expect(result, false);
      expect(service2.hasMasterKey, false);
    });

    test('initMasterKey migrates legacy plaintext password', () async {
      _mockStorage['master_password'] = 'legacy_pass';
      final service = EnhancedCryptoService(secureStorage: null);
      final result = await service.initMasterKey('legacy_pass');
      expect(result, true);
      expect(service.hasMasterKey, true);
      // Legacy key should be deleted and hash stored.
      expect(_mockStorage.containsKey('master_password'), false);
      expect(_mockStorage.containsKey('master_password_hash'), true);
    });

    test('initMasterKey rejects wrong legacy password', () async {
      _mockStorage['master_password'] = 'legacy_pass';
      final service = EnhancedCryptoService(secureStorage: null);
      final result = await service.initMasterKey('wrong');
      expect(result, false);
      expect(service.hasMasterKey, false);
    });

    test('verifyMasterPassword returns true for correct password', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('password123');
      final ok = await service.verifyMasterPassword('password123');
      expect(ok, true);
    });

    test('verifyMasterPassword returns false for wrong password', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('password123');
      final ok = await service.verifyMasterPassword('wrong');
      expect(ok, false);
    });

    test('verifyMasterPassword returns false when nothing stored', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      final ok = await service.verifyMasterPassword('anything');
      expect(ok, false);
    });

    test('updateMasterPassword with correct old password', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('old_pass');
      final ok = await service.updateMasterPassword('old_pass', 'new_pass');
      expect(ok, true);
      expect(service.hasMasterKey, true);
      // New password should work.
      final verify = await service.verifyMasterPassword('new_pass');
      expect(verify, true);
    });

    test('updateMasterPassword with wrong old password fails', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('old_pass');
      final ok = await service.updateMasterPassword('wrong', 'new_pass');
      expect(ok, false);
    });

    test('logout clears master key', () async {
      final service = EnhancedCryptoService(secureStorage: null);
      await service.initMasterKey('password123');
      expect(service.hasMasterKey, true);
      service.logout();
      expect(service.hasMasterKey, false);
    });

    test('calculatePasswordStrength scores weak password low', () {
      expect(
        EnhancedCryptoService.calculatePasswordStrength('123'),
        lessThan(EnhancedCryptoService.strengthThresholdWeak),
      );
    });

    test('calculatePasswordStrength scores strong password high', () {
      expect(
        EnhancedCryptoService.calculatePasswordStrength(
          'Tr0ub4dor&3xcellent!Long',
        ),
        greaterThan(EnhancedCryptoService.strengthThresholdStrong),
      );
    });

    test('getPasswordStrengthLevel returns correct labels', () {
      expect(
        EnhancedCryptoService.getPasswordStrengthLevel(90),
        'Very strong',
      );
      expect(
        EnhancedCryptoService.getPasswordStrengthLevel(70),
        'Strong',
      );
      expect(
        EnhancedCryptoService.getPasswordStrengthLevel(50),
        'Medium',
      );
      expect(
        EnhancedCryptoService.getPasswordStrengthLevel(30),
        'Weak',
      );
      expect(
        EnhancedCryptoService.getPasswordStrengthLevel(10),
        'Very weak',
      );
    });
  });
}
