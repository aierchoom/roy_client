import 'dart:convert';

/// The current state of the sync engine.
enum SyncState {
  offline,
  connecting,
  pulling,
  pushing,
  idle,
  conflictRecovery,
  networkUnreachable,
  serverError,
  protocolError,
  authError,
}

extension SyncStateExt on SyncState {
  bool get isError =>
      this == SyncState.networkUnreachable ||
      this == SyncState.serverError ||
      this == SyncState.protocolError ||
      this == SyncState.authError;
}

class SyncConfig {
  final String serverUrl;
  final Duration syncInterval;

  const SyncConfig({
    required this.serverUrl,
    this.syncInterval = const Duration(minutes: 5),
  });
}

enum SyncRecoveryPhase { pull, push, conflictRecovery }

class SyncRecoveryMarker {
  final SyncRecoveryPhase phase;
  final int localVersion;
  final DateTime startedAt;
  final String? itemId;
  final String? conflictType;

  const SyncRecoveryMarker({
    required this.phase,
    required this.localVersion,
    required this.startedAt,
    this.itemId,
    this.conflictType,
  });

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'local_version': localVersion,
      'started_at': startedAt.toIso8601String(),
      'item_id': itemId,
      'conflict_type': conflictType,
    };
  }

  factory SyncRecoveryMarker.fromJson(Map<String, dynamic> json) {
    final phaseName = json['phase'] as String?;
    final phase = SyncRecoveryPhase.values.firstWhere(
      (candidate) => candidate.name == phaseName,
      orElse: () => SyncRecoveryPhase.pull,
    );

    return SyncRecoveryMarker(
      phase: phase,
      localVersion: json['local_version'] as int? ?? 0,
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      itemId: json['item_id'] as String?,
      conflictType: json['conflict_type'] as String?,
    );
  }
}

class SyncProtocolException implements Exception {
  final String message;

  const SyncProtocolException(this.message);

  @override
  String toString() => 'SyncProtocolException($message)';
}

class ConflictException implements Exception {
  final String serverResponse;
  final String? conflictType;
  final String? itemId;
  final int? yourBase;
  final int? serverActual;
  final bool? serverIsDeleted;

  ConflictException._(
    this.serverResponse, {
    this.conflictType,
    this.itemId,
    this.yourBase,
    this.serverActual,
    this.serverIsDeleted,
  });

  factory ConflictException(String serverResponse) {
    try {
      final json = jsonDecode(serverResponse) as Map<String, dynamic>;
      return ConflictException._(
        serverResponse,
        conflictType: json['conflict_type'] as String?,
        itemId: json['item_id'] as String?,
        yourBase: json['your_base'] as int?,
        serverActual: json['server_actual'] as int?,
        serverIsDeleted: json['server_is_deleted'] as bool?,
      );
    } catch (_) {
      return ConflictException._(serverResponse);
    }
  }
}

class SyncServerErrorPayload {
  final String? message;
  final String? conflictType;
  final String? itemId;

  const SyncServerErrorPayload({this.message, this.conflictType, this.itemId});
}

class SyncHttpException implements Exception {
  final String phase;
  final int statusCode;
  final String? serverMessage;
  final String? conflictType;
  final String? itemId;

  const SyncHttpException({
    required this.phase,
    required this.statusCode,
    this.serverMessage,
    this.conflictType,
    this.itemId,
  });

  String get userMessage {
    if (statusCode == 503) {
      return serverMessage ??
          'Sync server storage is temporarily unavailable. Retry later.';
    }
    if (serverMessage != null && serverMessage!.isNotEmpty) {
      return serverMessage!;
    }
    return '${phase[0].toUpperCase()}${phase.substring(1)} HTTP $statusCode';
  }

  String get logMessage {
    final prefix =
        '${phase[0].toUpperCase()}${phase.substring(1)} HTTP $statusCode';
    if (serverMessage == null || serverMessage!.isEmpty) {
      return prefix;
    }
    return '$prefix: $serverMessage';
  }
}

class SyncResult {
  final bool success;
  final bool pushed;
  final bool pulled;
  final String? error;
  final int version;
  final int conflictCount;
  final String? notice;

  SyncResult._({
    required this.success,
    this.pushed = false,
    this.pulled = false,
    this.error,
    this.version = 0,
    this.conflictCount = 0,
    this.notice,
  });

  factory SyncResult.success({
    bool pushed = false,
    bool pulled = false,
    int version = 0,
    int conflictCount = 0,
    String? notice,
  }) {
    return SyncResult._(
      success: true,
      pushed: pushed,
      pulled: pulled,
      version: version,
      conflictCount: conflictCount,
      notice: notice,
    );
  }

  factory SyncResult.failure(String error) {
    return SyncResult._(success: false, error: error);
  }
}
