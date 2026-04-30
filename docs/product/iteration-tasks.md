# SecretRoy 迭代任务清单

**最后更新**: 2026-04-30
**文档定位**: 当前阶段逐项执行的产品/工程任务列表
**执行原则**: 一次只推进一个主任务，完成验收和文档同步后再进入下一项

## 1. 使用规则

本清单用于我们后续“一项一项做”。每个任务开始前，先确认：

1. 是否影响 `docs/product/application-characteristics.md` 的全局功能地图或准入规则。
2. 是否需要新增功能级文档、执行报告或测试维护文档。
3. 是否可以按最小可维护单元拆分，而不是继续把代码塞进已有大文件。
4. 是否有明确验收命令、手动验收路径或剩余风险说明。

任务完成标准：

```text
代码实现完成
-> 最小必要测试通过或残留风险写清
-> 文档同步
-> application-characteristics.md 已检查
-> 工作区可整理提交
```

勾选规则：

```text
完成一个任务，就勾选一个任务。
任务未完成前，不提前标记完成。
完成当前任务后，将总表状态改为“完成”，并把下一项改为“进行中”。
如果任务只完成了部分子项，只勾选子项，不改总任务状态。
```

状态含义：

| 状态 | 含义 |
|---|---|
| 未开始 | 尚未进入实现 |
| 进行中 | 当前正在开发或收口 |
| 待验证 | 代码已完成，等待测试、手动验收或文档收敛 |
| 阻塞 | 需要先解决依赖或环境问题 |
| 完成 | 已实现、验证、文档同步并可提交 |

## 2. 当前执行顺序

| 顺序 | 状态 | 任务 | 目标 |
|---|---|---|---|
| T0 | 完成 | 本地出站同步审阅收口 | 让本机编辑/删除先进入首页审阅，再由用户确认推送 |
| T1 | 完成 | 真实化 vault/device identity | 去掉过渡身份，建立可持久化、可推理的 vault/device 生命周期 |
| T2 | 完成 | 同步元数据按 vault 隔离 | 避免 dirty、版本号、恢复标记在多 vault/多环境下串用 |
| T3 | 完成 | 同步 payload 标准 AEAD/E2EE | 将普通同步 payload 保护升级为标准加密/认证边界 |
| T4 | 完成 | 冲突类型正式化 | 不再把主要冲突都压成通用 409 |
| T5 | 完成 | 冲突恢复路径扩展 | remote missing、stale base、并发编辑、并发删除都有明确分支 |
| T6 | 完成 | CRDT merge 不变量测试 | 给合并逻辑建立长期回归护栏 |
| T7 | 完成 | 最小双设备集成测试 | 用自动化场景覆盖多设备新增、编辑、删除、离线恢复 |
| T8 | 完成 | 崩溃恢复闭环 | pull/push/数据库替换中断后可恢复 |
| T9 | 未开始 | 同步状态机清理 | 让 UI 消费稳定状态，不猜内部失败 |
| T10 | 未开始 | 服务端持久化语义加固 | 强化薄后端的校验、幂等、错误分类和半写入恢复 |
| T11 | 计划中 | 2FA/TOTP 动态验证码 | 账号内置 TOTP 密钥保存、验证码生成、复制和同步 |

## 3. T0 本地出站同步审阅收口

目标：

- 普通账号/模板编辑后不自动 push。
- 本机删除先进入待审队列。
- 首页可以查看、推送、撤销本地待同步变更。
- 启动同步、周期同步、手动同步都不能绕过 `pendingReview`。

当前已完成基础实现：

- 新增 `LocalSyncChange` 数据模型。
- 新增 `local_sync_changes` 本地表。
- `ServiceManager` 保存/删除链路记录 outbox。
- `SyncService._runPushPhase()` 只推送 approved 本地变更。
- 首页展示待同步变更。

待收口：

- [x] 复查当前 diff，确认没有把同步审阅逻辑塞进单个过大模块。
- [x] 补齐或修正失败文案，确保用户能理解“未推送”和“推送失败”的区别。
- [x] 复查 create -> delete、update -> delete、delete -> revert 的边界。
- [x] 重新运行可稳定通过的最小测试集。
- [x] 复跑长链路测试，并同步移除过期的超时残留说明。
- [x] 更新执行报告和全局特性文档检查记录。

完成记录：

- `SyncService` 出站 push 只处理 approved outbox。
- outbox 状态更新按 `entityType + entityId` 匹配，避免账号和模板同 ID 时误标记。
- `dart analyze lib test` 通过。
- `sync_state_machine_test.dart`、`multi_device_sync_test.dart`、`sync_conflict_recovery_test.dart`、`sync_recovery_loop_test.dart` 通过。

验收：

- 保存账号后只出现本地待同步变更，不自动上传。
- 删除账号后首页显示删除风险项。
- 点击推送后才允许进入 push。
- 点击撤销后本地状态可解释，不留下悬空 outbox。

## 4. T1 真实化 vault/device identity

目标：

- 去掉固定或过渡 `vaultId`。
- 每个本地 vault 都有真实、持久、可恢复的身份。
- 每台设备有自己的唯一 `deviceId`。
- 密钥同步后，新设备继承同一 `vaultId`，但保留自己的 `deviceId`。

涉及范围：

- `lib/services/identity_service.dart`
- `lib/services/service_manager.dart`
- `lib/sync/sync_service.dart`
- 密钥链接导入链路
- 同步初始化链路

任务拆分：

- [x] 梳理当前 `vaultId`、`deviceId` 生成和读取路径。
- [x] 明确首次初始化、重启读取、导入密钥链接、identity 损坏四种分支。
- [x] 去掉硬编码或测试态身份。
- [x] 为 identity 未初始化/缺失/损坏建立明确错误。
- [x] 补 `identity_service_test.dart` 或等价测试。
- [x] 更新密钥同步和全局功能地图相关文档。

完成记录：

- `IdentityService.initialize()` 支持在已有数据库场景禁止静默生成新 vault identity。
- `ServiceManager` 解锁时会先判断本地数据库是否存在；已有数据库但 identity 缺失/损坏时进入明确失败。
- 缺失 `deviceId` 但 vault identity 完整时，允许修复本机 `deviceId`，不改变 `vaultId`。
- `checkIdentityExists()` 会校验 vault identity 格式，不再只检查 key 是否存在。
- `UnlockView` 不再把“已有数据库但 identity 缺失”当作首次运行自动重建。
- `dart analyze lib test`、`identity_service_test.dart`、`sync_service_identity_test.dart` 通过。

验收：

- 新安装设备首次启动生成稳定 `vaultId`。
- 应用重启后 `vaultId` 不变。
- 两个独立安装默认不共享 `vaultId`。
- 密钥链接导入后 `vaultId` 与旧设备一致，`deviceId` 仍为本机唯一。
- identity 异常不会伪装成同步成功。

## 5. T2 同步元数据按 vault 隔离

目标：

- 所有 sync metadata 都能明确归属到当前 vault。
- 避免未来多 vault、多环境、多服务器配置下状态串用。

涉及范围：

- `lib/sync/sync_service.dart`
- `lib/services/secure_storage_service.dart`
- 本地 settings key
- sync dirty/version/recovery marker
- sync server url

任务拆分：

- [x] 搜索所有 sync 相关 settings key。
- [x] 制定统一命名规则，例如 `sync_dirty_$vaultId`。
- [x] 为历史单 vault key 提供一次性迁移。
- [x] 确保 pending outbox、conflict log、recovery marker 不跨 vault 串用。
- [x] 补同步元数据隔离测试。

完成记录：

- `sync_version`、`sync_dirty`、`sync_last_time`、`sync_recovery` 均按 `$vaultId` 隔离。
- `sync_server_url` 支持按 vault 读写和 legacy 迁移。
- `local_sync_changes` 已按 `vault_id` 查询；conflict log 当前仍跟随单 vault 本地库，真正多 vault 同库前需再评估。
- `dart analyze lib test`、`sync_service_identity_test.dart`、`sync_state_machine_test.dart`、`sync_recovery_loop_test.dart` 通过。

验收：

- 同一设备切换不同 vault 时，dirty/version/recovery 状态不共享。
- 历史数据升级后不丢失同步状态。
- 代码中能追踪每个 sync metadata key 的 vault 归属。

## 6. T3 同步 payload 标准 AEAD/E2EE

目标：

- 将普通同步 payload 保护从过渡实现升级到标准 AEAD/E2EE 边界。
- 服务端继续只保存 opaque payload，不能理解账号明文。

涉及范围：

- `lib/sync/sync_payload_codec.dart`
- `lib/sync/sync_service.dart`
- `lib/services/enhanced_crypto_service.dart`
- `lib/services/identity_service.dart`

任务拆分：

- [x] 审计当前 payload envelope、nonce、签名/校验实现。
- [x] 明确 vault symmetric key 来源、派生和轮换边界。
- [x] 保留高层 encode/decode 接口，降低调用层改动。
- [x] 建立 payload 篡改、身份不匹配、无法解密的正式错误。
- [x] 补充 `sync_payload_codec_test.dart` 的 AEAD、篡改、vault 不匹配、legacy 明文拒绝测试。

完成记录：

- `SyncPayloadCodec` 从自定义 XOR keystream + HMAC 过渡实现切换为 `AesGcm.with256bits()`。
- payload envelope 使用 `sroy-sync:` 前缀、`alg=aes-256-gcm-hkdf-sha256`、12 字节 nonce、随机 salt 和 AEAD mac。
- payload key 由 vault symmetric key + vault private key 经 HKDF-SHA256 派生；AEAD AAD 绑定版本、算法、vaultId、nodeId。
- 旧的 base64 明文 JSON payload 不再被静默接受，避免远端或服务端绕过加密边界。
- `SyncService`、`VaultDumpCoordinator` 已适配 async encode/decode。
- `dart analyze lib test`、`sync_payload_codec_test.dart`、`sync_state_machine_test.dart`、`sync_conflict_recovery_test.dart`、`sync_recovery_loop_test.dart`、`sync_service_identity_test.dart`、`multi_device_sync_test.dart` 通过。

验收：

- 远端 payload 被篡改时客户端拒绝导入。
- 非当前 vault 的 payload 不能静默接受。
- payload 无法解密时同步进入明确失败状态。
- 正常 pull/push 保持现有行为。

## 7. T4 冲突类型正式化

目标：

- 把“冲突”从单一 HTTP 状态变成可处理的协议语义。

涉及范围：

- `roy_server` pairing/sync routes
- `lib/sync/sync_service.dart`
- conflict inbox 数据结构

任务拆分：

- [x] 服务端返回 machine-readable conflict type。
- [x] 至少区分 `remote_missing`、`stale_base_version`、`concurrent_edit`、`concurrent_delete`、`invalid_payload`。
- [x] 客户端按类型进入不同恢复分支。
- [x] 补服务端 conflict type 测试。
- [x] 补客户端 conflict handling 测试。

完成记录：

- 服务端已有 `remote_missing`、`stale_base_version`、`concurrent_edit`、`concurrent_delete` 冲突分类。
- 服务端新增 `SyncPayloadValidationError`，将非法同步 payload 归类为 `invalid_payload`，响应体包含 `conflict_type` 和 `item_id`。
- 服务端只校验 opaque sync envelope 的最低协议形态，不解密、不理解账号内容。
- 客户端 `_SyncHttpException` 解析 `conflict_type`，对 `invalid_payload` 给出明确失败状态和用户可理解文案。
- `node --test test/index.test.js`、`dart analyze lib test`、`sync_state_machine_test.dart` 通过。

验收：

- 客户端不再把主要冲突都落入“重试后失败”。
- 每一种冲突类型都有明确处理策略。
- 服务端返回体可被测试稳定断言。

## 8. T5 冲突恢复路径扩展

目标：

- 从“能处理 remote missing”升级到“主要冲突都能收敛”。

任务拆分：

- [x] 保留 remote missing 现有恢复路径。
- [x] 增加 stale base 的重新 pull + merge。
- [x] 增加并发编辑的自动 merge / inbox 分流。
- [x] 增加并发删除的 tombstone 优先或恢复策略。
- [x] 让 inbox 显示冲突来源、类型和建议动作。

完成记录：

- `SyncService` 将 `remote_missing`、`stale_base_version`、`concurrent_edit`、`concurrent_delete` 拆成明确恢复分支。
- `remote_missing` 继续生成 `record.remote_missing` 冲突记录，用户可在冲突箱选择覆盖远端。
- `stale_base_version` 和 `concurrent_edit` 走重新拉取快照 + CRDT merge；字段冲突进入 conflict inbox。
- `concurrent_delete` 保持 tombstone 优先规则，远端删除胜出时给出明确同步提示，不静默变成“已最新”。
- 冲突箱行内显示冲突类型、来源节点和建议动作。
- `dart analyze lib test`、`sync_conflict_recovery_test.dart`、`sync_state_machine_test.dart`、`multi_device_sync_test.dart`、`crdt_merge_engine_test.dart` 通过。

验收：

- 主要冲突路径最终进入 `synchronized`、`pendingPush` 或 `conflict`。
- 不出现既失败又没有诊断信息的状态。
- 用户能理解冲突原因和下一步操作。

## 9. T6 CRDT merge 不变量测试

目标：

- 给合并逻辑建立长期回归护栏。

任务拆分：

- [x] 覆盖相同输入必得相同输出。
- [x] 覆盖 merge 结果不产生非法空字段。
- [x] 覆盖 tombstone 胜负规则稳定。
- [x] 覆盖 conflict log 不改变主结果。
- [x] 覆盖双端交错编辑后结果可再次 push。

验收：

- `crdt_merge_invariants_test.dart` 能稳定运行。
- 修改 merge 逻辑时能快速暴露收敛性问题。

完成记录：

- `crdt_merge_invariants_test.dart` 覆盖同输入确定性、data key 与 HLC 对齐、墓碑胜负、conflict log 不影响主合并结果、交错字段合并后可再次 push。
- merge 结果断言包含非空主字段、模板/创建时间继承、data/dataHlc key 一致、远端版本对齐和最终 `syncStatus`。
- `flutter test test\sync\crdt_merge_invariants_test.dart` 通过。
- 已更新执行报告和全局特性文档检查记录。

## 10. T7 最小双设备集成测试

目标：

- 让多设备同步不再主要依赖人工点击验证。

任务拆分：

- [x] 构造两个客户端副本与一个服务端实例。
- [x] 覆盖 A 新增、B 拉取。
- [x] 覆盖 A/B 并发编辑不同字段。
- [x] 覆盖 A 删除、B 修改。
- [x] 覆盖 A 离线修改、恢复后 push。
- [x] 断言最终数据、syncStatus、conflict inbox/conflict log。

验收：

- `multi_device_sync_test.dart` 拆成可稳定运行的最小场景。
- 测试失败时能定位到具体同步阶段。

完成记录：

- `multi_device_sync_test.dart` 使用两个内存客户端和一个内存 vault server 覆盖多设备最小链路。
- 场景覆盖 A 新增/B 拉取、A/B 并发字段编辑、A 删除/B 修改、A 离线本地编辑后恢复 push。
- 断言覆盖服务器版本、本地 `syncStatus`、最终账号数据、tombstone、conflict log 和恢复后 B 端拉取结果。
- `flutter test test\sync\multi_device_sync_test.dart` 通过。
- 离线期间如果主动触发 sync 并留下 interrupted pull marker，会进入 T8 崩溃/中断恢复语义；本任务只覆盖离线编辑后恢复网络再推送。

## 11. T8 崩溃恢复闭环

目标：

- 让中途失败成为可回放、可恢复的正式场景。

任务拆分：

- [x] 明确 pull 中断恢复。
- [x] 明确 push 中断恢复。
- [x] 明确数据库替换中断恢复。
- [x] 增加必要阶段标记。
- [x] 补 crash recovery tests。

验收：

- 模拟中断后，重新启动能恢复到一致状态。
- 不因部分成功导致版本号错乱。

完成记录：

- `pull` marker 恢复现在从 marker 的 `localVersion` 拉取增量，远端没有新版本时不会把本地 `pendingPush` 误转成冲突。
- `push` marker 保持快照恢复语义，避免重复 post 已可能被服务端接受的 payload。
- 加密数据库启动准备阶段会恢复原子替换中断留下的 `.bak`，并清理 `.tmp` 残留，避免主文件缺失时创建空库。
- 新增 interrupted pull + 本地 pendingPush + 远端无新版本测试，确认恢复后继续 push 并同步到新 serverVersion。
- 新增加密数据库替换中断测试，确认 `.enc` 主文件缺失、`.bak` 和 `.tmp` 同时残留时可恢复旧库并清理残留文件。
- 已通过：
  - `flutter test test\sync\sync_recovery_loop_test.dart`
  - `flutter test test\services\secure_storage_service_encryption_test.dart`
  - `flutter test test\sync\sync_state_machine_test.dart test\sync\sync_conflict_recovery_test.dart test\sync\multi_device_sync_test.dart test\sync\sync_recovery_loop_test.dart`
  - `dart analyze lib test`
  - `flutter test`，结果为 78 passed, 1 skipped；跳过项仍是 Windows runner 下不稳定的 UDP broadcast discovery。

## 12. T9 同步状态机清理

目标：

- 避免 `offline`、`syncing`、`synced`、`error`、`conflictRecovery` 语义互相打架。

任务拆分：

- [ ] 画出当前状态迁移。
- [ ] 区分网络离线、冲突处理中、协议错误、可恢复失败。
- [ ] 让 UI 只消费稳定状态。
- [ ] 清理零散状态推断。
- [ ] 补状态机测试。

验收：

- 每个状态都有明确进入条件和退出条件。
- UI 不再通过内部细节猜同步情况。

## 13. T10 服务端持久化语义加固

目标：

- 保持薄后端路线，同时提升写入可靠性和诊断能力。

任务拆分：

- [ ] 明确写入前校验。
- [ ] 明确写入后确认。
- [ ] 明确重复请求幂等语义。
- [ ] 明确异常分类和半写入恢复路径。
- [ ] 补服务端持久化测试。

验收：

- 服务端对重复请求、非法 payload、半写入失败有稳定行为。
- 错误返回不会泄露 vault 秘密。
- 客户端能根据错误类型给出可解释状态。

## 14. T11 2FA/TOTP 动态验证码

目标：

- 在账号中保存网站 2FA/TOTP 密钥，并在本地生成动态验证码。

计划文档：

- `docs/features/two-factor-auth/feasibility-and-implementation-plan.md`

任务拆分：

- [ ] 实现 TOTP service、Base32 和 `otpauth://` 解析。
- [ ] 新增 `AccountFieldType.totp` 并接入模板编辑。
- [ ] 给内置网站模板增加可选 `totp_secret` 字段。
- [ ] 在账号编辑/查看页增加 TOTP 专用控件、验证码倒计时和复制动作。
- [ ] 验证 outbox、同步、冲突恢复和多设备一致性。
- [ ] 补执行报告、全局特性文档和测试维护说明。

验收：

- 固定时间戳下 TOTP 结果符合 RFC 6238 向量。
- 粘贴 Base32 secret 或 `otpauth://totp` URI 后可保存并生成验证码。
- TOTP secret 默认隐藏、不参与搜索、不被服务端明文读取。
- 未审阅的 TOTP 修改不会自动 push；批准后可信设备可同步并生成同一验证码。
