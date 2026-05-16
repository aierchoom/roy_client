import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/l10n/app_localizations.dart';
import 'package:secret_roy/services/device_alias_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DeviceAliasService', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<String> _resolve(
      WidgetTester tester,
      DeviceAliasService service,
      String? deviceId, {
      String? currentDeviceId,
    }) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) {
              result = service.resolve(
                context,
                deviceId,
                currentDeviceId: currentDeviceId,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      return result;
    }

    testWidgets('create returns a service instance', (tester) async {
      final service = await DeviceAliasService.create();
      expect(service, isA<DeviceAliasService>());
    });

    testWidgets('resolve returns cached alias for remote device', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      await service.setAlias('device_abc123', 'My Laptop');
      final result = await _resolve(tester, service, 'device_abc123');
      expect(result, 'My Laptop');
    });

    testWidgets('resolve falls back to l10n deviceLabel with shortId', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      final result = await _resolve(tester, service, 'device_abc123456');
      expect(result, '设备 #123456');
    });

    testWidgets('resolve falls back to full deviceId when length <= 6', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      final result = await _resolve(tester, service, 'abc');
      expect(result, '设备 #abc');
    });

    testWidgets('resolve returns unknownDevice for null deviceId', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      final result = await _resolve(tester, service, null);
      expect(result, '未知设备');
    });

    testWidgets('resolve returns unknownDevice for empty deviceId', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      final result = await _resolve(tester, service, '');
      expect(result, '未知设备');
    });

    testWidgets('resolve returns cached alias for current device', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      await service.setCurrentDeviceAlias('My Phone');
      final result = await _resolve(
        tester,
        service,
        'dev_123',
        currentDeviceId: 'dev_123',
      );
      expect(result, 'My Phone');
    });

    testWidgets('resolve returns thisDevice for current device without alias', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      final result = await _resolve(
        tester,
        service,
        'dev_123',
        currentDeviceId: 'dev_123',
      );
      expect(result, '本机');
    });

    testWidgets('setAlias persists and trims whitespace', (tester) async {
      final service = await DeviceAliasService.create();
      await service.setAlias('dev_456', '  Work PC  ');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_alias_dev_456'), 'Work PC');

      final result = await _resolve(tester, service, 'dev_456');
      expect(result, 'Work PC');
    });

    testWidgets('setCurrentDeviceAlias persists and trims whitespace', (
      tester,
    ) async {
      final service = await DeviceAliasService.create();
      await service.setCurrentDeviceAlias('  My Tablet  ');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('device_alias_current'), 'My Tablet');

      final result = await _resolve(
        tester,
        service,
        'dev_789',
        currentDeviceId: 'dev_789',
      );
      expect(result, 'My Tablet');
    });

    testWidgets('setAlias with empty deviceId is a no-op', (tester) async {
      final service = await DeviceAliasService.create();
      await service.setAlias('', 'Should not persist');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('device_alias_'), isFalse);
    });

    testWidgets(
      'resolve ignores empty cached alias and falls back for current device',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_alias_current', '');

        final service = await DeviceAliasService.create();
        final result = await _resolve(
          tester,
          service,
          'dev_x',
          currentDeviceId: 'dev_x',
        );
        expect(result, '本机');
      },
    );

    testWidgets(
      'resolve ignores empty cached alias and falls back for remote device',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('device_alias_dev_y', '');

        final service = await DeviceAliasService.create();
        final result = await _resolve(tester, service, 'dev_y');
        expect(result, '设备 #dev_y');
      },
    );

    testWidgets(
      'resolve returns alias for remote device even when currentDeviceId matches another device',
      (tester) async {
        final service = await DeviceAliasService.create();
        await service.setAlias('remote_1', 'Remote Alias');
        final result = await _resolve(
          tester,
          service,
          'remote_1',
          currentDeviceId: 'current_2',
        );
        expect(result, 'Remote Alias');
      },
    );
  });
}
