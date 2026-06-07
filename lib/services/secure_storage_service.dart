import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:secret_roy/core/app_logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../core/crypto_random.dart';
import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/app_notification.dart';
import '../models/hlc.dart';
import '../models/local_sync_change.dart';
import '../models/quick_note.dart';
import '../models/template_conflict_log.dart';
import '../models/totp_credential.dart';
import '../utils/template_reference_validator.dart';
import '../sync/crdt_merge_engine.dart';
import 'database_file_cipher.dart';
import 'totp_service.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

enum StorageItemType {
  account,
  template,
  totpCredential,
  quickNote,
  setting,
  localSyncChange,
}

/// 本地加密 SQLite 数据库的存储服务，负责所有保险库数据的持久化。
///
/// [SecureStorageService] 将数据保存在 AES-GCM-256 加密的长期文件中，
/// 解锁时解密到临时运行时工作库，操作完成后立即重新加密持久化。
/// 它管理 accounts、templates、totp_credentials、notifications、
/// local_sync_changes 等多个表，并提供 HLC 时间戳与同步状态维护。
///
/// 使用场景：
/// ```dart
/// final storage = SecureStorageService();
/// storage.setDatabaseCipher(cipher);
/// await storage.initialize(deviceId: identityService.deviceId);
/// final accounts = await storage.loadAccounts();
/// ```
///
/// 生命周期：
/// - [setDatabaseCipher] / [initialize] → 各种 CRUD 操作 → [close]
/// - [deleteDatabaseFile] 用于彻底删除本地数据库。
///
/// 异常：
/// - [StorageOpenException] 数据库打开失败（如密文损坏）。
/// - [TemplateInUseException] 删除仍被账号引用的模板。
/// - [TemplateStaleException] 保存的模板版本落后于已存在版本。
class SecureStorageService {
  static const String _databaseName = 'secret_roy_vault.db';
  static const String _encryptedDatabaseName = 'secret_roy_vault.db.enc';
  static const String _workingDatabaseName = 'secret_roy_vault.runtime.db';
  static const int _databaseVersion = 14;

  DatabaseFileCipher? _databaseCipher;

  Database? _database;
  StreamController<StorageChangeEvent> _changeController =
      StreamController<StorageChangeEvent>.broadcast();

  String _deviceId = 'local';
  SyncClock? _syncClock;
  String? _encryptedDatabasePath;
  String? _workingDatabasePath;
  String? _legacyDatabasePath;

  Future<Directory> _resolveDocumentsDirectory() async {
    if (Platform.environment['SECRETROY_TEST_DIR'] case final path?
        when path.isNotEmpty) {
      return Directory(path);
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> _resolveTemporaryDirectory() async {
    if (Platform.environment['SECRETROY_TEST_DIR'] case final path?
        when path.isNotEmpty) {
      return Directory(path);
    }
    try {
      return await getApplicationSupportDirectory();
    } catch (_) {
      return await getTemporaryDirectory();
    }
  }

  SecureStorageService({DatabaseFileCipher? databaseCipher})
    : _databaseCipher = databaseCipher;

  Stream<StorageChangeEvent> get onChange => _changeController.stream;
  bool get isOpen => _database?.isOpen ?? false;

  String _newWorkingDatabaseName() {
    if (Platform.environment['SECRETROY_TEST_DIR'] != null &&
        Platform.environment['SECRETROY_TEST_DIR']!.isNotEmpty) {
      return _workingDatabaseName;
    }
    final suffix = CryptoRandom.bytes(
      8,
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '$_workingDatabaseName.$suffix';
  }

  void setDatabaseCipher(DatabaseFileCipher cipher) {
    _databaseCipher = cipher;
  }

  void clearDatabaseCipher() {
    _databaseCipher = null;
  }

  Future<void> rotateDatabaseCipher(DatabaseFileCipher cipher) async {
    _databaseCipher = cipher;
    if (isOpen) {
      await _persistEncryptedDatabase();
    }
  }

  /// 初始化数据库连接，解密长期文件到运行时工作库。
  ///
  /// [deviceId] 用于初始化 HLC 时钟，确保本地操作的时间戳携带正确设备标识。
  /// 必须在调用前通过 [setDatabaseCipher] 配置数据库文件加密器，
  /// 否则抛出 [StateError]。
  ///
  /// 若加密数据库文件损坏，会将其备份并抛出 [StorageOpenException]。
  Future<void> initialize({String deviceId = 'local'}) async {
    _deviceId = deviceId;
    _syncClock = SyncClock(deviceId);
    if (_changeController.isClosed) {
      _changeController = StreamController<StorageChangeEvent>.broadcast();
    }

    final documentsDirectory = await _resolveDocumentsDirectory();
    final temporaryDirectory =
        Platform.environment['SECRETROY_TEST_DIR'] != null &&
            Platform.environment['SECRETROY_TEST_DIR']!.isNotEmpty
        ? documentsDirectory
        : await _resolveTemporaryDirectory();
    _legacyDatabasePath = join(documentsDirectory.path, _databaseName);
    _encryptedDatabasePath = join(
      documentsDirectory.path,
      _encryptedDatabaseName,
    );
    _workingDatabasePath = join(
      temporaryDirectory.path,
      'secret_roy',
      _newWorkingDatabaseName(),
    );

    if (_databaseCipher == null) {
      throw StateError('Database file cipher is not configured.');
    }

    if (isOpen) {
      await _persistEncryptedDatabase();
      return;
    }

    await _cleanupStaleWorkingFiles(temporaryDirectory);

    try {
      await _prepareWorkingDatabase();
      await _openAndInitialize(_workingDatabasePath!);
      await _setRuntimePragmas();
      await _persistEncryptedDatabase();
      await _deleteLegacyPlaintextDatabase();
    } catch (e) {
      final backupPath = await _backupUnreadableDatabase(
        _encryptedDatabasePath!,
      );
      try {
        await _database?.close();
      } catch (closeError) {
        AppLogger.d(
          'Failed to close working database after open error: $closeError',
        );
      } finally {
        _database = null;
      }
      try {
        await _deleteWorkingDatabase();
      } catch (cleanupError) {
        AppLogger.d(
          'Failed to clean working database after open error: $cleanupError',
        );
      }
      AppLogger.d('Failed to open database safely: $e');
      throw StorageOpenException(
        originalError: e.toString(),
        backupPath: backupPath,
      );
    }
  }

  Future<void> _openAndInitialize(String databasePath) async {
    if (_isDesktop) {
      ffi.sqfliteFfiInit();
      _database = await ffi.databaseFactoryFfi.openDatabase(
        databasePath,
        options: ffi.OpenDatabaseOptions(
          version: _databaseVersion,
          onCreate: (db, version) => _onCreate(db, version),
          onUpgrade: (db, oldVersion, newVersion) =>
              _onUpgrade(db, oldVersion, newVersion),
        ),
      );
      return;
    }

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 关闭数据库连接，将运行时工作库加密持久化后删除工作文件。
  ///
  /// [dispose] 为 true 时同时关闭变更事件流（[onChange]）。
  /// 多次调用安全，内部会检查数据库是否已打开。
  Future<void> close({bool dispose = false}) async {
    final hadOpenDatabase = isOpen;
    if (hadOpenDatabase) {
      try {
        await _checkpointRuntimeDatabase();
      } catch (e) {
        AppLogger.d('Failed to checkpoint runtime database during close: $e');
      }
    }

    try {
      await _database?.close();
    } catch (e) {
      AppLogger.d('Failed to close database connection: $e');
    } finally {
      _database = null;
    }

    if (hadOpenDatabase) {
      try {
        await _persistEncryptedDatabase(databaseIsOpen: false);
      } catch (e) {
        AppLogger.d('Failed to persist encrypted database during close: $e');
      }
      try {
        await _deleteWorkingDatabase();
      } catch (e) {
        AppLogger.d('Failed to delete working database during close: $e');
      }
    }

    if (dispose && !_changeController.isClosed) {
      await _changeController.close();
    }
  }

  Future<bool> isDatabaseInitialized() async {
    final documentsDirectory = await _resolveDocumentsDirectory();
    final databasePath = join(documentsDirectory.path, _encryptedDatabaseName);
    return File(databasePath).existsSync();
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final documentsDirectory = await _resolveDocumentsDirectory();
    final temporaryDirectory =
        Platform.environment['SECRETROY_TEST_DIR'] != null &&
            Platform.environment['SECRETROY_TEST_DIR']!.isNotEmpty
        ? documentsDirectory
        : await _resolveTemporaryDirectory();
    _legacyDatabasePath = join(documentsDirectory.path, _databaseName);
    _encryptedDatabasePath = join(
      documentsDirectory.path,
      _encryptedDatabaseName,
    );
    _workingDatabasePath = join(
      temporaryDirectory.path,
      'secret_roy',
      _newWorkingDatabaseName(),
    );

    try {
      await _deleteDatabaseFamily(_encryptedDatabasePath!);
      await _deleteDatabaseFamily(_legacyDatabasePath!);
      await _deleteWorkingDatabase();
      await _deleteCorruptBackups(_encryptedDatabasePath!);
      await _deleteCorruptBackups(_legacyDatabasePath!);
      clearDatabaseCipher();
      AppLogger.d('[Storage] Encrypted database files deleted manually.');
    } catch (e) {
      AppLogger.d('[Storage] Failed to delete database file: $e');
    }
  }

  Future<void> clearAllData() async {
    if (!isOpen) return;
    try {
      await _database!.execute('DELETE FROM accounts');
      await _database!.execute('DELETE FROM totp_credentials');
      await _database!.execute('DELETE FROM templates WHERE is_custom = 1');
      await _database!.execute('DELETE FROM conflict_logs');
      await _database!.execute('DELETE FROM local_sync_changes');
      await _persistAfterMutation();
      _notifyChange(
        StorageChangeEvent(
          type: StorageItemType.account,
          action: StorageAction.delete,
        ),
      );
    } catch (e) {
      AppLogger.d('Failed to clear all data: $e');
      rethrow;
    }
  }

  /// 导入覆盖：用传入数据整体替换本地库，保留源数据的 syncStatus。
  ///
  /// 用于 vault 导入流程中的状态重建（T14 规则）。
  /// 执行前会清空 accounts、templates、totp_credentials、conflict_logs、
  /// local_sync_changes 表，然后批量插入新数据。
  ///
  /// 调用方应在导入后重置 [SyncService] 状态，使 version / dirty 重新读取。
  ///
  /// 若数据库未打开，抛出 [StateError]。
  /// 导入完成后会自动重新加密持久化数据库。
  Future<void> replaceAllDataForImport({
    required List<AccountTemplate> templates,
    required List<AccountItem> accounts,
    List<TotpCredential> totpCredentials = const <TotpCredential>[],
  }) async {
    if (!isOpen) {
      throw StateError('Encrypted storage is not open.');
    }

    final batch = _database!.batch();
    batch.delete('accounts');
    batch.delete('totp_credentials');
    batch.delete('templates', where: 'is_custom = 1');
    batch.delete('conflict_logs');
    batch.delete('local_sync_changes');

    for (final template in templates) {
      batch.insert('templates', {
        'id': template.templateId,
        'title': template.title,
        'subtitle': template.subTitle,
        'icon_code_point': templateIconStorageValue(template.icon),
        'category': template.category.name,
        'fields': jsonEncode(template.fields.map((f) => f.toJson()).toList()),
        'is_custom': template.isCustom ? 1 : 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'hlc': template.hlc?.toString(),
        'server_version': template.serverVersion,
        'sync_status': template.syncStatus.index,
        'is_deleted': template.isDeleted ? 1 : 0,
        'delete_hlc': template.deleteHlc?.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final account in accounts) {
      batch.insert('accounts', {
        'id': account.id,
        'name': account.name,
        'email': account.email,
        'template_id': account.templateId,
        'data': jsonEncode(account.data),
        'created_at': account.createdAt,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
        'name_hlc': account.nameHlc.toString(),
        'email_hlc': account.emailHlc.toString(),
        'data_hlc': jsonEncode(
          account.dataHlc.map((k, v) => MapEntry(k, v.toString())),
        ),
        'server_version': account.serverVersion,
        'sync_status': account.syncStatus.index,
        'is_deleted': account.isDeleted ? 1 : 0,
        'delete_hlc': account.deleteHlc?.toString(),
        'is_pinned': account.isPinned ? 1 : 0,
        'pin_hlc': account.pinHlc?.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final credential in totpCredentials) {
      batch.insert(
        'totp_credentials',
        _totpCredentialRow(credential),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.save,
      ),
    );
  }

  Future<String> getDatabaseFilePath() async {
    final documentsDirectory = await _resolveDocumentsDirectory();
    return join(documentsDirectory.path, _encryptedDatabaseName);
  }

  Future<String?> _backupUnreadableDatabase(String databasePath) async {
    final dbFile = File(databasePath);
    if (!dbFile.existsSync()) {
      return null;
    }

    final backupPath =
        '$databasePath.corrupt.${DateTime.now().millisecondsSinceEpoch}.bak';
    try {
      await dbFile.copy(backupPath);
      return backupPath;
    } catch (e) {
      AppLogger.d('Failed to back up unreadable database: $e');
      return null;
    }
  }

  Future<void> replaceDatabase(Uint8List newDbBytes) async {
    final databasePath = await getDatabaseFilePath();

    await _database?.close();
    _database = null;

    _encryptedDatabasePath = databasePath;
    final cipher = _requireDatabaseCipher();
    final encryptedBytes = await cipher.encrypt(newDbBytes);
    await _writeFileAtomically(databasePath, encryptedBytes);
    await _deleteWorkingDatabase();
    await _deleteLegacyPlaintextDatabase();
  }

  DatabaseFileCipher _requireDatabaseCipher() {
    final cipher = _databaseCipher;
    if (cipher == null) {
      throw StateError('Database file cipher is not configured.');
    }
    return cipher;
  }

  Future<void> _prepareWorkingDatabase() async {
    final workingPath = _workingDatabasePath!;
    await _deleteWorkingDatabase();
    await Directory(dirname(workingPath)).create(recursive: true);
    await _recoverInterruptedEncryptedDatabaseWrite();

    final encryptedFile = File(_encryptedDatabasePath!);
    if (!encryptedFile.existsSync()) {
      return;
    }

    final encryptedBytes = Uint8List.fromList(
      await encryptedFile.readAsBytes(),
    );
    final plaintextBytes = await _requireDatabaseCipher().decrypt(
      encryptedBytes,
    );
    await _writeFileAtomically(workingPath, plaintextBytes);
    await _restrictFilePermissions(workingPath);
  }

  Future<void> _recoverInterruptedEncryptedDatabaseWrite() async {
    final encryptedPath = _encryptedDatabasePath;
    if (encryptedPath == null) {
      return;
    }

    final targetFile = File(encryptedPath);
    final backupFile = File('$encryptedPath.bak');
    final tempFile = File('$encryptedPath.tmp');

    if (!targetFile.existsSync() && backupFile.existsSync()) {
      try {
        await backupFile.rename(targetFile.path);
      } catch (_) {}
    }

    if (targetFile.existsSync() && tempFile.existsSync()) {
      try {
        await tempFile.delete();
      } catch (_) {}
    }

    if (targetFile.existsSync() && backupFile.existsSync()) {
      try {
        await backupFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _setRuntimePragmas() async {
    await _executePragmaSafely('PRAGMA journal_mode = DELETE');
    await _executePragmaSafely('PRAGMA synchronous = FULL');
  }

  Future<void> _executePragmaSafely(String sql) async {
    if (!isOpen) return;
    try {
      await _database!.execute(sql);
    } catch (e) {
      AppLogger.d('Failed to apply SQLite pragma "$sql": $e');
    }
  }

  Future<void> _checkpointRuntimeDatabase() async {
    if (!isOpen) return;
    try {
      await _database!.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (e) {
      AppLogger.d('Failed to checkpoint runtime database: $e');
    }
  }

  Future<void> _persistEncryptedDatabase({bool databaseIsOpen = true}) async {
    final encryptedPath = _encryptedDatabasePath;
    final workingPath = _workingDatabasePath;
    if (encryptedPath == null || workingPath == null) {
      return;
    }

    if (databaseIsOpen && isOpen) {
      await _checkpointRuntimeDatabase();
    }

    final workingFile = File(workingPath);
    if (!workingFile.existsSync()) {
      return;
    }

    final plaintextBytes = Uint8List.fromList(await workingFile.readAsBytes());
    final encryptedBytes = await _requireDatabaseCipher().encrypt(
      plaintextBytes,
    );
    await _writeFileAtomically(encryptedPath, encryptedBytes);
  }

  Future<void> _persistAfterMutation() async {
    await _persistEncryptedDatabase();
  }

  Future<void> _restrictFilePermissions(String path) async {
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['600', path]);
      } else if (Platform.isWindows) {
        await Process.run('attrib', ['+H', path]);
      }
    } catch (_) {}
  }

  Future<void> _writeFileAtomically(String targetPath, Uint8List bytes) async {
    await Directory(dirname(targetPath)).create(recursive: true);

    final targetFile = File(targetPath);
    // Use a unique temp file name to avoid concurrency conflicts on Windows.
    final tempSuffix = DateTime.now().microsecondsSinceEpoch;
    final tempFile = File('$targetPath.$tempSuffix.tmp');
    final backupFile = File('$targetPath.bak');

    try {
      // Explicitly open/close the file to ensure the handle is released
      // before rename on Windows.
      final raf = await tempFile.open(mode: FileMode.write);
      try {
        await raf.writeFrom(bytes);
        await raf.flush();
      } finally {
        await raf.close();
      }

      if (backupFile.existsSync()) {
        try {
          await backupFile.delete();
        } catch (_) {}
      }
      if (targetFile.existsSync()) {
        try {
          await targetFile.rename(backupFile.path);
        } catch (_) {
          // rename can fail if the file was deleted between existsSync and
          // rename, or if the backup file is locked. Fall through to copy.
          try {
            await targetFile.copy(backupFile.path);
            await targetFile.delete();
          } catch (_) {}
        }
      }

      try {
        await tempFile.rename(targetPath);
      } on FileSystemException catch (_) {
        // Windows: MoveFileEx can throw even when the OS moved the file.
        // If the temp is already gone and target exists, it succeeded.
        if (targetFile.existsSync()) {
          try { await tempFile.delete(); } catch (_) {}
        }
        // Regardless, ensure target has the new bytes. Use copy as fallback.
        if (!targetFile.existsSync() || targetFile.lengthSync() != bytes.length) {
          await Future.delayed(const Duration(milliseconds: 50));
          if (tempFile.existsSync()) {
            await tempFile.copy(targetPath);
            try { await tempFile.delete(); } catch (_) {}
          } else {
            // Temp gone — write directly to target.
            final t = await targetFile.open(mode: FileMode.write);
            try { await t.writeFrom(bytes); await t.flush(); } finally { await t.close(); }
          }
        }
      }
      await _restrictFilePermissions(targetPath);
      if (backupFile.existsSync()) {
        try {
          await backupFile.delete();
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.d('Database file atomic write failed: $e');
      if (backupFile.existsSync() && !targetFile.existsSync()) {
        try {
          await backupFile.rename(targetPath);
        } catch (_) {}
      }
      rethrow;
    } finally {
      // Best-effort cleanup — never let temp file deletion propagate.
      try {
        if (tempFile.existsSync()) await tempFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _cleanupStaleWorkingFiles(Directory tempDir) async {
    final secretRoyDir = Directory(join(tempDir.path, 'secret_roy'));
    if (!secretRoyDir.existsSync()) return;
    await for (final entity in secretRoyDir.list()) {
      if (entity is File) {
        final name = basename(entity.path);
        if (name.startsWith(_workingDatabaseName)) {
          try {
            await entity.delete();
            AppLogger.d('[Storage] Deleted stale working file: ${entity.path}');
          } catch (e) {
            AppLogger.d('[Storage] Failed to delete stale working file: $e');
          }
        }
      }
    }
  }

  Future<void> _deleteWorkingDatabase() async {
    final workingPath = _workingDatabasePath;
    if (workingPath == null) {
      return;
    }
    await _deleteDatabaseFamily(workingPath);
  }

  Future<void> _deleteLegacyPlaintextDatabase() async {
    final legacyPath = _legacyDatabasePath;
    if (legacyPath == null) {
      return;
    }
    await _deleteDatabaseFamily(legacyPath);
  }

  Future<void> _deleteDatabaseFamily(String basePath) async {
    final paths = [
      basePath,
      '$basePath-journal',
      '$basePath-wal',
      '$basePath-shm',
      '$basePath.tmp',
      '$basePath.bak',
    ];

    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  Future<void> _deleteCorruptBackups(String basePath) async {
    final parent = Directory(dirname(basePath));
    if (!parent.existsSync()) {
      return;
    }
    final baseFileName = basename(basePath);
    await for (final entity in parent.list()) {
      if (entity is! File) {
        continue;
      }
      final name = basename(entity.path);
      if (name.startsWith('$baseFileName.corrupt.')) {
        await entity.delete();
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        template_id TEXT NOT NULL,
        template_version INTEGER DEFAULT 0,
        data TEXT NOT NULL,
        field_meta TEXT,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        last_edited_by TEXT,
        name_hlc TEXT,
        email_hlc TEXT,
        data_hlc TEXT,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT,
        is_pinned INTEGER DEFAULT 0,
        pin_hlc TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE conflict_logs (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        hlc TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT,
        icon_code_point INTEGER,
        category TEXT,
        fields TEXT NOT NULL,
        is_custom INTEGER DEFAULT 1,
        created_at INTEGER NOT NULL,
        modified_at INTEGER,
        last_edited_by TEXT,
        hlc TEXT,
        version INTEGER DEFAULT 1,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT,
        parent_template_ids TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE template_conflict_logs (
        id TEXT PRIMARY KEY,
        template_id TEXT NOT NULL,
        field_key TEXT NOT NULL,
        attribute_name TEXT NOT NULL,
        local_value TEXT NOT NULL,
        remote_value TEXT NOT NULL,
        local_hlc TEXT NOT NULL,
        remote_hlc TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )
    ''');

    await _createTotpCredentialsTable(db);
    await _createQuickNotesTable(db);

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await _createLocalSyncChangesTable(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        account_id TEXT,
        created_at INTEGER NOT NULL,
        is_read INTEGER DEFAULT 0,
        params TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_accounts_template ON accounts(template_id)',
    );
    await db.execute(
      'CREATE INDEX idx_accounts_modified ON accounts(modified_at)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE templates ADD COLUMN category TEXT');
    }

    if (oldVersion < 3) {
      // Data Migration for Phase 2 HLC Structure
      await db.execute('ALTER TABLE accounts ADD COLUMN name_hlc TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN email_hlc TEXT');
      await db.execute('ALTER TABLE accounts ADD COLUMN data_hlc TEXT');
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      // sync_status 1 = pendingPush (since migration changes the data, push it up)
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN sync_status INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE accounts ADD COLUMN delete_hlc TEXT');

      await db.execute('''
        CREATE TABLE conflict_logs (
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          key TEXT NOT NULL,
          value TEXT,
          hlc TEXT NOT NULL,
          saved_at INTEGER NOT NULL
        )
      ''');

      // Populate default HLCs for old accounts so they don't break the new model
      final stamp = '${DateTime.now().millisecondsSinceEpoch}-0-migration';
      await db.execute(
        'UPDATE accounts SET name_hlc = ?, email_hlc = ?, data_hlc = ?, sync_status = 1',
        [stamp, stamp, '{}'],
      );
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE templates ADD COLUMN hlc TEXT');
      await db.execute(
        'ALTER TABLE templates ADD COLUMN server_version INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE templates ADD COLUMN sync_status INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE templates ADD COLUMN is_deleted INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE templates ADD COLUMN delete_hlc TEXT');
    }

    if (oldVersion < 5) {
      await _createLocalSyncChangesTable(db);
    }

    if (oldVersion < 6) {
      await _createTotpCredentialsTable(db);
    }

    if (oldVersion < 7) {
      await db.execute('ALTER TABLE templates ADD COLUMN field_hlc TEXT');
    }

    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE templates ADD COLUMN version INTEGER DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN template_version INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE accounts ADD COLUMN field_meta TEXT');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS template_conflict_logs (
          id TEXT PRIMARY KEY,
          template_id TEXT NOT NULL,
          field_key TEXT NOT NULL,
          attribute_name TEXT NOT NULL,
          local_value TEXT NOT NULL,
          remote_value TEXT NOT NULL,
          local_hlc TEXT NOT NULL,
          remote_hlc TEXT NOT NULL,
          saved_at INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          account_id TEXT,
          created_at INTEGER NOT NULL,
          is_read INTEGER DEFAULT 0,
          params TEXT
        )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute('ALTER TABLE accounts ADD COLUMN last_edited_by TEXT');
      await db.execute('ALTER TABLE templates ADD COLUMN modified_at INTEGER');
      await db.execute('ALTER TABLE templates ADD COLUMN last_edited_by TEXT');
    }

    if (oldVersion < 11) {
      await db.execute(
        'ALTER TABLE accounts ADD COLUMN is_pinned INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE accounts ADD COLUMN pin_hlc TEXT');
    }

    if (oldVersion < 12) {
      // params column already exists in v9+ CREATE TABLE, skip for safety
      try {
        await db.execute('ALTER TABLE notifications ADD COLUMN params TEXT');
      } catch (e) {
        // Column may already exist; ignore
      }
    }

    if (oldVersion < 13) {
      await _createQuickNotesTable(db);
    }

    if (oldVersion < 14) {
      await db.execute(
        'ALTER TABLE templates ADD COLUMN parent_template_ids TEXT',
      );
    }
  }

  Future<void> _createTotpCredentialsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS totp_credentials (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        config TEXT NOT NULL,
        linked_account_ids TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        label_hlc TEXT,
        config_hlc TEXT,
        links_hlc TEXT,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_totp_credentials_modified ON totp_credentials(modified_at)',
    );
  }

  Future<void> _createLocalSyncChangesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_sync_changes (
        id TEXT PRIMARY KEY,
        vault_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        title TEXT NOT NULL,
        before_json TEXT,
        after_json TEXT,
        diff_json TEXT NOT NULL,
        base_server_version INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        approved_at INTEGER,
        pushed_at INTEGER,
        error_message TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_sync_changes_open ON local_sync_changes(vault_id, status, updated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_local_sync_changes_entity ON local_sync_changes(vault_id, entity_type, entity_id)',
    );
  }

  Future<void> _createQuickNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quick_notes (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quick_notes_updated ON quick_notes(updated_at DESC)',
    );
  }

  Future<List<Map<String, dynamic>>> _query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final raw = await _database!.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
    return (raw as List).cast<Map<String, dynamic>>();
  }

  /// 加载所有账号记录，默认排除已软删除的条目。
  ///
  /// [includeDeleted] 为 true 时同时返回 is_deleted = 1 的记录。
  /// 若数据库未打开，返回空列表。
  /// 结果按 modified_at 降序排列。
  Future<List<AccountItem>> loadAccounts({bool includeDeleted = false}) async {
    if (!isOpen) return [];

    try {
      final rows = await _query(
        'accounts',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'modified_at DESC',
      );
      return rows.map(_mapToAccountItem).whereType<AccountItem>().toList();
    } catch (e, stack) {
      AppLogger.d('Failed to load accounts: $e');
      AppLogger.d(stack.toString());
      return [];
    }
  }

  Future<List<AccountItem>> loadPendingSyncAccounts() async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'accounts',
        where: 'sync_status = ?',
        whereArgs: [SyncStatus.pendingPush.index],
        orderBy: 'modified_at DESC',
      );
      return rows.map(_mapToAccountItem).whereType<AccountItem>().toList();
    } catch (e) {
      AppLogger.d('Failed to load pending sync accounts: $e');
      return [];
    }
  }

  Future<AccountItem?> getAccountById(
    String id, {
    bool includeDeleted = false,
  }) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'accounts',
        where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return _mapToAccountItem(rows.first);
    } catch (e) {
      AppLogger.d('Failed to load account by id: $e');
      return null;
    }
  }

  /// 保存或更新一条账号记录，自动处理 HLC 时间戳与同步状态。
  ///
  /// [account] 为要保存的账号数据。
  /// [isSyncMerge] 为 true 时表示来自同步合并，跳过本地 HLC  stamping
  /// 并保留源数据的同步状态。
  ///
  /// 若数据库未打开，静默返回。
  /// 保存成功后会触发 [StorageChangeEvent] 并重新加密持久化数据库。
  Future<void> saveAccount(
    AccountItem account, {
    bool isSyncMerge = false,
  }) async {
    if (!isOpen) return;

    AccountItem itemToSave = account;

    if (!isSyncMerge) {
      // Local Save logic: Stamp HLCs on explicitly modified fields
      final existingRows = await _query(
        'accounts',
        where: 'id = ?',
        whereArgs: [account.id],
      );
      final newStamp = _syncClock!.send();

      final template = await loadTemplateById(account.templateId);
      final Map<String, AccountFieldMeta> newFieldMeta = Map.from(
        account.fieldMeta,
      );
      // Remove stale fieldMeta for keys no longer in account data
      newFieldMeta.removeWhere((key, _) => !account.data.containsKey(key));
      if (template != null) {
        for (final field in template.fields) {
          if (account.data.containsKey(field.fieldKey)) {
            newFieldMeta[field.fieldKey] = AccountFieldMeta(
              type: field.attributes.type.name,
              label: field.label,
              sourceTemplateId: template.templateId,
              sourceTemplateVersion: template.version,
            );
          }
        }
      }
      final newTemplateVersion = template?.version ?? account.templateVersion;

      if (existingRows.isNotEmpty) {
        final old = _mapToAccountItem(existingRows.first);
        if (old != null) {
          final nHlc = account.name != old.name ? newStamp : old.nameHlc;
          final eHlc = account.email != old.email ? newStamp : old.emailHlc;
          final pHlc = account.isPinned != old.isPinned ? newStamp : old.pinHlc;

          final Map<String, Hlc> dHlc = Map.from(old.dataHlc);
          account.data.forEach((k, v) {
            if (old.data[k] != v) {
              dHlc[k] = newStamp;
            }
          });

          itemToSave = account.copyWith(
            nameHlc: nHlc,
            emailHlc: eHlc,
            dataHlc: dHlc,
            pinHlc: pHlc,
            fieldMeta: newFieldMeta,
            templateVersion: newTemplateVersion,
            syncStatus: SyncStatus.pendingPush,
            isDeleted: false,
            serverVersion: old.serverVersion,
          );
        }
      } else {
        // Completely new account being saved
        final Map<String, Hlc> dHlc = {};
        account.data.forEach((k, v) {
          dHlc[k] = newStamp;
        });
        itemToSave = account.copyWith(
          nameHlc: newStamp,
          emailHlc: newStamp,
          dataHlc: dHlc,
          fieldMeta: newFieldMeta,
          templateVersion: newTemplateVersion,
          syncStatus: SyncStatus.pendingPush,
          isDeleted: false,
        );
      }
    }

    await _database!.insert('accounts', {
      'id': itemToSave.id,
      'name': itemToSave.name,
      'email': itemToSave.email,
      'template_id': itemToSave.templateId,
      'template_version': itemToSave.templateVersion,
      'data': jsonEncode(itemToSave.data),
      'field_meta': jsonEncode(
        itemToSave.fieldMeta.map((k, v) => MapEntry(k, v.toJson())),
      ),
      'created_at': itemToSave.createdAt,
      'modified_at': DateTime.now().millisecondsSinceEpoch,
      'last_edited_by': _deviceId,
      'name_hlc': itemToSave.nameHlc.toString(),
      'email_hlc': itemToSave.emailHlc.toString(),
      'data_hlc': jsonEncode(
        itemToSave.dataHlc.map((k, v) => MapEntry(k, v.toString())),
      ),
      'server_version': itemToSave.serverVersion,
      'sync_status': itemToSave.syncStatus.index,
      'is_deleted': itemToSave.isDeleted ? 1 : 0,
      'delete_hlc': itemToSave.deleteHlc?.toString(),
      'is_pinned': itemToSave.isPinned ? 1 : 0,
      'pin_hlc': itemToSave.pinHlc?.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.save,
        id: itemToSave.id,
      ),
    );
  }

  /// 软删除指定 ID 的账号记录。
  ///
  /// [id] 为账号唯一标识符。
  /// [isSyncMerge] 为 true 时使用 [syncDeleteHlc] 作为删除时间戳。
  /// 默认行为为生成本地 HLC 删除 tombstone 并将 sync_status 设为 pendingPush。
  ///
  /// 若数据库未打开，静默返回。
  Future<void> deleteAccount(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen) return;

    Hlc stamp = syncDeleteHlc ?? _syncClock!.send();

    // Apply Soft Delete (Tombstone)
    await _database!.update(
      'accounts',
      {
        'is_deleted': 1,
        'delete_hlc': stamp.toString(),
        'sync_status': SyncStatus.pendingPush.index,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<void> togglePin(String id) async {
    if (!isOpen) return;
    final rows = await _query('accounts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final account = _mapToAccountItem(rows.first);
    if (account == null) return;

    final newPinned = !account.isPinned;
    final stamp = _syncClock!.send();
    await _database!.update(
      'accounts',
      {
        'is_pinned': newPinned ? 1 : 0,
        'pin_hlc': stamp.toString(),
        'sync_status': SyncStatus.pendingPush.index,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.update,
        id: id,
      ),
    );
  }

  Future<List<TotpCredential>> loadTotpCredentials({
    bool includeDeleted = false,
  }) async {
    if (!isOpen || _database == null) return [];

    try {
      final rows = await _query(
        'totp_credentials',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'modified_at DESC',
      );
      return rows
          .map(_mapToTotpCredential)
          .whereType<TotpCredential>()
          .toList();
    } catch (e) {
      AppLogger.d('Failed to load TOTP credentials: $e');
      return [];
    }
  }

  Future<List<TotpCredential>> loadDirtyTotpCredentials() async {
    if (!isOpen || _database == null) return [];

    try {
      final rows = await _query(
        'totp_credentials',
        where: 'sync_status != ?',
        whereArgs: [SyncStatus.synchronized.index],
      );
      return rows
          .map(_mapToTotpCredential)
          .whereType<TotpCredential>()
          .toList();
    } catch (e) {
      AppLogger.d('Failed to load dirty TOTP credentials: $e');
      return [];
    }
  }

  Future<TotpCredential?> getTotpCredentialById(
    String id, {
    bool includeDeleted = false,
  }) async {
    if (!isOpen || _database == null) return null;

    try {
      final rows = await _query(
        'totp_credentials',
        where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final credential = _mapToTotpCredential(rows.first);
      if (credential == null) return null;
      return _cleanupOrphanedLinks(credential);
    } catch (e) {
      AppLogger.d('Failed to load TOTP credential by id: $e');
      return null;
    }
  }

  Future<void> saveTotpCredential(
    TotpCredential credential, {
    bool isSyncMerge = false,
  }) async {
    if (!isOpen || _database == null) return;

    TotpCredential itemToSave = credential;

    if (isSyncMerge) {
      itemToSave = await _cleanupOrphanedLinks(credential);
    } else {
      final existingRows = await _query(
        'totp_credentials',
        where: 'id = ?',
        whereArgs: [credential.id],
      );
      final newStamp = Hlc.now(_deviceId);

      if (existingRows.isNotEmpty) {
        final old = _mapToTotpCredential(existingRows.first);
        if (old != null) {
          final labelHlc = credential.label != old.label
              ? newStamp
              : old.labelHlc;
          final configHlc =
              _totpConfigJson(credential.config) != _totpConfigJson(old.config)
              ? newStamp
              : old.configHlc;
          final linksHlc =
              listEquals(credential.linkedAccountIds, old.linkedAccountIds)
              ? old.linksHlc
              : newStamp;

          itemToSave = credential.copyWith(
            labelHlc: labelHlc,
            configHlc: configHlc,
            linksHlc: linksHlc,
            syncStatus: SyncStatus.pendingPush,
            isDeleted: false,
            serverVersion: old.serverVersion,
          );
        }
      } else {
        itemToSave = credential.copyWith(
          labelHlc: newStamp,
          configHlc: newStamp,
          linksHlc: newStamp,
          syncStatus: SyncStatus.pendingPush,
          isDeleted: false,
        );
      }
    }

    await _database!.insert(
      'totp_credentials',
      _totpCredentialRow(itemToSave),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.totpCredential,
        action: StorageAction.save,
        id: itemToSave.id,
      ),
    );
  }

  Future<TotpCredential> _cleanupOrphanedLinks(
    TotpCredential credential,
  ) async {
    if (credential.linkedAccountIds.isEmpty) return credential;

    final validIds = <String>[];
    for (final accountId in credential.linkedAccountIds) {
      if (await _accountExists(accountId)) {
        validIds.add(accountId);
      }
    }

    if (validIds.length != credential.linkedAccountIds.length) {
      AppLogger.d(
        '[Storage] Cleaned up ${credential.linkedAccountIds.length - validIds.length} orphaned link(s) for TOTP ${credential.id}',
      );
      return credential.copyWith(linkedAccountIds: validIds);
    }

    return credential;
  }

  Future<bool> _accountExists(String id) async {
    if (!isOpen || _database == null) return false;
    try {
      final rows = await _database!.rawQuery(
        'SELECT 1 FROM accounts WHERE id = ? AND is_deleted = 0 LIMIT 1',
        [id],
      );
      return rows.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteTotpCredential(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen || _database == null) return;

    final stamp = syncDeleteHlc ?? Hlc.now(_deviceId);

    await _database!.update(
      'totp_credentials',
      {
        'is_deleted': 1,
        'delete_hlc': stamp.toString(),
        'sync_status': SyncStatus.pendingPush.index,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.totpCredential,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<List<QuickNote>> loadQuickNotes({bool includeDeleted = false}) async {
    if (!isOpen || _database == null) return [];
    try {
      final rows = await _query(
        'quick_notes',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'updated_at DESC',
      );
      return rows.map(_mapToQuickNote).whereType<QuickNote>().toList();
    } catch (e) {
      AppLogger.d('Failed to load quick notes: $e');
      return [];
    }
  }

  Future<List<QuickNote>> loadDirtyQuickNotes() async {
    if (!isOpen || _database == null) return [];
    try {
      final rows = await _query(
        'quick_notes',
        where: 'sync_status != ?',
        whereArgs: [SyncStatus.synchronized.index],
        orderBy: 'updated_at DESC',
      );
      return rows.map(_mapToQuickNote).whereType<QuickNote>().toList();
    } catch (e) {
      AppLogger.d('Failed to load dirty quick notes: $e');
      return [];
    }
  }

  Future<QuickNote?> getQuickNoteById(
    String id, {
    bool includeDeleted = false,
  }) async {
    if (!isOpen || _database == null) return null;
    try {
      final rows = await _query(
        'quick_notes',
        where: includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapToQuickNote(rows.first);
    } catch (e) {
      AppLogger.d('Failed to load quick note by id: $e');
      return null;
    }
  }

  Future<void> saveQuickNote(QuickNote note, {bool isSyncMerge = false}) async {
    if (!isOpen || _database == null) return;

    var noteToSave = note;
    if (!isSyncMerge) {
      final existing = await getQuickNoteById(note.id, includeDeleted: true);
      noteToSave = note.copyWith(
        serverVersion: existing?.serverVersion ?? note.serverVersion,
        syncStatus: SyncStatus.pendingPush,
        isDeleted: false,
      );
    }

    await _database!.insert(
      'quick_notes',
      _quickNoteRow(noteToSave),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.quickNote,
        action: StorageAction.save,
        id: noteToSave.id,
      ),
    );
  }

  Future<void> deleteQuickNote(String id, {bool isSyncMerge = false}) async {
    if (!isOpen || _database == null) return;
    await _database!.update(
      'quick_notes',
      {
        'is_deleted': 1,
        'sync_status': isSyncMerge
            ? SyncStatus.synchronized.index
            : SyncStatus.pendingPush.index,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.quickNote,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<int> countAccountsByTemplate(String templateId) async {
    if (!isOpen) return 0;
    try {
      final rows = await _database!.rawQuery(
        'SELECT COUNT(*) AS count FROM accounts WHERE template_id = ? AND is_deleted = 0',
        [templateId],
      );
      return Sqflite.firstIntValue(rows) ?? 0;
    } catch (e) {
      AppLogger.d('Failed to count accounts by template: $e');
      return 0;
    }
  }

  Future<void> saveConflictLogs(List<ConflictLog> logs) async {
    if (!isOpen || logs.isEmpty) return;
    final batch = _database!.batch();
    for (final log in logs) {
      batch.insert(
        'conflict_logs',
        log.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.save,
        id: logs.first.accountId,
      ),
    );
  }

  Future<List<ConflictLog>> getConflictLogs(String accountId) async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'conflict_logs',
        where: 'account_id = ?',
        whereArgs: [accountId],
        orderBy: 'saved_at DESC',
      );
      return rows.map((r) => ConflictLog.fromJson(r)).toList();
    } catch (e) {
      AppLogger.d('Failed to load conflict logs: $e');
      return [];
    }
  }

  Future<void> deleteConflictLog(String logId) async {
    if (!isOpen) return;
    await _database!.delete(
      'conflict_logs',
      where: 'id = ?',
      whereArgs: [logId],
    );
    await _persistAfterMutation();
  }

  Future<void> saveTemplateConflictLogs(List<TemplateConflictLog> logs) async {
    if (!isOpen || logs.isEmpty) return;
    final batch = _database!.batch();
    for (final log in logs) {
      batch.insert(
        'template_conflict_logs',
        log.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _persistAfterMutation();
  }

  Future<List<TemplateConflictLog>> getTemplateConflictLogs([
    String? templateId,
  ]) async {
    if (!isOpen) return [];
    try {
      final rows = templateId == null
          ? await _query('template_conflict_logs', orderBy: 'saved_at DESC')
          : await _query(
              'template_conflict_logs',
              where: 'template_id = ?',
              whereArgs: [templateId],
              orderBy: 'saved_at DESC',
            );
      return rows.map((r) => TemplateConflictLog.fromJson(r)).toList();
    } catch (e) {
      AppLogger.d('Failed to load template conflict logs: $e');
      return [];
    }
  }

  // ── Notification CRUD ──────────────────────────────────────────────

  Future<void> _ensureNotificationsTable() async {
    if (!isOpen) return;
    try {
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          account_id TEXT,
          created_at INTEGER NOT NULL,
          is_read INTEGER DEFAULT 0,
          params TEXT
        )
      ''');
    } catch (e) {
      AppLogger.d('Failed to ensure notifications table: $e');
    }
  }

  Future<List<AppNotification>> loadNotifications() async {
    if (!isOpen) return [];
    try {
      final rows = await _query('notifications', orderBy: 'created_at DESC');
      return rows.map((r) => AppNotification.fromRow(r)).toList();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such table') && msg.contains('notifications')) {
        await _ensureNotificationsTable();
        return [];
      }
      AppLogger.d('Failed to load notifications: $e');
      return [];
    }
  }

  Future<void> saveNotification(AppNotification notification) async {
    if (!isOpen) return;
    try {
      await _database!.insert(
        'notifications',
        notification.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such table') && msg.contains('notifications')) {
        await _ensureNotificationsTable();
        return;
      }
      AppLogger.d('Failed to save notification: $e');
    }
  }

  Future<void> markNotificationRead(String id) async {
    if (!isOpen) return;
    try {
      await _database!.update(
        'notifications',
        {'is_read': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such table') && msg.contains('notifications')) {
        await _ensureNotificationsTable();
        return;
      }
      AppLogger.d('Failed to mark notification read: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (!isOpen) return;
    try {
      await _database!.update('notifications', {
        'is_read': 1,
      }, where: 'is_read = 0');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such table') && msg.contains('notifications')) {
        await _ensureNotificationsTable();
        return;
      }
      AppLogger.d('Failed to mark all notifications read: $e');
    }
  }

  Future<void> deleteNotification(String id) async {
    if (!isOpen) return;
    try {
      await _database!.delete(
        'notifications',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such table') && msg.contains('notifications')) {
        await _ensureNotificationsTable();
        return;
      }
      AppLogger.d('Failed to delete notification: $e');
    }
  }

  Future<int> getUnreadNotificationCount() async {
    if (!isOpen) return 0;
    try {
      final rows = await _database!.rawQuery(
        'SELECT COUNT(*) as cnt FROM notifications WHERE is_read = 0',
      );
      return rows.first['cnt'] as int? ?? 0;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('no such table') && msg.contains('notifications')) {
        await _ensureNotificationsTable();
        return 0;
      }
      return 0;
    }
  }

  Future<void> deleteAllNotifications() async {
    if (!isOpen) return;
    try {
      await _database!.delete('notifications');
    } catch (e) {
      AppLogger.d('Failed to delete all notifications: $e');
    }
  }

  AccountItem? _mapToAccountItem(Map<String, dynamic> row) {
    try {
      final dataStr = row['data'] as String;
      final parsedData = jsonDecode(dataStr);
      final mapData = parsedData is Map
          ? Map<String, dynamic>.from(parsedData)
          : <String, dynamic>{};

      Map<String, dynamic> dataHlcMap = {};
      if (row['data_hlc'] != null && row['data_hlc'].toString().isNotEmpty) {
        final parsedHlcStr = jsonDecode(row['data_hlc'] as String);
        if (parsedHlcStr is Map) {
          dataHlcMap = Map<String, dynamic>.from(parsedHlcStr);
        }
      }

      Map<String, AccountFieldMeta> fieldMeta = {};
      if (row['field_meta'] != null &&
          row['field_meta'].toString().isNotEmpty) {
        final parsedMeta = jsonDecode(row['field_meta'] as String);
        if (parsedMeta is Map) {
          fieldMeta = parsedMeta.map(
            (k, v) => MapEntry(
              k as String,
              AccountFieldMeta.fromJson(Map<String, dynamic>.from(v as Map)),
            ),
          );
        }
      }

      final dummyHlc = Hlc.zero('local');

      return AccountItem(
        id: row['id'] as String,
        name: row['name'] as String,
        email: row['email'] as String? ?? '',
        templateId: row['template_id'] as String,
        templateVersion: row['template_version'] as int? ?? 0,
        data: mapData,
        fieldMeta: fieldMeta,
        createdAt: row['created_at'] as int,
        modifiedAt: row['modified_at'] as int? ?? row['created_at'] as int,
        lastEditedBy: row['last_edited_by'] as String?,
        lastEditedAt: row['modified_at'] as int?,
        nameHlc: row['name_hlc'] != null
            ? Hlc.parse(row['name_hlc'])
            : dummyHlc,
        emailHlc: row['email_hlc'] != null
            ? Hlc.parse(row['email_hlc'])
            : dummyHlc,
        dataHlc: dataHlcMap.map((k, v) => MapEntry(k, Hlc.parse(v.toString()))),
        serverVersion: row['server_version'] as int? ?? 0,
        syncStatus: syncStatusFromJson(row['sync_status']),
        isDeleted: row['is_deleted'] == 1,
        deleteHlc: row['delete_hlc'] != null
            ? Hlc.parse(row['delete_hlc'])
            : null,
        isPinned: row['is_pinned'] == 1,
        pinHlc: row['pin_hlc'] != null ? Hlc.parse(row['pin_hlc']) : null,
      );
    } catch (e) {
      AppLogger.d('Skipping unreadable account row: $e');
      return null;
    }
  }

  Map<String, dynamic> _accountItemToMap(AccountItem item) {
    return {
      'id': item.id,
      'name': item.name,
      'email': item.email,
      'template_id': item.templateId,
      'template_version': item.templateVersion,
      'data': jsonEncode(item.data),
      'field_meta': jsonEncode(
        item.fieldMeta.map((k, v) => MapEntry(k, v.toJson())),
      ),
      'created_at': item.createdAt,
      'modified_at': DateTime.now().millisecondsSinceEpoch,
      'last_edited_by': item.lastEditedBy ?? _deviceId,
      'name_hlc': item.nameHlc.toString(),
      'email_hlc': item.emailHlc.toString(),
      'data_hlc': jsonEncode(
        item.dataHlc.map((k, v) => MapEntry(k, v.toString())),
      ),
      'server_version': item.serverVersion,
      'sync_status': item.syncStatus.index,
      'is_deleted': item.isDeleted ? 1 : 0,
      'delete_hlc': item.deleteHlc?.toString(),
      'is_pinned': item.isPinned ? 1 : 0,
      'pin_hlc': item.pinHlc?.toString(),
    };
  }

  Map<String, dynamic> _templateToMap(AccountTemplate item) {
    return {
      'id': item.templateId,
      'title': item.title,
      'subtitle': item.subTitle,
      'icon_code_point': templateIconStorageValue(item.icon),
      'category': item.category.name,
      'fields': jsonEncode(item.fields.map((f) => f.toJson()).toList()),
      'is_custom': item.isCustom ? 1 : 0,
      'created_at': item.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'modified_at': item.modifiedAt ?? DateTime.now().millisecondsSinceEpoch,
      'last_edited_by': item.lastEditedBy ?? _deviceId,
      'hlc': item.hlc?.toString(),
      'version': item.version,
      'server_version': item.serverVersion,
      'sync_status': item.syncStatus.index,
      'is_deleted': item.isDeleted ? 1 : 0,
      'delete_hlc': item.deleteHlc?.toString(),
      'parent_template_ids':
          item.parentTemplateIds.isEmpty
              ? null
              : jsonEncode(item.parentTemplateIds),
    };
  }

  Map<String, dynamic> _totpCredentialRow(TotpCredential credential) {
    return {
      'id': credential.id,
      'label': credential.label,
      'config': _totpConfigJson(credential.config),
      'linked_account_ids': jsonEncode(credential.linkedAccountIds),
      'created_at': credential.createdAt,
      'modified_at': DateTime.now().millisecondsSinceEpoch,
      'label_hlc': credential.labelHlc.toString(),
      'config_hlc': credential.configHlc.toString(),
      'links_hlc': credential.linksHlc.toString(),
      'server_version': credential.serverVersion,
      'sync_status': credential.syncStatus.index,
      'is_deleted': credential.isDeleted ? 1 : 0,
      'delete_hlc': credential.deleteHlc?.toString(),
    };
  }

  TotpCredential? _mapToTotpCredential(Map<String, dynamic> row) {
    try {
      final configRaw = row['config'] as String;
      final linkedRaw = row['linked_account_ids'] as String? ?? '[]';
      return TotpCredential.fromJson({
        'id': row['id'],
        'label': row['label'],
        'config': jsonDecode(configRaw),
        'linkedAccountIds': jsonDecode(linkedRaw),
        'createdAt': row['created_at'],
        'labelHlc': row['label_hlc'],
        'configHlc': row['config_hlc'],
        'linksHlc': row['links_hlc'],
        'serverVersion': row['server_version'],
        'syncStatus': row['sync_status'],
        'isDeleted': row['is_deleted'],
        'deleteHlc': row['delete_hlc'],
      });
    } catch (e) {
      AppLogger.d('Skipping unreadable TOTP credential row: $e');
      return null;
    }
  }

  Map<String, dynamic> _quickNoteRow(QuickNote note) {
    return {
      'id': note.id,
      'content': note.content,
      'created_at': note.createdAt.millisecondsSinceEpoch,
      'updated_at': note.updatedAt.millisecondsSinceEpoch,
      'server_version': note.serverVersion,
      'sync_status': note.syncStatus.index,
      'is_deleted': note.isDeleted ? 1 : 0,
    };
  }

  QuickNote? _mapToQuickNote(Map<String, dynamic> row) {
    try {
      return QuickNote(
        id: row['id'] as String,
        content: row['content'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at'] as int? ?? 0,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at'] as int? ?? 0,
        ),
        serverVersion: row['server_version'] as int? ?? 0,
        syncStatus: syncStatusFromJson(row['sync_status']),
        isDeleted: row['is_deleted'] == 1,
      );
    } catch (e) {
      AppLogger.d('Skipping unreadable quick note row: $e');
      return null;
    }
  }

  String _totpConfigJson(TotpConfig config) {
    return jsonEncode(config.toJson());
  }

  Future<List<AccountTemplate>> loadCustomTemplates({
    bool includeDeleted = false,
  }) async {
    if (!isOpen) return [];
    try {
      final where = includeDeleted
          ? 'is_custom = ?'
          : 'is_custom = ? AND is_deleted = 0';
      final rows = await _query(
        'templates',
        where: where,
        whereArgs: [1],
        orderBy: 'created_at DESC',
      );
      return rows
          .map((row) => _mapToAccountTemplate(row, isCustom: true))
          .whereType<AccountTemplate>()
          .toList();
    } catch (e) {
      AppLogger.d('Failed to load templates: $e');
      return [];
    }
  }

  /// 加载所有模板记录（内置 + 自定义），默认排除已软删除的条目。
  ///
  /// [includeDeleted] 为 true 时同时返回已删除模板。
  /// 结果按 is_custom DESC, created_at DESC 排序。
  /// 若数据库未打开，返回空列表。
  Future<List<AccountTemplate>> loadAllTemplates({
    bool includeDeleted = false,
  }) async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'templates',
        where: includeDeleted ? null : 'is_deleted = 0',
        orderBy: 'is_custom DESC, created_at DESC',
      );
      return rows
          .map(
            (row) =>
                _mapToAccountTemplate(row, isCustom: row['is_custom'] == 1),
          )
          .whereType<AccountTemplate>()
          .toList();
    } catch (e) {
      AppLogger.d('Failed to load all templates: $e');
      return [];
    }
  }

  Future<List<AccountTemplate>> loadDirtyTemplates() async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'templates',
        where: 'sync_status != ? AND is_custom = 1',
        whereArgs: [SyncStatus.synchronized.index],
      );
      return rows
          .map((row) => _mapToAccountTemplate(row, isCustom: true))
          .whereType<AccountTemplate>()
          .toList();
    } catch (e) {
      AppLogger.d('Failed to load dirty templates: $e');
      return [];
    }
  }

  Future<AccountTemplate?> loadTemplateById(
    String id, {
    bool includeDeleted = false,
  }) async {
    if (!isOpen) return null;
    try {
      final where = includeDeleted ? 'id = ?' : 'id = ? AND is_deleted = 0';
      final rows = await _query(
        'templates',
        where: where,
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _mapToAccountTemplate(
        rows.first,
        isCustom: rows.first['is_custom'] == 1,
      );
    } catch (e) {
      return null;
    }
  }

  /// 保存或更新一条模板记录，自动处理字段级 HLC 与版本号。
  ///
  /// [template] 为要保存的模板数据。
  /// [isSyncMerge] 为 true 时直接写入，跳过本地冲突检测。
  ///
  /// 若数据库未打开，静默返回。
  /// 当本地模板版本比待保存版本更新时，抛出 [TemplateStaleException]。
  Future<void> saveTemplate(
    AccountTemplate template, {
    bool isSyncMerge = false,
  }) async {
    if (!isOpen) return;

    AccountTemplate itemToSave;
    List<TemplateConflictLog> conflictLogs = [];

    if (isSyncMerge) {
      // Caller has already performed CRDT merge; save directly.
      itemToSave = template;
    } else {
      // Validate all template references before saving.
      await _validateTemplateReferences(template);

      final newStamp = _syncClock!.send();
      final existing = await loadTemplateById(template.templateId);
      if (existing != null) {
        if (existing.hlc != null &&
            template.hlc != null &&
            existing.hlc!.compareTo(template.hlc!) > 0) {
          throw TemplateStaleException();
        }
        itemToSave = _stampTemplateChanges(existing, template, newStamp);
      } else {
        itemToSave = template.copyWith(
          hlc: newStamp,
          fields: template.fields
              .map(
                (f) => f.copyWith(
                  labelHlc: newStamp,
                  descriptionHlc: newStamp,
                  attributesHlc: newStamp,
                  orderHlc: newStamp,
                ),
              )
              .toList(),
          syncStatus: SyncStatus.pendingPush,
        );
      }
    }

    await _database!.insert('templates', {
      'id': itemToSave.templateId,
      'title': itemToSave.title,
      'subtitle': itemToSave.subTitle,
      'icon_code_point': templateIconStorageValue(itemToSave.icon),
      'category': itemToSave.category.name,
      'fields': jsonEncode(itemToSave.fields.map((f) => f.toJson()).toList()),
      'is_custom': itemToSave.isCustom ? 1 : 0,
      'created_at':
          itemToSave.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      'modified_at': DateTime.now().millisecondsSinceEpoch,
      'last_edited_by': _deviceId,
      'hlc': itemToSave.hlc?.toString(),
      'version': itemToSave.version,
      'server_version': itemToSave.serverVersion,
      'sync_status': itemToSave.syncStatus.index,
      'is_deleted': itemToSave.isDeleted ? 1 : 0,
      'delete_hlc': itemToSave.deleteHlc?.toString(),
      'parent_template_ids':
          itemToSave.parentTemplateIds.isEmpty
              ? null
              : jsonEncode(itemToSave.parentTemplateIds),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    if (conflictLogs.isNotEmpty) {
      await saveTemplateConflictLogs(conflictLogs);
    }

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.template,
        action: StorageAction.save,
        id: itemToSave.templateId,
      ),
    );
  }

  Future<void> _validateTemplateReferences(AccountTemplate template) async {
    final selfId = template.templateId;

    // 1. Self-reference checks.
    if (template.parentTemplateIds.contains(selfId)) {
      throw TemplateReferenceException(
        'Template "$selfId" cannot inherit from itself.',
      );
    }
    for (final f in template.fields) {
      if (f.attributes.targetTemplateId == selfId) {
        throw TemplateReferenceException(
          'Field "${f.label}" cannot reference its own template as target.',
        );
      }
      if (f.attributes.subTemplateId == selfId) {
        throw TemplateReferenceException(
          'Field "${f.label}" cannot use its own template as sub-form.',
        );
      }
    }

    // 2. Inheritance cycle detection.
    final allTemplates = await loadAllTemplates();
    final parentGraph = <String, List<String>>{};
    final subFormGraph = <String, String?>{};
    for (final t in allTemplates) {
      if (t.isDeleted) continue;
      parentGraph[t.templateId] = t.parentTemplateIds;
      for (final f in t.fields) {
        if (f.attributes.subTemplateId != null) {
          subFormGraph[t.templateId] = f.attributes.subTemplateId;
        }
      }
    }
    // Merge incoming template's data.
    parentGraph[selfId] = template.parentTemplateIds;
    for (final f in template.fields) {
      if (f.attributes.subTemplateId != null) {
        subFormGraph[selfId] = f.attributes.subTemplateId;
      }
    }

    for (final parentId in template.parentTemplateIds) {
      if (TemplateReferenceValidator.wouldCreateInheritanceCycle(
        selfId: selfId,
        candidateId: parentId,
        parentGraph: parentGraph,
      )) {
        throw TemplateReferenceException(
          'Adding "$parentId" as parent of "$selfId" '
          'would create an inheritance cycle.',
        );
      }
    }

    // 3. SubForm recursion detection.
    for (final f in template.fields) {
      if (f.attributes.subTemplateId != null &&
          TemplateReferenceValidator.wouldCreateSubFormRecursion(
            selfId: selfId,
            candidateId: f.attributes.subTemplateId!,
            subFormTargets: subFormGraph,
          )) {
        throw TemplateReferenceException(
          'Field "${f.label}": sub-form template '
          '"${f.attributes.subTemplateId}" would create recursive nesting.',
        );
      }
    }
  }

  AccountTemplate _stampTemplateChanges(
    AccountTemplate existing,
    AccountTemplate updated,
    Hlc stamp,
  ) {
    final newFields = <AccountField>[];
    for (final field in updated.fields) {
      final oldField = existing.fields.cast<AccountField?>().firstWhere(
        (f) => f?.fieldKey == field.fieldKey,
        orElse: () => null,
      );
      if (oldField == null) {
        newFields.add(
          field.copyWith(
            labelHlc: stamp,
            descriptionHlc: stamp,
            attributesHlc: stamp,
            orderHlc: stamp,
          ),
        );
      } else {
        newFields.add(
          field.copyWith(
            labelHlc: field.label != oldField.label ? stamp : oldField.labelHlc,
            descriptionHlc: field.description != oldField.description
                ? stamp
                : oldField.descriptionHlc,
            attributesHlc:
                jsonEncode(field.attributes.toJson()) !=
                    jsonEncode(oldField.attributes.toJson())
                ? stamp
                : oldField.attributesHlc,
            orderHlc: field.order != oldField.order ? stamp : oldField.orderHlc,
          ),
        );
      }
    }
    return updated.copyWith(
      version: existing.version + 1,
      hlc: stamp,
      fields: newFields,
      syncStatus: SyncStatus.pendingPush,
      serverVersion: existing.serverVersion,
    );
  }

  /// 软删除指定 ID 的模板。
  ///
  /// [id] 为模板唯一标识符。
  /// 非同步合并模式下，若该模板仍被账号引用，抛出 [TemplateInUseException]。
  ///
  /// 若数据库未打开，静默返回。
  Future<void> deleteTemplate(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen) return;

    // Reference checks are always performed, even for sync-merge deletes.
    // (Sync deletes shouldn't leave dangling references in the local vault.)
    final allTemplates = await loadAllTemplates();
    final children = allTemplates
        .where((t) => t.parentTemplateIds.contains(id))
        .toList();
    if (children.isNotEmpty) {
      throw TemplateInUseException(
        templateId: id,
        usageCount: 0,
        customMessage:
            'Cannot delete: inherited by ${children.map((t) => t.title).join(", ")}',
      );
    }

    for (final t in allTemplates) {
      for (final f in t.fields) {
        if (f.attributes.targetTemplateId == id) {
          throw TemplateInUseException(
            templateId: id,
            usageCount: 0,
            customMessage:
                'Cannot delete: referenced by field "${f.label}" '
                'in template "${t.title}"',
          );
        }
        if (f.attributes.subTemplateId == id) {
          throw TemplateInUseException(
            templateId: id,
            usageCount: 0,
            customMessage:
                'Cannot delete: used as sub-form in field "${f.label}" '
                'of template "${t.title}"',
          );
        }
      }
    }

    // Scan sub-form data in accounts for dangling references.
    final subFormCount = await _countSubFormItemsByTemplate(id);
    if (subFormCount > 0) {
      throw TemplateInUseException(
        templateId: id,
        usageCount: 0,
        customMessage:
            'Cannot delete: $subFormCount sub-form items in accounts '
            'still use this template.',
      );
    }

    if (!isSyncMerge) {
      final usageCount = await countAccountsByTemplate(id);
      if (usageCount > 0) {
        throw TemplateInUseException(templateId: id, usageCount: usageCount);
      }
    }

    Hlc stamp = syncDeleteHlc ?? _syncClock!.send();

    await _database!.update(
      'templates',
      {
        'is_deleted': 1,
        'delete_hlc': stamp.toString(),
        'sync_status': SyncStatus.pendingPush.index,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.template,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  AccountTemplate? _mapToAccountTemplate(
    Map<String, dynamic> row, {
    required bool isCustom,
  }) {
    try {
      final iconCodePoint = row['icon_code_point'] as int?;
      return AccountTemplate(
        templateId: row['id'] as String,
        version: row['version'] as int? ?? 1,
        title: row['title'] as String,
        subTitle: row['subtitle'] as String? ?? '',
        iconCodePoint: iconCodePoint,
        category: templateCategoryFromString(row['category'] as String?),
        fields: (jsonDecode(row['fields'] as String) as List)
            .map(
              (field) => AccountField.fromJson(field as Map<String, dynamic>),
            )
            .toList(),
        parentTemplateIds: _parseParentTemplateIds(
          row['parent_template_ids'] as String?,
        ),
        isCustom: isCustom,
        createdAt: row['created_at'] as int?,
        modifiedAt: row['modified_at'] as int?,
        lastEditedBy: row['last_edited_by'] as String?,
        lastEditedAt: row['modified_at'] as int?,
        hlc: row['hlc'] != null ? Hlc.parse(row['hlc'] as String) : null,
        serverVersion: row['server_version'] as int? ?? 0,
        syncStatus: syncStatusFromJson(
          row['sync_status'],
          fallback: SyncStatus.synchronized,
        ),
        isDeleted: row['is_deleted'] == 1,
        deleteHlc: row['delete_hlc'] != null
            ? Hlc.parse(row['delete_hlc'] as String)
            : null,
      );
    } catch (e) {
      AppLogger.d('Skipping unreadable template row: $e');
      return null;
    }
  }

  /// Counts how many sub-form items across all accounts use [templateId]
  /// as their [AccountFieldType.subForm] template.
  Future<int> _countSubFormItemsByTemplate(String templateId) async {
    final accounts = await loadAccounts(includeDeleted: false);
    if (accounts.isEmpty) return 0;

    // Find all templates that have a subForm field pointing to templateId.
    final allTemplates = await loadAllTemplates();
    final subFormFieldKeys = <String, Set<String>>{};
    for (final t in allTemplates) {
      for (final f in t.fields) {
        if (f.attributes.subTemplateId == templateId) {
          subFormFieldKeys.putIfAbsent(t.templateId, () => {}).add(f.fieldKey);
        }
      }
    }

    if (subFormFieldKeys.isEmpty) return 0;

    var count = 0;
    for (final account in accounts) {
      final keys = subFormFieldKeys[account.templateId];
      if (keys == null) continue;
      for (final key in keys) {
        final raw = account.data[key];
        if (raw == null || raw.toString().isEmpty) continue;
        try {
          final items = (jsonDecode(raw.toString()) as List);
          count += items.length;
        } catch (_) {}
      }
    }
    return count;
  }

  List<String> _parseParentTemplateIds(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  /// 记录一条本地同步变更到 outbox（local_sync_changes 表）。
  ///
  /// 该方法会自动合并同一实体的连续变更（create → update → delete 的 coalesce 规则）。
  /// 新生成的变更状态为 [LocalSyncStatus.pendingReview]，等待用户审批后推送到服务器。
  ///
  /// [vaultId] 当前保险库 ID。
  /// [entityType] / [entityId] / [action] 描述变更对象与操作类型。
  /// [beforeSnapshot] / [afterSnapshot] 用于生成 diff 与展示给用户。
  /// [skipIfUnchanged] 为 true 时，若快照与现有记录完全一致则跳过写入。
  ///
  /// 若数据库未打开，静默返回。
  Future<void> recordLocalSyncChange({
    required String vaultId,
    required LocalSyncEntityType entityType,
    required String entityId,
    required LocalSyncAction action,
    required String title,
    required Map<String, dynamic>? beforeSnapshot,
    required Map<String, dynamic>? afterSnapshot,
    required int baseServerVersion,
    bool skipIfUnchanged = false,
  }) async {
    if (!isOpen) return;

    try {
      final existingRows = await _query(
        'local_sync_changes',
        where:
            'vault_id = ? AND entity_type = ? AND entity_id = ? AND status IN (${_coalescableStatusPlaceholders()})',
        whereArgs: [
          vaultId,
          entityType.name,
          entityId,
          ..._coalescableLocalSyncStatusNames,
        ],
        orderBy: 'created_at ASC',
        limit: 1,
      );
      final existing = existingRows.isEmpty
          ? null
          : LocalSyncChange.fromDatabaseRow(existingRows.first);

      final originalBefore = existing?.beforeSnapshot ?? beforeSnapshot;
      final effectiveAction = _coalesceLocalSyncAction(
        existing: existing,
        nextAction: action,
        originalBefore: originalBefore,
      );
      final beforeJson = originalBefore == null
          ? null
          : jsonEncode(originalBefore);
      final afterJson = afterSnapshot == null
          ? null
          : jsonEncode(afterSnapshot);

      if (existing?.action == LocalSyncAction.create &&
          action == LocalSyncAction.delete) {
        await deleteLocalSyncChange(existing!.id);
        if (entityType == LocalSyncEntityType.account) {
          await hardDeleteAccount(entityId);
        } else if (entityType == LocalSyncEntityType.template) {
          await hardDeleteTemplate(entityId);
        } else if (entityType == LocalSyncEntityType.totpCredential) {
          await hardDeleteTotpCredential(entityId);
        } else {
          await hardDeleteQuickNote(entityId);
        }
        return;
      }
      if (skipIfUnchanged &&
          existing != null &&
          existing.action == effectiveAction &&
          existing.beforeJson == beforeJson &&
          existing.afterJson == afterJson) {
        return;
      }

      final changedFields = _changedReviewFields(
        before: originalBefore,
        after: afterSnapshot,
        action: effectiveAction,
      );
      if (effectiveAction == LocalSyncAction.update && changedFields.isEmpty) {
        if (existing != null) {
          await deleteLocalSyncChange(existing.id);
        }
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final idStamp = DateTime.now().microsecondsSinceEpoch;
      final id =
          existing?.id ??
          'local-${vaultId.hashCode}-${entityType.name}-$entityId-$idStamp';

      await _database!.insert('local_sync_changes', {
        'id': id,
        'vault_id': vaultId,
        'entity_type': entityType.name,
        'entity_id': entityId,
        'action': effectiveAction.name,
        'title': title.trim().isEmpty ? entityId : title.trim(),
        'before_json': beforeJson,
        'after_json': afterJson,
        'diff_json': jsonEncode({'changed_fields': changedFields}),
        'base_server_version': existing?.baseServerVersion ?? baseServerVersion,
        'status': LocalSyncStatus.pendingReview.name,
        'created_at': existing?.createdAt ?? now,
        'updated_at': now,
        'approved_at': null,
        'pushed_at': null,
        'error_message': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await _persistAfterMutation();
      _notifyChange(
        StorageChangeEvent(
          type: StorageItemType.localSyncChange,
          action: StorageAction.save,
          id: id,
        ),
      );
    } catch (e) {
      AppLogger.d('Failed to record local sync change: $e');
      rethrow;
    }
  }

  /// Creates an approved [LocalSyncChange] for LAN sync merges.
  ///
  /// Unlike [recordLocalSyncChange] which creates a pendingReview entry,
  /// this directly inserts an approved entry so the item is eligible for
  /// server push without user review.
  Future<void> createApprovedLocalSyncChange({
    required String vaultId,
    required LocalSyncEntityType entityType,
    required String entityId,
    required String title,
    int baseServerVersion = 0,
  }) async {
    if (!isOpen) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final idStamp = DateTime.now().microsecondsSinceEpoch;
      final id =
          'lan-${vaultId.hashCode}-${entityType.name}-$entityId-$idStamp';

      await _database!.insert('local_sync_changes', {
        'id': id,
        'vault_id': vaultId,
        'entity_type': entityType.name,
        'entity_id': entityId,
        'action': LocalSyncAction.update.name,
        'title': title.trim().isEmpty ? entityId : title.trim(),
        'before_json': null,
        'after_json': null,
        'diff_json': jsonEncode({'changed_fields': []}),
        'base_server_version': baseServerVersion,
        'status': LocalSyncStatus.approved.name,
        'created_at': now,
        'updated_at': now,
        'approved_at': now,
        'pushed_at': null,
        'error_message': null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      AppLogger.d('Failed to create approved local sync change: $e');
      rethrow;
    }
  }

  Future<void> ensurePendingSyncOutboxEntries(String vaultId) async {
    if (!isOpen) return;
    try {
      await _recoverInterruptedLocalSyncPushes(vaultId);

      final pendingAccounts = await loadPendingSyncAccounts();
      for (final account in pendingAccounts) {
        await recordLocalSyncChange(
          vaultId: vaultId,
          entityType: LocalSyncEntityType.account,
          entityId: account.id,
          action: account.isDeleted
              ? LocalSyncAction.delete
              : account.serverVersion == 0
              ? LocalSyncAction.create
              : LocalSyncAction.update,
          title: account.name,
          beforeSnapshot: null,
          afterSnapshot: account.toJson(),
          baseServerVersion: account.serverVersion,
          skipIfUnchanged: true,
        );
      }

      final dirtyTemplates = await loadDirtyTemplates();
      for (final template in dirtyTemplates) {
        await recordLocalSyncChange(
          vaultId: vaultId,
          entityType: LocalSyncEntityType.template,
          entityId: template.templateId,
          action: template.isDeleted
              ? LocalSyncAction.delete
              : template.serverVersion == 0
              ? LocalSyncAction.create
              : LocalSyncAction.update,
          title: template.title,
          beforeSnapshot: null,
          afterSnapshot: template.toJson(),
          baseServerVersion: template.serverVersion,
          skipIfUnchanged: true,
        );
      }

      final dirtyTotpCredentials = await loadDirtyTotpCredentials();
      for (final credential in dirtyTotpCredentials) {
        await recordLocalSyncChange(
          vaultId: vaultId,
          entityType: LocalSyncEntityType.totpCredential,
          entityId: credential.id,
          action: credential.isDeleted
              ? LocalSyncAction.delete
              : credential.serverVersion == 0
              ? LocalSyncAction.create
              : LocalSyncAction.update,
          title: credential.displayLabel,
          beforeSnapshot: null,
          afterSnapshot: credential.toJson(),
          baseServerVersion: credential.serverVersion,
          skipIfUnchanged: true,
        );
      }

      final dirtyQuickNotes = await loadDirtyQuickNotes();
      for (final note in dirtyQuickNotes) {
        await recordLocalSyncChange(
          vaultId: vaultId,
          entityType: LocalSyncEntityType.quickNote,
          entityId: note.id,
          action: note.isDeleted
              ? LocalSyncAction.delete
              : note.serverVersion == 0
              ? LocalSyncAction.create
              : LocalSyncAction.update,
          title: note.title,
          beforeSnapshot: null,
          afterSnapshot: note.toJson(),
          baseServerVersion: note.serverVersion,
          skipIfUnchanged: true,
        );
      }
    } catch (e) {
      AppLogger.d('Failed to ensure pending sync outbox entries: $e');
    }
  }

  Future<void> refreshOpenLocalSyncChangeBaseVersion({
    required String vaultId,
    required LocalSyncEntityType entityType,
    required String entityId,
    required int baseServerVersion,
  }) async {
    if (!isOpen) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = await _database!.update(
      'local_sync_changes',
      {'base_server_version': baseServerVersion, 'updated_at': now},
      where:
          'vault_id = ? AND entity_type = ? AND entity_id = ? AND status IN (${_coalescableStatusPlaceholders()})',
      whereArgs: [
        vaultId,
        entityType.name,
        entityId,
        ..._coalescableLocalSyncStatusNames,
      ],
    );
    if (updated == 0) return;

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.localSyncChange,
        action: StorageAction.save,
      ),
    );
  }

  Future<List<LocalSyncChange>> loadOpenLocalSyncChanges({
    required String vaultId,
  }) async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'local_sync_changes',
        where: 'vault_id = ? AND status IN (${_openStatusPlaceholders()})',
        whereArgs: [vaultId, ..._openLocalSyncStatusNames],
        orderBy: 'updated_at DESC',
      );
      return rows.map(LocalSyncChange.fromDatabaseRow).toList();
    } catch (e) {
      AppLogger.d('Failed to load local sync changes: $e');
      return [];
    }
  }

  Future<List<LocalSyncChange>> loadApprovedLocalSyncChanges({
    required String vaultId,
  }) async {
    if (!isOpen) return [];
    try {
      final rows = await _query(
        'local_sync_changes',
        where: 'vault_id = ? AND status = ?',
        whereArgs: [vaultId, LocalSyncStatus.approved.name],
        orderBy: 'approved_at ASC',
      );
      return rows.map(LocalSyncChange.fromDatabaseRow).toList();
    } catch (e) {
      AppLogger.d('Failed to load approved local sync changes: $e');
      return [];
    }
  }

  Future<LocalSyncChange?> getLocalSyncChange(String id) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'local_sync_changes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return LocalSyncChange.fromDatabaseRow(rows.first);
    } catch (e) {
      AppLogger.d('Failed to load local sync change: $e');
      return null;
    }
  }

  Future<bool> hasOpenLocalSyncChanges(String vaultId) async {
    if (!isOpen) return false;
    try {
      final rows = await _database!.rawQuery(
        'SELECT COUNT(*) AS count FROM local_sync_changes WHERE vault_id = ? AND status IN (${_openStatusPlaceholders()})',
        [vaultId, ..._openLocalSyncStatusNames],
      );
      return (Sqflite.firstIntValue(rows) ?? 0) > 0;
    } catch (e) {
      AppLogger.d('Failed to check open local sync changes: $e');
      return false;
    }
  }

  Future<void> approveLocalSyncChanges({
    required String vaultId,
    Iterable<String>? ids,
  }) async {
    if (!isOpen) return;
    final idList = ids?.toList(growable: false) ?? const <String>[];
    if (ids != null && idList.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final where = idList.isEmpty
        ? 'vault_id = ? AND status IN (?, ?, ?)'
        : 'vault_id = ? AND id IN (${List.filled(idList.length, '?').join(', ')}) AND status IN (?, ?, ?)';
    final whereArgs = <Object?>[
      vaultId,
      if (idList.isNotEmpty) ...idList,
      LocalSyncStatus.pendingReview.name,
      LocalSyncStatus.failed.name,
      LocalSyncStatus.conflict.name,
    ];

    await _database!.update(
      'local_sync_changes',
      {
        'status': LocalSyncStatus.approved.name,
        'approved_at': now,
        'updated_at': now,
        'error_message': null,
      },
      where: where,
      whereArgs: whereArgs,
    );
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.localSyncChange,
        action: StorageAction.save,
      ),
    );
  }

  Future<void> markLocalSyncChangesPushing(Iterable<String> ids) {
    return _updateLocalSyncChangeStatus(
      ids,
      LocalSyncStatus.pushing,
      fromStatuses: const [LocalSyncStatus.approved],
    );
  }

  Future<void> markLocalSyncChangesPushed(Iterable<String> ids) {
    return _updateLocalSyncChangeStatus(
      ids,
      LocalSyncStatus.pushed,
      terminal: true,
      fromStatuses: const [LocalSyncStatus.pushing],
    );
  }

  Future<void> markLocalSyncChangesFailed(
    Iterable<String> ids,
    String errorMessage,
  ) {
    return _updateLocalSyncChangeStatus(
      ids,
      LocalSyncStatus.failed,
      errorMessage: errorMessage,
      fromStatuses: const [LocalSyncStatus.pushing],
    );
  }

  Future<void> markLocalSyncChangesConflict(
    Iterable<String> ids,
    String errorMessage,
  ) {
    return _updateLocalSyncChangeStatus(
      ids,
      LocalSyncStatus.conflict,
      errorMessage: errorMessage,
      fromStatuses: const [LocalSyncStatus.pushing],
    );
  }

  Future<void> deleteLocalSyncChange(String id) async {
    if (!isOpen) return;
    await _database!.delete(
      'local_sync_changes',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.localSyncChange,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<void> hardDeleteAccount(String id) async {
    if (!isOpen) return;
    await _database!.delete('accounts', where: 'id = ?', whereArgs: [id]);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<void> hardDeleteTemplate(String id) async {
    if (!isOpen) return;
    await _database!.delete('templates', where: 'id = ?', whereArgs: [id]);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.template,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<void> hardDeleteTotpCredential(String id) async {
    if (!isOpen || _database == null) return;
    await _database!.delete(
      'totp_credentials',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.totpCredential,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<void> hardDeleteQuickNote(String id) async {
    if (!isOpen || _database == null) return;
    await _database!.delete('quick_notes', where: 'id = ?', whereArgs: [id]);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.quickNote,
        action: StorageAction.delete,
        id: id,
      ),
    );
  }

  Future<void> clearLocalSyncChanges(String vaultId) async {
    if (!isOpen) return;
    await _database!.delete(
      'local_sync_changes',
      where: 'vault_id = ?',
      whereArgs: [vaultId],
    );
    await _persistAfterMutation();
  }

  Future<void> markAllSynchronizedItemsAsPendingPush() async {
    if (!isOpen) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _database!.update(
      'accounts',
      {'sync_status': SyncStatus.pendingPush.index, 'modified_at': now},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.synchronized.index],
    );

    await _database!.update(
      'templates',
      {'sync_status': SyncStatus.pendingPush.index, 'created_at': now},
      where: 'sync_status = ? AND is_custom = 1',
      whereArgs: [SyncStatus.synchronized.index],
    );

    await _database!.update(
      'totp_credentials',
      {'sync_status': SyncStatus.pendingPush.index, 'modified_at': now},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.synchronized.index],
    );

    await _database!.update(
      'quick_notes',
      {'sync_status': SyncStatus.pendingPush.index, 'updated_at': now},
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.synchronized.index],
    );

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.account,
        action: StorageAction.save,
      ),
    );
  }

  Future<void> _updateLocalSyncChangeStatus(
    Iterable<String> ids,
    LocalSyncStatus status, {
    bool terminal = false,
    String? errorMessage,
    Iterable<LocalSyncStatus>? fromStatuses,
  }) async {
    if (!isOpen) return;
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) return;

    final fromStatusList = fromStatuses?.toList(growable: false);
    final statusGuard = fromStatusList == null || fromStatusList.isEmpty
        ? ''
        : ' AND status IN (${List.filled(fromStatusList.length, '?').join(', ')})';
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = await _database!.update(
      'local_sync_changes',
      {
        'status': status.name,
        'updated_at': now,
        'pushed_at': terminal ? now : null,
        'error_message': errorMessage,
      },
      where:
          'id IN (${List.filled(idList.length, '?').join(', ')})$statusGuard',
      whereArgs: [
        ...idList,
        if (fromStatusList != null)
          ...fromStatusList.map((status) => status.name),
      ],
    );
    if (updated == 0) return;

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.localSyncChange,
        action: StorageAction.save,
      ),
    );
  }

  List<String> get _openLocalSyncStatusNames => const [
    'pendingReview',
    'approved',
    'pushing',
    'failed',
    'conflict',
  ];

  List<String> get _coalescableLocalSyncStatusNames => const [
    'pendingReview',
    'approved',
    'failed',
    'conflict',
  ];

  String _openStatusPlaceholders() {
    return List.filled(_openLocalSyncStatusNames.length, '?').join(', ');
  }

  String _coalescableStatusPlaceholders() {
    return List.filled(_coalescableLocalSyncStatusNames.length, '?').join(', ');
  }

  Future<void> _recoverInterruptedLocalSyncPushes(String vaultId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = await _database!.update(
      'local_sync_changes',
      {
        'status': LocalSyncStatus.failed.name,
        'updated_at': now,
        'pushed_at': null,
        'error_message':
            'Push was interrupted before acknowledgement. Review and push again.',
      },
      where: 'vault_id = ? AND status = ?',
      whereArgs: [vaultId, LocalSyncStatus.pushing.name],
    );
    if (updated == 0) return;

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.localSyncChange,
        action: StorageAction.save,
      ),
    );
  }

  LocalSyncAction _coalesceLocalSyncAction({
    required LocalSyncChange? existing,
    required LocalSyncAction nextAction,
    required Map<String, dynamic>? originalBefore,
  }) {
    if (nextAction == LocalSyncAction.delete) {
      return LocalSyncAction.delete;
    }
    if (existing?.action == LocalSyncAction.create) {
      return LocalSyncAction.create;
    }
    if (nextAction == LocalSyncAction.create) {
      return LocalSyncAction.create;
    }
    return LocalSyncAction.update;
  }

  List<String> _changedReviewFields({
    required Map<String, dynamic>? before,
    required Map<String, dynamic>? after,
    required LocalSyncAction action,
  }) {
    switch (action) {
      case LocalSyncAction.create:
        return const ['record.created'];
      case LocalSyncAction.delete:
        return const ['record.deleted'];
      case LocalSyncAction.update:
        if (before == null || after == null) {
          return const ['record.updated'];
        }
        final changed = <String>{};
        for (final key in {...before.keys, ...after.keys}) {
          if (_reviewIgnoredSnapshotKeys.contains(key)) continue;
          final beforeValue = before[key];
          final afterValue = after[key];
          if (key == 'data' && beforeValue is Map && afterValue is Map) {
            for (final fieldKey in {...beforeValue.keys, ...afterValue.keys}) {
              if (beforeValue[fieldKey] != afterValue[fieldKey]) {
                changed.add('data.$fieldKey');
              }
            }
            continue;
          }
          if (jsonEncode(beforeValue) != jsonEncode(afterValue)) {
            changed.add(key);
          }
        }
        return changed.toList()..sort();
    }
  }

  static const Set<String> _reviewIgnoredSnapshotKeys = {
    'nameHlc',
    'emailHlc',
    'dataHlc',
    'labelHlc',
    'configHlc',
    'linksHlc',
    'hlc',
    'syncStatus',
    'serverVersion',
    'isDeleted',
    'deleteHlc',
  };

  Future<String?> getSetting(String key) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e) {
      AppLogger.d('Failed to load setting: $key, error: $e');
      return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    if (!isOpen) return;
    await _database!.insert('settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.setting,
        action: StorageAction.save,
        id: key,
      ),
    );
  }

  /// Commits a batch of merged items from LAN sync in a single transaction.
  ///
  /// For each item:
  /// - Saves via [saveAccount]/[saveTemplate]/[saveTotpCredential] with
  ///   [isSyncMerge]=true to skip HLC stamping and outbox recording.
  /// - If [markForServerPush] is true, records an approved
  ///   [LocalSyncChange] so the item is eligible for server push.
  ///
  /// The [items] list contains tuples of (type, payload).
  /// Returns the number of items successfully committed.
  Future<int> commitLanSyncBatch({
    required String vaultId,
    required List<({LocalSyncEntityType type, Map<String, dynamic> payload})>
    items,
    required bool markForServerPush,
  }) async {
    if (!isOpen || items.isEmpty) return 0;

    var committedCount = 0;
    await _database!.transaction((txn) async {
      for (final item in items) {
        try {
          final payload = item.payload;
          switch (item.type) {
            case LocalSyncEntityType.account:
              final account = AccountItem.fromJson(payload);
              await txn.insert(
                'accounts',
                _accountItemToMap(account),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              if (markForServerPush) {
                await _insertApprovedChange(
                  txn: txn,
                  vaultId: vaultId,
                  entityType: LocalSyncEntityType.account,
                  entityId: account.id,
                  title: account.name,
                );
              }
            case LocalSyncEntityType.template:
              final template = AccountTemplate.fromJson(payload);
              await txn.insert(
                'templates',
                _templateToMap(template),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              if (markForServerPush) {
                await _insertApprovedChange(
                  txn: txn,
                  vaultId: vaultId,
                  entityType: LocalSyncEntityType.template,
                  entityId: template.templateId,
                  title: template.title,
                );
              }
            case LocalSyncEntityType.totpCredential:
              final totp = TotpCredential.fromJson(payload);
              await txn.insert(
                'totp_credentials',
                _totpCredentialRow(totp),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              if (markForServerPush) {
                await _insertApprovedChange(
                  txn: txn,
                  vaultId: vaultId,
                  entityType: LocalSyncEntityType.totpCredential,
                  entityId: totp.id,
                  title: totp.label,
                );
              }
            case LocalSyncEntityType.quickNote:
              final note = QuickNote.fromJson(payload);
              await txn.insert(
                'quick_notes',
                _quickNoteRow(note),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              if (markForServerPush) {
                await _insertApprovedChange(
                  txn: txn,
                  vaultId: vaultId,
                  entityType: LocalSyncEntityType.quickNote,
                  entityId: note.id,
                  title: note.title,
                );
              }
          }
          committedCount++;
        } catch (e) {
          AppLogger.d('commitLanSyncBatch item failed: $e');
          // Continue with remaining items in the batch.
        }
      }
    });

    // Notify listeners once after the transaction.
    // Use a generic notification so all entity types trigger reloads.
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.quickNote,
        action: StorageAction.save,
      ),
    );
    await _persistAfterMutation();

    return committedCount;
  }

  Future<void> _insertApprovedChange({
    required Transaction txn,
    required String vaultId,
    required LocalSyncEntityType entityType,
    required String entityId,
    required String title,
    int baseServerVersion = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final idStamp = DateTime.now().microsecondsSinceEpoch;
    final id = 'lan-$vaultId-${entityType.name}-$entityId-$idStamp';

    await txn.insert('local_sync_changes', {
      'id': id,
      'vault_id': vaultId,
      'entity_type': entityType.name,
      'entity_id': entityId,
      'action': LocalSyncAction.update.name,
      'title': title.trim().isEmpty ? entityId : title.trim(),
      'before_json': null,
      'after_json': null,
      'diff_json': jsonEncode({'changed_fields': []}),
      'base_server_version': baseServerVersion,
      'status': LocalSyncStatus.approved.name,
      'created_at': now,
      'updated_at': now,
      'approved_at': now,
      'pushed_at': null,
      'error_message': null,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  void _notifyChange(StorageChangeEvent event) {
    _changeController.add(event);
  }
}

class StorageChangeEvent {
  final StorageItemType type;
  final StorageAction action;
  final String? id;

  StorageChangeEvent({required this.type, required this.action, this.id});
}

enum StorageAction { save, update, delete }

class StorageOpenException implements Exception {
  final String originalError;
  final String? backupPath;

  const StorageOpenException({required this.originalError, this.backupPath});

  @override
  String toString() {
    if (backupPath == null) {
      return 'StorageOpenException(originalError: $originalError)';
    }
    return 'StorageOpenException(originalError: $originalError, backupPath: $backupPath)';
  }
}

class TemplateInUseException implements Exception {
  final String templateId;
  final int usageCount;
  final String? customMessage;

  const TemplateInUseException({
    required this.templateId,
    required this.usageCount,
    this.customMessage,
  });

  @override
  String toString() =>
      customMessage ??
      'TemplateInUseException(templateId: $templateId, usageCount: $usageCount)';
}

class TemplateStaleException implements Exception {
  const TemplateStaleException();

  @override
  String toString() =>
      'TemplateStaleException: Template has been updated by sync. Please reload and retry.';
}

class TemplateReferenceException implements Exception {
  final String message;
  const TemplateReferenceException(this.message);

  @override
  String toString() => 'TemplateReferenceException: $message';
}
