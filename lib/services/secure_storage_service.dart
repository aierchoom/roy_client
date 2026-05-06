import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:secret_roy/core/app_logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/hlc.dart';
import '../models/local_sync_change.dart';
import '../models/totp_credential.dart';
import '../sync/crdt_merge_engine.dart';
import 'database_file_cipher.dart';
import 'totp_service.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

enum StorageItemType {
  account,
  template,
  totpCredential,
  setting,
  localSyncChange,
}

class SecureStorageService {
  static const String _databaseName = 'secret_roy_vault.db';
  static const String _encryptedDatabaseName = 'secret_roy_vault.db.enc';
  static const String _workingDatabaseName = 'secret_roy_vault.runtime.db';
  static const int _databaseVersion = 6;

  DatabaseFileCipher? _databaseCipher;

  Database? _database;
  StreamController<StorageChangeEvent> _changeController =
      StreamController<StorageChangeEvent>.broadcast();

  String _deviceId = 'local';
  String? _encryptedDatabasePath;
  String? _workingDatabasePath;
  String? _legacyDatabasePath;

  SecureStorageService({DatabaseFileCipher? databaseCipher})
    : _databaseCipher = databaseCipher;

  Stream<StorageChangeEvent> get onChange => _changeController.stream;
  bool get isOpen => _database?.isOpen ?? false;

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

  Future<void> initialize({String deviceId = 'local'}) async {
    _deviceId = deviceId;
    if (_changeController.isClosed) {
      _changeController = StreamController<StorageChangeEvent>.broadcast();
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final temporaryDirectory = await getTemporaryDirectory();
    _legacyDatabasePath = join(documentsDirectory.path, _databaseName);
    _encryptedDatabasePath = join(
      documentsDirectory.path,
      _encryptedDatabaseName,
    );
    _workingDatabasePath = join(
      temporaryDirectory.path,
      'secret_roy',
      _workingDatabaseName,
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
      await _deleteWorkingDatabase();
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

  Future<void> close({bool dispose = false}) async {
    final hadOpenDatabase = isOpen;
    if (hadOpenDatabase) {
      await _checkpointRuntimeDatabase();
    }

    await _database?.close();
    _database = null;

    if (hadOpenDatabase) {
      await _persistEncryptedDatabase(databaseIsOpen: false);
      await _deleteWorkingDatabase();
    }

    if (dispose && !_changeController.isClosed) {
      await _changeController.close();
    }
  }

  Future<bool> isDatabaseInitialized() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = join(documentsDirectory.path, _encryptedDatabaseName);
    return File(databasePath).existsSync();
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final temporaryDirectory = await getTemporaryDirectory();
    _legacyDatabasePath = join(documentsDirectory.path, _databaseName);
    _encryptedDatabasePath = join(
      documentsDirectory.path,
      _encryptedDatabaseName,
    );
    _workingDatabasePath = join(
      temporaryDirectory.path,
      'secret_roy',
      _workingDatabaseName,
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
      final itemToSave = account.copyWith(syncStatus: SyncStatus.synchronized);
      batch.insert('accounts', {
        'id': itemToSave.id,
        'name': itemToSave.name,
        'email': itemToSave.email,
        'template_id': itemToSave.templateId,
        'data': jsonEncode(itemToSave.data),
        'created_at': itemToSave.createdAt,
        'modified_at': DateTime.now().millisecondsSinceEpoch,
        'name_hlc': itemToSave.nameHlc.toString(),
        'email_hlc': itemToSave.emailHlc.toString(),
        'data_hlc': jsonEncode(
          itemToSave.dataHlc.map((k, v) => MapEntry(k, v.toString())),
        ),
        'server_version': itemToSave.serverVersion,
        'sync_status': itemToSave.syncStatus.index,
        'is_deleted': itemToSave.isDeleted ? 1 : 0,
        'delete_hlc': itemToSave.deleteHlc?.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    for (final credential in totpCredentials) {
      final itemToSave = credential.copyWith(
        syncStatus: SyncStatus.synchronized,
      );
      batch.insert(
        'totp_credentials',
        _totpCredentialRow(itemToSave),
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
    final documentsDirectory = await getApplicationDocumentsDirectory();
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
      await backupFile.rename(targetFile.path);
    }

    if (targetFile.existsSync() && tempFile.existsSync()) {
      await tempFile.delete();
    }

    if (targetFile.existsSync() && backupFile.existsSync()) {
      await backupFile.delete();
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

  Future<void> _writeFileAtomically(String targetPath, Uint8List bytes) async {
    await Directory(dirname(targetPath)).create(recursive: true);

    final targetFile = File(targetPath);
    final tempFile = File('$targetPath.tmp');
    final backupFile = File('$targetPath.bak');

    if (tempFile.existsSync()) {
      await tempFile.delete();
    }
    await tempFile.writeAsBytes(bytes, flush: true);

    if (backupFile.existsSync()) {
      await backupFile.delete();
    }
    if (targetFile.existsSync()) {
      await targetFile.rename(backupFile.path);
    }

    try {
      await tempFile.rename(targetPath);
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
    } catch (_) {
      if (backupFile.existsSync() && !targetFile.existsSync()) {
        await backupFile.rename(targetPath);
      }
      rethrow;
    } finally {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
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
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        modified_at INTEGER NOT NULL,
        name_hlc TEXT,
        email_hlc TEXT,
        data_hlc TEXT,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT
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
        hlc TEXT,
        server_version INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0,
        delete_hlc TEXT
      )
    ''');

    await _createTotpCredentialsTable(db);

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await _createLocalSyncChangesTable(db);

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
      Hlc newStamp = Hlc.now(_deviceId);

      if (existingRows.isNotEmpty) {
        final old = _mapToAccountItem(existingRows.first);
        if (old != null) {
          final nHlc = account.name != old.name ? newStamp : old.nameHlc;
          final eHlc = account.email != old.email ? newStamp : old.emailHlc;

          Map<String, Hlc> dHlc = Map.from(old.dataHlc);
          account.data.forEach((k, v) {
            if (old.data[k] != v) {
              dHlc[k] = newStamp;
            }
          });

          itemToSave = account.copyWith(
            nameHlc: nHlc,
            emailHlc: eHlc,
            dataHlc: dHlc,
            syncStatus: SyncStatus.pendingPush,
            isDeleted: false,
            serverVersion: old.serverVersion,
          );
        }
      } else {
        // Completely new account being saved
        Map<String, Hlc> dHlc = {};
        account.data.forEach((k, v) {
          dHlc[k] = newStamp;
        });
        itemToSave = account.copyWith(
          nameHlc: newStamp,
          emailHlc: newStamp,
          dataHlc: dHlc,
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
      'data': jsonEncode(itemToSave.data),
      'created_at': itemToSave.createdAt,
      'modified_at': DateTime.now().millisecondsSinceEpoch,
      'name_hlc': itemToSave.nameHlc.toString(),
      'email_hlc': itemToSave.emailHlc.toString(),
      'data_hlc': jsonEncode(
        itemToSave.dataHlc.map((k, v) => MapEntry(k, v.toString())),
      ),
      'server_version': itemToSave.serverVersion,
      'sync_status': itemToSave.syncStatus.index,
      'is_deleted': itemToSave.isDeleted ? 1 : 0,
      'delete_hlc': itemToSave.deleteHlc?.toString(),
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

  Future<void> deleteAccount(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen) return;

    Hlc stamp = syncDeleteHlc ?? Hlc.now(_deviceId);

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

  Future<TotpCredential> _cleanupOrphanedLinks(TotpCredential credential) async {
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
    } catch (_) {
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

  AccountItem? _mapToAccountItem(Map<String, dynamic> row) {
    try {
      final dataStr = row['data'] as String;
      final parsedData = jsonDecode(dataStr);
      final mapData = parsedData is Map
          ? parsedData.map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
            )
          : <String, String>{};

      Map<String, dynamic> dataHlcMap = {};
      if (row['data_hlc'] != null && row['data_hlc'].toString().isNotEmpty) {
        final parsedHlcStr = jsonDecode(row['data_hlc'] as String);
        if (parsedHlcStr is Map) {
          dataHlcMap = Map<String, dynamic>.from(parsedHlcStr);
        }
      }

      final dummyHlc = Hlc.zero('local');

      return AccountItem(
        id: row['id'] as String,
        name: row['name'] as String,
        email: row['email'] as String? ?? '',
        templateId: row['template_id'] as String,
        data: Map<String, String>.from(mapData),
        createdAt: row['created_at'] as int,
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
      );
    } catch (e) {
      AppLogger.d('Skipping unreadable account row: $e');
      return null;
    }
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

  Future<AccountTemplate?> loadTemplateById(String id) async {
    if (!isOpen) return null;
    try {
      final rows = await _query(
        'templates',
        where: 'id = ?',
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

  Future<void> saveTemplate(
    AccountTemplate template, {
    bool isSyncMerge = false,
  }) async {
    if (!isOpen) return;

    AccountTemplate itemToSave;
    if (isSyncMerge) {
      final existing = await loadTemplateById(template.templateId);
      if (existing != null) {
        itemToSave = CrdtMergeEngine.mergeTemplate(existing, template);
      } else {
        itemToSave = template;
      }
    } else {
      Hlc newStamp = Hlc.now(_deviceId);
      final existing = await loadTemplateById(template.templateId);
      if (existing != null) {
        itemToSave = template.copyWith(
          hlc: newStamp,
          syncStatus: SyncStatus.pendingPush,
          serverVersion: existing.serverVersion,
        );
      } else {
        itemToSave = template.copyWith(
          hlc: newStamp,
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
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'hlc': itemToSave.hlc?.toString(),
      'server_version': itemToSave.serverVersion,
      'sync_status': itemToSave.syncStatus.index,
      'is_deleted': itemToSave.isDeleted ? 1 : 0,
      'delete_hlc': itemToSave.deleteHlc?.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _persistAfterMutation();
    _notifyChange(
      StorageChangeEvent(
        type: StorageItemType.template,
        action: StorageAction.save,
        id: itemToSave.templateId,
      ),
    );
  }

  Future<void> deleteTemplate(
    String id, {
    bool isSyncMerge = false,
    Hlc? syncDeleteHlc,
  }) async {
    if (!isOpen) return;

    if (!isSyncMerge) {
      final usageCount = await countAccountsByTemplate(id);
      if (usageCount > 0) {
        throw TemplateInUseException(templateId: id, usageCount: usageCount);
      }
    }

    Hlc stamp = syncDeleteHlc ?? Hlc.now(_deviceId);

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
        title: row['title'] as String,
        subTitle: row['subtitle'] as String? ?? '',
        icon: templateIconFromStorageValue(iconCodePoint),
        category: templateCategoryFromString(row['category'] as String?),
        fields: (jsonDecode(row['fields'] as String) as List)
            .map(
              (field) => AccountField.fromJson(field as Map<String, dynamic>),
            )
            .toList(),
        isCustom: isCustom,
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
        } else {
          await hardDeleteTotpCredential(entityId);
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
    } catch (_) {
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
      {
        'sync_status': SyncStatus.pendingPush.index,
        'modified_at': now,
      },
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.synchronized.index],
    );

    await _database!.update(
      'templates',
      {
        'sync_status': SyncStatus.pendingPush.index,
        'created_at': now,
      },
      where: 'sync_status = ? AND is_custom = 1',
      whereArgs: [SyncStatus.synchronized.index],
    );

    await _database!.update(
      'totp_credentials',
      {
        'sync_status': SyncStatus.pendingPush.index,
        'modified_at': now,
      },
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
    if (originalBefore == null && nextAction == LocalSyncAction.create) {
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
    } catch (_) {
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

enum StorageAction { save, delete }

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

  const TemplateInUseException({
    required this.templateId,
    required this.usageCount,
  });

  @override
  String toString() =>
      'TemplateInUseException(templateId: $templateId, usageCount: $usageCount)';
}
