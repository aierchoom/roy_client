import 'package:flutter/foundation.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/vault_pairing_crypto.dart';
import 'package:secret_roy/services/vault_pairing_service.dart';

import 'sync_coordinator.dart';
import 'vault_import_export_coordinator.dart';

/// 保险库配对协调器：封装 VaultPairing 与 LANPairing 的完整流程。
///
/// 将 ServiceManager 中的配对职责拆分为独立的 coordinator，
/// 保持 ServiceManager 作为 facade 仅负责状态管理与通知。
class VaultPairingCoordinator {
  final VaultPairingService _vaultPairingService;
  final LanPairingService _lanPairingService;
  final IdentityService _identityService;
  final SyncCoordinator _syncCoordinator;
  final VaultImportExportCoordinator _importExportCoordinator;

  final Map<String, VaultPairingKeyPair> _joinKeysByRequestId = {};

  VaultPairingCoordinator({
    required VaultPairingService vaultPairingService,
    required LanPairingService lanPairingService,
    required IdentityService identityService,
    required SyncCoordinator syncCoordinator,
    required VaultImportExportCoordinator importExportCoordinator,
  })  : _vaultPairingService = vaultPairingService,
        _lanPairingService = lanPairingService,
        _identityService = identityService,
        _syncCoordinator = syncCoordinator,
        _importExportCoordinator = importExportCoordinator;

  // === Vault Pairing ===

  Future<PairingSessionInfo> createSession({
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final serverUrl = await _syncCoordinator.resolveServerUrl();
    return _vaultPairingService.createSession(
      serverUrl: serverUrl,
      vaultId: _identityService.vaultId,
      hostDeviceId: _identityService.deviceId,
      ttl: ttl,
    );
  }

  Future<PairingSessionStatus> getSessionStatus(String sessionId) async {
    final serverUrl = await _syncCoordinator.resolveServerUrl();
    return _vaultPairingService.getHostSessionStatus(
      serverUrl: serverUrl,
      sessionId: sessionId,
      hostDeviceId: _identityService.deviceId,
    );
  }

  Future<void> approveRequest({
    required String sessionId,
    required String requestId,
  }) async {
    final serverUrl = await _syncCoordinator.resolveServerUrl();
    final status = await _vaultPairingService.getHostSessionStatus(
      serverUrl: serverUrl,
      sessionId: sessionId,
      hostDeviceId: _identityService.deviceId,
    );
    final pendingRequest = status.pendingRequest;
    if (pendingRequest == null || pendingRequest.requestId != requestId) {
      throw const VaultPairingServiceException(
        'Pairing request is no longer pending. Refresh and try again.',
      );
    }
    if (pendingRequest.requesterPublicKey.isEmpty) {
      throw const VaultPairingServiceException(
        'Pairing request is missing the requester public key.',
      );
    }

    final vaultDump = await _importExportCoordinator.exportEncryptedVaultDump();
    // LAN pairing encrypts with the requester's public key, so the cleartext
    // transfer code is safe in transit — unlike exportSecureLinkCode which
    // uses password-derived encryption.
    // ignore: deprecated_member_use_from_same_package
    final transferCode = _identityService.exportTransferCode(
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
    final wrappedVaultBundle = await VaultPairingCrypto.encryptBundle(
      plainBundle: transferCode,
      requesterPublicKey: pendingRequest.requesterPublicKey,
    );
    await _vaultPairingService.approveSession(
      serverUrl: serverUrl,
      sessionId: sessionId,
      hostDeviceId: _identityService.deviceId,
      requestId: requestId,
      wrappedVaultBundle: wrappedVaultBundle,
    );
  }

  Future<PairingJoinResult> joinSession(String pairingCode) async {
    final serverUrl = await _syncCoordinator.resolveServerUrl();
    final keyPair = await VaultPairingCrypto.createKeyPair();
    final joinResult = await _vaultPairingService.joinSession(
      serverUrl: serverUrl,
      pairingCode: pairingCode.trim(),
      requesterDeviceId: _identityService.deviceId,
      requesterPublicKey: keyPair.publicKey,
    );
    _joinKeysByRequestId[joinResult.requestId] = keyPair;
    return joinResult;
  }

  Future<PairingBundleResult> fetchAndImportBundle({
    required String sessionId,
    required String requestId,
    bool forceOverwrite = false,
  }) async {
    final serverUrl = await _syncCoordinator.resolveServerUrl();
    final bundleResult = await _vaultPairingService.getBundle(
      serverUrl: serverUrl,
      sessionId: sessionId,
      requestId: requestId,
      requesterDeviceId: _identityService.deviceId,
    );

    if (bundleResult.status == 'approved') {
      final wrappedBundle = bundleResult.wrappedVaultBundle;
      if (wrappedBundle == null || wrappedBundle.isEmpty) {
        throw const VaultPairingServiceException(
          'Pairing bundle is empty. Retry the approval flow.',
        );
      }
      final keyPair = _joinKeysByRequestId[requestId];
      if (keyPair == null) {
        throw const VaultPairingServiceException(
          'Pairing key expired locally. Rejoin the pairing session.',
        );
      }
      final transferCode = await VaultPairingCrypto.decryptBundle(
        wrappedBundle: wrappedBundle,
        keyPair: keyPair,
      );
      await _importExportCoordinator.importVaultLinkCode(
        transferCode,
        forceOverwrite: forceOverwrite,
      );
      _joinKeysByRequestId.remove(requestId);
    }

    return bundleResult;
  }

  // === LAN Pairing ===

  Future<LanPairingHostSession> startLanHost({
    Duration ttl = const Duration(minutes: 3),
  }) async {
    if (kIsWeb) {
      throw const LanPairingServiceException(
        'LAN direct pairing is not supported on web builds.',
      );
    }

    final serverUrl = await _syncCoordinator.resolveServerUrl(allowEmpty: true);
    final vaultDump = await _importExportCoordinator.exportEncryptedVaultDump();
    // LAN pairing encrypts with the requester's public key, so the cleartext
    // transfer code is safe in transit — unlike exportSecureLinkCode which
    // uses password-derived encryption.
    // ignore: deprecated_member_use_from_same_package
    final transferCode = _identityService.exportTransferCode(
      syncServerUrl: serverUrl.isEmpty ? null : serverUrl,
      vaultDump: vaultDump,
    );
    return _lanPairingService.startHosting(
      transferCode: transferCode,
      ttl: ttl,
    );
  }

  Future<void> stopLanHost() async {
    await _lanPairingService.stopHosting();
  }

  void clearJoinKeys() {
    _joinKeysByRequestId.clear();
  }

  Future<void> joinLanWithCode(
    String pairingCode, {
    bool forceOverwrite = false,
  }) async {
    if (kIsWeb) {
      throw const LanPairingServiceException(
        'LAN direct pairing is not supported on web builds.',
      );
    }

    final transferCode = await _lanPairingService.claimTransferCodeByCode(
      pairingCode: pairingCode,
      requesterDeviceId: _identityService.deviceId,
    );
    await _importExportCoordinator.importVaultLinkCode(
      transferCode,
      forceOverwrite: forceOverwrite,
    );
  }
}
