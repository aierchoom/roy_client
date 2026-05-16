import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:secret_roy/services/vault_pairing_service.dart';

const _serverUrl = 'https://example.com';

http.Request _captureRequest(http.Request request) => request;

void main() {
  test('VaultPairingServiceException formats message', () {
    const e = VaultPairingServiceException('something wrong');
    expect(e.toString(), 'VaultPairingServiceException(something wrong)');
  });

  group('createSession', () {
    test('returns PairingSessionInfo on 201 with default ttl', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = _captureRequest(request);
        return http.Response(
          jsonEncode({
            'session_id': 'sess_abc',
            'pairing_code': 'ABCD1234',
            'status': 'waiting',
            'expires_at': '2024-01-01T00:10:00Z',
          }),
          201,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.createSession(
        serverUrl: _serverUrl,
        vaultId: 'vault_123',
        hostDeviceId: 'host_dev',
      );

      expect(result.sessionId, 'sess_abc');
      expect(result.pairingCode, 'ABCD1234');
      expect(result.status, 'waiting');

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.toString(), '$_serverUrl/pairing/sessions');
      final body = jsonDecode(captured!.body);
      expect(body['vault_id'], 'vault_123');
      expect(body['host_device_id'], 'host_dev');
      expect(body['pairing_ttl_seconds'], 600);
    });

    test('respects custom ttl', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = _captureRequest(request);
        return http.Response(
          jsonEncode({
            'session_id': 'sess_def',
            'pairing_code': 'EFGH5678',
            'status': 'waiting',
            'expires_at': '2024-01-01T00:02:00Z',
          }),
          201,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      await service.createSession(
        serverUrl: _serverUrl,
        vaultId: 'vault_123',
        hostDeviceId: 'host_dev',
        ttl: const Duration(minutes: 2),
      );

      final body = jsonDecode(captured!.body);
      expect(body['pairing_ttl_seconds'], 120);
    });

    test('throws VaultPairingServiceException with server error on failure',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'vault not found'}),
          404,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.createSession(
          serverUrl: _serverUrl,
          vaultId: 'vault_123',
          hostDeviceId: 'host_dev',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'vault not found',
          ),
        ),
      );
    });

    test('throws fallback error when server provides no error message',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 500);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.createSession(
          serverUrl: _serverUrl,
          vaultId: 'vault_123',
          hostDeviceId: 'host_dev',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'Failed to create pairing session.',
          ),
        ),
      );
    });

    test('throws fallback error on invalid JSON body', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not-json', 500);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.createSession(
          serverUrl: _serverUrl,
          vaultId: 'vault_123',
          hostDeviceId: 'host_dev',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'Failed to create pairing session.',
          ),
        ),
      );
    });

    test('throws fallback error on empty body', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 500);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.createSession(
          serverUrl: _serverUrl,
          vaultId: 'vault_123',
          hostDeviceId: 'host_dev',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'Failed to create pairing session.',
          ),
        ),
      );
    });

    test('propagates network exception', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('no internet');
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.createSession(
          serverUrl: _serverUrl,
          vaultId: 'vault_123',
          hostDeviceId: 'host_dev',
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('joinSession', () {
    test('returns PairingJoinResult on 200', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = _captureRequest(request);
        return http.Response(
          jsonEncode({
            'session_id': 'sess_abc',
            'request_id': 'req_001',
            'status': 'pending_approval',
            'expires_at': '2024-01-01T00:10:00Z',
          }),
          200,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.joinSession(
        serverUrl: _serverUrl,
        pairingCode: 'ABCD1234',
        requesterDeviceId: 'device_req',
        requesterPublicKey: 'pubkey_req',
      );

      expect(result.sessionId, 'sess_abc');
      expect(result.requestId, 'req_001');
      expect(result.status, 'pending_approval');

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(
        captured!.url.toString(),
        '$_serverUrl/pairing/sessions/join',
      );
      final body = jsonDecode(captured!.body);
      expect(body['pairing_code'], 'ABCD1234');
      expect(body['requester_device_id'], 'device_req');
      expect(body['requester_public_key'], 'pubkey_req');
    });

    test('throws VaultPairingServiceException with server error on failure',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'invalid pairing code'}),
          400,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.joinSession(
          serverUrl: _serverUrl,
          pairingCode: 'BADCODE1',
          requesterDeviceId: 'device_req',
          requesterPublicKey: 'pubkey_req',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'invalid pairing code',
          ),
        ),
      );
    });

    test('throws fallback error when server provides no error message',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 404);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.joinSession(
          serverUrl: _serverUrl,
          pairingCode: 'ABCD1234',
          requesterDeviceId: 'device_req',
          requesterPublicKey: 'pubkey_req',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'Failed to join pairing session.',
          ),
        ),
      );
    });
  });

  group('getHostSessionStatus', () {
    test('returns status with pending request on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          '$_serverUrl/pairing/sessions/sess_abc?host_device_id=host_dev',
        );
        return http.Response(
          jsonEncode({
            'session_id': 'sess_abc',
            'status': 'pending_approval',
            'expires_at': '2024-01-01T00:10:00Z',
            'pending_request': {
              'request_id': 'req_001',
              'requester_device_id': 'device_req',
              'requester_public_key': 'pubkey_req',
              'requested_at': '2024-01-01T00:00:00Z',
            },
          }),
          200,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getHostSessionStatus(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        hostDeviceId: 'host_dev',
      );

      expect(result.sessionId, 'sess_abc');
      expect(result.status, 'pending_approval');
      expect(result.pendingRequest, isNotNull);
      expect(result.pendingRequest!.requestId, 'req_001');
      expect(result.pendingRequest!.requesterDeviceId, 'device_req');
      expect(result.pendingRequest!.requesterPublicKey, 'pubkey_req');
    });

    test('returns status without pending request on 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'session_id': 'sess_abc',
            'status': 'waiting',
            'expires_at': '2024-01-01T00:10:00Z',
          }),
          200,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getHostSessionStatus(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        hostDeviceId: 'host_dev',
      );

      expect(result.pendingRequest, isNull);
    });

    test('ignores non-map pending_request', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'session_id': 'sess_abc',
            'status': 'waiting',
            'expires_at': '2024-01-01T00:10:00Z',
            'pending_request': 'not-a-map',
          }),
          200,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getHostSessionStatus(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        hostDeviceId: 'host_dev',
      );

      expect(result.pendingRequest, isNull);
    });

    test('throws VaultPairingServiceException on non-200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'forbidden'}),
          403,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.getHostSessionStatus(
          serverUrl: _serverUrl,
          sessionId: 'sess_abc',
          hostDeviceId: 'host_dev',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'forbidden',
          ),
        ),
      );
    });
  });

  group('approveSession', () {
    test('completes successfully on 200', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = _captureRequest(request);
        return http.Response(jsonEncode({}), 200);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await service.approveSession(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        hostDeviceId: 'host_dev',
        requestId: 'req_001',
        wrappedVaultBundle: 'bundle_123',
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(
        captured!.url.toString(),
        '$_serverUrl/pairing/sessions/sess_abc/approve',
      );
      final body = jsonDecode(captured!.body);
      expect(body['host_device_id'], 'host_dev');
      expect(body['request_id'], 'req_001');
      expect(body['action'], 'approve');
      expect(body['wrapped_vault_bundle'], 'bundle_123');
    });

    test('throws VaultPairingServiceException on non-200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'request expired'}),
          410,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.approveSession(
          serverUrl: _serverUrl,
          sessionId: 'sess_abc',
          hostDeviceId: 'host_dev',
          requestId: 'req_001',
          wrappedVaultBundle: 'bundle_123',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'request expired',
          ),
        ),
      );
    });

    test('throws fallback error when server provides no error message',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 403);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.approveSession(
          serverUrl: _serverUrl,
          sessionId: 'sess_abc',
          hostDeviceId: 'host_dev',
          requestId: 'req_001',
          wrappedVaultBundle: 'bundle_123',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'Failed to approve pairing request.',
          ),
        ),
      );
    });
  });

  group('model fromJson fallback paths', () {
    test('PairingSessionInfo falls back on bad expires_at', () {
      final info = PairingSessionInfo.fromJson({
        'session_id': 's1',
        'pairing_code': 'pc1',
        'status': 'waiting',
        'expires_at': 'not-a-date',
      });
      expect(info.expiresAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('PairingJoinResult falls back on bad expires_at', () {
      final result = PairingJoinResult.fromJson({
        'session_id': 's1',
        'request_id': 'r1',
        'status': 'pending',
        'expires_at': 'not-a-date',
      });
      expect(result.expiresAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('PairingPendingRequest falls back on bad requested_at', () {
      final req = PairingPendingRequest.fromJson({
        'request_id': 'r1',
        'requester_device_id': 'd1',
        'requester_public_key': 'pk1',
        'requested_at': 'not-a-date',
      });
      expect(req.requestedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('PairingSessionStatus falls back on bad expires_at', () {
      final status = PairingSessionStatus.fromJson({
        'session_id': 's1',
        'status': 'waiting',
        'expires_at': 'not-a-date',
      });
      expect(status.expiresAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('getBundle', () {
    test('returns approved bundle on 200', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          '$_serverUrl/pairing/sessions/sess_abc/bundle?request_id=req_001&requester_device_id=device_req',
        );
        return http.Response(
          jsonEncode({
            'status': 'approved',
            'wrapped_vault_bundle': 'wrapped_bundle_123',
          }),
          200,
        );
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getBundle(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        requestId: 'req_001',
        requesterDeviceId: 'device_req',
      );

      expect(result.status, 'approved');
      expect(result.wrappedVaultBundle, 'wrapped_bundle_123');
    });

    test('returns pending_approval on 202', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'pending_approval'}), 202);
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getBundle(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        requestId: 'req_001',
        requesterDeviceId: 'device_req',
      );

      expect(result.status, 'pending_approval');
      expect(result.wrappedVaultBundle, isNull);
    });

    test('returns rejected on 403', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'rejected'}), 403);
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getBundle(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        requestId: 'req_001',
        requesterDeviceId: 'device_req',
      );

      expect(result.status, 'rejected');
      expect(result.wrappedVaultBundle, isNull);
    });

    test('returns expired on 410', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 'expired'}), 410);
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getBundle(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        requestId: 'req_001',
        requesterDeviceId: 'device_req',
      );

      expect(result.status, 'expired');
      expect(result.wrappedVaultBundle, isNull);
    });

    test('infers status from statusCode when body omits status', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 200);
      });

      final service = VaultPairingService(httpClient: mockClient);
      final result = await service.getBundle(
        serverUrl: _serverUrl,
        sessionId: 'sess_abc',
        requestId: 'req_001',
        requesterDeviceId: 'device_req',
      );

      expect(result.status, 'approved');
    });

    test('throws fallback error on unrecognized status code', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({}), 404);
      });

      final service = VaultPairingService(httpClient: mockClient);
      await expectLater(
        service.getBundle(
          serverUrl: _serverUrl,
          sessionId: 'sess_abc',
          requestId: 'req_001',
          requesterDeviceId: 'device_req',
        ),
        throwsA(
          isA<VaultPairingServiceException>().having(
            (e) => e.message,
            'message',
            'Failed to fetch pairing bundle.',
          ),
        ),
      );
    });
  });
}
