import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:secret_roy/core/app_logger.dart';
import 'package:http/http.dart' as http;

import '../sync/lan_sync_host_handler.dart';
import '../sync/lan_sync_session.dart';
import 'vault_pairing_crypto.dart';

/// LAN 配对过程中的异常。
class LanPairingServiceException implements Exception {
  final String message;

  const LanPairingServiceException(this.message);

  @override
  String toString() => 'LanPairingServiceException($message)';
}

/// LAN 配对主机会话信息，包含配对码、服务端口与过期时间。
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

/// 发现的 LAN 主机信息，包含 IP 地址与端口。
class LanPairingHostInfo {
  final InternetAddress address;
  final int port;

  const LanPairingHostInfo({required this.address, required this.port});
}

/// LAN 配对服务，通过 UDP 广播发现与 HTTP 声明在局域网内安全交换 transfer code。
///
/// 主机端广播配对信息，客户端通过配对码获取加密后的 vault bundle。
class LanPairingService {
  static const int defaultDiscoveryPort = 48653;
  static const String _advertisementKind = 'sroy_lan_pairing';
  static const String _claimPath = '/lan-pairing/claim';
  static const int _maxFailedClaims = 5;

  final Random _random;
  final int _discoveryPort;

  HttpServer? _hostServer;
  List<RawDatagramSocket>? _hostSockets;
  Timer? _hostBroadcastTimer;
  Timer? _hostExpiryTimer;
  StreamSubscription<dynamic>? _hostSubscription;
  String? _hostPairingCode;
  String? _hostTransferCode;
  DateTime? _hostExpiresAt;
  bool _hostClaimed = false;
  int _hostFailedClaims = 0;
  LanSyncHostHandler? _syncHandler;
  InternetAddress? _lastHostAddress;
  int? _lastHostPort;

  /// The host address saved from the last successful claim/discovery.
  /// Used by requester to start data sync without re-discovering the host.
  InternetAddress? get lastHostAddress => _lastHostAddress;
  int? get lastHostPort => _lastHostPort;

  LanPairingService({
    Random? random,
    int discoveryPort = defaultDiscoveryPort,
  })  : _random = random ?? Random.secure(),
        _discoveryPort = discoveryPort;

  bool get isHosting => _hostServer != null;

  /// 启动 LAN 配对主机，生成配对码并通过 UDP 广播服务信息。
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
          AppLogger.d('[LAN] Failed to bind to ${addr.address}: $e');
        }
      }
    }

    // Fallback if no interfaces worked (unlikely)
    if (sockets.isEmpty) {
      try {
        final s = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          0,
          reuseAddress: true,
        );
        s.broadcastEnabled = true;
        sockets.add(s);
      } catch (e) {
        AppLogger.d('[LAN] Failed to bind fallback socket: $e');
      }
    }

    _hostServer = server;
    _hostSockets = sockets;
    _hostPairingCode = code;
    _hostTransferCode = normalizedTransferCode;
    _hostExpiresAt = expiresAt;
    _hostClaimed = false;
    _hostFailedClaims = 0;

    _hostSubscription = server.listen(_handleHostRequest);

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
          AppLogger.d('[LAN] Failed to send broadcast: $e');
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

  void attachSyncHandler(LanSyncHostHandler handler) {
    _syncHandler = handler;
  }

  void detachSyncHandler() {
    _syncHandler = null;
  }

  void _extendHostingForSync() {
    // 延长 Server 生命周期 5 分钟供同步使用
    _hostExpiryTimer?.cancel();
    _hostExpiryTimer = Timer(const Duration(minutes: 5), () {
      AppLogger.d('[LAN] Sync hosting TTL expired. Stopping server.');
      unawaited(stopHosting());
    });
  }

  /// 停止 LAN 配对主机，关闭广播、HTTP 服务与相关资源。
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

    _syncHandler?.dispose();
    _syncHandler = null;

    await _hostSubscription?.cancel();
    _hostSubscription = null;
    final server = _hostServer;
    _hostServer = null;
    if (server != null) {
      await server.close(force: true);
    }

    _clearHostedBundleState();
  }

  /// 通过配对码在 LAN 中发现主机并请求 transfer code，返回解密后的明文 bundle。
  Future<String> claimTransferCodeByCode({
    required String pairingCode,
    required String requesterDeviceId,
    Duration discoveryTimeout = const Duration(seconds: 12),
    Duration claimTimeout = const Duration(seconds: 8),
    bool useRequesterEncryption = true,
  }) async {
    final normalizedCode = normalizePairingCode(pairingCode);
    if (requesterDeviceId.trim().isEmpty) {
      throw const LanPairingServiceException(
        'Requester device id is required.',
      );
    }
    final requesterKeyPair = useRequesterEncryption
        ? await VaultPairingCrypto.createKeyPair()
        : null;

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
              requesterKeyPair: requesterKeyPair,
              timeout: claimTimeout,
            )
            .then((transferCode) {
              if (transferCode != null && !completer.isCompleted) {
                completer.complete(transferCode);
              }
            })
            .catchError((Object e) {
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
        } catch (e) {
          AppLogger.d('LAN pairing datagram decode failed: $e');
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

  /// Discovers a LAN host by listening for UDP broadcast advertisements.
  ///
  /// Returns the first host found, or null if no host is discovered within
  /// the [timeout].
  Future<LanPairingHostInfo?> discoverHost({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _discoveryPort,
      reuseAddress: true,
    );

    final completer = Completer<LanPairingHostInfo?>();
    late final Timer timer;
    late final StreamSubscription<RawSocketEvent> subscription;

    void completeWithNull() {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    timer = Timer(timeout, completeWithNull);

    subscription = socket.listen((event) {
      if (event != RawSocketEvent.read || completer.isCompleted) return;

      final datagram = socket.receive();
      if (datagram == null) return;

      String raw;
      try {
        raw = utf8.decode(datagram.data);
      } catch (e) {
        return;
      }

      final advertisement = _decodeJson(raw);
      if (advertisement['kind'] != _advertisementKind) return;

      final advertisedPort = advertisement['port'];
      final port = switch (advertisedPort) {
        int value => value,
        String value => int.tryParse(value) ?? -1,
        _ => -1,
      };
      if (port <= 0 || port > 65535) return;

      if (!completer.isCompleted) {
        completer.complete(
          LanPairingHostInfo(address: datagram.address, port: port),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
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

    // Reject requests from non-local origins.
    // LAN pairing uses plaintext HTTP; the transfer code payload is protected
    // by X25519+AES-GCM via VaultPairingCrypto, but the pairing code itself
    // is sent in cleartext. Restricting to local network segments mitigates
    // interception on shared WiFi.
    final remoteAddress = request.connectionInfo?.remoteAddress;
    if (remoteAddress != null &&
        !_isLocalNetworkAddress(remoteAddress.address)) {
      response.statusCode = HttpStatus.forbidden;
      response.write(jsonEncode({'error': 'Only local network connections are accepted.'}));
      await response.close();
      return;
    }

    // 处理 LAN 同步端点
    if (_syncHandler != null && request.uri.path.startsWith('/lan-sync/')) {
      await _handleSyncRequest(request);
      return;
    }

    if (request.method != 'POST' || request.uri.path != _claimPath) {
      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({'error': 'Not found'}));
      await response.close();
      return;
    }

    final hostCode = _hostPairingCode;
    final transferCode = _hostTransferCode;
    if (hostCode == null || transferCode == null || _isHostExpired()) {
      _clearHostedBundleState();
      response.statusCode = HttpStatus.gone;
      response.write(jsonEncode({'error': 'LAN pairing session expired.'}));
      await response.close();
      unawaited(stopHosting());
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
    final incomingCode = _normalizeIncomingClaimCode(body['code']);
    final requesterPublicKey = (body['requester_public_key'] as String?)
        ?.trim();

    if (incomingCode != hostCode) {
      _hostFailedClaims += 1;
      final locked = _hostFailedClaims >= _maxFailedClaims;
      if (locked) {
        _clearHostedBundleState();
      }
      response.statusCode = HttpStatus.forbidden;
      response.write(
        jsonEncode({
          'error': locked
              ? 'LAN pairing stopped after too many failed attempts.'
              : 'Pairing code mismatch.',
        }),
      );
      await response.close();
      if (locked) {
        unawaited(stopHosting());
      }
      return;
    }

    if (requesterPublicKey == null || requesterPublicKey.isEmpty) {
      response.statusCode = HttpStatus.badRequest;
      response.write(
        jsonEncode({
          'error': 'LAN pairing claim requires requester_public_key.',
        }),
      );
      await response.close();
      return;
    }

    _hostClaimed = true;
    _clearHostedBundleState(claimed: true);

    late final String wrappedTransferCode;
    try {
      wrappedTransferCode = await VaultPairingCrypto.encryptBundle(
        plainBundle: transferCode,
        requesterPublicKey: requesterPublicKey,
      );
    } on VaultPairingCryptoException catch (e) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': e.message}));
      await response.close();
      unawaited(stopHosting());
      return;
    }

    response.statusCode = HttpStatus.ok;
    response.write(
      jsonEncode({
        'status': 'approved',
        'wrapped_transfer_code': wrappedTransferCode,
      }),
    );
    await response.close();

    // 如果存在 sync handler，延长 Server 生命周期以支持数据同步
    if (_syncHandler != null) {
      AppLogger.d('[LAN] Pairing approved. Extending server for sync session.');
      _extendHostingForSync();
    } else {
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 250),
        ).then((_) => stopHosting()),
      );
    }
  }

  Future<String?> _claimEndpoint({
    required InternetAddress address,
    required int port,
    required String pairingCode,
    required String requesterDeviceId,
    required VaultPairingKeyPair? requesterKeyPair,
    required Duration timeout,
  }) async {
    final response = await http
        .post(
          Uri.parse('http://${address.address}:$port$_claimPath'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': pairingCode,
            'requester_device_id': requesterDeviceId,
            if (requesterKeyPair != null)
              'requester_public_key': requesterKeyPair.publicKey,
          }),
        )
        .timeout(timeout);

    final body = _decodeJson(response.body);
    if (response.statusCode != 200) {
      final errorMsg = body['error'] as String?;
      if (response.statusCode == HttpStatus.forbidden ||
          response.statusCode == HttpStatus.conflict ||
          response.statusCode == HttpStatus.gone) {
        throw LanPairingServiceException(
          errorMsg ?? 'Pairing rejected by host.',
        );
      }
      return null;
    }

    final wrappedTransferCode = body['wrapped_transfer_code'] as String?;
    if (wrappedTransferCode != null && wrappedTransferCode.isNotEmpty) {
      if (requesterKeyPair == null) {
        throw const LanPairingServiceException(
          'Host returned an encrypted transfer code without a local key.',
        );
      }
      try {
        final code = VaultPairingCrypto.decryptBundle(
          wrappedBundle: wrappedTransferCode,
          keyPair: requesterKeyPair,
        );
        _lastHostAddress = address;
        _lastHostPort = port;
        return code;
      } on VaultPairingCryptoException catch (e) {
        throw LanPairingServiceException(e.message);
      }
    }

    throw const LanPairingServiceException(
      'Host did not return an encrypted transfer code.',
    );
  }

  Future<void> _handleSyncRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.contentType = ContentType.json;

    final remoteAddress = request.connectionInfo?.remoteAddress;
    if (remoteAddress != null &&
        !_isLocalNetworkAddress(remoteAddress.address)) {
      response.statusCode = HttpStatus.forbidden;
      response.write(jsonEncode({'error': 'Only local network connections are accepted.'}));
      await response.close();
      return;
    }

    final handler = _syncHandler;
    if (handler == null) {
      response.statusCode = HttpStatus.serviceUnavailable;
      response.write(jsonEncode({'error': 'Sync not available.'}));
      await response.close();
      return;
    }

    try {
      final path = request.uri.path;
      final body = await _decodeRequestBody(request);

      switch (path) {
        case '/lan-sync/start':
          if (request.method != 'POST') {
            response.statusCode = HttpStatus.methodNotAllowed;
            break;
          }
          final peerDeviceId = (body['device_id'] as String?) ?? '';
          final peerRecordIds = (body['record_ids'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList();
          final result = await handler.handleStart(
            peerDeviceId,
            peerRecordIds: peerRecordIds,
          );
          response.statusCode = HttpStatus.ok;
          response.write(jsonEncode(result));
          break;

        case '/lan-sync/push':
          if (request.method != 'POST') {
            response.statusCode = HttpStatus.methodNotAllowed;
            break;
          }
          final sessionId = body['session_id'] as String? ?? '';
          final page = (body['page'] as int?) ?? 0;
          final items = (body['items'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          final result = await handler.handlePush(sessionId, page, items);
          response.statusCode = HttpStatus.ok;
          response.write(jsonEncode(result));
          break;

        case '/lan-sync/result':
          if (request.method != 'GET' && request.method != 'POST') {
            response.statusCode = HttpStatus.methodNotAllowed;
            break;
          }
          final querySessionId = request.uri.queryParameters['session_id'] ??
              (body['session_id'] as String?) ??
              '';
          final result = await handler.handleResultQuery(querySessionId);
          response.statusCode = HttpStatus.ok;
          response.write(jsonEncode(result));
          break;

        case '/lan-sync/pull':
          if (request.method != 'POST') {
            response.statusCode = HttpStatus.methodNotAllowed;
            break;
          }
          final sessionId = body['session_id'] as String? ?? '';
          final result = await handler.handlePull(sessionId);
          response.statusCode = HttpStatus.ok;
          response.write(jsonEncode(result));
          break;

        case '/lan-sync/abort':
          if (request.method != 'POST') {
            response.statusCode = HttpStatus.methodNotAllowed;
            break;
          }
          final sessionId = body['session_id'] as String? ?? '';
          await handler.handleAbort(sessionId);
          response.statusCode = HttpStatus.ok;
          response.write(jsonEncode({'aborted': true}));
          break;

        default:
          response.statusCode = HttpStatus.notFound;
          response.write(jsonEncode({'error': 'Unknown sync endpoint'}));
      }
    } on LanSyncException catch (e) {
      response.statusCode = HttpStatus.badRequest;
      response.write(jsonEncode({'error': e.message}));
    } catch (e) {
      AppLogger.d('[LAN] Sync request failed: $e');
      response.statusCode = HttpStatus.internalServerError;
      response.write(jsonEncode({'error': 'Internal error'}));
    }

    await response.close();
  }

  Future<Map<String, dynamic>> _decodeRequestBody(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      if (body.isEmpty) return {};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (e) {
      return {};
    }
  }

  bool _isHostExpired() {
    final expiresAt = _hostExpiresAt;
    if (expiresAt == null) {
      return true;
    }
    return DateTime.now().isAfter(expiresAt);
  }

  void _clearHostedBundleState({bool claimed = false}) {
    _hostPairingCode = null;
    _hostTransferCode = null;
    _hostExpiresAt = null;
    _hostClaimed = claimed;
    _hostFailedClaims = 0;
  }

  String? _normalizeIncomingClaimCode(Object? rawCode) {
    if (rawCode is! String) {
      return null;
    }
    try {
      return normalizePairingCode(rawCode);
    } on LanPairingServiceException {
      return null;
    }
  }

  bool _isLocalNetworkAddress(String address) {
    // IPv4 loopback
    if (address == '127.0.0.1') return true;
    // IPv4 link-local (169.254.x.x)
    if (address.startsWith('169.254.')) return true;
    // IPv4 private ranges (10.x, 172.16-31.x, 192.168.x)
    if (address.startsWith('10.')) return true;
    if (address.startsWith('192.168.')) return true;
    if (address.startsWith('172.')) {
      final second = int.tryParse(address.split('.')[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }
    // IPv6 loopback and link-local
    if (address == '::1' || address == '::ffff:127.0.0.1') return true;
    if (address.startsWith('fe80')) return true;
    return false;
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
      AppLogger.d('[LAN] Failed to decode JSON: $e');
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
      AppLogger.d('[LAN] Failed to detect local IPv4: $e');
    }
    return null;
  }
}
