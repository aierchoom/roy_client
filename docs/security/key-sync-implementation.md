# SecretRoy 密钥同步实现说明

| 项目 | 内容 |
|---|---|
| 文档 ID | SR-ARCH-07 |
| 文档类型 | 实现说明 |
| 读者 | 客户端、同步、服务端、QA |
| 范围 | 多设备密钥同步、保险库加入、恢复路线 |
| 更新日期 | 2026-04-29 |

## 1. 目的

密钥同步让已有可信设备把新设备加入同一个 vault namespace。

共享 vault 身份包含：

- `vaultId`
- `privateKey`
- `symmetricKey`

接收设备保留自己的 `deviceId`。这点很关键：CRDT/HLC 冲突排序需要每台设备有独立节点身份，而同步 payload 解密需要多设备共享同一组 vault 密钥。

产品、实现和风险的统一口径见 [vault-recovery-routes.md](../sync/vault-recovery-routes.md)。本文只记录这些路线对应的实现边界。

## 2. 当前支持路线

### 2.1 离线恢复码

产品入口：

- `密钥恢复与设备链接 -> 离线恢复码`

主要代码路径：

- `ServiceManager.exportSecureVaultLinkCode(...)`
- `ServiceManager.importSecureVaultLinkCode(...)`
- `IdentityService.exportSecureLinkCode(...)`
- `IdentityService.previewSecureLinkCode(...)`
- `IdentityService.applyImportPreview(...)`

当前协议格式：

- 前缀：`sroy-recovery:`
- 信封：Base64URL JSON
- KDF：PBKDF2-HMAC-SHA256
- 迭代次数：`150000`
- Salt：16 随机字节
- 加密：AES-GCM-256
- Nonce：12 随机字节
- Payload 压缩：加密前 zlib 压缩

加密包内字段：

- `vid`: vault id
- `pk`: vault signing/private key placeholder
- `sk`: vault symmetric key placeholder
- `url`: 可选同步服务器 URL
- `dump`: 可选加密 vault 数据快照

导入行为：

- 写入前先验证 vault id、key 格式和可选 dump。
- 只写入 vault-level identity 字段。
- 保留接收设备已有 `deviceId`。
- 可选持久化传入的同步服务器 URL。
- 可选导入加密 vault dump。
- 非 clean device 必须通过 `forceOverwrite` 明确确认覆盖。
- dump 失败会抛错，不允许静默半成功。

兼容性：

- 当前不保留旧恢复码协议兼容导入。
- 导出和导入都使用 `sroy-recovery:` 当前格式。

### 2.2 远程配对

产品入口：

- `密钥恢复与设备链接 -> 远程配对：可信设备批准`

主要代码路径：

- `VaultPairingService`
- `ServiceManager.createVaultPairingSession(...)`
- `ServiceManager.joinVaultPairingSession(...)`
- `ServiceManager.approveVaultPairingRequest(...)`
- `ServiceManager.fetchAndImportVaultPairingBundle(...)`
- `VaultPairingCrypto`

流程：

1. 已有设备在同步服务器上创建短期配对会话。
2. 服务器返回一次性配对码和 session id。
3. 新设备生成临时 X25519 keypair 并输入配对码。
4. 新设备携带 `requester_public_key` join；private key 留在本地。
5. 已有设备看到 pending request 并手动批准。
6. 已有设备在本地导出 vault transfer payload，加密给 `requester_public_key`，只上传 `sroy-pairing:` 密文。
7. 新设备一次性拉取密文 bundle，服务端删除 pairing session 和密文 bundle。
8. 新设备用本地临时 private key 解密，再导入 vault identity。

当前协议格式：

- 前缀：`sroy-pairing:`
- 密钥协商：请求方临时 X25519 key + 主机临时 key
- KDF：HMAC-SHA256 over shared secret、salt、protocol label
- 加密：AES-GCM-256
- 服务器可见字段：配对元数据、请求方 public key、加密 bundle
- 服务器禁止 payload：明文 `sroy-link:` transfer code
- 密文 bundle 成功领取后即从服务端内存中删除。

### 2.3 面对面链接

产品入口：

- `密钥恢复与设备链接 -> 面对面链接：8 位临时码`

主要代码路径：

- `LanPairingService`
- `ServiceManager.startLanVaultPairingHost(...)`
- `ServiceManager.joinLanVaultPairingWithCode(...)`

流程：

1. 已有设备打开面对面链接码窗口。
2. 已有设备只在该窗口打开期间启动本地 HTTP claim endpoint。
3. 已有设备通过 UDP 广播 endpoint 元数据。
4. 已有设备显示 8 位临时码。
5. 新设备在同一可信局域网内输入该临时码。
6. 新设备在 claim 请求中发送临时 requester public key。
7. 已有设备必须使用该临时公钥加密 transfer code，只返回加密 LAN bundle。
8. 新设备本地解密返回 bundle 并导入。
9. claim 成功、窗口关闭、TTL 到期、手动停止或错误码次数过多时，host 销毁 transfer bundle。

临时码规则：

- 长度：8 个字符
- 字符集：`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`
- 排除易混字符：`I`、`O`、`1`、`0`
- 输入会移除空白并转大写。
- 这不是 6 位数字码；提到 6 位数字码的旧笔记或 UI 草稿均为过期内容。
- 默认 TTL 为 3 分钟。
- 一次成功 claim 后 host 停止。
- 多次错误码后 host 停止。

发现与隐私：

- UDP 广播只暴露 LAN claim endpoint 元数据。
- 8 位临时码不进入广播 payload。
- 只有 joining device 发送 HTTP claim 请求时才校验临时码。
- 未显示 8 位临时码窗口时，没有可领取的 hosted transfer bundle。
- UI 会提示仅在可信私有网络使用，不建议公共 Wi-Fi。
- claim 请求必须携带临时 public key，host 只返回 `wrapped_transfer_code`，不返回 plaintext `transfer_code`。

### 2.4 内部兼容码

产品入口：

- 无普通用户入口。

主要代码路径：

- `IdentityService.exportTransferCode(...)`
- `IdentityService.previewTransferCode(...)`
- `IdentityService.importTransferCode(...)`

当前协议格式：

- 前缀：`sroy-link:`
- 用途：内部承载 vault identity payload，仍被面对面链接和远程配对的内部密钥包流程使用。
- 边界：普通用户不应手动保存、粘贴或分享该格式。

## 3. 安全模型

同步服务器仍应只是加密 payload 的中转站。密钥同步会改变哪些设备能解密 vault，但不应要求服务器解密账号内容。

关键边界：

- 主密码 verifier 以 PBKDF2 hash 存在 `master_password_v2`。
- Vault identity 存在平台 secure storage。
- `deviceId` 是每台设备本地身份，导入不会覆盖。
- 离线恢复码使用恢复密码和认证加密保护。
- 远程配对在上传前把 vault transfer payload 加密给 joining device 的临时 public key。
- 面对面链接 claim 是短期信任仪式，只能在可信局域网内使用。
- `sroy-link:` 内部兼容码是 bearer secret，不应作为普通用户恢复入口。

## 4. 回归覆盖

当前测试覆盖：

- `test/sync/sync_service_identity_test.dart`
  - 底层 transfer import 保留目标设备 `deviceId`
  - 离线恢复码用正确密码导入 vault keys
  - 离线恢复码用错误密码会拒绝
  - 导入 preview 不提前写入 vault 密钥
  - 坏 dump 不写 storage
  - dirty sync state 按 vault 隔离
- `test/sync/lan_pairing_service_test.dart`
  - 8 位临时码归一化
  - 非法临时码拒绝
  - 面对面链接 host 生命周期
  - claim/import 路径
  - 成功领取、过期、重复错误码后的 transfer bundle 销毁
  - requester-encrypted claim response
- `roy_server/test/index.test.js`
  - 远程配对 session 生命周期
  - requester public key 传递
  - approve 阶段拒绝 plaintext transfer code
  - 未知配对码 join 失败
  - opaque wrapped bundle delivery
- `test/services/vault_pairing_crypto_test.dart`
  - pairing bundle encrypt/decrypt roundtrip
  - wrong requester key rejection

## 5. 剩余加固项

- 增加设备信任元数据和撤销 UI。
- 增加面对面链接和离线恢复码的 QR 扫描支持。
- 将 placeholder `privateKey` / `symmetricKey` 字符串迁移到正式 key hierarchy。
- 继续推进同步 payload 的标准 AEAD/E2EE 化。
