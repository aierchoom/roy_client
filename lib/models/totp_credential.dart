import 'package:flutter/foundation.dart';

import '../services/totp_service.dart';
import 'account_item.dart';
import 'hlc.dart';

@immutable
class TotpCredential {
  final String id;
  final String label;
  final TotpConfig config;
  final List<String> linkedAccountIds;
  final int createdAt;
  final Hlc labelHlc;
  final Hlc configHlc;
  final Hlc linksHlc;
  final int serverVersion;
  final SyncStatus syncStatus;
  final bool isDeleted;
  final Hlc? deleteHlc;

  TotpCredential({
    required this.id,
    required this.label,
    required this.config,
    required List<String> linkedAccountIds,
    required this.createdAt,
    required this.labelHlc,
    required this.configHlc,
    required this.linksHlc,
    this.serverVersion = 0,
    this.syncStatus = SyncStatus.pendingPush,
    this.isDeleted = false,
    this.deleteHlc,
  }) : linkedAccountIds = _normalizeLinkedAccountIds(linkedAccountIds);

  factory TotpCredential.fromJson(Map<String, dynamic> json) {
    final dummyHlc = Hlc.zero('local');
    return TotpCredential(
      id:
          json['id'] as String? ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      label: json['label'] as String? ?? '',
      config: _readConfig(json['config']),
      linkedAccountIds: _readLinkedAccountIds(json['linkedAccountIds']),
      createdAt:
          json['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      labelHlc: json['labelHlc'] != null
          ? Hlc.parse(json['labelHlc'].toString())
          : dummyHlc,
      configHlc: json['configHlc'] != null
          ? Hlc.parse(json['configHlc'].toString())
          : dummyHlc,
      linksHlc: json['linksHlc'] != null
          ? Hlc.parse(json['linksHlc'].toString())
          : dummyHlc,
      serverVersion: json['serverVersion'] as int? ?? 0,
      syncStatus: syncStatusFromJson(json['syncStatus']),
      isDeleted: parseBoolValue(json['isDeleted']),
      deleteHlc: json['deleteHlc'] != null
          ? Hlc.parse(json['deleteHlc'].toString())
          : null,
    );
  }

  String get displayLabel {
    final explicit = label.trim();
    if (explicit.isNotEmpty) return explicit;
    final issuer = config.issuer?.trim() ?? '';
    final account = config.account?.trim() ?? '';
    if (issuer.isNotEmpty && account.isNotEmpty) return '$issuer · $account';
    if (account.isNotEmpty) return account;
    if (issuer.isNotEmpty) return issuer;
    return '2FA Credential';
  }

  bool isLinkedToAccount(String accountId) {
    return linkedAccountIds.contains(accountId);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'config': config.toJson(),
      'linkedAccountIds': linkedAccountIds,
      'createdAt': createdAt,
      'labelHlc': labelHlc.toString(),
      'configHlc': configHlc.toString(),
      'linksHlc': linksHlc.toString(),
      'serverVersion': serverVersion,
      'syncStatus': syncStatus.name,
      'isDeleted': isDeleted,
      'deleteHlc': deleteHlc?.toString(),
    };
  }

  TotpCredential copyWith({
    String? id,
    String? label,
    TotpConfig? config,
    List<String>? linkedAccountIds,
    int? createdAt,
    Hlc? labelHlc,
    Hlc? configHlc,
    Hlc? linksHlc,
    int? serverVersion,
    SyncStatus? syncStatus,
    bool? isDeleted,
    Hlc? deleteHlc,
  }) {
    return TotpCredential(
      id: id ?? this.id,
      label: label ?? this.label,
      config: config ?? this.config,
      linkedAccountIds: linkedAccountIds ?? this.linkedAccountIds,
      createdAt: createdAt ?? this.createdAt,
      labelHlc: labelHlc ?? this.labelHlc,
      configHlc: configHlc ?? this.configHlc,
      linksHlc: linksHlc ?? this.linksHlc,
      serverVersion: serverVersion ?? this.serverVersion,
      syncStatus: syncStatus ?? this.syncStatus,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteHlc: deleteHlc ?? this.deleteHlc,
    );
  }

  static TotpConfig _readConfig(Object? raw) {
    if (raw is TotpConfig) return raw.validated();
    if (raw is Map<String, dynamic>) return TotpConfig.fromJson(raw);
    if (raw is Map) return TotpConfig.fromJson(Map<String, dynamic>.from(raw));
    if (raw is String) return TotpService.parseConfig(raw);
    throw const TotpException('TOTP config is required.');
  }

  static List<String> _readLinkedAccountIds(Object? raw) {
    if (raw is List) {
      return _normalizeLinkedAccountIds(raw.map((item) => item.toString()));
    }
    return const <String>[];
  }

  static List<String> _normalizeLinkedAccountIds(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) continue;
      seen.add(trimmed);
      result.add(trimmed);
    }
    return List.unmodifiable(result);
  }
}
