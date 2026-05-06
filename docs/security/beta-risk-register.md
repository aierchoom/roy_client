# SecretRoy Beta 风险清单

> 2026-05-01 delta: T9/T12/T15/T16 completed. Biometric storage now uses AES-256-GCM encrypted envelope; no-password mode auto-disables biometric. Vault-level API token (`X-Vault-Token`) added for sync endpoints. External security Beta blockers reduced to transport hardening (HTTPS/TLS) and runtime protection.

更新日期：2026-05-01

## 结论

当前版本已经从“原型开发态”收敛到了“可做功能性 Beta 测试”的状态，但还**不适合对外宣称为安全可用的密码管理器 Beta**。

本次已修复的重点是：

- 避免数据库打开失败时自动删库
- 修复生物识别解锁状态机错误
- 修复删除墓碑不同步导致的脏数据风险
- 修复新安装实例默认共享同一个测试 Vault 的隔离问题
- 为同步服务端补充原子写入、输入校验与自动化测试入口

仍然阻塞“安全 Beta / 外部公测”的核心问题主要集中在服务端认证、传输安全、解锁密钥托管和运行期保护。

## 风险分级说明

- `P0`：禁止外部 Beta 发布，存在严重安全或数据风险
- `P1`：可做内部测试，但需要明确限制范围
- `P2`：建议在下一轮迭代收敛
- `P3`：低优先级质量项

## 风险列表

| 等级 | 状态 | 风险 | 影响 | 当前结论 |
|---|---|---|---|---|
| P0 | 已缓解 | 本地账户数据长期落盘已加密为 `secret_roy_vault.db.enc` | 单独拷走 DB 文件时只能得到 AES-GCM-256 密文；解锁运行期 runtime DB 仍需依赖系统防护 | 外部 Beta 阻塞已从本地明文转移到运行期、同步和服务端风险 |
| P0 | 已缓解 | 同步 payload 已升级为 `sroy-sync:` AES-256-GCM + HKDF envelope | 服务端只保存 opaque encrypted payload；仍需继续回归 envelope 校验和 vault 归属 | 已进入回归基线 |
| P0 | 已缓解 | 同步服务端没有身份认证/授权 | 任意知道地址的人都可读写 vault | Vault-level API token (`X-Vault-Token`) 已落地；legacy vault 保持匿名兼容 |
| P1 | 已缓解 | 主密码 verifier 已升级为 PBKDF2-HMAC-SHA256 | 不再直接用主密码明文做比对；后续仍需评估 KDF 参数、no-password 模式和生物识别密钥托管 | Beta 前安全复核项 |
| P1 | 已缓解 | 数据库打开失败会自动删库 | 会在损坏或异常时直接丢失本地数据 | 已改为保留损坏备份并抛错 |
| P1 | 已缓解 | 生物识别解锁会卡在 `alreadyInProgress` | 生物识别无法稳定进入主流程 | 已修复 |
| P1 | 已缓解 | 删除记录不会进入待同步队列 | 多设备会出现“本地删了，远端还在” | 已修复 |
| P1 | 已缓解 | 新安装实例默认共享固定测试 Vault | 不同安装实例之间数据会互串 | 已修复为默认独立身份 |
| P1 | 未关闭 | 旧安装若之前已写入固定测试 Vault 标识，仍可能继续使用旧共享数据 | 历史开发数据可能延续污染 | Beta 前建议重置旧测试数据 |
| P1 | 已缓解 | `flutter_secure_storage` 中仍保存生物识别回填主密码，且 no-password mode 需要重新定界 | 桌面端安全边界不足，UI 文案容易超过真实保护 | T15 已完成：biometric 改用 AES-256-GCM 加密信封；no-password 模式自动禁用 biometric |
| P2 | 已缓解 | 服务端 JSON 落盘不是原子写 | 宕机或异常中断时可能损坏 vault 文件 | 已改为 temp + backup + rename |
| P2 | 已缓解 | 服务端缺乏 push 输入校验 | 异常 payload 会导致脏写或崩溃 | 已加校验 |
| P2 | 未关闭 | 服务端仍允许 HTTP 明文接入 | 局域网或公网部署时易被窃听 | T16 需补 HTTPS/TLS 指引和客户端安全提示 |
| P2 | 已缓解 | 密钥恢复入口和文案混用“链接码 / 转移码 / 配对码” | 用户可能误把内部兼容码当作恢复能力，或在错误场景覆盖本地数据 | 已新增恢复路线矩阵，UI 区分面对面链接、远程配对、离线恢复码、内部兼容码 |
| P2 | 未关闭 | 缺少端到端集成测试 | 回归主要依赖局部单测与静态检查 | 下一轮建议补齐 |
| P3 | 未关闭 | 服务端仍保留未使用依赖 `sqlite3` / `ws` | 增加维护噪音 | 可后续清理 |

## Stage 1 新增已关闭风险

### T12. 敏感复制策略不一致

位置：
- `roy_client/lib/services/sensitive_clipboard_service.dart`
- `roy_client/lib/widgets/password_generator_sheet.dart`
- `roy_client/lib/views/sync_settings_view.dart`
- `roy_client/lib/widgets/account_list_tile.dart`
- `roy_client/lib/views/accounts/account_edit_view.dart`
- `roy_client/lib/views/accounts/totp_account_list_view.dart`
- `roy_client/lib/views/accounts/totp_credential_edit_view.dart`

原问题：
- 只有 TOTP 验证码复制使用自动清理；密码生成器、账号详情复制、配对码、恢复码等仍直接调用 `Clipboard.setData`，敏感内容长期停留在系统剪贴板。

当前处理：
- `SensitiveClipboardService` 重构为支持 `high`/`medium`/`low` 风险等级。
- `high` 风险（密码、配对码、恢复码、TOTP）默认 45 秒后自动清理。
- 新增 SHA-256 hash 比对：清理前检查剪贴板当前内容是否仍为原写入内容，避免误删用户后续复制。
- 7 个文件中的 10 处 raw `Clipboard.setData` 全部替换为统一策略。

### T9. 同步状态机语义模糊

位置：
- `roy_client/lib/sync/sync_service.dart`
- `roy_client/lib/views/sync_settings_view.dart`

原问题：
- `SyncState` 只有 5 个值，`error` 混合了网络超时、协议解析失败、payload 篡改、服务器 503 等完全不同的失败语义。
- UI 被迫通过解析 `syncErrorMessage` 字符串（`message.contains('vault file is unreadable')`、`message.contains('server address')` 等）来猜测内部失败原因。

当前处理：
- `SyncState` 扩展为 10 个精确状态：`offline`, `connecting`, `pulling`, `pushing`, `idle`, `conflictRecovery`, `networkUnreachable`, `serverError`, `protocolError`, `authError`。
- `_setError` 改为接收 typed `SyncState`，错误分类内聚在状态机。
- `sync_settings_view.dart` 删除所有 `message.contains(...)` 分支，UI 纯按 `SyncState` exhaustive switch 路由。

---

## 本次已关闭或显著缓解的风险

### 1. 自动删库风险

位置：

- `roy_client/lib/services/secure_storage_service.dart`

原问题：

- 打开数据库失败时直接 `deleteDatabaseFile()`，有极高概率把“可恢复故障”变成“不可恢复丢数”。

当前处理：

- 改为先备份为 `.corrupt.<timestamp>.bak`
- 抛出 `StorageOpenException`
- 不再在异常路径自动删库

### 2. 生物识别解锁失败风险

位置：

- `roy_client/lib/services/service_manager.dart`

原问题：

- 生物识别入口先把状态设置为 `unlocking`，随后又调用 `unlockWithPassword()`，后者检测到同态后直接返回 `alreadyInProgress`。

当前处理：

- 抽出共享解锁流程 `_completeUnlock()`
- 生物识别与密码解锁都走同一条真正的解锁执行路径

### 3. 删除墓碑不同步风险

位置：

- `roy_client/lib/services/secure_storage_service.dart`
- `roy_client/lib/sync/sync_service.dart`

原问题：

- `loadAccounts()` 默认过滤已删除数据，导致待同步删除记录不会被推送。

当前处理：

- 增加 `loadPendingSyncAccounts()`
- 增加 `getAccountById(includeDeleted: true)`
- pull/merge 过程可识别 tombstone，push 过程会带上删除项

### 4. 默认共享测试 Vault 风险

位置：

- `roy_client/lib/services/identity_service.dart`

原问题：

- 所有新设备都默认写死同一个 `vaultId/privateKey/symmetricKey`

当前处理：

- 新安装实例默认生成独立 mock identity
- 只有已有安全存储中的历史实例才继续沿用旧值

### 5. 服务端脏写和非法输入风险

位置：

- `roy_server/index.js`

当前处理：

- 加入 `validatePushes()`
- 限制批量数量和单条 payload 大小
- 使用原子写入流程保存 vault
- 输出健康检查接口 `/healthz`
- 支持 `node --test` 自动化测试

## Beta 发布建议

### 可以做

- 单人、本机或受控局域网内的功能测试
- UI、模板、CRUD、软删除、冲突收敛、同步基本流程验证
- 内部开发自测与小范围回归测试

### 不建议做

- 对外宣传为“安全密码管理器”
- 在公网开放同步服务
- 承载真实生产密码数据
- 让多名外部测试者直接共用当前服务端形态

## 发布门槛建议

### 内部功能 Beta

- 可以进入
- 前提是明确标注“非生产安全版本”

### 外部安全 Beta

- 暂不建议进入
- 至少补齐以下两项后再评估：
  - HTTPS/TLS 或等价受控传输边界
  - 运行期明文数据库保护和结构化诊断
