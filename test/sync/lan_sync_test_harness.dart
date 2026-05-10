import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/local_sync_change.dart';
import 'package:secret_roy/models/totp_credential.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/identity_service.dart';
import 'package:secret_roy/services/lan_pairing_service.dart';
import 'package:secret_roy/services/secure_storage_service.dart';
import 'package:secret_roy/sync/lan_sync_coordinator.dart';
import 'package:secret_roy/sync/sync_service.dart';

/// 单台物理机上的虚拟设备（用于 LAN 同步集成测试）。
///
/// 每个 harness 拥有：
/// - 独立的临时数据库（SQLite）
/// - 独立的 deviceId / vaultId（通过 [IdentityService] 生成）
/// - 独立的 UDP 发现端口（避免与真实服务或其他 harness 冲突）
/// - 独立的 [LanPairingService] / [LanSyncCoordinator] / [SyncService]
///
/// 使用示例：
/// ```dart
/// final deviceA = await LanSyncTestHarness.create(
///   label: 'A',
///   discoveryPort: 50001,
/// );
/// await deviceA.initialize();
/// // ... 测试逻辑 ...
/// await deviceA.dispose();
/// ```
class LanSyncTestHarness {
  final String label;
  final Directory rootDir;
  final int discoveryPort;

  late final DatabaseFileCipher _cipher;
  late final SecureStorageService _storage;
  late final IdentityService _identity;
  late final MemoryKeyValueStore _identityStore;
  late final LanPairingService _pairing;
  late final SyncService _syncService;
  late final LanSyncCoordinator _coordinator;

  bool _initialized = false;

  LanSyncTestHarness._({
    required this.label,
    required this.rootDir,
    required this.discoveryPort,
  });

  SecureStorageService get storage => _storage;
  IdentityService get identity => _identity;
  LanPairingService get pairing => _pairing;
  LanSyncCoordinator get coordinator => _coordinator;
  SyncService get syncService => _syncService;
  bool get isInitialized => _initialized;

  /// The underlying memory identity store.
  MemoryKeyValueStore get identityStore => _identityStore;

  /// Creates a harness with a fresh temporary directory.
  static Future<LanSyncTestHarness> create({
    required String label,
    required int discoveryPort,
  }) async {
    final root = Directory.systemTemp.createTempSync('lan_sync_${label}_');
    final harness = LanSyncTestHarness._(
      label: label,
      rootDir: root,
      discoveryPort: discoveryPort,
    );
    await harness._setup();
    return harness;
  }

  Future<void> _setup() async {
    final documentsDir = Directory(p.join(rootDir.path, 'documents'))
      ..createSync(recursive: true);
    final tempDir = Directory(p.join(rootDir.path, 'temp'))
      ..createSync(recursive: true);

    // Override path_provider for this isolate
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsDir.path,
      temporaryPath: tempDir.path,
    );

    _cipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, label.hashCode % 256)),
    );

    _storage = SecureStorageService(databaseCipher: _cipher);

    // Create a memory-backed identity store to avoid FlutterSecureStorage
    _identityStore = MemoryKeyValueStore();
    _identity = IdentityService(secureStorage: _identityStore);
    // Note: identity.initialize() is deferred to [initialize()] so that
    // tests can pre-populate the store (e.g. share vault identity).

    _pairing = LanPairingService(discoveryPort: discoveryPort);

    _syncService = SyncService(
      storageService: _storage,
      identityService: _identity,
      config: const SyncConfig(serverUrl: ''),
    );

    _coordinator = LanSyncCoordinator(
      storage: _storage,
      identity: _identity,
      pairing: _pairing,
      syncService: _syncService,
    );
  }

  /// Opens the encrypted database with the vault identity.
  ///
  /// Also initializes [IdentityService] if not already done.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!_identity.hasIdentity) {
      await _identity.initialize();
    }
    await _storage.initialize(deviceId: _identity.deviceId);
    _initialized = true;
  }

  /// Seeds the database with sample accounts/templates/TOTP.
  Future<void> seedAccounts(List<AccountItem> accounts) async {
    for (final account in accounts) {
      await _storage.saveAccount(account);
    }
  }

  Future<void> seedTemplates(List<AccountTemplate> templates) async {
    for (final template in templates) {
      await _storage.saveTemplate(template);
    }
  }

  Future<void> seedTotpCredentials(List<TotpCredential> totps) async {
    for (final totp in totps) {
      await _storage.saveTotpCredential(totp);
    }
  }

  /// Returns all local accounts (excluding deleted).
  Future<List<AccountItem>> loadAccounts() => _storage.loadAccounts();

  /// Returns all approved local sync changes.
  Future<List<LocalSyncChange>> loadApprovedChanges() async {
    return _storage.loadApprovedLocalSyncChanges(vaultId: _identity.vaultId);
  }

  /// Cleans up all resources.
  Future<void> dispose() async {
    _coordinator.dispose();
    _pairing.dispose();
    _syncService.dispose();
    await _storage.close(dispose: true);
    if (rootDir.existsSync()) {
      rootDir.deleteSync(recursive: true);
    }
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String documentsPath;
  final String temporaryPath;

  _FakePathProviderPlatform({
    required this.documentsPath,
    required this.temporaryPath,
  });

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

/// In-memory [SecureKeyValueStore] for testing without FlutterSecureStorage.
class MemoryKeyValueStore implements SecureKeyValueStore {
  final _data = <String, String>{};

  @override
  Future<String?> read({required String key}) async => _data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  // Synchronous helpers for test setup
  String? readSync(String key) => _data[key];
  void writeSync(String key, String value) => _data[key] = value;
}
