import 'totp_service.dart';

class TotpImportService {
  static final RegExp _otpAuthUriPattern = RegExp(
    r'''otpauth://totp/[^\s<>"']+''',
    caseSensitive: false,
  );
  static final RegExp _labeledSecretPattern = RegExp(
    r'(?:secret|key|密钥)\s*[:：]\s*([A-Z2-7][A-Z2-7 =-]{15,})',
    caseSensitive: false,
  );

  const TotpImportService._();

  static String normalizeImportValue(String raw) {
    final candidate = extractCandidate(raw);
    if (candidate == null) {
      throw const TotpException('No TOTP QR content was found.');
    }
    return TotpService.encodeConfig(candidate);
  }

  static String? extractCandidate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (_canParse(trimmed)) return trimmed;

    for (final match in _otpAuthUriPattern.allMatches(trimmed)) {
      final uri = _trimUriCandidate(match.group(0) ?? '');
      if (_canParse(uri)) return uri;
    }

    for (final match in _labeledSecretPattern.allMatches(trimmed)) {
      final secret = match.group(1)?.trim() ?? '';
      if (_canParse(secret)) return secret;
    }

    return null;
  }

  static bool _canParse(String value) {
    if (value.trim().isEmpty) return false;
    try {
      TotpService.parseConfig(value);
      return true;
    } catch (_) {
      // Validation helper: any parse failure means the value is not valid TOTP config.
      return false;
    }
  }

  static String _trimUriCandidate(String value) {
    return value.trim().replaceFirst(RegExp(r'[),.;\]}]+$'), '');
  }
}
