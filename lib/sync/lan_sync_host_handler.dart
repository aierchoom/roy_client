import 'dart:async';


import 'package:secret_roy/core/app_logger.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';

import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';


import 'crdt_merge_engine.dart';
import 'lan_sync_session.dart';
import 'sync_payload_codec.dart';
import 'totp_credential_merge_engine.dart';

/// Host 端 LAN 同步处理器。
///
/// 配对成功后，Host 保持 HTTP Server 开启，通过此类处理同步请求。
/// 内存中维护活跃会话（Map&lt;String, LanSyncHostSession&gt;）。
class LanSyncHostHandler {
  final SecureStorageService _storage;
  final IdentityService _identity;
  final LanSyncConfig _config;

  final Map<String, LanSyncHostSession> _sessions = {};
  Timer? _cleanupTimer;

  LanSyncHostHandler({
    required SecureStorageService storage,
    required IdentityService identity,
    LanSyncConfig? config,
  })  : _storage = storage,
        _identity = identity,
        _config = config ?? const LanSyncConfig();

  /// HTTP Server 收到 /lan-sync/start 时调用
  Future<Map<String, dynamic>> handleStart(String peerDeviceId) async {
    _startCleanupTimer();

    // 如果已有该设备的活跃会话，先清理
    final existing = _sessions.values
        .where((s) => s.peerDeviceId == peerDeviceId && s.phase.isActive)
        .toList();
    for (final s in existing) {
      s.phase = LanSyncPhase.interrupted;
    }

    final sessionId = generateLanSyncSessionId();
    final now = DateTime.now();
    final session = LanSyncHostSession(
      sessionId: sessionId,
      peerDeviceId: peerDeviceId,
      startedAt: now,
      expiresAt: now.add(_config.sessionTtl),
    );
    _sessions[sessionId] = session;

    AppLogger.d('[LAN-Host] Session started: $sessionId for $peerDeviceId');
    return {
      'session_id': sessionId,
      'ttl_seconds': _config.sessionTtl.inSeconds,
    };
  }

  /// HTTP Server 收到 /lan-sync/push 时调用
  Future<Map<String, dynamic>> handlePush(
    String sessionId,
    int page,
    List<String> encryptedPayloads,
  ) async {
    final session = _getSession(sessionId);
    if (session.phase != LanSyncPhase.receiving &&
        session.phase != LanSyncPhase.connecting) {
      throw kLanSyncSessionExpired;
    }

    session.phase = LanSyncPhase.receiving;

    for (final cipher in encryptedPayloads) {
      try {
        final payload = await SyncPayloadCodec.decodePayload(
          encodedPayload: cipher,
          expectedVaultId: _identity.vaultId,
          privateKey: _identity.privateKey,
          symmetricKey: _identity.symmetricKey,
        );
        session.peerPayloads.add(payload);
      } catch (e) {
        AppLogger.d('[LAN-Host] Decrypt failed for payload: $e');
        throw kLanSyncDataCorrupted;
      }
    }

    AppLogger.d(
      '[LAN-Host] Received page $page, ${encryptedPayloads.length} items, total ${session.peerPayloads.length}',
    );

    return {'accepted': page, 'phase': session.phase.name};
  }

  /// 所有分页数据接收完成后，Host 触发合并
  Future<void> triggerMerge(String sessionId) async {
    final session = _getSession(sessionId);
    if (session.peerPayloads.isEmpty) {
      // B 没有推送数据，直接进入 pushing（准备把自己数据推给 B）
      session.phase = LanSyncPhase.pushing;
      return;
    }

    await _runMerge(session);
  }

  /// 查询会话状态（供 B 轮询）
  Future<Map<String, dynamic>> handleResultQuery(String sessionId) async {
    final session = _getSession(sessionId);
    final result = <String, dynamic>{
      'phase': session.phase.name,
      'conflict_count': session.conflictCount ?? 0,
    };

    if (session.phase == LanSyncPhase.resolving &&
        session.conflictPreview != null) {
      result['conflict_preview'] = session.conflictPreview;
    }

    return result;
  }

  /// B 拉取合并结果
  Future<Map<String, dynamic>> handlePull(String sessionId) async {
    final session = _getSession(sessionId);
    if (session.phase != LanSyncPhase.pushing) {
      return {'items': <String>[], 'phase': session.phase.name};
    }

    final items = <String>[];
    final merged = session.mergedItems ?? [];

    for (final item in merged) {
      final payloadJson = _itemToPayloadJson(item);
      final cipher = await SyncPayloadCodec.encodePayload(
        payloadJson: payloadJson,
        vaultId: _identity.vaultId,
        nodeId: _identity.deviceId,
        privateKey: _identity.privateKey,
        symmetricKey: _identity.symmetricKey,
      );
      items.add(cipher);
    }

    // 同时把 Host 自己的全部数据也推给 B（包含 B 没有的数据）
    final hostItems = await _loadHostItems();
    for (final item in hostItems) {
      // 如果已经在 merged 中，跳过
      if (_containsItem(merged, item)) continue;

      final payloadJson = _itemToPayloadJson(item);
      final cipher = await SyncPayloadCodec.encodePayload(
        payloadJson: payloadJson,
        vaultId: _identity.vaultId,
        nodeId: _identity.deviceId,
        privateKey: _identity.privateKey,
        symmetricKey: _identity.symmetricKey,
      );
      items.add(cipher);
    }

    AppLogger.d('[LAN-Host] Pulled ${items.length} items to peer');
    return {'items': items, 'phase': session.phase.name};
  }

  /// 用户确认冲突后，Host 提交到本地数据库
  Future<void> commit(String sessionId) async {
    final session = _getSession(sessionId);
    if (session.phase != LanSyncPhase.pushing) {
      throw const LanSyncException('INVALID_PHASE', 'Not in pushing phase');
    }

    session.phase = LanSyncPhase.committing;

    try {
      await _commitToDatabase(session);
      session.phase = LanSyncPhase.completed;
      AppLogger.d('[LAN-Host] Committed session $sessionId');
    } catch (e) {
      session.phase = LanSyncPhase.failed;
      session.failureReason = e.toString();
      rethrow;
    }
  }

  /// 中断会话
  Future<void> handleAbort(String sessionId) async {
    final session = _sessions[sessionId];
    if (session != null) {
      session.phase = LanSyncPhase.interrupted;
      _sessions.remove(sessionId);
      AppLogger.d('[LAN-Host] Aborted session $sessionId');
    }
  }

  /// 清理过期会话
  void cleanup() {
    final expired = _sessions.entries
        .where((e) => e.value.isExpired || e.value.phase.isTerminal)
        .map((e) => e.key)
        .toList();
    for (final id in expired) {
      _sessions.remove(id);
      AppLogger.d('[LAN-Host] Cleaned up session $id');
    }
    if (_sessions.isEmpty) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
    }
  }

  LanSyncPhase? getSessionPhase(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.isExpired) return null;
    return session.phase;
  }

  /// Returns the conflict preview for a session, or null if none.
  List<Map<String, dynamic>>? getConflictPreview(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.isExpired) return null;
    return session.conflictPreview;
  }

  /// Returns an unmodifiable list of active sessions (for testing).
  List<LanSyncHostSession> getSessions() => List.unmodifiable(_sessions.values);

  void dispose() {
    _cleanupTimer?.cancel();
    _sessions.clear();
  }

  // === Private ===

  LanSyncHostSession _getSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null || session.isExpired) {
      if (session != null) _sessions.remove(sessionId);
      throw kLanSyncSessionExpired;
    }
    return session;
  }

  void _startCleanupTimer() {
    _cleanupTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => cleanup(),
    );
  }

  Future<void> _runMerge(LanSyncHostSession session) async {
    session.phase = LanSyncPhase.merging;

    final mergedItems = <dynamic>[];
    final conflictLogs = <ConflictLog>[];

    for (final payload in session.peerPayloads) {
      final type = payload['_type'] as String?;
      if (type == 'account') {
        final remote = AccountItem.fromJson(payload);
        final local = await _storage.getAccountById(remote.id, includeDeleted: true);
        if (local == null) {
          mergedItems.add(remote);
        } else {
          final result = CrdtMergeEngine.merge(local, remote);
          mergedItems.add(result.mergedItem);
          if (!result.isPureFastForward) {
            conflictLogs.addAll(result.conflictLogs);
          }
        }
      } else if (type == 'template') {
        final remote = AccountTemplate.fromJson(payload);
        final local = await _storage.loadTemplateById(remote.templateId);
        if (local == null) {
          mergedItems.add(remote);
        } else {
          final result = CrdtMergeEngine.mergeTemplate(local, remote);
          mergedItems.add(result.template);
          // TemplateConflictLog 暂不支持预览，直接记录
        }
      } else if (type == 'totp_credential') {
        final remote = TotpCredential.fromJson(payload);
        final local = await _storage.getTotpCredentialById(remote.id, includeDeleted: true);
        if (local == null) {
          mergedItems.add(remote);
        } else {
          final merged = TotpCredentialMergeEngine.merge(local, remote);
          mergedItems.add(merged);
        }
      }
    }

    session.mergedItems = mergedItems;
    session.conflictCount = conflictLogs.length;

    if (conflictLogs.isNotEmpty) {
      session.conflictPreview = conflictLogs
          .map((l) => {
                'account_id': l.accountId,
                'field_key': l.fieldKey,
                'field_value': l.fieldValue,
              })
          .toList();
      session.phase = LanSyncPhase.resolving;
      AppLogger.d(
        '[LAN-Host] Merge completed with ${conflictLogs.length} conflicts',
      );
    } else {
      session.phase = LanSyncPhase.pushing;
      AppLogger.d('[LAN-Host] Merge completed, no conflicts');
    }
  }

  Future<void> _commitToDatabase(LanSyncHostSession session) async {
    final merged = session.mergedItems ?? [];

    for (final item in merged) {
      if (item is AccountItem) {
        final toSave = item.copyWith(syncStatus: SyncStatus.pendingPush);
        await _storage.saveAccount(toSave, isSyncMerge: true);
        await _ensureApprovedLocalSyncChange(
          entityType: LocalSyncEntityType.account,
          entityId: item.id,
          title: item.name,
        );
      } else if (item is AccountTemplate) {
        final toSave = item.copyWith(syncStatus: SyncStatus.pendingPush);
        await _storage.saveTemplate(toSave, isSyncMerge: true);
        await _ensureApprovedLocalSyncChange(
          entityType: LocalSyncEntityType.template,
          entityId: item.templateId,
          title: item.title,
        );
      } else if (item is TotpCredential) {
        final toSave = item.copyWith(syncStatus: SyncStatus.pendingPush);
        await _storage.saveTotpCredential(toSave, isSyncMerge: true);
        await _ensureApprovedLocalSyncChange(
          entityType: LocalSyncEntityType.totpCredential,
          entityId: item.id,
          title: item.label,
        );
      }
    }

    if (session.conflictCount != null && session.conflictCount! > 0) {
      // 冲突日志已在 merging 时生成，但预览版不包含完整 ConflictLog
      // 实际冲突日志由 CrdtMergeEngine 在 merging 阶段生成并存储
      // 此处如需保存额外的冲突审计日志，可扩展
    }

    // 记录上次 LAN 同步时间
    await _storage.setSetting(
      'lan_sync_last_${_identity.vaultId}',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> _ensureApprovedLocalSyncChange({
    required LocalSyncEntityType entityType,
    required String entityId,
    required String title,
  }) async {
    await _storage.createApprovedLocalSyncChange(
      vaultId: _identity.vaultId,
      entityType: entityType,
      entityId: entityId,
      title: title,
    );
  }

  Future<List<dynamic>> _loadHostItems() async {
    final items = <dynamic>[];
    items.addAll(await _storage.loadAccounts(includeDeleted: true));
    items.addAll(await _storage.loadAllTemplates(includeDeleted: true));
    items.addAll(await _storage.loadTotpCredentials(includeDeleted: true));
    return items;
  }

  bool _containsItem(List<dynamic> list, dynamic item) {
    final id = _itemId(item);
    for (final existing in list) {
      if (_itemId(existing) == id) return true;
    }
    return false;
  }

  String _itemId(dynamic item) {
    if (item is AccountItem) return item.id;
    if (item is AccountTemplate) return item.templateId;
    if (item is TotpCredential) return item.id;
    return '';
  }

  Map<String, dynamic> _itemToPayloadJson(dynamic item) {
    final json = (item as dynamic).toJson() as Map<String, dynamic>;
    if (item is AccountItem) {
      json['_type'] = 'account';
    } else if (item is AccountTemplate) {
      json['_type'] = 'template';
    } else if (item is TotpCredential) {
      json['_type'] = 'totp_credential';
    }
    return json;
  }
}
