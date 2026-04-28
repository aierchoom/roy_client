# SecretRoy Key Sync Implementation

| Item | Value |
|---|---|
| Doc ID | SR-ARCH-07 |
| Document Type | Implementation note |
| Audience | Client, sync, server, QA |
| Scope | Multi-device key synchronization and vault onboarding |
| Last Updated | 2026-04-28 |

## 1. Purpose

Key sync lets a trusted existing device provision a new device into the same vault namespace.

The shared vault identity contains:

- `vaultId`
- `privateKey`
- `symmetricKey`

The receiving device keeps its own `deviceId`. This is important because CRDT/HLC conflict ordering still needs per-device identity, while encrypted sync payloads need shared vault keys.

## 2. Current Supported Flows

### 2.1 Secure Vault Link Code

Primary code path:

- `ServiceManager.exportSecureVaultLinkCode(...)`
- `ServiceManager.importSecureVaultLinkCode(...)`
- `IdentityService.exportSecureLinkCode(...)`
- `IdentityService.importSecureLinkCode(...)`

Current format:

- Prefix: `sroy-secure-v2:`
- Envelope: Base64URL JSON
- KDF: PBKDF2-HMAC-SHA256
- Iterations: `150000`
- Salt: 16 random bytes
- Encryption: AES-GCM-256
- Nonce: 12 random bytes
- Payload compression: zlib before encryption

Payload fields inside the encrypted bundle:

- `vid`: vault id
- `pk`: vault signing/private key placeholder
- `sk`: vault symmetric key placeholder
- `url`: optional sync server URL
- `dump`: optional encrypted vault data snapshot

Import behavior:

- validates vault id and key formats before writing
- writes only vault-level identity fields
- preserves the receiving device's existing `deviceId`
- optionally persists the incoming sync server URL
- optionally imports an encrypted vault dump

Compatibility:

- `sroy-secure-v1:` import is still accepted for migration.
- New exports always use `sroy-secure-v2:`.

### 2.2 Server-Mediated Vault Pairing

Primary code path:

- `VaultPairingService`
- `ServiceManager.createVaultPairingSession(...)`
- `ServiceManager.joinVaultPairingSession(...)`
- `ServiceManager.approveVaultPairingRequest(...)`
- `ServiceManager.fetchAndImportVaultPairingBundle(...)`
- `VaultPairingCrypto`

Flow:

1. Existing device creates a short-lived pairing session on the sync server.
2. Server returns a one-time pairing code and session id.
3. New device generates a temporary X25519 keypair and enters the pairing code.
4. New device joins with `requester_public_key`; the private key stays local.
5. Existing device sees the pending request and approves it.
6. Existing device exports the vault transfer payload locally, encrypts it to
   `requester_public_key`, and uploads only `sroy-pairing-v2:` ciphertext.
7. New device fetches the encrypted bundle, decrypts it locally with the
   temporary private key, and imports the vault identity.

Current format:

- Prefix: `sroy-pairing-v2:`
- Key agreement: X25519 temporary requester key plus host ephemeral key
- KDF: HMAC-SHA256 over the shared secret, salt, and protocol label
- Encryption: AES-GCM-256
- Server-visible fields: pairing metadata, requester public key, encrypted bundle
- Server-forbidden payload: raw `sroy-link-v1:` transfer code

### 2.3 LAN Direct Pairing

Primary code path:

- `LanPairingService`
- `ServiceManager.startLanVaultPairingHost(...)`
- `ServiceManager.joinLanVaultPairingWithCode(...)`

Flow:

1. Existing device opens the LAN pairing code window.
2. Existing device starts a local HTTP claim endpoint only for that window.
3. Existing device advertises the endpoint over UDP broadcast.
4. Existing device displays an 8-character pairing code.
5. New device enters the code on the same LAN while the window is open.
6. New device claims the transfer code from the host and imports it locally.
7. Host destroys the transfer bundle when the claim succeeds, the code window
   closes, the TTL expires, pairing is stopped, or too many wrong codes are
   submitted.

Pairing code rules:

- Length: 8 characters
- Alphabet: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
- Ambiguous characters are excluded: `I`, `O`, `1`, `0`
- Input is normalized by removing whitespace and uppercasing.
- This is intentionally not a 6-digit numeric code. Older notes or UI drafts
  that mention 6 digits are stale.

Discovery privacy:

- UDP broadcast advertises only the LAN claim endpoint metadata.
- The pairing code itself is not included in the broadcast payload.
- The code is checked only when the joining device sends the HTTP claim request.
- When LAN pairing is not actively showing the 8-character code window, there is
  no hosted transfer bundle to claim.

## 3. Security Model

The sync server remains a dumb relay for encrypted payloads. Key sync changes which devices can decrypt the vault, but it does not require the server to decrypt account contents.

Important boundaries:

- Master password verification is stored as PBKDF2 hash in `master_password_v2`.
- Vault identity is stored in platform secure storage.
- `deviceId` is local per device and is not overwritten by imports.
- Secure link codes are password protected with authenticated encryption.
- Server-mediated pairing encrypts the vault transfer payload to the joining
  device's temporary public key before upload.
- Plain transfer codes and LAN transfer claims are bearer secrets and should be treated as short-lived trust ceremonies.

## 4. Regression Coverage

Current tests cover:

- `test/sync/sync_service_identity_test.dart`
  - raw vault transfer preserves target `deviceId`
  - secure link imports vault keys with the right password
  - secure link rejects a wrong password
  - dirty sync state remains vault scoped
- `test/sync/lan_pairing_service_test.dart`
  - 8-character LAN code normalization
  - invalid LAN code rejection
  - LAN host lifecycle
  - LAN claim/import path
  - transfer bundle destruction after successful claim, expiry, and repeated
    wrong-code attempts
- `roy_server/test/index.test.js`
  - server pairing session lifecycle
  - requester public key propagation
  - plaintext transfer code rejection during approve
  - join failure for unknown pairing code
  - opaque wrapped bundle delivery
- `test/services/vault_pairing_crypto_test.dart`
  - pairing bundle encrypt/decrypt roundtrip
  - wrong requester key rejection

## 5. Open Hardening Items

- Add explicit clean-device checks before destructive imports.
- Add device trust metadata and revocation UI.
- Add QR scan support for secure link and LAN pairing codes.
- Move placeholder `privateKey` / `symmetricKey` strings into a formal key hierarchy.
