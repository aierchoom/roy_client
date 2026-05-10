import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

class DeviceAliasService {
  static const String _prefix = 'device_alias_';
  static const String _currentDeviceAliasKey = 'device_alias_current';

  final SharedPreferences? _prefs;

  DeviceAliasService._(this._prefs);

  static Future<DeviceAliasService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceAliasService._(prefs);
  }

  String resolve(BuildContext context, String? deviceId, {String? currentDeviceId}) {
    final l10n = AppLocalizations.of(context)!;

    if (deviceId == null || deviceId.isEmpty) {
      return l10n.unknownDevice;
    }

    if (currentDeviceId != null && deviceId == currentDeviceId) {
      final cached = _prefs?.getString(_currentDeviceAliasKey);
      if (cached != null && cached.isNotEmpty) return cached;
      return l10n.thisDevice;
    }

    final alias = _prefs?.getString('$_prefix$deviceId');
    if (alias != null && alias.isNotEmpty) return alias;

    final shortId = deviceId.length > 6 ? deviceId.substring(deviceId.length - 6) : deviceId;
    return '${l10n.deviceLabel} #$shortId';
  }

  Future<void> setAlias(String deviceId, String alias) async {
    if (deviceId.isEmpty) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$deviceId', alias.trim());
  }

  Future<void> setCurrentDeviceAlias(String alias) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_currentDeviceAliasKey, alias.trim());
  }
}
