import 'dart:math';

/// LAN 同步会话阶段
enum LanSyncPhase {
  idle,
  connecting,
  receiving,
  merging,
  resolving,
  pushing,
  committing,
  completed,
  interrupted,
  failed,
}

extension LanSyncPhaseExt on LanSyncPhase {
  bool get isActive =>
      this == LanSyncPhase.connecting ||
      this == LanSyncPhase.receiving ||
      this == LanSyncPhase.merging ||
      this == LanSyncPhase.resolving ||
      this == LanSyncPhase.pushing ||
      this == LanSyncPhase.committing;

  bool get isTerminal =>
      this == LanSyncPhase.completed ||
      this == LanSyncPhase.interrupted ||
      this == LanSyncPhase.failed;
}

/// LAN 同步异常
class LanSyncException implements Exception {
  final String code;
  final String message;

  const LanSyncException(this.code, this.message);

  @override
  String toString() => 'LanSyncException($code: $message)';
}

const kLanSyncTimeout = LanSyncException('TIMEOUT', 'Sync timeout');
const kLanSyncSessionExpired = LanSyncException('SESSION_EXPIRED', 'Session expired');
const kLanSyncDataCorrupted = LanSyncException('DATA_CORRUPTED', 'Data verification failed');
const kLanSyncHostBusy = LanSyncException('HOST_BUSY', 'Host device is busy');
const kLanSyncChannelConflict = LanSyncException('CHANNEL_CONFLICT', 'Server sync in progress');

/// Host 端内存会话状态
class LanSyncHostSession {
  final String sessionId;
  final String peerDeviceId;
  final DateTime startedAt;
  final DateTime expiresAt;
  LanSyncPhase phase;
  final List<Map<String, dynamic>> peerPayloads;
  List<dynamic>? mergedItems;
  List<Map<String, dynamic>>? conflictPreview;
  int? conflictCount;
  String? failureReason;
  final Set<String> peerRecordIds;

  LanSyncHostSession({
    required this.sessionId,
    required this.peerDeviceId,
    required this.startedAt,
    required this.expiresAt,
    this.phase = LanSyncPhase.receiving,
    List<Map<String, dynamic>>? peerPayloads,
    this.mergedItems,
    this.conflictPreview,
    this.conflictCount,
    this.failureReason,
    Set<String>? peerRecordIds,
  })  : peerPayloads = peerPayloads ?? [],
        peerRecordIds = peerRecordIds ?? <String>{};

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Requester 端同步结果
class LanSyncResult {
  final bool success;
  final int pushedItems;
  final int pulledItems;
  final int conflictCount;
  final String? error;

  LanSyncResult({
    required this.success,
    this.pushedItems = 0,
    this.pulledItems = 0,
    this.conflictCount = 0,
    this.error,
  });
}

/// LAN 同步配置
class LanSyncConfig {
  final Duration sessionTtl;
  final int pageSize;

  const LanSyncConfig({
    this.sessionTtl = const Duration(minutes: 3),
    this.pageSize = 100,
  });
}

/// Coordinator 端会话状态（Host 和 Requester 共用）
class LanSyncSessionState {
  final String sessionId;
  final LanSyncPhase phase;
  final DateTime startedAt;
  final DateTime? expiresAt;

  const LanSyncSessionState({
    required this.sessionId,
    required this.phase,
    required this.startedAt,
    this.expiresAt,
  });

  LanSyncSessionState copyWith({
    String? sessionId,
    LanSyncPhase? phase,
    DateTime? startedAt,
    DateTime? expiresAt,
  }) {
    return LanSyncSessionState(
      sessionId: sessionId ?? this.sessionId,
      phase: phase ?? this.phase,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

/// 生成唯一 session ID
String generateLanSyncSessionId() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final rand = Random.secure().nextInt(0xFFFFFF);
  return 'lan_${now}_$rand';
}
