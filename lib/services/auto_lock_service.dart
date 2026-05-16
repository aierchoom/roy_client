import 'dart:async';

import 'package:secret_roy/core/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'enhanced_crypto_service.dart';

enum AutoLockDuration {
  immediately(Duration.zero),
  fiveSeconds(Duration(seconds: 5)),
  thirtySeconds(Duration(seconds: 30)),
  oneMinute(Duration(minutes: 1)),
  fiveMinutes(Duration(minutes: 5)),
  tenMinutes(Duration(minutes: 10)),
  never(
    Duration(days: 999999),
  ); // Semantically "never" via special-case checks in lock logic.

  final Duration duration;

  const AutoLockDuration(this.duration);

  String get displayName {
    switch (this) {
      case AutoLockDuration.immediately:
        return 'Immediately';
      case AutoLockDuration.fiveSeconds:
        return '5 seconds';
      case AutoLockDuration.thirtySeconds:
        return '30 seconds';
      case AutoLockDuration.oneMinute:
        return '1 minute';
      case AutoLockDuration.fiveMinutes:
        return '5 minutes';
      case AutoLockDuration.tenMinutes:
        return '10 minutes';
      case AutoLockDuration.never:
        return 'Never';
    }
  }

  static AutoLockDuration fromDuration(Duration duration) {
    for (final option in values) {
      if (option.duration == duration) {
        return option;
      }
    }
    return AutoLockDuration.oneMinute;
  }
}

enum AutoLockState { unlocked, locked, backgroundTimer }

/// 自动锁定服务，根据应用生命周期与超时策略控制保险库的自动锁定。
///
/// [AutoLockService] 监听应用前后台切换，在用户设定的无操作时间后自动触发锁定。
/// 锁定操作会清除 [EnhancedCryptoService] 中的数据库密钥，使保险库回到加密状态。
/// 支持从 immediately 到 never 的多档超时配置，配置持久化在 [FlutterSecureStorage]。
///
/// 使用场景：
/// ```dart
/// final autoLock = AutoLockService(cryptoService: cryptoService);
/// await autoLock.initialize();
/// // 应用进入后台时自动启动计时器
/// autoLock.onAppLifecycleStateChanged(AppLifecycleState.paused);
/// ```
///
/// 生命周期：
/// - [initialize] 读取上次活跃时间并判断是否需要立即锁定。
/// - [unlock] / [lock] 由 [ServiceManager] 在解锁/锁定时调用。
/// - [dispose] 在应用退出时取消后台计时器。
///
/// 注意：实际的生命周期监听由 [AutoLockObserver]（[WidgetsBindingObserver]）代理。
class AutoLockService extends ChangeNotifier {
  final EnhancedCryptoService _cryptoService;
  final FlutterSecureStorage _secureStorage;

  static const String _autoLockDurationKey = 'auto_lock_duration';
  static const String _lastActiveTimeKey = 'last_active_time';

  Timer? _backgroundTimer;
  AutoLockState _state = AutoLockState.locked;
  AutoLockDuration _duration = AutoLockDuration.oneMinute;
  DateTime? _backgroundTime;
  bool _disposed = false;

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  AutoLockService({
    required EnhancedCryptoService cryptoService,
    FlutterSecureStorage? secureStorage,
  }) : _cryptoService = cryptoService,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  AutoLockState get state => _state;
  AutoLockDuration get duration => _duration;
  bool get isLocked => _state == AutoLockState.locked;
  bool get isUnlocked => _state == AutoLockState.unlocked;

  /// 初始化自动锁定服务，加载持久化的超时设置并判断当前锁定状态。
  ///
  /// 从 [FlutterSecureStorage] 读取上次活跃时间与 [AutoLockDuration]，
  /// 若已超时则状态设为 [AutoLockState.locked]，否则为 [AutoLockState.unlocked]。
  /// 初始化完成后会通知监听者。
  Future<void> initialize() async {
    await _loadSettings();
    _state = await _checkNeedsLock()
        ? AutoLockState.locked
        : AutoLockState.unlocked;
    _notify();
  }

  /// 设置自动锁定超时时长并持久化。
  ///
  /// [duration] 为新的超时策略，会写入 [FlutterSecureStorage] 的 `_auto_lock_duration_key`。
  /// 设置完成后通知监听者。
  Future<void> setDuration(AutoLockDuration duration) async {
    _duration = duration;
    await _secureStorage.write(
      key: _autoLockDurationKey,
      value: duration.duration.inSeconds.toString(),
    );
    _notify();
  }

  /// 响应应用生命周期状态变化，启动或取消后台锁定计时器。
  ///
  /// [state] 为 Flutter 应用生命周期状态：
  /// - [AppLifecycleState.paused] / [AppLifecycleState.inactive] / [AppLifecycleState.hidden]：
  ///   记录当前时间并启动后台计时器（若设置为 immediately 则直接锁定）。
  /// - [AppLifecycleState.resumed]：检查后台期间是否已超时，若超时则锁定。
  /// - [AppLifecycleState.detached]：保存最后活跃时间。
  ///
  /// 通常由 [AutoLockObserver.didChangeAppLifecycleState] 代理调用。
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _onAppBackgrounded();
        return;
      case AppLifecycleState.resumed:
        _onAppResumed();
        return;
      case AppLifecycleState.detached:
        _onAppDetached();
        return;
    }
  }

  /// 立即锁定保险库，取消后台计时器并清除加密密钥。
  ///
  /// 内部调用 [EnhancedCryptoService.logout] 清除数据库密钥，
  /// 并将状态设为 [AutoLockState.locked]。
  /// 此操作会触发 [notifyListeners]，[ServiceManager] 应监听并执行进一步清理。
  void lock() {
    _cancelBackgroundTimer();
    _cryptoService.logout();
    _state = AutoLockState.locked;
    _backgroundTime = null;
    _notify();
  }

  /// 将自动锁定状态重置为解锁，清除后台计时状态。
  ///
  /// 通常在 [ServiceManager] 成功解锁保险库后调用，
  /// 使 [AutoLockService] 重新开始计时。
  void unlock() {
    _state = AutoLockState.unlocked;
    _backgroundTime = null;
    _notify();
  }

  Future<void> _loadSettings() async {
    try {
      final rawValue = await _secureStorage.read(key: _autoLockDurationKey);
      final seconds = int.tryParse(rawValue ?? '');
      if (seconds != null) {
        _duration = AutoLockDuration.fromDuration(Duration(seconds: seconds));
      }
    } catch (e) {
      AppLogger.d('Failed to load auto-lock setting: $e');
    }
  }

  void _onAppBackgrounded() {
    if (_state == AutoLockState.locked) return;

    _backgroundTime = DateTime.now();
    unawaited(_saveLastActiveTime());

    if (_duration == AutoLockDuration.immediately) {
      lock();
      return;
    }

    if (_duration != AutoLockDuration.never) {
      _state = AutoLockState.backgroundTimer;
      _startBackgroundTimer();
      _notify();
    }
  }

  void _onAppResumed() {
    _cancelBackgroundTimer();
    if (_state == AutoLockState.locked) return;

    if (_checkTimeout()) {
      lock();
      return;
    }

    _state = AutoLockState.unlocked;
    _backgroundTime = null;
    _notify();
  }

  void _onAppDetached() {
    _cancelBackgroundTimer();
    unawaited(_saveLastActiveTime());
  }

  Future<bool> _checkNeedsLock() async {
    if (_duration == AutoLockDuration.never) return false;

    try {
      final lastActiveRaw = await _secureStorage.read(key: _lastActiveTimeKey);
      if (lastActiveRaw == null) return true;

      final lastActive = DateTime.fromMillisecondsSinceEpoch(
        int.parse(lastActiveRaw),
      );
      final elapsed = DateTime.now().difference(lastActive);
      return elapsed > _duration.duration;
    } catch (e) {
      AppLogger.d('Auto-lock check failed, defaulting to locked: $e');
      return true;
    }
  }

  bool _checkTimeout() {
    if (_backgroundTime == null) return false;
    if (_duration == AutoLockDuration.never) return false;

    final elapsed = DateTime.now().difference(_backgroundTime!);
    return elapsed > _duration.duration;
  }

  void _startBackgroundTimer() {
    _cancelBackgroundTimer();
    if (_duration == AutoLockDuration.never) return;

    _backgroundTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_checkTimeout()) {
        lock();
      }
    });
  }

  void _cancelBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  Future<void> _saveLastActiveTime() async {
    await _secureStorage.write(
      key: _lastActiveTimeKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelBackgroundTimer();
    unawaited(_saveLastActiveTime());
    super.dispose();
  }
}

class AutoLockObserver extends WidgetsBindingObserver {
  final AutoLockService _autoLockService;

  AutoLockObserver(this._autoLockService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _autoLockService.onAppLifecycleStateChanged(state);
  }
}
