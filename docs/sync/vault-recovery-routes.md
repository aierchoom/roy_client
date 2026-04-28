# SecretRoy 密钥恢复路线与风险口径

导航：
[文档首页](../README.md) |
[同步文档](README.md) |
[密钥同步实现](../security/key-sync-implementation.md)

| 项目 | 内容 |
|---|---|
| 文档 ID | SR-SYNC-08 |
| 文档类型 | 产品 / 实现 / 风险统一口径 |
| 读者 | 产品、客户端、同步服务端、QA、安全复核 |
| 范围 | 本地密钥数据链接、设备配对、离线恢复和内部兼容码 |
| 状态 | 当前实现口径 |
| 更新日期 | 2026-04-29 |

## 1. 结论

SecretRoy 当前有四条和“恢复保险库密钥”相关的路线，但它们不是同一种产品能力。

| 路线 | 用户入口 | 风险等级 | 推荐度 | 当前结论 |
|---|---|---:|---|---|
| 面对面链接 | `密钥恢复与设备链接 -> 面对面链接：8 位临时码` | P1 | 首选 | 同一可信局域网内加新设备，窗口关闭即销毁密钥包 |
| 远程配对 | `密钥恢复与设备链接 -> 远程配对：可信设备批准` | P1 | 首选 | 不在同一局域网时使用，已有设备必须批准 |
| 离线恢复码 | `密钥恢复与设备链接 -> 离线恢复码` | P2 | 备用 | 无法配对时手动恢复；恢复码和密码必须分开保存 |
| 内部兼容码 | 无普通用户入口 | P2 | 不推荐用户直接接触 | `sroy-link-v1:` 是内部承载格式，不作为恢复入口展示 |

产品侧应避免使用“链接码”“转移码”这类泛化说法。面向用户时只使用：

- 面对面链接
- 远程配对
- 离线恢复码
- 内部兼容码

## 2. 通用导入安全规则

所有导入路线都必须遵守以下规则：

1. 导入前先解析和验证密钥包，不允许先切换本机 vault 密钥。
2. 目标设备如已有账号、模板、同步版本或待同步脏状态，必须要求用户明确确认覆盖。
3. 如果导入包携带 `vault_dump`，必须先验证 dump 可解密和可解析，再清空本地数据。
4. dump 写入失败必须向上抛错，不允许只打印日志后继续提示成功。
5. 导入成功后只替换共享 vault 身份材料，不覆盖本机 `deviceId`。
6. 导入失败时不能留下“已切换密钥但数据未恢复”的半成功状态。

当前实现对应：

- `IdentityService.previewTransferCode(...)`
- `IdentityService.previewSecureLinkCode(...)`
- `IdentityService.applyImportPreview(...)`
- `VaultDumpCoordinator.validateEncryptedVaultDump(...)`
- `VaultDumpCoordinator.importValidatedVaultDump(...)`
- `ServiceManager.importVaultLinkCode(..., forceOverwrite: ...)`
- `ServiceManager.importSecureVaultLinkCode(..., forceOverwrite: ...)`

## 3. 路线一：面对面链接

### 3.1 适用场景

用于已有可信设备和新设备在同一可信局域网内时加新设备，例如：

- 家庭 Wi-Fi
- 办公室可信网络
- 手机热点
- 两台设备面对面操作

不建议用于：

- 公共 Wi-Fi
- 酒店、咖啡厅、商场等不可控网络
- 用户无法确认另一台设备是否可信的场景

### 3.2 当前实现链路

| 环节 | 当前实现 |
|---|---|
| 主入口 | `SyncSettingsView._startLanPairingHost()` |
| 加入口 | `SyncSettingsView._showJoinLanPairingDialog()` |
| 服务层 | `ServiceManager.startLanVaultPairingHost()` / `joinLanVaultPairingWithCode()` |
| 协议层 | `LanPairingService` |
| 用户码 | 8 位可读字符，字符集 `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| 生命周期 | 默认 TTL 3 分钟；窗口关闭、领取成功、停止、超时、失败次数过多都会销毁密钥包 |
| 广播边界 | UDP 广播只带 endpoint 元数据，不带配对码 |
| 加密边界 | 新设备 claim 时发送临时公钥；主设备优先返回 `wrapped_transfer_code` |

### 3.3 风险等级

等级：P1。

原因：

- 局域网 HTTP claim 本身没有 TLS。
- 攻击者如果位于同一不可信网络，可能监听 endpoint 或尝试撞码。
- 8 位码空间和失败次数限制能降低撞码风险，但不能把公共 Wi-Fi 变成可信环境。

已缓解：

- 配对码不出现在 UDP 广播里。
- 密钥包只在弹窗打开期间存在。
- 一次领取后销毁。
- 失败次数过多后销毁。
- 当前客户端支持临时公钥加密返回包。
- UI 在打开和加入前提示仅在可信局域网使用。

### 3.4 验收方式

功能验收：

- 打开面对面链接弹窗后显示 8 位临时码。
- 另一台设备输入正确码后可以导入同一 vault 身份。
- 新设备导入后 `vaultId` 与已有设备一致，`deviceId` 保持自身不变。
- 成功领取后再次用同一码领取应失败。
- 关闭弹窗后再领取应失败。
- TTL 到期后领取应失败。
- 连续错误码达到限制后 host 停止。

安全验收：

- UDP 广播 payload 中不能包含 8 位码。
- claim 返回优先使用 `wrapped_transfer_code`，不能在新客户端路径返回明文 `transfer_code`。
- 公共 Wi-Fi 风险文案必须出现在打开和加入流程前。

自动化覆盖：

- `test/sync/lan_pairing_service_test.dart`
- 重点用例：8 位码归一化、错误码拒绝、一次性领取、超时销毁、失败次数限制、临时公钥加密 claim。

## 4. 路线二：远程配对

### 4.1 适用场景

用于两台设备不在同一局域网，但仍能由已有可信设备批准新设备加入的场景，例如：

- 手机在外网，桌面端在家中
- 两台设备只能通过同步服务器中转
- 用户可以同时操作或远程确认两台可信设备

不适用于：

- 没有任何已有可信设备可批准的账号恢复
- 需要完全离线恢复的场景
- 希望服务器代管恢复密钥的场景

### 4.2 当前实现链路

| 环节 | 当前实现 |
|---|---|
| 主入口 | `SyncSettingsView._createVaultPairingSession()` |
| 加入口 | `SyncSettingsView._showJoinPairingCodeDialog()` |
| 审批入口 | `SyncSettingsView._approvePendingPairingRequest()` |
| 领取入口 | `SyncSettingsView._checkPairingBundleAndImport()` |
| 服务层 | `VaultPairingService` + `ServiceManager` |
| 加密层 | `VaultPairingCrypto` |
| 服务端角色 | 保存会话、请求、公钥和密文包；不应读取 vault 密钥材料 |
| 密文格式 | `sroy-pairing-v2:` |

### 4.3 风险等级

等级：P1。

原因：

- 依赖同步服务器可用性和会话状态正确性。
- 如果实现退回明文 bundle，服务器会看到 vault 密钥材料。
- 如果审批 UI 不清楚，用户可能误批准陌生设备。

已缓解：

- 新设备 join 时提交临时 X25519 公钥。
- 已有设备 approve 时把密钥包加密给新设备临时公钥。
- 服务端 approve 路由拒绝 legacy plaintext `sroy-link-v1:` bundle。
- 新设备本地解密后再走导入流程。
- UI 使用“远程配对”和“可信设备批准”口径，不再把它混同为普通链接码。

### 4.4 验收方式

功能验收：

- 已有设备创建远程配对码。
- 新设备输入远程配对码后生成 pending request。
- 已有设备能看到 requester device id 并手动批准。
- 新设备领取审批结果后导入同一 vault 身份。
- 新设备 `deviceId` 不被覆盖。
- 会话过期、拒绝或不存在时导入失败且 UI 明确提示。

安全验收：

- join 请求必须包含 `requester_public_key`。
- approve 上传的 `wrapped_vault_bundle` 必须是 `sroy-pairing-v2:`。
- 服务端必须拒绝 plaintext `sroy-link-v1:` bundle。
- 服务端日志和持久化数据中不能出现可读 vault key material。

自动化覆盖：

- `roy_server/test/index.test.js`
- `test/services/vault_pairing_crypto_test.dart`
- `test/sync/sync_service_identity_test.dart`

## 5. 路线三：离线恢复码

### 5.1 适用场景

用于无法使用面对面链接和远程配对时的手动恢复，例如：

- 用户提前导出并离线保存恢复码。
- 新设备无法联系已有设备，但用户持有恢复码和恢复密码。
- 需要在无网络环境恢复密钥；如恢复码包含数据快照，也可恢复离线快照。

不适用于：

- 日常加新设备的首选流程。
- 把恢复码通过不可信聊天工具长期保存。
- 把恢复码和恢复密码保存在同一个位置。

### 5.2 当前实现链路

| 环节 | 当前实现 |
|---|---|
| 导出入口 | `SyncSettingsView._exportSecureVaultLinkCode()`，UI 文案为“导出离线恢复码” |
| 导入口 | `SyncSettingsView._importSecureVaultLinkCode()`，UI 文案为“导入离线恢复码” |
| 服务层 | `ServiceManager.exportSecureVaultLinkCode()` / `importSecureVaultLinkCode()` |
| 身份层 | `IdentityService.exportSecureLinkCode()` / `previewSecureLinkCode()` |
| 当前格式 | `sroy-secure-v2:` |
| KDF | PBKDF2-HMAC-SHA256，150000 次迭代 |
| 加密 | AES-GCM-256 |
| 可选数据 | `vault_dump`，由当前 vault key 加密的数据快照 |

### 5.3 风险等级

等级：P2。

原因：

- 恢复码是高价值密文，离线保存周期可能很长。
- 安全性依赖用户设置的恢复密码强度和保存方式。
- 如果用户把恢复码和密码放在同一位置，等同于给攻击者完整恢复能力。
- 如果只导出身份密钥但没有数据快照，新设备仍需要同步服务器才能拿到数据。

已缓解：

- 当前导出使用 PBKDF2-HMAC-SHA256 和 AES-GCM-256。
- 导入前会先验证恢复码和 dump。
- 目标设备非 clean 时必须确认覆盖。
- dump 导入失败会抛错，不再静默半成功。
- UI 文案明确恢复码只作为无法配对时的备用路线。

### 5.4 验收方式

功能验收：

- 导出恢复码时必须先选择“仅恢复密钥”或“密钥 + 数据快照”。
- 导出时必须设置恢复密码。
- 使用正确恢复密码可导入。
- 使用错误恢复密码必须失败。
- 包含数据快照时，离线导入后应恢复账号和模板数据。
- 不包含数据快照时，导入后只切换 vault 身份，后续需要同步拉取数据。

安全验收：

- 恢复码文本不能包含明文 `privateKey` 或 `symmetricKey`。
- 导入前应先验证 `vault_dump`，不能先写 vault 身份。
- dump 写入失败必须反馈失败，不允许提示恢复成功。
- 本地已有数据时必须出现覆盖确认。

自动化覆盖：

- `test/sync/sync_service_identity_test.dart`
- 重点用例：正确密码导入、错误密码拒绝、preview 不提前写入密钥、坏 dump 不写 storage。

## 6. 路线四：内部兼容码

### 6.1 适用场景

内部兼容码不是普通用户恢复入口。它只用于：

- 旧实现迁移兼容。
- 面对面链接和远程配对内部承载 vault identity payload。
- 测试或调试低层导入逻辑。

### 6.2 当前实现链路

| 环节 | 当前实现 |
|---|---|
| 格式 | `sroy-link-v1:` |
| 导出底层 | `IdentityService.exportTransferCode(...)` |
| 导入底层 | `IdentityService.previewTransferCode(...)` / `importTransferCode(...)` |
| 普通 UI | 不直接展示 |
| 当前承载位置 | LAN claim bundle、远程配对加密 bundle 内部 plaintext，再由外层路线加密或保护 |

### 6.3 风险等级

等级：P2。

原因：

- `sroy-link-v1:` 本身是 bearer secret，拿到即可导入 vault key material。
- 如果被当成用户可复制的普通恢复码，会绕过恢复密码和配对审批心智模型。
- 如果服务器中转明文 `sroy-link-v1:`，服务器就有机会读取 vault 密钥材料。

已缓解：

- 普通 UI 不再突出“原始链接码”。
- 远程配对 approve 路由拒绝明文 `sroy-link-v1:` bundle。
- 面对面链接当前优先把内部码加密为 `wrapped_transfer_code` 返回。
- 文档和 UI 把它标记为“内部兼容码”，不作为用户恢复路线。

### 6.4 验收方式

功能验收：

- 设置页不能出现“导出普通转移码”或“导入内部兼容码”的普通按钮。
- 内部兼容码说明只能解释边界，不能引导用户复制保存。
- 旧版兼容导入路径仍可在测试中验证，不作为产品主入口。

安全验收：

- 服务器中转路径不能接受 plaintext `sroy-link-v1:` bundle。
- 面对面 claim 返回不应在新客户端路径暴露 plaintext `transfer_code`。
- 文档、UI、错误提示都必须避免把 `sroy-link-v1:` 称为“恢复码”。

自动化覆盖：

- `roy_server/test/index.test.js`：plaintext transfer code rejection during approve。
- `test/sync/lan_pairing_service_test.dart`：requester-encrypted LAN claim response。
- `test/sync/sync_service_identity_test.dart`：底层导入 preserves target `deviceId`。

## 7. 产品文案规则

允许使用：

- 面对面链接
- 8 位临时码
- 远程配对
- 可信设备批准
- 离线恢复码
- 内部兼容码

避免在用户入口使用：

- 链接码
- 转移码
- 普通转移码
- 原始码
- 安全链接码
- 加密链接码

例外：

- 代码级文档可以出现 `sroy-link-v1:`、`sroy-secure-v2:`、`sroy-pairing-v2:`。
- 代码级文档必须同时说明这些是协议格式，不是产品入口名称。

## 8. 回归检查清单

每次修改密钥恢复或配对链路时，至少检查：

- [ ] 设置页四条路线命名仍一致。
- [ ] 面对面链接只在 8 位临时码弹窗打开期间可领取。
- [ ] 远程配对必须经过已有设备批准。
- [ ] 离线恢复码导出必须要求恢复密码。
- [ ] 内部兼容码没有普通用户导出 / 导入按钮。
- [ ] 非 clean device 导入必须要求用户确认覆盖。
- [ ] dump 导入失败会向上抛错并展示失败原因。
- [ ] 新设备导入后保留自己的 `deviceId`。
- [ ] 服务器中转路径不能读取 vault key material。

## 9. 相关文件

客户端：

- `lib/views/sync_settings_view.dart`
- `lib/widgets/sync_settings_dialogs.dart`
- `lib/services/service_manager.dart`
- `lib/services/identity_service.dart`
- `lib/services/lan_pairing_service.dart`
- `lib/services/vault_pairing_service.dart`
- `lib/services/vault_pairing_crypto.dart`
- `lib/system/service_manager/vault_dump_coordinator.dart`

服务端：

- `roy_server/index.js`
- `roy_server/test/index.test.js`

测试：

- `test/sync/sync_service_identity_test.dart`
- `test/sync/lan_pairing_service_test.dart`
- `test/services/vault_pairing_crypto_test.dart`
