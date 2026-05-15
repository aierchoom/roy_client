import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/auto_lock_service.dart';
import 'package:secret_roy/services/enhanced_crypto_service.dart';

void main() {
  group('AutoLockService', () {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return null;
      });
    });

    tearDownAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('initial state is locked', () {
      final service = AutoLockService(
        cryptoService: EnhancedCryptoService(secureStorage: null),
      );
      expect(service.state, AutoLockState.locked);
      expect(service.isLocked, true);
      expect(service.isUnlocked, false);
      service.dispose();
    });

    test('unlock transitions to unlocked', () {
      final service = AutoLockService(
        cryptoService: EnhancedCryptoService(secureStorage: null),
      );
      service.unlock();
      expect(service.state, AutoLockState.unlocked);
      expect(service.isLocked, false);
      expect(service.isUnlocked, true);
      service.dispose();
    });

    test('lock transitions to locked', () {
      final service = AutoLockService(
        cryptoService: EnhancedCryptoService(secureStorage: null),
      );
      service.unlock();
      service.lock();
      expect(service.state, AutoLockState.locked);
      expect(service.isLocked, true);
      service.dispose();
    });

    test('setDuration updates duration', () async {
      final service = AutoLockService(
        cryptoService: EnhancedCryptoService(secureStorage: null),
      );
      expect(service.duration, AutoLockDuration.oneMinute);
      await service.setDuration(AutoLockDuration.fiveMinutes);
      expect(service.duration, AutoLockDuration.fiveMinutes);
      service.dispose();
    });

    test('duration display names are correct', () {
      expect(AutoLockDuration.immediately.displayName, 'Immediately');
      expect(AutoLockDuration.fiveSeconds.displayName, '5 seconds');
      expect(AutoLockDuration.thirtySeconds.displayName, '30 seconds');
      expect(AutoLockDuration.oneMinute.displayName, '1 minute');
      expect(AutoLockDuration.fiveMinutes.displayName, '5 minutes');
      expect(AutoLockDuration.tenMinutes.displayName, '10 minutes');
      expect(AutoLockDuration.never.displayName, 'Never');
    });

    test('fromDuration returns matching enum', () {
      expect(
        AutoLockDuration.fromDuration(const Duration(seconds: 5)),
        AutoLockDuration.fiveSeconds,
      );
      expect(
        AutoLockDuration.fromDuration(const Duration(minutes: 10)),
        AutoLockDuration.tenMinutes,
      );
    });

    test('fromDuration falls back to oneMinute for unknown duration', () {
      expect(
        AutoLockDuration.fromDuration(const Duration(hours: 1)),
        AutoLockDuration.oneMinute,
      );
    });

    test('notifyListeners on state change', () {
      final service = AutoLockService(
        cryptoService: EnhancedCryptoService(secureStorage: null),
      );
      var notified = 0;
      service.addListener(() => notified++);
      service.unlock();
      expect(notified, greaterThanOrEqualTo(1));
      service.lock();
      expect(notified, greaterThanOrEqualTo(2));
      service.dispose();
    });
  });
}
