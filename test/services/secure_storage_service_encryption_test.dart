import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:secret_roy/models/account_item.dart';
import 'package:secret_roy/models/account_template.dart';
import 'package:secret_roy/models/hlc.dart';
import 'package:secret_roy/services/database_file_cipher.dart';
import 'package:secret_roy/services/secure_storage_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory rootDirectory;
  late Directory documentsDirectory;
  late Directory temporaryDirectory;
  late DatabaseFileCipher cipher;

  setUp(() {
    rootDirectory = Directory.systemTemp.createTempSync('secret_roy_storage_');
    documentsDirectory = Directory(p.join(rootDirectory.path, 'documents'))
      ..createSync(recursive: true);
    temporaryDirectory = Directory(p.join(rootDirectory.path, 'temp'))
      ..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsPath: documentsDirectory.path,
      temporaryPath: temporaryDirectory.path,
    );
    cipher = DatabaseFileCipher(
      keyBytes: Uint8List.fromList(List<int>.filled(32, 11)),
    );
  });

  tearDown(() {
    if (rootDirectory.existsSync()) {
      rootDirectory.deleteSync(recursive: true);
    }
  });

  test(
    'stores the vault as an encrypted file and removes runtime plaintext',
    () async {
      final storage = SecureStorageService(databaseCipher: cipher);
      await storage.initialize(deviceId: 'device_test');
      await storage.saveAccount(_account());

      final encryptedPath = await storage.getDatabaseFilePath();
      final encryptedFile = File(encryptedPath);
      final encryptedText = utf8.decode(
        await encryptedFile.readAsBytes(),
        allowMalformed: true,
      );

      expect(encryptedFile.existsSync(), isTrue);
      expect(
        DatabaseFileCipher.looksEncrypted(await encryptedFile.readAsBytes()),
        isTrue,
      );
      expect(encryptedText, isNot(contains('secret-password')));
      expect(
        File(
          p.join(documentsDirectory.path, 'secret_roy_vault.db'),
        ).existsSync(),
        isFalse,
      );

      await storage.close(dispose: true);

      final runtimeFiles = temporaryDirectory
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => p.basename(file.path))
          .toList();
      expect(runtimeFiles, isNot(contains('secret_roy_vault.runtime.db')));

      final reopenedStorage = SecureStorageService(databaseCipher: cipher);
      await reopenedStorage.initialize(deviceId: 'device_test');
      final reopenedAccount = await reopenedStorage.getAccountById('account_1');

      expect(reopenedAccount, isNotNull);
      expect(reopenedAccount!.data['password'], 'secret-password');
      await reopenedStorage.close(dispose: true);
    },
  );

  test('removes legacy plaintext databases without importing them', () async {
    final legacyFile = File(
      p.join(documentsDirectory.path, 'secret_roy_vault.db'),
    );
    await legacyFile.writeAsString('legacy-secret-password', flush: true);

    final storage = SecureStorageService(databaseCipher: cipher);
    await storage.initialize(deviceId: 'device_test');

    final encryptedPath = await storage.getDatabaseFilePath();
    final encryptedBytes = await File(encryptedPath).readAsBytes();
    final encryptedText = utf8.decode(encryptedBytes, allowMalformed: true);

    expect(legacyFile.existsSync(), isFalse);
    expect(DatabaseFileCipher.looksEncrypted(encryptedBytes), isTrue);
    expect(encryptedText, isNot(contains('legacy-secret-password')));
    expect(await storage.loadAccounts(), isEmpty);

    await storage.close(dispose: true);
  });

  test('recovers when encrypted database replacement is interrupted', () async {
    final storage = SecureStorageService(databaseCipher: cipher);
    await storage.initialize(deviceId: 'device_test');
    await storage.saveAccount(_account());

    final encryptedPath = await storage.getDatabaseFilePath();
    await storage.close(dispose: true);

    final encryptedFile = File(encryptedPath);
    final backupFile = File('$encryptedPath.bak');
    final tempFile = File('$encryptedPath.tmp');
    await encryptedFile.rename(backupFile.path);
    await tempFile.writeAsBytes(Uint8List.fromList([1, 2, 3]), flush: true);

    expect(encryptedFile.existsSync(), isFalse);
    expect(backupFile.existsSync(), isTrue);
    expect(tempFile.existsSync(), isTrue);

    final reopenedStorage = SecureStorageService(databaseCipher: cipher);
    await reopenedStorage.initialize(deviceId: 'device_test');
    final account = await reopenedStorage.getAccountById('account_1');

    expect(account, isNotNull);
    expect(account!.data['password'], 'secret-password');
    expect(encryptedFile.existsSync(), isTrue);
    expect(backupFile.existsSync(), isFalse);
    expect(tempFile.existsSync(), isFalse);

    await reopenedStorage.close(dispose: true);
  });

  test('round-trips template fieldHlc through encrypted database', () async {
    final storage = SecureStorageService(databaseCipher: cipher);
    await storage.initialize(deviceId: 'device_test');

    final template = AccountTemplate(
      templateId: 'custom_1',
      title: 'Test',
      subTitle: '',
      category: TemplateCategory.custom,
      fields: [
        const AccountField(
          fieldKey: 'url',
          label: 'URL',
          attributes: AccountFieldAttributes(type: AccountFieldType.url),
          labelHlc: Hlc(100, 0, 'device_test'),
          attributesHlc: Hlc(100, 0, 'device_test'),
        ),
      ],
      hlc: const Hlc(100, 0, 'device_test'),
      syncStatus: SyncStatus.synchronized,
    );

    await storage.saveTemplate(template, isSyncMerge: true);

    final loaded = await storage.loadTemplateById('custom_1');
    expect(loaded, isNotNull);
    expect(loaded!.fields.first.labelHlc, const Hlc(100, 0, 'device_test'));
    expect(loaded.fields.first.attributesHlc, const Hlc(100, 0, 'device_test'));

    await storage.close(dispose: true);
  });
}

AccountItem _account() {
  const stamp = Hlc(100, 0, 'device_test');
  return AccountItem(
    id: 'account_1',
    name: 'Example',
    email: 'owner@example.com',
    templateId: 'web_account',
    data: const {'password': 'secret-password'},
    createdAt: 1,
    nameHlc: stamp,
    emailHlc: stamp,
    dataHlc: const {'password': stamp},
    syncStatus: SyncStatus.pendingPush,
  );
}
