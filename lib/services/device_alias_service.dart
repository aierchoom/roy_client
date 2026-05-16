import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// 设备别名服务，用于管理本地与远程设备的可读别名。
///
/// 当前设备别名优先从 [SharedPreferences] 读取，远程设备通过 deviceId 查表或生成短 ID 标签。
class DeviceAliasService {
  static const String _prefix = 'device_alias_';
  static const String _currentDeviceAliasKey = 'device_alias_current';

  final SharedPreferences? _prefs;

  DeviceAliasService._(this._prefs);

  /// Test-only constructor that avoids SharedPreferences initialization.
  DeviceAliasService.testable() : _prefs = null;

  static Future<DeviceAliasService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceAliasService._(prefs);
  }

  /// 解析给定 [deviceId] 的显示名称。当前设备优先返回已缓存别名，未知设备返回短 ID 标签。
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

  /// 为指定 [deviceId] 设置别名。
  Future<void> setAlias(String deviceId, String alias) async {
    if (deviceId.isEmpty) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$deviceId', alias.trim());
  }

  /// 设置当前设备的别名。
  Future<void> setCurrentDeviceAlias(String alias) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await prefs.setString(_currentDeviceAliasKey, alias.trim());
  }
}
