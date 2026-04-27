import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LanPairingServiceException implements Exception {
  final String message;

  const LanPairingServiceException(this.message);

  @override
  String toString() => 'LanPairingServiceException($message)';
}

class LanPairingHostSession {
  final String pairingCode;
  final int serverPort;
  final DateTime expiresAt;
  final String? localAddress;

  const LanPairingHostSession({
    required this.pairingCode,
    required this.serverPort,
    required this.expiresAt,
    this.localAddress,
  });
}

class LanPairingService {
  static const int _discoveryPort = 48653;
  static const String _advertisementKind = 'sroy_lan_pairing';
  static const String _claimPath = '/lan-pairing/claim';

  final Random _random;

  HttpServer? _hostServer;
  List<RawDatagramSocket>? _hostSockets;
  Timer? _hostBroadcastTimer;
  Timer? _hostExpiryTimer;
  String? _hostPairingCode;
  String? _hostTransferCode;
  DateTime? _hostExpiresAt;
  bool _hostClaimed = false;

  LanPairingService({Random? random}) : _random = random ?? Random.secure();

  bool get isHosting => _hostServer != null;

  Future<LanPairingHostSession> startHosting({
    required String transferCode,
    Duration ttl = const Duration(minutes: 3),
  }) async {
    final normalizedTransferCode = transferCode.trim();
    if (normalizedTransferCode.isEmpty) {
      throw const LanPairingServiceException('Transfer code is empty.');
    }
    if (ttl <= Duration.zero) {
      throw const LanPairingServiceException('Pairing ttl must be positive.');
    }

    await stopHosting();

    final code = _generatePairingCode();
    final expiresAt = DateTime.now().add(ttl);
    final server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );

    final interfaces = await NetworkInterface.list(
      includeLoopback: true,
      type: InternetAddressType.IPv4,
    );

    final sockets = <RawDatagramSocket>[];
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        try {
          final s = await RawDatagramSocket.bind(addr, 0, reuseAddress: true);
          s.broadcastEnabled = true;
          sockets.add(s);
        } catch (e) {
          debugPrint('[LAN] Failed to bind to ${addr.address}: $e');
        }
      }
    }

    // Fallback if no interfaces worked (unlikely)
    if (sockets.isEmpty) {
      try {
        final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true);
        s.broadcastEnabled = true;
        sockets.add(s);
      } catch (e) {
        debugPrint('[LAN] Failed to bind fallback socket: $e');
      }
    }

    _hostServer = server;
    _hostSockets = sockets;
    _hostPairingCode = code;
    _hostTransferCode = normalizedTransferCode;
    _hostExpiresAt = expiresAt;
    _hostClaimed = false;

    server.listen(_handleHostRequest);

    final packet = utf8.encode(
      jsonEncode({
        'kind': _advertisementKind,
        'version': 1,
        'port': server.port,
        'expires_at': expiresAt.toIso8601String(),
      }),
    );

    final broadcast = InternetAddress('255.255.255.255');
    void sendAdvertisement() {
      if (_isHostExpired()) {
        return;
      }
      for (final s in sockets) {
        try {
          s.send(packet, broadcast, _discoveryPort);
        } catch (e) {
          debugPrint('[LAN] Failed to send broadcast: $e');
        }
      }
    }

    sendAdvertisement();
    _hostBroadcastTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => sendAdvertisement(),
    );
    _hostExpiryTimer = Timer(ttl, () {
      unawaited(stopHosting());
    });

    return LanPairingHostSession(
      pairingCode: code,
      serverPort: server.port,
      expiresAt: expiresAt,
      localAddress: await _detectLocalIpv4(),
    );
  }

  Future<void> stopHosting() async {
    _hostBroadcastTimer?.cancel();
    _hostBroadcastTimer = null;
    _hostExpiryTimer?.cancel();
    _hostExpiryTimer = null;
    final sockets = _hostSockets;
    _hostSockets = null;
    if (sockets != null) {
      for (final s in sockets) {
        s.close();
      }
    }

    final server = _hostServer;
    _hostServer = null;
    if (server != null) {
      await server.close(force: true);
    }

    _hostPairingCode = null;
    _hostTransferCode = null;
    _hostExpiresAt = null;
    _hostClaimed = false;
  }

  Future<String> claimTransferCodeByCode({
    required String pairingCode,
    required String requesterDeviceId,
    Duration discoveryTimeout = const Duration(seconds: 12),
    Duration claimTimeout = const Duration(seconds: 8),
  }) async {
    final normalizedCode = normalizePairingCode(pairingCode);
    if (requesterDeviceId.trim().isEmpty) {
      throw const LanPairingServiceException(
        'Requester device id is required.',
      );
    }

    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _discoveryPort,
      reuseAddress: true,
    );
    socket.broadcastEnabled = true;

    final completer = Completer<String>();
    final seenEndpoints = <String>{};
    var sawPairingHost = false;
    late final Timer timeoutTimer;
    late final StreamSubscription<RawSocketEvent> subscription;

    void completeWithDiscoveryError() {
      if (completer.isCompleted) {
        return;
      }
      completer.completeError(
        LanPairingServiceException(
          sawPairingHost
              ? 'Pairing code did not match any LAN host.'
              : 'No LAN pairing host found on this network.',
        ),
      );
    }

    void tryClaimEndpoint(InternetAddress address, int port) {
      unawaited(
        _claimEndpoint(
          address: address,
          port: port,
          pairingCode: normalizedCode,
          requesterDeviceId: requesterDeviceId,
          timeout: claimTimeout,
        ).then((transferCode) {
          if (transferCode != null && !completer.isCompleted) {
            completer.complete(transferCode);
          }
        }).catchError((Object e) {
          // Ignore individual endpoint failures (e.g. 403 Wrong Code) 
          // because there might be other hosts on the network.
          // If no host accepts the code, the discoveryTimeout will eventually trigger.
        }),
      );
    }

    try {
      timeoutTimer = Timer(discoveryTimeout, completeWithDiscoveryError);
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) {
          return;
        }

        final datagram = socket.receive();
        if (datagram == null) {
          return;
        }

        String rawAdvertisement;
        try {
          rawAdvertisement = utf8.decode(datagram.data);
        } catch (_) {
          return;
        }

        final advertisement = _decodeJson(rawAdvertisement);
        if (advertisement['kind'] != _advertisementKind) {
          return;
        }

        final advertisedPort = advertisement['port'];
        final port = switch (advertisedPort) {
          int value => value,
          String value => int.tryParse(value) ?? -1,
          _ => -1,
        };
        if (port <= 0 || port > 65535) {
          return;
        }

        sawPairingHost = true;
        final endpointKey = '${datagram.address.address}:$port';
        if (!seenEndpoints.add(endpointKey)) {
          return;
        }
        tryClaimEndpoint(datagram.address, port);
      });

      return await completer.future;
    } finally {
      timeoutTimer.cancel();
      await subscription.cancel();
      socket.close();
    }
  }

  void dispose() {
    unawaited(stopHosting());
  }

  static String normalizePairingCode(String rawValue) {
    final normalized = rawValue.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (!RegExp(r'^[A-Z2-9]{8}$').hasMatch(normalized)) {
      throw const LanPairingServiceException(
        'Pairing code must contain exactly 8 letters or digits.',
      );
    }
    return normalized;
  }

  Future<void> _handleHostRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    if (request.method != 'POST' || request.uri.path != _claimPath) {
      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({'error': 'Not found'}));
      await response.close();
      return;
    }

    final hostCode = _hostPairingCode;
    final transferCode = _hostTransferCode;
    if (hostCode == null || transferCode == null || _isHostExpired()) {
      response.statusCode = HttpStatus.gone;
      response.write(jsonEncode({'error': 'LAN pairing session expired.'}));
      await response.close();
      return;
    }

    if (_hostClaimed) {
      response.statusCode = HttpStatus.conflict;
      response.write(jsonEncode({'error': 'LAN pairing code already used.'}));
      await response.close();
      return;
    }

    final requestBody = await utf8.decoder.bind(request).join();
    final body = _decodeJson(requestBody);
    final incomingCode = body['code'] as String?;

    if (incomingCode != hostCode) {
      response.statusCode = HttpStatus.forbidden;
      response.write(jsonEncode({'error': 'Pairing code mismatch.'}));
      await response.close();
      return;
    }

    _hostClaimed = true;
    response.statusCode = HttpStatus.ok;
    response.write(
      jsonEncode({'status': 'approved', 'transfer_code': transferCode}),
    );
    await response.close();

    unawaited(
      Future<void>.delayed(
        const Duration(milliseconds: 250),
      ).then((_) => stopHosting()),
    );
  }

  Future<String?> _claimEndpoint({
    required InternetAddress address,
    required int port,
    required String pairingCode,
    required String requesterDeviceId,
    required Duration timeout,
  }) async {
    final response = await http
        .post(
          Uri.parse('http://${address.address}:$port$_claimPath'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': pairingCode,
            'requester_device_id': requesterDeviceId,
          }),
        )
        .timeout(timeout);

    final body = _decodeJson(response.body);
    if (response.statusCode != 200) {
      final errorMsg = body['error'] as String?;
      if (response.statusCode == HttpStatus.forbidden ||
          response.statusCode == HttpStatus.conflict ||
          response.statusCode == HttpStatus.gone) {
        throw LanPairingServiceException(errorMsg ?? 'Pairing rejected by host.');
      }
      return null;
    }

    final transferCode = body['transfer_code'] as String?;
    if (transferCode == null || transferCode.isEmpty) {
      throw const LanPairingServiceException(
        'Host returned an empty transfer code.',
      );
    }
    return transferCode;
  }

  bool _isHostExpired() {
    final expiresAt = _hostExpiresAt;
    if (expiresAt == null) {
      return true;
    }
    return DateTime.now().isAfter(expiresAt);
  }

  Map<String, dynamic> _decodeJson(String rawValue) {
    if (rawValue.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('[LAN] Failed to decode JSON: $e');
    }
    return {};
  }

  static const String _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generatePairingCode() {
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buffer.write(_codeAlphabet[_random.nextInt(_codeAlphabet.length)]);
    }
    return buffer.toString();
  }

  Future<String?> _detectLocalIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final address in iface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (e) {
      debugPrint('[LAN] Failed to detect local IPv4: $e');
    }
    return null;
  }
}
