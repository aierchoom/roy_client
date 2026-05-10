import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:secret_roy/core/app_logger.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';

import 'lan_sync_session.dart';
import 'sync_payload_codec.dart';
import 'sync_service.dart';

/// Requester 端 LAN 同步客户端。
///
/// 主动向 Host 发起同步，推送本地数据，拉取合并结果，本地提交。
class LanSyncClient {
  final SecureStorageService _storage;
  final IdentityService _identity;
  final SyncService _syncService;
  final LanSyncConfig _config;

  LanSyncPhase _phase = LanSyncPhase.idle;
  String? _sessionId;
  String? _hostUrl;
  bool _isBusy = false;

  LanSyncClient({
    required SecureStorageService storage,
    required IdentityService identity,
    required SyncService syncService,
    LanSyncConfig? config,
  })  : _storage = storage,
        _identity = identity,
        _syncService = syncService,
        _config = config ?? const LanSyncConfig();

  bool get isBusy => _isBusy;
  LanSyncPhase get phase => _phase;
  String? get sessionId => _sessionId;

  /// 发起 LAN 同步（B 调用）
  Future<LanSyncResult> startSync({
    required InternetAddress hostAddress,
    required int hostPort,
    required void Function(LanSyncPhase phase, String? message) onProgress,
  }) async {
    if (_isBusy) {
      return LanSyncResult(
        success: false,
        error: 'Another LAN sync is in progress',
      );
    }

    // 红线 R3：检查服务器同步是否活跃
    if (_syncService.isSyncing) {
      return LanSyncResult(
        success: false,
        error: 'Server sync is in progress. Please wait.',
      );
    }

    _isBusy = true;
    _phase = LanSyncPhase.connecting;
    _hostUrl = 'http://${hostAddress.address}:$hostPort';

    try {
      // 1. Start session
      onProgress(LanSyncPhase.connecting, null);
      final startResp = await _post('$_hostUrl/lan-sync/start', {
        'device_id': _identity.deviceId,
      });
      _sessionId = startResp['session_id'] as String;
      AppLogger.d('[LAN-Client] Session started: $_sessionId');

      // 2. Push local pending data
      _phase = LanSyncPhase.receiving;
      onProgress(LanSyncPhase.receiving, 'Sending local data...');
      await _pushLocalData();

      // 3. Poll until Host merging complete
      _phase = LanSyncPhase.merging;
      onProgress(LanSyncPhase.merging, 'Waiting for host to merge...');
      await _pollUntilMerged(onProgress);

      // 4. Pull merged result
      _phase = LanSyncPhase.pushing;
      onProgress(LanSyncPhase.pushing, 'Receiving merged result...');
      final mergedItems = await _pullMergedResult();

      // 5. Commit local
      _phase = LanSyncPhase.committing;
      onProgress(LanSyncPhase.committing, 'Writing to database...');
      await _commitLocal(mergedItems);

      _phase = LanSyncPhase.completed;
      onProgress(LanSyncPhase.completed, 'Sync complete');

      return LanSyncResult(
        success: true,
        pushedItems: await _countPendingItems(),
        pulledItems: mergedItems.length,
        conflictCount: 0,
      );
    } on LanSyncException catch (e) {
      _phase = LanSyncPhase.interrupted;
      onProgress(LanSyncPhase.interrupted, e.message);
      await _abortQuietly();
      return LanSyncResult(success: false, error: e.message);
    } catch (e) {
      _phase = LanSyncPhase.failed;
      onProgress(LanSyncPhase.failed, e.toString());
      await _abortQuietly();
      return LanSyncResult(success: false, error: e.toString());
    } finally {
      _isBusy = false;
      _sessionId = null;
      _hostUrl = null;
    }
  }

  Future<void> abort() async {
    await _abortQuietly();
  }

  void reset() {
    _phase = LanSyncPhase.idle;
    _isBusy = false;
    _sessionId = null;
    _hostUrl = null;
  }

  // === Private ===

  Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));

    final respBody = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 404) {
      throw kLanSyncSessionExpired;
    }
    if (response.statusCode == 410) {
      throw kLanSyncSessionExpired;
    }
    if (response.statusCode == 409) {
      throw kLanSyncDataCorrupted;
    }
    if (response.statusCode == 503) {
      throw kLanSyncHostBusy;
    }
    if (response.statusCode != 200) {
      throw LanSyncException(
        'HTTP_${response.statusCode}',
        respBody['error']?.toString() ?? 'Unknown error',
      );
    }

    return respBody;
  }

  Future<void> _pushLocalData() async {
    final accounts = await _storage.loadPendingSyncAccounts();
    final templates = await _storage.loadDirtyTemplates();
    final totps = await _storage.loadDirtyTotpCredentials();

    final allItems = <dynamic>[...accounts, ...templates, ...totps];
    final pageSize = _config.pageSize;

    for (var i = 0; i < allItems.length; i += pageSize) {
      final page = allItems.skip(i).take(pageSize).toList();
      final payloads = await Future.wait(
        page.map((item) => _encryptItem(item)),
      );

      await _post('$_hostUrl/lan-sync/push', {
        'session_id': _sessionId,
        'page': i ~/ pageSize,
        'items': payloads,
      });
    }

    // 通知 Host 所有数据已发送完毕（通过空 page 或额外端点）
    // 简化：Host 通过超时或最后一页判断
    AppLogger.d('[LAN-Client] Pushed ${allItems.length} items');
  }

  Future<void> _pollUntilMerged(
    void Function(LanSyncPhase, String?) onProgress,
  ) async {
    const maxRetries = 180; // 90 秒（每 500ms 轮询一次）
    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(const Duration(milliseconds: 500));

      final result = await _post('$_hostUrl/lan-sync/result', {
        'session_id': _sessionId,
      });

      final phaseName = result['phase'] as String?;
      final conflictCount = (result['conflict_count'] as int?) ?? 0;

      if (phaseName == LanSyncPhase.pushing.name) {
        return;
      }
      if (phaseName == LanSyncPhase.resolving.name) {
        onProgress(
          LanSyncPhase.resolving,
          'Host is resolving $conflictCount conflict(s)...',
        );
        // B 端只等待，冲突在 Host 上处理
        continue;
      }
      if (phaseName == LanSyncPhase.interrupted.name ||
          phaseName == LanSyncPhase.failed.name) {
        throw LanSyncException('HOST_FAILED', 'Host processing failed');
      }
    }
    throw kLanSyncTimeout;
  }

  Future<List<dynamic>> _pullMergedResult() async {
    final response = await _post('$_hostUrl/lan-sync/pull', {
      'session_id': _sessionId,
    });

    final items = response['items'] as List<dynamic>? ?? [];
    final decrypted = <dynamic>[];

    for (final cipher in items) {
      try {
        final payload = await SyncPayloadCodec.decodePayload(
          encodedPayload: cipher as String,
          expectedVaultId: _identity.vaultId,
          privateKey: _identity.privateKey,
          symmetricKey: _identity.symmetricKey,
        );
        decrypted.add(_payloadToItem(payload));
      } catch (e) {
        AppLogger.d('[LAN-Client] Decrypt failed: $e');
        throw kLanSyncDataCorrupted;
      }
    }

    return decrypted;
  }

  Future<void> _commitLocal(List<dynamic> mergedItems) async {
    for (final item in mergedItems) {
      if (item is AccountItem) {
        final toSave = item.copyWith(syncStatus: SyncStatus.pendingPush);
        await _storage.saveAccount(toSave, isSyncMerge: true);
      } else if (item is AccountTemplate) {
        final toSave = item.copyWith(syncStatus: SyncStatus.pendingPush);
        await _storage.saveTemplate(toSave, isSyncMerge: true);
      } else if (item is TotpCredential) {
        final toSave = item.copyWith(syncStatus: SyncStatus.pendingPush);
        await _storage.saveTotpCredential(toSave, isSyncMerge: true);
      }
    }

    await _storage.setSetting(
      'lan_sync_last_${_identity.vaultId}',
      DateTime.now().toIso8601String(),
    );

    AppLogger.d('[LAN-Client] Committed ${mergedItems.length} items');
  }

  Future<void> _abortQuietly() async {
    if (_sessionId == null || _hostUrl == null) return;
    try {
      await http
          .post(
            Uri.parse('$_hostUrl/lan-sync/abort'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'session_id': _sessionId}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // 静默忽略 abort 失败
    }
  }

  Future<String> _encryptItem(dynamic item) async {
    Map<String, dynamic> payloadJson;
    if (item is AccountItem) {
      payloadJson = item.toJson();
      payloadJson['_type'] = 'account';
    } else if (item is AccountTemplate) {
      payloadJson = item.toJson();
      payloadJson['_type'] = 'template';
    } else if (item is TotpCredential) {
      payloadJson = item.toJson();
      payloadJson['_type'] = 'totp_credential';
    } else {
      throw ArgumentError('Unknown item type: ${item.runtimeType}');
    }

    return SyncPayloadCodec.encodePayload(
      payloadJson: payloadJson,
      vaultId: _identity.vaultId,
      nodeId: _identity.deviceId,
      privateKey: _identity.privateKey,
      symmetricKey: _identity.symmetricKey,
    );
  }

  dynamic _payloadToItem(Map<String, dynamic> payload) {
    final type = payload['_type'] as String?;
    switch (type) {
      case 'account':
        return AccountItem.fromJson(payload);
      case 'template':
        return AccountTemplate.fromJson(payload);
      case 'totp_credential':
        return TotpCredential.fromJson(payload);
      default:
        throw ArgumentError('Unknown payload type: $type');
    }
  }

  Future<int> _countPendingItems() async {
    final accounts = await _storage.loadPendingSyncAccounts();
    final templates = await _storage.loadDirtyTemplates();
    final totps = await _storage.loadDirtyTotpCredentials();
    return accounts.length + templates.length + totps.length;
  }
}
