import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// TOTP 使用的 HMAC 哈希算法枚举。
enum TotpAlgorithm { sha1, sha256, sha512 }

/// TOTP 处理过程中的异常。
class TotpException implements Exception {
  final String message;

  const TotpException(this.message);

  @override
  String toString() => 'TotpException($message)';
}

/// TOTP 配置数据类，包含密钥、算法、位数与周期等参数。
class TotpConfig {
  /// Base32 编码的 TOTP 密钥。
  final String secret;
  /// 服务商名称（如 Google）。
  final String? issuer;
  /// 用户账号标识。
  final String? account;
  /// 使用的 HMAC 算法，默认 SHA1。
  final TotpAlgorithm algorithm;
  /// OTP 位数，通常为 6 或 8。
  final int digits;
  /// 生成周期，单位为秒，默认 30。
  final int period;

  const TotpConfig({
    required this.secret,
    this.issuer,
    this.account,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
  });

  factory TotpConfig.fromJson(Map<String, dynamic> json) {
    return TotpConfig(
      secret: json['secret']?.toString() ?? '',
      issuer: _readOptionalString(json['issuer']),
      account: _readOptionalString(json['account']),
      algorithm: TotpService.parseAlgorithm(json['algorithm']),
      digits: _readInt(
        json['digits'],
        fieldName: 'digits',
        fallback: TotpService.defaultDigits,
      ),
      period: _readInt(
        json['period'],
        fieldName: 'period',
        fallback: TotpService.defaultPeriod,
      ),
    ).validated();
  }

  TotpConfig copyWith({
    String? secret,
    String? issuer,
    String? account,
    TotpAlgorithm? algorithm,
    int? digits,
    int? period,
  }) {
    return TotpConfig(
      secret: secret ?? this.secret,
      issuer: issuer ?? this.issuer,
      account: account ?? this.account,
      algorithm: algorithm ?? this.algorithm,
      digits: digits ?? this.digits,
      period: period ?? this.period,
    );
  }

  TotpConfig validated() {
    TotpService.decodeBase32(secret);
    if (digits < 6 || digits > 8) {
      throw const TotpException('TOTP digits must be between 6 and 8.');
    }
    if (period <= 0) {
      throw const TotpException('TOTP period must be greater than zero.');
    }
    return copyWith(secret: TotpService.normalizeSecret(secret));
  }

  Map<String, dynamic> toJson() {
    return {
      'secret': TotpService.normalizeSecret(secret),
      if (issuer != null && issuer!.isNotEmpty) 'issuer': issuer,
      if (account != null && account!.isNotEmpty) 'account': account,
      'algorithm': TotpService.algorithmName(algorithm),
      'digits': digits,
      'period': period,
    };
  }
}

/// TOTP 实时码数据类，包含当前 OTP 值与剩余有效时间。
class TotpCode {
  /// 当前 OTP 字符串值。
  final String value;
  /// 当前周期内剩余有效秒数。
  final int secondsRemaining;
  /// 生成周期，单位为秒。
  final int period;
  /// 当前时间窗口计数器。
  final int counter;
  /// 生成时间戳。
  final DateTime generatedAt;

  const TotpCode({
    required this.value,
    required this.secondsRemaining,
    required this.period,
    required this.counter,
    required this.generatedAt,
  });
}

/// TOTP 服务，实现 RFC 6238 标准的时间一次性密码生成与解析。
///
/// 支持 Base32 密钥、otpauth:// URI 与 JSON 配置三种输入格式。
class TotpService {
  static const int defaultDigits = 6;
  static const int defaultPeriod = 30;
  static const int minimumSecretBytes = 10;
  static const String _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  const TotpService();

  /// 解析 TOTP 配置，支持 JSON、otpauth:// URI 与纯 Base32 字符串。
  static TotpConfig parseConfig(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      throw const TotpException('TOTP secret is required.');
    }

    if (normalized.startsWith('{')) {
      final Object? decoded;
      try {
        decoded = jsonDecode(normalized);
      } on FormatException {
        throw const TotpException('TOTP config JSON is invalid.');
      }
      if (decoded is! Map) {
        throw const TotpException('TOTP config JSON must be an object.');
      }
      return TotpConfig.fromJson(Map<String, dynamic>.from(decoded));
    }

    if (normalized.toLowerCase().startsWith('otpauth://')) {
      return parseOtpAuthUri(normalized);
    }

    return TotpConfig(secret: normalized).validated();
  }

  static String encodeConfig(String raw) {
    return jsonEncode(parseConfig(raw).toJson());
  }

  static TotpConfig parseOtpAuthUri(String rawUri) {
    final uri = Uri.tryParse(rawUri.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'otpauth') {
      throw const TotpException('TOTP URI must start with otpauth://.');
    }
    if (uri.host.toLowerCase() != 'totp') {
      throw const TotpException('Only otpauth://totp URIs are supported.');
    }

    final secret = uri.queryParameters['secret'];
    if (secret == null || secret.trim().isEmpty) {
      throw const TotpException('TOTP URI is missing a secret.');
    }

    final label = uri.pathSegments.isEmpty ? '' : uri.pathSegments.join('/');
    final labelParts = _splitIssuerLabel(label);
    final issuer =
        _readOptionalString(uri.queryParameters['issuer']) ?? labelParts.issuer;
    final account = labelParts.account;

    return TotpConfig(
      secret: secret,
      issuer: issuer,
      account: account,
      algorithm: parseAlgorithm(uri.queryParameters['algorithm']),
      digits: _readInt(
        uri.queryParameters['digits'],
        fieldName: 'digits',
        fallback: defaultDigits,
      ),
      period: _readInt(
        uri.queryParameters['period'],
        fieldName: 'period',
        fallback: defaultPeriod,
      ),
    ).validated();
  }

  /// 根据 [config] 生成当前时间窗口的 TOTP 码，可选指定时间 [at]。
  TotpCode generate(TotpConfig config, {DateTime? at}) {
    final validConfig = config.validated();
    final now = at ?? DateTime.now();
    final seconds = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final counter = seconds ~/ validConfig.period;
    final remaining = validConfig.period - (seconds % validConfig.period);

    return TotpCode(
      value: hotp(
        secret: validConfig.secret,
        counter: counter,
        algorithm: validConfig.algorithm,
        digits: validConfig.digits,
      ),
      secondsRemaining: remaining == 0 ? validConfig.period : remaining,
      period: validConfig.period,
      counter: counter,
      generatedAt: now,
    );
  }

  /// 基于 [secret] 与 [counter] 生成 HOTP 码（RFC 4226）。
  static String hotp({
    required String secret,
    required int counter,
    TotpAlgorithm algorithm = TotpAlgorithm.sha1,
    int digits = defaultDigits,
  }) {
    if (counter < 0) {
      throw const TotpException('HOTP counter must not be negative.');
    }
    if (digits < 6 || digits > 8) {
      throw const TotpException('TOTP digits must be between 6 and 8.');
    }

    final key = decodeBase32(secret);
    final counterBytes = ByteData(8)..setUint64(0, counter);
    final digest = _hmac(algorithm, key, counterBytes.buffer.asUint8List());
    final offset = digest.last & 0x0f;
    final binary =
        ((digest[offset] & 0x7f) << 24) |
        ((digest[offset + 1] & 0xff) << 16) |
        ((digest[offset + 2] & 0xff) << 8) |
        (digest[offset + 3] & 0xff);
    final otp = binary % _powerOf10(digits);
    return otp.toString().padLeft(digits, '0');
  }

  static List<int> decodeBase32(String secret) {
    final normalized = normalizeSecret(secret);
    if (normalized.isEmpty) {
      throw const TotpException('TOTP secret is required.');
    }

    var buffer = 0;
    var bitsLeft = 0;
    final bytes = <int>[];

    for (final codeUnit in normalized.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      final value = _base32Alphabet.indexOf(char);
      if (value < 0) {
        throw const TotpException('TOTP secret must be valid Base32.');
      }
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        bytes.add((buffer >> bitsLeft) & 0xff);
      }
    }

    if (bytes.length < minimumSecretBytes) {
      throw const TotpException('TOTP secret is too short.');
    }
    return bytes;
  }

  static String normalizeSecret(String secret) {
    return secret.trim().replaceAll(RegExp(r'[\s=-]+'), '').toUpperCase();
  }

  static TotpAlgorithm parseAlgorithm(Object? raw) {
    final normalized = (raw?.toString().trim().isEmpty ?? true)
        ? 'sha1'
        : raw.toString().trim().toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );

    return switch (normalized) {
      'sha1' => TotpAlgorithm.sha1,
      'sha256' => TotpAlgorithm.sha256,
      'sha512' => TotpAlgorithm.sha512,
      _ => throw const TotpException('Unsupported TOTP algorithm.'),
    };
  }

  static String algorithmName(TotpAlgorithm algorithm) {
    return switch (algorithm) {
      TotpAlgorithm.sha1 => 'SHA1',
      TotpAlgorithm.sha256 => 'SHA256',
      TotpAlgorithm.sha512 => 'SHA512',
    };
  }

  static List<int> _hmac(
    TotpAlgorithm algorithm,
    List<int> key,
    List<int> message,
  ) {
    final digest = switch (algorithm) {
      TotpAlgorithm.sha1 => crypto.sha1,
      TotpAlgorithm.sha256 => crypto.sha256,
      TotpAlgorithm.sha512 => crypto.sha512,
    };
    return crypto.Hmac(digest, key).convert(message).bytes;
  }

  static int _powerOf10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i += 1) {
      result *= 10;
    }
    return result;
  }

  static ({String? issuer, String? account}) _splitIssuerLabel(String label) {
    if (label.isEmpty) {
      return (issuer: null, account: null);
    }
    final separatorIndex = label.indexOf(':');
    if (separatorIndex < 0) {
      return (issuer: null, account: label);
    }
    final issuer = label.substring(0, separatorIndex).trim();
    final account = label.substring(separatorIndex + 1).trim();
    return (
      issuer: issuer.isEmpty ? null : issuer,
      account: account.isEmpty ? null : account,
    );
  }
}

String? _readOptionalString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

int _readInt(
  Object? value, {
  required String fieldName,
  required int fallback,
}) {
  if (value == null) {
    return fallback;
  }
  if (value is int) {
    return value;
  }
  final parsed = int.tryParse(value.toString());
  if (parsed == null) {
    throw TotpException('TOTP $fieldName must be an integer.');
  }
  return parsed;
}
