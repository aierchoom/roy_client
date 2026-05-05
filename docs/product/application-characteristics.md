# SecretRoy 应用程序特性基准

**最后更新**: 2026-04-30
**文档定位**: 全局产品与工程参考
**适用范围**: 后续所有功能设计、实现、测试、文档和质量收敛
**维护原则**: 以后扫描代码或迭代功能时，只要发现本文档未记录的真实功能点，必须同步补入本文档

## 1. 应用定位

SecretRoy 是一个本地优先的个人密钥/账号保险库应用。

它的核心价值不是“把数据放到云端统一管理”，而是：

```text
用户掌握本地保险库。
可信设备之间共享同一个 vault 密钥空间。
同步服务器只承担弱中转和版本协调职责。
普通数据变更必须避免误操作自动扩散。
```

后续任何功能迭代都必须优先保护：

1. 本地数据安全。
2. vault 密钥材料不被服务器读取。
3. 可信设备之间的一致性。
4. 用户对危险出站变更的确认权。
5. 清晰、克制、专业的操作体验。

## 2. 产品特性

| 特性 | 解释 |
|---|---|
| 本地优先 | 本地保险库是第一数据入口，服务器不可用时仍应保留基本查看和编辑能力 |
| 密钥自持 | vault 身份和密钥材料属于客户端，不属于服务器账号 |
| 多设备可信 | 加入同一 vault 的设备被视为可信客户端 |
| 弱服务器 | 服务器负责同步、配对中转、版本检查，不负责理解用户明文数据 |
| 审阅式出站同步 | 本机编辑和删除先进入待审队列，用户确认后才推送 |
| 专业工具体验 | UI 应安静、清晰、紧凑、可扫描，避免装饰性和营销式表达 |

## 3. 全局功能地图

本节是后续功能迭代的全局索引。新增、发现、重构任何功能点时，都要检查这里是否需要更新。

| 功能点 | 产品定位 | 主要代码入口 | 长期维护重点 |
|---|---|---|---|
| 本地保险库解锁 | 进入本地加密保险库的第一入口 | `unlock_view.dart`, `EnhancedCryptoService`, `SecureStorageService` | 密码校验、无密码模式、生物识别、自动锁定、失败态 |
| 本地加密数据库 | 用户数据的本地事实存储 | `SecureStorageService`, `DatabaseFileCipher`, `DatabaseFileKeyManager` | 加密落盘、运行时明文清理、数据库迁移、导入覆盖 |
| 账号管理 | 保存、编辑、删除用户账号和字段数据 | `account_edit_view.dart`, `account_list_view.dart`, `AccountItem` | 历史字段保留、敏感字段展示、删除可控、模板缺失保护 |
| 模板管理 | 定义账号字段结构和内置/自定义模板 | `template_edit_view.dart`, `template_list_view.dart`, `AccountTemplate` | 模板删除保护、字段变更不静默丢数据、内置模板中文优先 |
| 2FA/TOTP 验证器 | 独立保存网站 TOTP 凭据并本地生成动态验证码，账号信息只关联它 | `totp_credential.dart`, `totp_service.dart`, `totp_qr_image_import_service.dart`, `totp_account_list_view.dart`, `account_edit_view.dart` | secret 默认隐藏、不搜索、不泄露到服务端、移动端扫码、二维码图片主动粘贴导入、列表只提示已关联、同步走独立 AEAD payload |
| 首页搜索与任务聚合 | 搜索账号，并聚合需要用户处理的事项 | `home_search_view.dart`, `EnhancedAppProvider` | 待同步变更、冲突入口、搜索结果、移动端布局 |
| 密码工具 | 生成和评估密码强度 | `password_tools_view.dart`, `password_generator_sheet.dart` | 字符池覆盖、强度提示、填入/复制动作 |
| 外观设置 | 控制主题、色彩和视觉偏好 | `appearance_settings_view.dart`, `theme_provider.dart` | 专业工具感、浅/深色、布局不溢出 |
| 安全设置 | 管理锁定、生物识别、无密码等安全体验 | `security_settings_view.dart`, `auto_lock_service.dart`, `biometric_auth_service.dart` | 锁定时机、状态文案、敏感操作确认 |
| 服务端同步 | 多设备共享普通账号/模板数据 | `SyncService`, `sync_payload_codec.dart`, server `/vaults/:vaultId/sync` | pull/push 分离、版本冲突、payload 校验、弱服务器边界 |
| 本地出站同步审阅 | 防止本机误删误改自动扩散 | `local_sync_change.dart`, `ServiceManager`, `SyncService`, `home_search_view.dart` | pendingReview 不 push、approved 才 push、删除撤销、首页可见 |
| 冲突收件箱 | 展示并处理同步冲突 | `conflict_inbox_view.dart`, `CrdtMergeEngine`, `ConflictLog` | remote missing、concurrent edit/delete、用户决策闭环 |
| 密钥同步与设备链接 | 让可信新设备加入同一 vault 密钥空间 | `IdentityService`, `VaultPairingService`, `LanPairingService`, `VaultPairingCrypto`, `sync_settings_view.dart` | vaultId 一致、deviceId 唯一、服务器不可读密钥包、配对码生命周期 |
| 面对面 LAN 链接 | 同一可信局域网内用 8 位临时码加入设备 | `LanPairingService`, `ServiceManager.startLanVaultPairingHost` | 仅弹窗开启期间可领取、TTL、一次性、失败次数、临时公钥加密 |
| 远程配对 | 不在同一局域网时由旧设备批准新设备加入 | `VaultPairingService`, server pairing routes | join 提交临时公钥、approve 加密 bundle、服务器只保存密文 |
| 离线恢复码 | 无法配对时的备用 vault 恢复方式 | `IdentityService.exportSecureLinkCode`, import preview/apply | 不作为日常入口突出、导入前预览和覆盖确认 |
| 内部兼容码 | 兼容旧实现或内部传输格式 | `IdentityService.exportTransferCode`, `importTransferCode` | 不作为普通用户主入口，不混同正式恢复路线 |
| vault dump 导入 | 随密钥链接迁移普通数据快照 | `VaultDumpCoordinator`, `ServiceManager.importVaultLinkCode` | 先验证再导入、失败抛错、clean-device/forceOverwrite、syncStatus 可解释 |
| 发布说明 | 展示版本变化 | `release_note_view.dart` | 文案准确、和真实迭代一致 |
| 全局敏感复制策略 | 统一管理密码、配对码、恢复码、TOTP 验证码等高风险复制的剪贴板清理时长和覆盖保护 | `SensitiveClipboardService`, 全局 `Clipboard.setData` 调用 | 分级策略、不覆盖用户后续复制、定时清理、回归测试 |
| Vault Health 本地体检 | 把加密、备份、凭据风险和待同步状态变成可见产品能力 | `SecureStorageService`, `IdentityService`, `SyncService`, password tools, 新增 health service | 离线可用、不上传、每个风险项指向可执行动作 |
| 项目文档 | 记录产品、架构、功能和回归基准 | `docs/**` | 发现功能即更新，避免文档落后于代码 |

## 4. 密钥同步功能基准

密钥同步是 SecretRoy 的一级核心能力，不只是同步设置页里的一个入口。

它解决的问题是：

```text
新设备如何加入已有 vault，
并使用同一套 vault 密钥材料解密和同步普通数据，
同时保持自己的 deviceId 唯一。
```

### 4.1 密钥同步路线

| 路线 | 用户场景 | 必须保持的安全边界 |
|---|---|---|
| 面对面链接 | 两台设备在同一可信局域网，用户面对面输入 8 位临时码 | 配对码只在弹窗打开期间有效；成功、超时、停止后销毁密钥包 |
| 远程配对 | 新旧设备不在同一局域网，旧设备批准新设备加入 | 新设备提交临时公钥；旧设备对该公钥加密 bundle；服务器不能读取 vault 密钥材料 |
| 离线恢复码 | 无法配对时手动恢复 vault 身份 | 不作为日常入口突出；导入前必须预览和确认覆盖风险 |
| 内部兼容码 | 旧格式或内部承载格式 | 不作为普通用户主入口；不得和正式恢复路线混淆 |

### 4.2 长期验收点

1. 新设备导入后 `vaultId` 必须和旧设备一致。
2. 新设备 `deviceId` 必须保持自己生成的唯一值。
3. 服务器中转 bundle 必须是面向新设备临时公钥加密的密文。
4. LAN claim 必须要求 requester public key。
5. LAN 广播不得携带配对码。
6. 面对面链接只能在 8 位配对码弹窗开启期间领取。
7. 成功领取、超时、停止、失败次数过多后必须销毁密钥包。
8. 导入带 `vault_dump` 时必须先验证 dump，再切换或写入。
9. dump 导入失败必须向上抛错，不能留下半成功状态。
10. 导入后的普通数据同步状态必须进入可解释路径，不能静默自动扩散。
11. 已存在本地数据库时，如果 vault identity 缺失或损坏，不允许静默生成新的 `vaultId` 继续解锁。
12. 缺失 `deviceId` 但 vault identity 完整时，可以生成新的本机 `deviceId`；这不改变 vault 归属。

### 4.3 相关文档

- `docs/sync/vault-recovery-routes.md`
- `docs/security/key-sync-implementation.md`
- `docs/features/local-outbound-sync-review/test-maintenance.md`
- `docs/reports/execution/2026-04-29-key-linking-quality-convergence.md`

## 5. 信任模型

### 5.1 可信对象

可信对象：

- 用户当前解锁的本机客户端。
- 已通过面对面链接、远程配对或离线恢复进入同一 vault 的设备。
- 用户明确确认过的本机出站变更。

不默认可信：

- 同步服务器。
- 局域网广播环境。
- 公共 Wi-Fi。
- 未经用户确认的本机删除或批量修改。
- 任何可以绕过 ServiceManager 的直接导入或直接写库入口。

### 5.2 服务器定位

服务器应该被视为弱服务：

```text
可以保存密文。
可以保存版本号。
可以做 expected_base_version 冲突检查。
可以做配对会话中转。
不应该读取 vault 密钥材料。
不应该理解账号明文内容。
不应该成为危险业务动作的最终裁判。
```

后续任何服务端能力如果需要看到 vault 明文或 vault 密钥材料，都必须被视为违反当前产品目标。

## 6. 数据模型特性

### 6.1 账号和模板

当前账号和模板是弱关联模型：

- `accounts` 保存账号主数据。
- `accounts.data` 保存字段 JSON。
- `templates` 保存自定义模板定义。
- 内置模板由客户端代码提供。
- 模板字段变化不会自动迁移历史账号数据。

长期原则：

```text
模板变化不能静默删除账号旧字段。
模板删除不能越过 ServiceManager 层保护。
账号保存不能因为 UI 当前不可见字段而清空历史数据。
```

### 6.2 同步状态

核心同步状态：

- `synchronized`: 本地和最近确认过的远端状态一致。
- `pendingPush`: 本地存在待推送实体快照。
- `conflict`: 本地存在需要用户处理或确认的冲突。

重要原则：

```text
pendingPush 不等于可以推送。
是否可以推送，必须看 local_sync_changes 是否 approved。
所有同步运行态元数据必须带 vault 归属。
```

### 6.3 删除语义

删除应优先使用 tombstone，而不是直接物理删除。

允许物理删除的典型场景：

- 本机新建但从未推送的草稿，随后被用户删除。
- 用户撤销 create 类型待同步变更。
- 重置应用或确认覆盖导入。

普通已同步账号删除必须能进入待审队列，并在推送前可撤销。

## 7. 同步模型

### 7.1 总原则

同步分为入站和出站：

```text
入站 pull:
可以自动执行，用于拉取其他可信客户端已经确认并推送的变更。

出站 push:
必须经过本机待审队列。
只有 approved 的本地变更可以被 push。
```

### 7.2 不做远端删除审阅

当前产品决策：

```text
每个客户端都是可信终端。
某个客户端已经审阅并推送的删除，其他客户端可以直接同步。
```

因此不做远端删除二次审阅。

唯一例外是冲突：

```text
如果本机对同一实体也存在未推送修改，
远端删除不能静默覆盖本机未处理变更，
应进入现有冲突处理链路。
```

### 7.3 出站同步审阅

本机普通编辑、删除、模板修改后：

```text
写入本地数据库
记录 local_sync_changes
保持 pendingReview
首页展示待同步变更
用户确认后变为 approved
SyncService 只推送 approved 实体
```

禁止：

- 保存账号后立即自动 push。
- 删除账号后立即自动 push tombstone。
- 启动同步或周期同步绕过 pendingReview。
- 把 `pendingPush` 数据全部无条件送入 `_runPushPhase()`。

### 7.4 同步元数据隔离

同步运行态元数据必须按 `vaultId` 隔离：

- `sync_version_$vaultId`
- `sync_dirty_$vaultId`
- `sync_last_time_$vaultId`
- `sync_recovery_$vaultId`
- `sync_server_url_$vaultId`

历史全局 key 只允许作为一次性迁移来源。读取顺序必须是：

```text
当前 vault scoped key
-> legacy global key
-> 写入当前 vault scoped key
-> 后续只依赖 scoped key
```

不得让一个 vault 的版本号、dirty、恢复标记或服务器地址影响另一个 vault。

### 7.5 同步 payload 加密边界

普通账号和模板同步 payload 必须是标准 AEAD envelope：

```text
明文账号/模板 JSON
-> 使用 vault 密钥材料派生 payload key
-> AesGcm.with256bits() 加密并认证
-> 服务端只保存 opaque encrypted_signed_payload
```

当前正式 envelope 要求：

- 必须带 `sroy-sync:` 前缀。
- 必须声明 `alg=aes-256-gcm-hkdf-sha256`。
- nonce 使用 12 字节随机值。
- salt 使用随机值并参与 HKDF-SHA256 key 派生。
- AEAD AAD 必须绑定版本、算法、`vaultId`、`nodeId`。
- 旧的 base64 明文 JSON payload 不允许静默导入。

长期原则：

```text
服务器不能通过同步 payload 读到账号明文。
客户端不能接受未认证、非当前 vault、算法不明或无法解密的 payload。
payload 解密失败必须进入明确同步失败状态，而不是写入本地数据库。
```

### 7.6 同步冲突类型

同步协议中的冲突和 payload 错误必须使用机器可读类型，不能只依赖 HTTP 状态码或自然语言文案。

当前正式类型：

| 类型 | 含义 | 客户端处理方向 |
|---|---|---|
| `remote_missing` | 本机认为远端已有记录，但服务器没有该记录 | 拉取最新快照，生成可审阅冲突 |
| `stale_base_version` | 本机基于过期版本推送 | 拉取最新快照并重新合并 |
| `concurrent_edit` | 本机新建/旧基线推送时远端已有更新 | 拉取最新快照，按 CRDT 合并或进入冲突箱 |
| `concurrent_delete` | 远端已经删除，本机仍在推送修改 | 拉取 tombstone，按删除冲突处理 |
| `invalid_payload` | 同步 payload 不符合加密 envelope 或协议要求 | 不重试写入，进入明确失败状态 |

长期原则：

```text
服务端返回体必须可稳定断言。
客户端不能把主要冲突都落入“重试几次后失败”。
新增冲突类型时必须同步更新客户端处理分支和测试。
```

### 7.7 冲突恢复路径

客户端识别冲突类型后，必须进入可解释的恢复路径：

- `remote_missing`: 拉取最新快照；如果本地仍有记录，生成 `record.remote_missing` 冲突项，用户可选择覆盖远端。
- `stale_base_version`: 拉取最新快照，使用 CRDT merge 合并；必要时进入冲突箱。
- `concurrent_edit`: 拉取最新快照，字段级合并；互相覆盖的字段进入冲突箱。
- `concurrent_delete`: 远端 tombstone 优先；如果删除胜出，状态必须说明远端删除已被接受。
- `invalid_payload`: 不写入本地库，不做无意义自动重试，进入明确失败状态。

冲突箱应展示：

```text
冲突类型
来源节点
当前值和被覆盖值
建议动作
```

## 8. 导入和覆盖原则

任何导入能力都必须遵守：

1. 导入前先验证密钥包和 dump。
2. 目标设备有本地数据时，必须明确要求覆盖确认。
3. ServiceManager 层必须强制 clean-device 或 forceOverwrite。
4. dump 导入失败必须向上抛错，不能只打印日志。
5. 不允许出现“vault 密钥已切换但数据没导入成功”的半成功状态。
6. 导入后的普通数据同步状态必须可解释。

后续重点：

```text
vault dump 导入后不能无条件把所有账号标记为 synchronized。
如果导入数据本身是本地未推送状态，应进入待同步队列。
```

## 9. UI 和交互特性

SecretRoy 的 UI 应保持专业工具感，而不是营销页或装饰性产品页。

长期方向：

- 中文优先。
- 结构清楚。
- 信息密度适中。
- 少嵌套卡片。
- 少装饰性边框。
- 操作按钮语义明确。
- 危险操作必须有足够清晰的提示。
- 首页承担“需要用户处理的事项”聚合职责。

对同步相关 UI 的要求：

- 待同步变更必须在首页可见。
- 删除类变更必须比普通修改更醒目。
- 用户要能看出变更类型、对象、影响和可执行动作。
- 不要用过度技术化文案暴露内部协议细节。

## 10. 工程架构特性

### 10.1 ServiceManager 是业务门面

跨模块业务规则应优先落在 `ServiceManager` 或其拆分出的 system module 中，而不是只写在 UI 层。

原因：

```text
UI 可以防误点。
ServiceManager 必须防绕过。
```

例如：

- 模板删除保护不能只在模板页面。
- 导入覆盖保护不能只在弹窗。
- 本地变更审阅不能只在首页 UI。

### 10.2 最小可维护单元

功能开发应按最小可维护单元拆分，保持单一职责、边界清晰、可独立测试。

不要把过多业务、状态、协议、UI 和数据访问逻辑堆在同一个文件、类或方法里。一个模块变得难以命名、难以测试、难以解释失败原因时，应优先拆分为更小的 service、model、coordinator、view model 或 widget。

判断标准：

- 一个模块只负责一个明确的业务角色。
- 跨层逻辑不混放：UI 负责展示和交互，ServiceManager/system module 负责业务约束，SyncService 负责同步状态机，Storage 负责持久化。
- 单个方法不同时承担校验、网络请求、数据库写入、UI 状态更新和错误展示。
- 新增功能优先扩展已有边界清晰的模块；如果只能靠继续塞代码完成，先拆边界再实现。
- 测试应能针对关键业务单元单独构造场景，而不是只能通过完整 UI 流程间接验证。

### 10.3 SyncService 是同步状态机

`SyncService` 负责：

- pull 远端数据。
- push 已批准本地变更。
- 处理版本冲突。
- 维护 sync version、dirty、recovery marker。

`SyncService` 不应该决定用户是否愿意推送某条本地业务变更；这个决定来自 outbox 审阅状态。

### 10.4 SecureStorageService 是本地事实存储

本地 SQLite 存储应保持：

- 可恢复。
- 可校验。
- 可迁移。
- 避免静默破坏历史数据。

涉及 `clearAllData()`、`replaceAllDataForImport()`、物理删除、批量写入时，必须按高风险路径审查。

## 11. 测试特性

后续每次迭代至少按影响范围选择测试。

| 改动范围 | 必测方向 |
|---|---|
| 账号保存/删除 | 是否进入 outbox，是否误 push，是否可撤销 |
| 2FA/TOTP | 算法向量、输入解析、验证码复制、secret 隐藏、列表不泄露、剪贴板清理、outbox 审阅、密文同步、多设备一致性、并发冲突 |
| 模板保存/删除 | 是否保护被引用模板，是否记录待同步变更 |
| SyncService | pendingReview 是否仍禁止 push，approved 是否可 push |
| 密钥链接 | vaultId 是否一致，deviceId 是否保持本机唯一 |
| 导入覆盖 | clean-device/forceOverwrite 是否强制生效 |
| 首页 UI | 待处理事项是否可见，危险变更是否明确 |
| 冲突处理 | 不应静默覆盖本地未推送变更 |
| CRDT merge | 同输入确定性、字段/HLC 对齐、墓碑胜负、冲突日志不改变主结果、交错编辑可再次 push |
| 双设备同步 | A 新增/B 拉取、并发字段编辑、删除/修改冲突、离线编辑恢复后推送 |
| 崩溃恢复 | pull/push marker 可回放，数据库原子替换中断后可恢复一致库文件 |

当前 T0 本地出站同步审阅收口已复跑通过：

- `test/sync/sync_state_machine_test.dart`
- `test/sync/multi_device_sync_test.dart`
- `test/sync/sync_conflict_recovery_test.dart`
- `test/sync/sync_recovery_loop_test.dart`

当前 T6 CRDT merge 不变量测试已通过：

- `test/sync/crdt_merge_invariants_test.dart`

当前 T7 最小双设备集成测试已通过：

- `test/sync/multi_device_sync_test.dart`

当前 T8 崩溃恢复闭环已通过：

- `test/sync/sync_recovery_loop_test.dart`
- `test/services/secure_storage_service_encryption_test.dart`
- `test/sync/sync_state_machine_test.dart`
- `test/sync/sync_conflict_recovery_test.dart`
- `test/sync/multi_device_sync_test.dart`
- `dart analyze lib test`
- `flutter test`，结果为 78 passed, 1 skipped；跳过项仍是 Windows runner 下不稳定的 UDP broadcast discovery。

T0-T7 断代质量收敛的历史基线：

- `dart analyze lib test`
- `flutter test`

当时全量测试结果为 76 passed, 1 skipped；跳过项是 Windows runner 下不稳定的 UDP broadcast discovery 测试。T8 新增恢复测试后，当前全量基线已更新为 78 passed, 1 skipped。

当前 T11 2FA/TOTP 动态验证码已从账号字段式方案收敛为独立凭据方案：

- `test/services/totp_service_test.dart`
- `test/services/totp_import_service_test.dart`
- `test/services/totp_qr_image_import_service_test.dart`
- `test/models/totp_credential_test.dart`
- `test/models/account_template_test.dart`
- `test/widgets/account_list_tile_test.dart`
- `test/sync/sync_state_machine_test.dart`
- `test/sync/multi_device_sync_test.dart`
- `test/sync/sync_conflict_recovery_test.dart`
- `dart analyze lib test`
- `flutter test`

T11 的同步原则是：TOTP secret 只存在于 `TotpCredential.config`，作为独立 `totp_credential` AEAD payload 参与本地加密、outbox 审阅、多设备同步和 HLC merge；模板里的 `AccountFieldType.totp` 只表示 2FA 关联控件，不新增账号数据 secret 字段、服务端 TOTP route 或 metadata key，服务端仍只保存密文。

T11 的展示原则是：2FA 页面独立展示验证码、倒计时、复制、编辑、删除和账号关联；账号详情页在模板 2FA 字段处维护关联关系，并支持快速关联已有 2FA 或新建独立 2FA；录入时移动端可扫码，不便扫码时打开粘贴面板并由用户主动粘贴二维码图片，文本导入只作为兜底；列表页和搜索卡片只提示“已关联 2FA”，不展示原始 secret、不显示当前验证码、不提供复制 secret 入口。

当前全量测试基线已更新为 112 passed, 1 skipped。如果后续这些长链路测试再次超时，需要优先判断是 Flutter 测试进程权限/生命周期问题，还是同步链路真实阻塞。

代码质量收敛基线（quality-pass-1, commit daea7fe）已纳入回归：
- `dart analyze lib test` 通过，0 issues。
- `flutter test` 112 passed, 1 skipped；跳过项仍是 Windows runner 下不稳定的 UDP broadcast discovery。
- 修复范围：ChangeNotifier _disposed 保护、dynamic→Database?、V1 恒定时间比较、AutoLockDuration.never 语义、debugPrint kDebugMode 包裹、URL 默认 https://、Hlc.parse 魔法字符串、StreamSubscription 泄漏、密码强度阈值共享化。

## 12. 功能迭代准入检查表

任何新功能或重构合入前，至少回答这些问题：

1. 这个改动是否会新增账号、模板、密钥、vault dump 或同步写入路径？
2. 这个写入路径是否绕过了 ServiceManager？
3. 是否可能在用户未确认时触发出站 push？
4. 是否可能让服务器看到 vault 密钥材料或账号明文？
5. 是否会清空、覆盖、迁移本地数据？
6. 失败时是否可能留下半成功状态？
7. 是否会影响可信设备模型？
8. 是否误引入了远端删除审阅？
9. 是否影响首页待处理事项？
10. 是否同步更新了功能文档、执行报告或回归测试？
11. 是否扫描到新的功能点但没有更新本文档？
12. 是否把过多业务、状态、协议、UI 或持久化逻辑塞进了同一个模块，而没有拆成最小可维护单元？

如果第 3、4、5、6、11、12 条无法明确回答，不允许合入。

## 13. 明确的非目标

当前阶段不把 SecretRoy 做成：

- 云端账号系统。
- 企业管理员控制台。
- 服务端可读的密码管理器。
- 助记词钱包。
- 多人协作编辑系统。
- 以服务器为最终事实源的 SaaS。

这些方向如果未来要做，必须先重新讨论产品定位和信任模型。

## 14. 文档维护规则

本文档是全局基准，不记录每次实现细节。实现细节应写入：

- 功能级文档：`docs/features/**`
- 同步协议文档：`docs/sync/**`
- 安全文档：`docs/security/**`
- 执行报告：`docs/reports/execution/**`

以后开发时遵守这条硬规则：

```text
扫描到任何真实功能点，如果本文档没有记录，就补入“全局功能地图”。
修改任何已有功能点，如果它改变了定位、信任边界、同步边界、导入边界、UI 入口或测试方式，就同步更新本文档对应条目。
```

后续每次功能扫描、功能迭代或质量收敛，都必须把本文档作为收口项，而不是额外的可选文档。

执行顺序：

1. 扫描代码入口、数据模型、服务层、UI 入口、测试和现有文档。
2. 对照“全局功能地图”，确认扫描到的真实功能点是否已经存在。
3. 如果发现缺失功能点，先补入“全局功能地图”，再补对应的长期维护重点。
4. 如果改动触及密钥同步、普通数据同步、导入覆盖、安全边界、UI 入口或测试方式，继续更新对应专题章节。
5. 在执行报告或提交说明里明确写出：`application-characteristics.md` 已检查、已更新或无需更新。

当某次迭代改变以下任一内容时，必须同步更新本文档：

- 全局功能地图。
- 信任模型。
- 出站同步原则。
- 密钥同步与设备链接路线。
- 导入覆盖原则。
- UI 全局体验原则。
- 全局非目标。

## 15. 代码扫描后的全局 Roadmap

2026-04-30 扫描结论：当前代码已经完成同步基础、身份基础、AEAD payload、冲突恢复、崩溃恢复和 TOTP 第一阶段；后续全局 roadmap 应从“继续堆功能”转向“状态可解释、恢复可信、安全边界真实、敏感复制一致、UI 架构可维护”。

| 阶段 | Roadmap 项 | 代码依据 | 收敛目标 | 准入条件 |
|---|---|---|---|---|
| 阶段1 | 同步状态机清理 | `SyncService`, `sync_settings_view.dart` | UI 消费稳定状态，不再猜 transport/protocol/persistence/recovery 的内部细节 | 纯客户端改动，不依赖服务端变更 |
| 阶段1 | 全局敏感复制策略 | `SensitiveClipboardService`, 全局 `Clipboard.setData` 调用 | 密码、配对码、恢复码和复制全部等高风险复制有统一清理策略 | 纯客户端改动 |
| 阶段2 | 解锁与密钥托管 | `BiometricAuthService`, `EnhancedCryptoService`, `SecuritySettingsView` | 生物识别、无密码模式和主密码托管不能让 UI 文案超过真实安全边界 | 阶段1完成后启动 |
| 阶段2 | 服务端认证和传输边界 | `roy_server/system/routes/**`, `sync_settings_view.dart` | 弱服务器仍然可以简单，但公网/局域网风险必须可解释，未认证请求不能读写 vault | 需要同步推进 roy_server |
| 阶段2 | 服务端持久化语义加固 | `roy_server/system/` 各模块 | 强化薄后端的校验、幂等、错误分类和半写入恢复 | 需要同步推进 roy_server |
| 阶段3 | 备份、恢复和导入一致性 | `VaultDumpCoordinator`, `SecureStorageService.replaceAllDataForImport` | 备份可演练，导入失败可回滚，导入后的 sync/outbox 状态可解释 | 阶段2安全边界清晰后启动 |
| 阶段3 | Vault Health 本地体检 | `SecureStorageService`, `IdentityService`, `SyncService`, password tools | 本地显示加密、备份、恢复、弱/复用/陈旧凭据、缺少恢复数据和待同步风险 | 阶段2完成后启动 |
| 阶段4 | UI 架构与本地化收敛 | 超大 view/service 文件、`_text(...)` 与 l10n 并存 | 拆分大视图，统一组件和文案路径，避免功能继续堆进单个文件 | 阶段3稳定后启动 |
| 阶段4 | 2FA 下一阶段 | `TotpCredential`, `TotpService`, QR 扫码与主动粘贴导入入口、2FA 文档 | QR 导出决策、恢复码模板、设备时间漂移提示 | 不抢占安全/恢复主线 |

执行队列以 `docs/product/iteration-tasks.md` 的阶段步骤为准；中长期方向以 `docs/todo.md` 为准。
