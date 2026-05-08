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

  Future<void> initialize() async {
    await _loadSettings();
    _state = await _checkNeedsLock()
        ? AutoLockState.locked
        : AutoLockState.unlocked;
    _notify();
  }

  Future<void> setDuration(AutoLockDuration duration) async {
    _duration = duration;
    await _secureStorage.write(
      key: _autoLockDurationKey,
      value: duration.duration.inSeconds.toString(),
    );
    _notify();
  }

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

  void lock() {
    _cancelBackgroundTimer();
    _cryptoService.logout();
    _state = AutoLockState.locked;
    _backgroundTime = null;
    _notify();
  }

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
