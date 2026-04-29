# SecretRoy Vault Linking Design

Navigation:
[Docs Home](../README.md) |
[Architecture Index](../architecture/README.md) |
[Recovery Routes](vault-recovery-routes.md)

| Item | Value |
|---|---|
| Doc ID | SR-ARCH-06 |
| Document Type | Feature design |
| Audience | Client, protocol, server engineers |
| Scope | Multi-device vault linking and shared key onboarding |
| Status | Draft |
| Last Updated | 2026-04-29 |

## 1. Problem

SecretRoy currently lets each fresh installation generate its own local identity:

- `deviceId`
- `vaultId`
- `privateKey`
- `symmetricKey`

This is enough for a single-device prototype, but it breaks the real multi-device story:

- a new device cannot join an already existing vault
- the new device generates a different `vaultId`
- sync then points at a different remote namespace
- even if the server URL matches, the new device cannot decrypt the old vault payloads

The core missing capability is:

**An already trusted device must be able to authorize a clean new device into the same vault keyspace without replacing the vault keys or re-encrypting all data.**

## 2. Design Goals

The mechanism must:

1. Let a clean new device join the same vault as an existing device.
2. Reuse the same vault-level crypto material across devices.
3. Keep each device's `deviceId` unique.
4. Avoid requiring the weak sync server to know plaintext vault contents.
5. Be implementable in stages, starting from the current prototype.
6. Provide a clean upgrade path from mock keys to a future formal key hierarchy.

## 3. Non-Goals

This design does not attempt to solve:

- full production-grade E2EE with mature audited cryptography in one step
- social recovery
- revocation UI for device trust management
- server-side account system
- QR camera scanning in the first rollout

## 4. Key Idea

Separate identity into two layers:

### 4.1 Device Identity

Per-device and never shared:

- `deviceId`
- future per-device keypair
- local trust metadata

### 4.2 Vault Identity

Shared by all devices in the same vault:

- `vaultId`
- vault signing secret or equivalent
- vault payload encryption secret or equivalent

The onboarding flow must copy or derive the **vault identity**, while preserving the new device's own **device identity**.

## 5. Rollout Strategy

We should implement this in two stages.

### Stage A: Transitional Internal Transfer Payload

Purpose:

- solve the functional multi-device gap now
- keep implementation simple
- avoid blocking the rest of sync work

Mechanism:

- existing device prepares an internal vault identity payload
- user-facing routes wrap that payload as face-to-face linking, remote pairing,
  or offline recovery code
- new clean device imports through one of those routes
- import overwrites only vault-level identity material
- import does not overwrite the new device's own `deviceId`

Payload content in the current prototype stage:

- `vaultId`
- `privateKey`
- `symmetricKey`

Pros:

- fast to implement
- no server changes required
- unblocks real multi-device testing

Cons:

- code is effectively a bearer secret
- export is only safe between trusted devices and secure channels
- still based on mock key material

### Stage B: Formal Pairing Session

Purpose:

- replace raw bearer transfer with an explicit trust ceremony
- prepare for production-grade device onboarding

Mechanism summary:

1. Existing device creates a short-lived pairing session.
2. Existing device displays a one-time pairing code.
3. New device enters the code and proves possession of the code to the server.
4. Existing device encrypts the vault secret bundle to the new device's session public material.
5. New device receives the wrapped vault bundle and activates the vault locally.

Pros:

- short-lived
- server can expire sessions
- easier to audit
- compatible with future device revocation

## 6. Transitional Stage A Detail

### 6.1 Export Preconditions

Export should be allowed only when:

- vault is unlocked
- local identity is valid
- user explicitly triggers export

Recommended UI warning:

- this code grants another device access to the same vault
- share only through a trusted channel
- prefer immediate import and then discard

### 6.2 Import Preconditions

Import should be allowed only when:

- vault is unlocked
- the target device is clean
- there is no existing vault data, sync version, or pending dirty state

If the target device is not clean:

- reject import
- instruct the user to reset local data first

### 6.3 Import Effects

Import updates:

- `vaultId`
- `privateKey`
- `symmetricKey`

Import preserves:

- `deviceId`

Import should also:

- disconnect sync if connected
- reinitialize sync metadata for the imported vault namespace
- require the user to run a fresh sync

## 7. Formal Stage B Detail

### 7.1 New Concepts

Add these concepts:

- `pairingSessionId`
- `pairingCode`
- `pairingExpiresAt`
- `deviceProvisioningPublic`
- `wrappedVaultBundle`

### 7.2 Suggested Flow

#### Existing Device

1. Generate ephemeral device-provisioning keypair.
2. Request a pairing session from the server.
3. Receive:
   - `pairingSessionId`
   - short numeric or alphanumeric `pairingCode`
   - expiry time
4. Show code to the user.

#### New Device

1. User enters server URL and pairing code.
2. Device generates its own ephemeral provisioning keypair.
3. Device sends:
   - `pairingSessionId` or `pairingCode`
   - new device proof material
   - new device metadata

#### Existing Device Approval

1. Existing device sees a pending approval request.
2. Existing device chooses approve or reject.
3. On approval, existing device wraps the vault bundle for the new device.

#### Wrapped Vault Bundle

Bundle should contain:

- `vaultId`
- vault encryption secret
- vault signing secret
- bundle version

Wrapped bundle should be encrypted to the new device's ephemeral provisioning key.

#### New Device Activation

1. New device fetches wrapped bundle.
2. New device decrypts it locally.
3. New device stores the imported vault identity.
4. New device performs initial sync.

## 8. Data Model Direction

The current `IdentityService` stores four flat fields. That is enough for Stage A, but Stage B should move toward a structured identity model.

Recommended local structure:

```text
device_identity:
  device_id
  device_keypair (future)
  created_at

vault_identity:
  vault_id
  vault_encryption_key
  vault_signing_key
  linked_at
  source = generated | imported | paired
```

Recommended future secure storage keys:

- `device_id`
- `device_private_key`
- `device_public_key`
- `vault_id`
- `vault_encryption_key`
- `vault_signing_key`
- `vault_identity_source`

## 9. Sync Implications

This feature is not just onboarding UI. It directly affects sync correctness.

After linking:

- all devices in the same vault must use the same `vaultId`
- all devices must be able to decrypt the same payload stream
- all devices must still stamp HLC with their own `deviceId`

That means:

- HLC node identity remains per device
- vault namespace remains shared
- conflict resolution remains deterministic across devices

## 10. Security Notes

### Stage A Risks

The transition code is a high-value bearer secret.

Mitigations:

- export only while unlocked
- do not auto-display secrets continuously
- require explicit user action
- treat the code as short-lived in user guidance even if not cryptographically enforced yet

### Stage B Security Improvements

Formal pairing should add:

- expiry
- approval from an existing device
- wrapped vault bundle instead of plaintext bearer export
- future device trust log

## 11. Recommended Implementation Order

### Phase 1

- add export/import vault-link capability to `IdentityService`
- preserve `deviceId`
- add Sync Settings entry points
- add tests for export/import roundtrip

### Phase 2

- add clean-device checks and explicit UX warnings
- isolate imported vault metadata from preexisting local state
- add docs and test scenarios for multi-device onboarding

### Phase 3

- introduce pairing-session protocol
- add server endpoints for short-lived pairing sessions
- replace raw transfer code as the primary onboarding path

## 12. Acceptance Criteria

The feature is acceptable when:

1. Device A creates data and syncs to server.
2. Device B starts clean.
3. Device B imports vault identity from Device A.
4. Device B keeps its own `deviceId`.
5. Device B uses the same `vaultId` as Device A.
6. Device B can pull and decrypt Device A data.
7. Device B edits data and syncs back successfully.
8. Device A later pulls those updates and merges correctly.

## 13. Current Repository Position

As of this design:

- the repository now separates user-facing recovery routes from internal code
  formats
- face-to-face linking and remote pairing are the preferred device-onboarding
  paths
- offline recovery code is the manual fallback path
- `sroy-link:` remains only an internal compatibility/transport format and
  should not be presented as a normal recovery entry

Current implementation update, 2026-04-29:

- `sroy-recovery:` is now documented and presented as an offline recovery
  code, not as a generic user-facing link code.
- LAN/face-to-face linking now uses an 8-character readable code from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`; it is not a 6-digit numeric code.
- LAN discovery broadcasts only endpoint metadata. The pairing code is supplied and verified during the HTTP claim step.
- Face-to-face linking is scoped to the visible 8-character code window: closing
  the window, successful claim, timeout, stop, or too many wrong-code attempts
  destroys the hosted key bundle.
- Face-to-face linking now requires requester-bound encryption: the joining
  device sends a temporary public key and the host returns only an encrypted
  `wrapped_transfer_code`.
- The UI asks the user to confirm they are on a trusted LAN before opening or
  joining a face-to-face linking session.
- Remote pairing is implemented as a short-lived approval flow. The
  joining device submits a temporary X25519 public key, and the approving device
  uploads only a `sroy-pairing:` AES-GCM encrypted vault bundle for that key.
- The server rejects plaintext `sroy-link:` bundles on the approve
  route, so the relay no longer receives readable vault key material.
- Import consistency protection is implemented at `ServiceManager`: imports
  preview and validate incoming identity/dump before writing, require
  `forceOverwrite` for non-clean devices, and throw on dump failures.
- The receiving device still preserves its own `deviceId` and imports only vault-level identity material.

See [vault-recovery-routes.md](vault-recovery-routes.md) for the product,
risk, and acceptance matrix. See
[key-sync-implementation.md](../security/key-sync-implementation.md) for the
implementation-level contract and current hardening backlog.

## 14. Next Step

Implementation should now follow this order:

1. Keep face-to-face linking, remote pairing, and offline recovery code naming
   consistent across UI and docs.
2. Add QR scan support for face-to-face and offline recovery code entry.
3. Add device trust metadata and revocation UI.
