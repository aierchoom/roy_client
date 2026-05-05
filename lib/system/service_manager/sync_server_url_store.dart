import 'package:shared_preferences/shared_preferences.dart';

import '../../services/vault_pairing_service.dart';
import 'default_sync_server_url.dart';

class SyncServerUrlStore {
  static const _prefsKey = 'sync_server_url';

  final String Function() defaultUrl;

  const SyncServerUrlStore({
    this.defaultUrl = defaultSyncServerUrlForCurrentPlatform,
  });

  Future<String?> read({String? vaultId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = _keyForVault(vaultId);
    if (scopedKey == _prefsKey) {
      return prefs.getString(_prefsKey);
    }

    final scopedValue = prefs.getString(scopedKey);
    if (scopedValue != null) {
      return scopedValue;
    }

    final legacyValue = prefs.getString(_prefsKey);
    if (legacyValue != null) {
      await prefs.setString(scopedKey, legacyValue);
    }
    return legacyValue;
  }

  Future<void> write(String url, {String? vaultId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForVault(vaultId), url);
  }

  Future<String> resolve({String? vaultId, bool allowEmpty = false}) async {
    final normalized = normalize(
      (await read(vaultId: vaultId)) ?? defaultUrl(),
    );
    if (normalized.isEmpty && !allowEmpty) {
      throw const VaultPairingServiceException(
        'Sync server URL is not configured.',
      );
    }
    return normalized;
  }

  static String _keyForVault(String? vaultId) {
    final normalizedVaultId = vaultId?.trim();
    if (normalizedVaultId == null || normalizedVaultId.isEmpty) {
      return _prefsKey;
    }
    return '${_prefsKey}_$normalizedVaultId';
  }

  static String normalize(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      return '';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
