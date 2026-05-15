import 'package:secret_roy/services/auto_lock_service.dart';
import 'package:secret_roy/services/enhanced_crypto_service.dart';

class FakeAutoLockService extends AutoLockService {
  bool _locked = false;
  AutoLockDuration _duration = AutoLockDuration.oneMinute;

  FakeAutoLockService()
      : super(
          cryptoService: EnhancedCryptoService(secureStorage: null),
          secureStorage: null,
        );

  @override
  bool get isLocked => _locked;

  @override
  AutoLockDuration get duration => _duration;

  @override
  void lock() {
    _locked = true;
    notifyListeners();
  }

  @override
  void unlock() {
    _locked = false;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> setDuration(AutoLockDuration duration) async {
    _duration = duration;
    notifyListeners();
  }
}
