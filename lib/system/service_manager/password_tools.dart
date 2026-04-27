import '../../services/enhanced_crypto_service.dart';

class ServiceManagerPasswordTools {
  const ServiceManagerPasswordTools._();

  static String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
  }) {
    return EnhancedCryptoService.generatePassword(
      length: length,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSpecial: includeSpecial,
    );
  }

  static int calculatePasswordStrength(String password) {
    return EnhancedCryptoService.calculatePasswordStrength(password);
  }

  static String getPasswordStrengthLevel(int score) {
    return EnhancedCryptoService.getPasswordStrengthLevel(score);
  }
}
