import 'package:shared_preferences/shared_preferences.dart';

import '../../services/vault_pairing_service.dart';
import 'default_sync_server_url.dart';

class SyncServerUrlStore {
  static const _prefsKey = 'sync_server_url';

  final String Function() defaultUrl;

  const SyncServerUrlStore({
    this.defaultUrl = defaultSyncServerUrlForCurrentPlatform,
  });

  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  Future<void> write(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
  }

  Future<String> resolve({bool allowEmpty = false}) async {
    final normalized = normalize((await read()) ?? defaultUrl());
    if (normalized.isEmpty && !allowEmpty) {
      throw const VaultPairingServiceException(
        'Sync server URL is not configured.',
      );
    }
    return normalized;
  }

  static String normalize(String rawUrl) {
    var url = rawUrl.trim();
    if (url.isEmpty) {
      return '';
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
