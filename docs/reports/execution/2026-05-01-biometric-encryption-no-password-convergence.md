# T15 Biometric Master Key Encryption + No-Password Mode Security Convergence

**Status**: Completed  
**Date**: 2026-05-01  
**Scope**: Client-only; BiometricAuthService encrypted storage + no-password mode hardening  
**Baseline**: `EA` tag on both repos; Stage 2 Step 3

---

## Goal

1. Eliminate plaintext master password storage in `FlutterSecureStorage` (`master_key_biometric_v1`). Replace with AES-256-GCM encryption using a random wrapping key.
2. Converge no-password mode security: entering no-password mode must automatically disable biometric unlock (since biometric + empty password = zero security), and the UI must clearly warn when biometric setup is attempted in no-password mode.

---

## Scope

- `lib/services/biometric_auth_service.dart` — AES-256-GCM encrypted storage, legacy plaintext migration path
- `lib/services/identity_service.dart` — `SecureKeyValueStore` interface extended with `delete`
- `lib/services/service_manager.dart` — no-password mode disables biometric; `enableBiometric` guards against no-password mode
- `lib/views/security_settings_view.dart` — `noPasswordMode` result handling in UI switch
- `test/services/biometric_auth_service_test.dart` — new unit tests for encryption round-trip and migration

---

## Changes

### 1. BiometricAuthService AES-256-GCM encrypted storage

**New storage schema:**

| Key | Value format | Purpose |
|-----|--------------|---------|
| `biometric_enabled` | `'true'` | Flag indicating biometric is active |
| `biometric_wrapping_key` | base64(32-byte random key) | AES-256-GCM wrapping key |
| `biometric_wrapped_key` | JSON `{nonce, ciphertext, mac}` | Encrypted master password |

**Deleted (on enable):**
- `master_key_biometric` — legacy plaintext key is removed during encrypted setup

**Encryption flow (`enableBiometric`):**
1. Generate 32 random bytes → wrapping key
2. `AesGcm.with256bits().encrypt(utf8.encode(masterPassword), secretKey: wrappingKey)`
3. Persist wrapping key + SecretBox envelope (nonce, ciphertext, mac)
4. Delete legacy `master_key_biometric`

**Decryption flow (`unlockWithBiometric`):**
1. Attempt encrypted decrypt using stored wrapping key
2. If encrypted envelope missing → fall back to `master_key_biometric` (migration path)
3. If both missing → return `null`

### 2. `SecureKeyValueStore` interface extension

```dart
abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});  // NEW
}
```

`BiometricAuthService` now accepts `SecureKeyValueStore` (instead of `FlutterSecureStorage` directly), enabling memory-backed tests without platform channel mock.

### 3. No-password mode security convergence

**ServiceManager changes:**

```dart
Future<void> enableNoPasswordMode() async {
  // ...
  await disableBiometric();  // NEW: biometric offers no value with empty password
  await unlockWithPassword('');
}

Future<BiometricSetupResult> enableBiometric(String currentPassword) async {
  if (await isNoPasswordMode()) {
    return BiometricSetupResult.noPasswordMode;  // NEW
  }
  // ... existing password verification ...
}
```

**UI changes:**
- `security_settings_view.dart` switch on `BiometricSetupResult` now handles `noPasswordMode` with a localized SnackBar error.

### 4. Dependency injection for testability

`BiometricAuthService` constructor now accepts optional `localAuth` and `secureStorage` parameters:

```dart
BiometricAuthService({
  SecureKeyValueStore? secureStorage,
  LocalAuthentication? localAuth,
})
```

This allows tests to inject a mock `LocalAuthentication` and a memory-backed `SecureKeyValueStore`.

### 5. Global de-versioning of internal storage keys

Because the product is unreleased, all internal secure-storage keys that carried premature version suffixes (`_v1`, `_v2`) were cleaned up across the codebase:

| Service | Old key | New key |
|---------|---------|---------|
| `BiometricAuthService` | `master_key_biometric_v1` | `master_key_biometric` |
| `DatabaseFileKeyManager` | `database_key_salt_v1` | `database_key_salt` |
| `DatabaseFileKeyManager` | `database_file_key_envelope_v1` | `database_file_key_envelope` |
| `DatabaseFileKeyManager` | `database_file_key_envelope_previous_v1` | `database_file_key_envelope_previous` |
| `EnhancedCryptoService` | `master_password_v1` | `master_password` |
| `EnhancedCryptoService` | `master_password_v2` | `master_password_hash` |

The PBKDF2 nonce label `SecretRoy database key wrap v1` was intentionally **not** changed because it is part of the key-derivation input and would break existing database unlocks.

---

## Validation

```bash
flutter analyze --no-pub  # 0 issues
flutter test --no-pub       # 127 passed / 1 skipped
```

New tests added:

| Test | Behavior verified |
|------|-------------------|
| `enableBiometric encrypts and stores master password` | Encrypted format created, legacy plaintext deleted |
| `unlockWithBiometric decrypts stored master password` | Round-trip encryption/decryption |
| `unlockWithBiometric falls back to legacy plaintext` | Migration path for existing users |
| `disableBiometric deletes all keys` | Complete cleanup including encrypted and legacy keys |

---

## Risk Notes

- **Legacy migration path**: `unlockWithBiometric` falls back to legacy plaintext if the encrypted envelope is absent. This means users who had biometric enabled before this change will continue to work without re-enrolling. Once they re-enable biometric, the plaintext key is deleted and encrypted storage takes over.
- **Wrapping key exposure**: The wrapping key is stored in the same secure storage as the encrypted payload. This does not protect against a root/attacker who can read secure storage contents; it primarily prevents accidental plaintext exposure in logs, backups, or debugging output. True hardware-backed key separation would require platform-specific Keystore/Keychain integration beyond the scope of this change.
- **No-password mode UX**: The UI already displayed a warning banner for no-password mode. The additional change is that biometric is now explicitly disabled and blocked, rather than silently allowing a zero-security configuration.

---

## Follow-ups

- Consider adding a one-time migration prompt: when a user unlocks with legacy plaintext, show a notice suggesting they re-enable biometric to upgrade to encrypted storage
- Consider wrapping key rotation if the user changes their master password while biometric is enabled
- Document the biometric storage contract in `docs/security/biometric-storage.md`
