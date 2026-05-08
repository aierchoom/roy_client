import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:secret_roy/core/app_logger.dart';

class VaultPairingServiceException implements Exception {
  final String message;

  const VaultPairingServiceException(this.message);

  @override
  String toString() => 'VaultPairingServiceException($message)';
}

class PairingSessionInfo {
  final String sessionId;
  final String pairingCode;
  final String status;
  final DateTime expiresAt;

  const PairingSessionInfo({
    required this.sessionId,
    required this.pairingCode,
    required this.status,
    required this.expiresAt,
  });

  factory PairingSessionInfo.fromJson(Map<String, dynamic> json) {
    return PairingSessionInfo(
      sessionId: json['session_id'] as String? ?? '',
      pairingCode: json['pairing_code'] as String? ?? '',
      status: json['status'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PairingJoinResult {
  final String sessionId;
  final String requestId;
  final String status;
  final DateTime expiresAt;

  const PairingJoinResult({
    required this.sessionId,
    required this.requestId,
    required this.status,
    required this.expiresAt,
  });

  factory PairingJoinResult.fromJson(Map<String, dynamic> json) {
    return PairingJoinResult(
      sessionId: json['session_id'] as String? ?? '',
      requestId: json['request_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PairingPendingRequest {
  final String requestId;
  final String requesterDeviceId;
  final String requesterPublicKey;
  final DateTime requestedAt;

  const PairingPendingRequest({
    required this.requestId,
    required this.requesterDeviceId,
    required this.requesterPublicKey,
    required this.requestedAt,
  });

  factory PairingPendingRequest.fromJson(Map<String, dynamic> json) {
    return PairingPendingRequest(
      requestId: json['request_id'] as String? ?? '',
      requesterDeviceId: json['requester_device_id'] as String? ?? '',
      requesterPublicKey: json['requester_public_key'] as String? ?? '',
      requestedAt:
          DateTime.tryParse(json['requested_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class PairingSessionStatus {
  final String sessionId;
  final String status;
  final DateTime expiresAt;
  final PairingPendingRequest? pendingRequest;

  const PairingSessionStatus({
    required this.sessionId,
    required this.status,
    required this.expiresAt,
    this.pendingRequest,
  });

  factory PairingSessionStatus.fromJson(Map<String, dynamic> json) {
    final rawPending = json['pending_request'];
    return PairingSessionStatus(
      sessionId: json['session_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      pendingRequest: rawPending is Map<String, dynamic>
          ? PairingPendingRequest.fromJson(rawPending)
          : null,
    );
  }
}

class PairingBundleResult {
  final String status;
  final String? wrappedVaultBundle;

  const PairingBundleResult({required this.status, this.wrappedVaultBundle});
}

class VaultPairingService {
  Future<PairingSessionInfo> createSession({
    required String serverUrl,
    required String vaultId,
    required String hostDeviceId,
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final response = await http.post(
      Uri.parse('$serverUrl/pairing/sessions'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'vault_id': vaultId,
        'host_device_id': hostDeviceId,
        'pairing_ttl_seconds': ttl.inSeconds,
      }),
    );

    final body = _decodeJsonBody(response.body);
    _ensureStatus(
      response,
      body,
      acceptedStatusCodes: const {201},
      fallbackError: 'Failed to create pairing session.',
    );
    return PairingSessionInfo.fromJson(body);
  }

  Future<PairingJoinResult> joinSession({
    required String serverUrl,
    required String pairingCode,
    required String requesterDeviceId,
    required String requesterPublicKey,
  }) async {
    final response = await http.post(
      Uri.parse('$serverUrl/pairing/sessions/join'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'pairing_code': pairingCode,
        'requester_device_id': requesterDeviceId,
        'requester_public_key': requesterPublicKey,
      }),
    );

    final body = _decodeJsonBody(response.body);
    _ensureStatus(
      response,
      body,
      acceptedStatusCodes: const {200},
      fallbackError: 'Failed to join pairing session.',
    );
    return PairingJoinResult.fromJson(body);
  }

  Future<PairingSessionStatus> getHostSessionStatus({
    required String serverUrl,
    required String sessionId,
    required String hostDeviceId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$serverUrl/pairing/sessions/$sessionId?host_device_id=$hostDeviceId',
      ),
    );

    final body = _decodeJsonBody(response.body);
    _ensureStatus(
      response,
      body,
      acceptedStatusCodes: const {200},
      fallbackError: 'Failed to fetch pairing session status.',
    );
    return PairingSessionStatus.fromJson(body);
  }

  Future<void> approveSession({
    required String serverUrl,
    required String sessionId,
    required String hostDeviceId,
    required String requestId,
    required String wrappedVaultBundle,
  }) async {
    final response = await http.post(
      Uri.parse('$serverUrl/pairing/sessions/$sessionId/approve'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'host_device_id': hostDeviceId,
        'request_id': requestId,
        'action': 'approve',
        'wrapped_vault_bundle': wrappedVaultBundle,
      }),
    );

    final body = _decodeJsonBody(response.body);
    _ensureStatus(
      response,
      body,
      acceptedStatusCodes: const {200},
      fallbackError: 'Failed to approve pairing request.',
    );
  }

  Future<PairingBundleResult> getBundle({
    required String serverUrl,
    required String sessionId,
    required String requestId,
    required String requesterDeviceId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$serverUrl/pairing/sessions/$sessionId/bundle?request_id=$requestId&requester_device_id=$requesterDeviceId',
      ),
    );
    final body = _decodeJsonBody(response.body);

    if (response.statusCode == 200 ||
        response.statusCode == 202 ||
        response.statusCode == 403 ||
        response.statusCode == 410) {
      final status =
          body['status'] as String? ??
          switch (response.statusCode) {
            200 => 'approved',
            202 => 'pending_approval',
            403 => 'rejected',
            410 => 'expired',
            _ => 'unknown',
          };
      return PairingBundleResult(
        status: status,
        wrappedVaultBundle: body['wrapped_vault_bundle'] as String?,
      );
    } else {
      _ensureStatus(
        response,
        body,
        acceptedStatusCodes: const {200, 202, 403, 410},
        fallbackError: 'Failed to fetch pairing bundle.',
      );
      // _ensureStatus always throws for unrecognized status codes,
      // but the analyzer cannot infer that.
      throw VaultPairingServiceException(
        'Failed to fetch pairing bundle.',
      );
    }
  }

  void _ensureStatus(
    http.Response response,
    Map<String, dynamic> body, {
    required Set<int> acceptedStatusCodes,
    required String fallbackError,
  }) {
    if (acceptedStatusCodes.contains(response.statusCode)) {
      return;
    }
    final serverError = body['error'] as String?;
    throw VaultPairingServiceException(
      (serverError == null || serverError.isEmpty)
          ? fallbackError
          : serverError,
    );
  }

  Map<String, dynamic> _decodeJsonBody(String body) {
    if (body.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (e) {
      AppLogger.d('Vault pairing response parse failed: $e');
      return {};
    }
  }
}
