# SecretRoy 分布式系统质量改造 Backlog

Navigation:
[Docs Home](C:\Users\choom\Desktop\CodeRepo\roy\docs\README.md) |
[Architecture Index](C:\Users\choom\Desktop\CodeRepo\roy\docs\ARCHITECTURE_DOCS_INDEX.md) |
[Quality Iteration Plan](C:\Users\choom\Desktop\CodeRepo\roy\docs\04_Distributed_System_Quality_Iteration_Plan.md)

| 项目 | 内容 |
|---|---|
| 文档类型 | 可执行任务清单 |
| 适用对象 | 客户端、服务端、协议、测试维护者 |
| 范围 | 本地优先同步系统质量迭代 |
| 最后更新 | 2026-04-21 |

## 1. 使用方式

这份文档不是原则说明，而是直接面向实施的 backlog。

建议执行顺序：

1. 先做 `P0`，不要并行跳做 `P1`
2. `P0` 完成后，补齐对应测试，再进入 `P1`
3. `P2` 只有在协议、恢复、测试基线稳定后再做

建议完成标准：

- 每项任务都要有代码改动
- 每项任务都要有至少一个自动化验证
- 每项任务都要明确“不变量”或“验收条件”

## 2. 当前阶段目标

本轮改造目标不是加功能，而是把系统从“能跑的原型”推进到“可信的本地优先同步系统”。

本轮只围绕五件事：

- 身份真实性
- 协议真实性
- 冲突可收敛
- 恢复可验证
- 测试可托底

## 3. P0 必做项

### P0-01 真实化 vault / device identity

目标：

- 去掉固定 `vaultId`
- 让每个本地库都拥有真实、可持久化、可推理的身份

涉及文件：

- `roy_client/lib/services/identity_service.dart`
- `roy_client/lib/services/service_manager.dart`
- `roy_client/lib/sync/sync_service.dart`

实施要点：

- `vaultId` 不再硬编码返回 `pub_test_global_vault_001`
- 统一使用初始化后的 `_vaultId`
- 明确 `deviceId`、`vaultId` 的生成、持久化和读取流程
- 为 identity 未初始化、identity 缺失、identity 损坏建立错误分支

验收标准：

- 新安装设备首次初始化后可稳定生成并持久化 `vaultId`
- 重启应用后 `vaultId` 不变
- 两个独立安装实例默认不会共享同一个 `vaultId`
- 未初始化 identity 时不会进入假同步成功状态

建议测试：

- `identity_service_test.dart`
- `sync_service_identity_test.dart`

### P0-02 把同步元数据全部按 vault 隔离

目标：

- 消除多 vault、多环境下元数据串用风险

涉及文件：

- `roy_client/lib/sync/sync_service.dart`
- `roy_client/lib/services/secure_storage_service.dart`

实施要点：

- 将 `sync_dirty` 改为 `sync_dirty_$vaultId`
- 审查所有 sync 相关 settings key，统一命名规则
- 给旧 key 提供一次性兼容迁移

验收标准：

- 同一设备上切换不同 vault 时，不共享 dirty 状态
- 历史单 vault 数据升级后不丢失同步状态
- 所有 sync metadata key 都能从代码中明确追踪归属

建议测试：

- `sync_metadata_namespace_test.dart`

### P0-03 把 payload “加密签名”从占位实现改成正式实现

目标：

- 让同步消息具备基本真实性，不再只是 base64 包装

涉及文件：

- `roy_client/lib/sync/sync_service.dart`
- `roy_client/lib/services/enhanced_crypto_service.dart`
- `roy_client/lib/services/identity_service.dart`

实施要点：

- 替换 `_encryptAndSign()` / `_decryptAndVerify()`
- 明确加密、签名、验签、解密的责任边界
- 为 payload 解析失败、验签失败、身份不匹配建立正式错误
- 不要把“安全完整方案”耦合进 UI 层

验收标准：

- 远端 payload 被篡改时客户端能拒绝导入
- 非当前 vault 的 payload 不能被静默接受
- payload 无法解密时同步进入明确失败状态
- 正常 pull / push 仍保持现有基本行为

建议测试：

- `sync_payload_crypto_test.dart`
- `sync_payload_validation_test.dart`

### P0-04 正式化冲突类型，而不是只依赖一个 409

目标：

- 把“冲突”从单一 HTTP 状态变成可处理的协议语义

涉及文件：

- `roy_server/index.js`
- `roy_client/lib/sync/sync_service.dart`

实施要点：

- 为冲突增加 machine-readable 类型
- 至少区分：
  - `remote_missing`
  - `stale_base_version`
  - `concurrent_edit`
  - `concurrent_delete`
  - `invalid_payload`
- 客户端按类型进入不同恢复分支

验收标准：

- 客户端不再把大多数冲突都落入“重试三次然后失败”
- 每一种冲突类型都能映射到明确处理策略
- 服务端返回体可被测试稳定断言

建议测试：

- `roy_server/test/conflict_types.test.js`
- `sync_conflict_handling_test.dart`

### P0-05 扩充 `_handleConflict()` 的恢复路径

目标：

- 从“只处理远端缺失”升级到“能覆盖主要冲突”

涉及文件：

- `roy_client/lib/sync/sync_service.dart`
- `roy_client/lib/sync/crdt_merge_engine.dart`
- `roy_client/lib/views/conflict_inbox_view.dart`

实施要点：

- 保留已有 `remote missing` 逻辑
- 增加 `stale_base_version` 的重新 pull + merge
- 增加并发编辑时的自动 merge / inbox 分流
- 增加并发删除时的 tombstone 优先或恢复策略
- 让 inbox 接收到的是“明确冲突类型”，而不只是字段残留

验收标准：

- 主要冲突路径都能收敛到 `synchronized`、`pendingPush` 或 `conflict`
- 不出现既失败又没有诊断信息的悬空状态
- conflict inbox 中的项目能解释来源和处理建议

建议测试：

- `sync_stale_base_test.dart`
- `sync_concurrent_edit_test.dart`
- `sync_delete_conflict_test.dart`

### P0-06 为 merge engine 写正式不变量测试

目标：

- 给当前 CRDT 合并逻辑建立可持续演进的护栏

涉及文件：

- `roy_client/lib/sync/crdt_merge_engine.dart`
- `roy_client/test/sync/crdt_merge_engine_test.dart`

实施要点：

- 在现有样例测试之外补充 invariant tests
- 至少覆盖：
  - 相同输入必得相同输出
  - merge 结果不产生非法空字段
  - tombstone 胜负规则稳定
  - 冲突日志不改变主结果
  - 双端交错编辑后结果可再次 push

验收标准：

- 合并规则有一组清晰命名的测试
- 改 merge 逻辑时能快速知道是否破坏收敛假设

建议测试：

- `crdt_merge_invariants_test.dart`

### P0-07 建立最小双设备集成测试

目标：

- 让同步不再只靠人工点击验证

涉及文件：

- `roy_client/test/`
- `roy_server/test/`

实施要点：

- 构造两个客户端副本与一个服务端实例
- 覆盖以下场景：
  - A 新增，B 拉取
  - A/B 并发编辑不同字段
  - A 删除，B 修改
  - A 离线修改，恢复后 push

验收标准：

- 每个场景都能断言最终状态
- 每个场景都能断言本地 `syncStatus`
- 至少一组测试断言 conflict inbox / conflict log

建议测试：

- `multi_device_sync_test.dart`

## 4. P1 高优先级项

### P1-01 写出同步协议不变量文档

目标：

- 让实现不再只靠“读代码理解”

涉及文件：

- `docs/secret_roy_sync_protocol.md`
- `docs/04_Distributed_System_Quality_Iteration_Plan.md`

实施要点：

- 明确客户端、服务端各自负责什么
- 明确 `serverVersion`、`HLC`、`syncStatus` 的关系
- 列出 merge invariants 与 recovery invariants

验收标准：

- 新开发者能只靠文档理解同步主流程
- 关键状态不再依赖口头共识

### P1-02 建立崩溃恢复闭环

目标：

- 让“中途失败”成为可回放、可恢复的正式场景

涉及文件：

- `roy_client/lib/services/secure_storage_service.dart`
- `roy_client/lib/sync/sync_service.dart`

实施要点：

- 明确 pull 中断、push 中断、replaceDatabase 中断后的恢复逻辑
- 加入必要的恢复标记或阶段标记
- 补一套 crash recovery tests

验收标准：

- 模拟中断后，重新启动能恢复到一致状态
- 不会因为部分成功导致版本号错乱

### P1-03 强化服务端持久化语义

目标：

- 让当前薄后端更稳，而不是更复杂

涉及文件：

- `roy_server/index.js`
- `roy_server/test/`

实施要点：

- 明确写入前校验、写入后确认、异常恢复路径
- 评估是否拆分快照和版本日志
- 为不可读 vault、半写入恢复、重复 push 补测试

验收标准：

- 服务端行为对重复请求和异常中断更可预测
- 错误返回有更稳定的分类

### P1-04 清理同步状态机

目标：

- 避免 `offline / syncing / synced / error / conflictRecovery` 语义互相打架

涉及文件：

- `roy_client/lib/sync/sync_service.dart`
- `roy_client/lib/views/sync_settings_view.dart`

实施要点：

- 梳理状态迁移图
- 区分“网络离线”“冲突处理中”“协议错误”“可恢复失败”
- 让 UI 只消费清晰状态，不猜测内部逻辑

验收标准：

- 每个状态都有明确进入条件和退出条件
- UI 不再通过零散判断推断同步情况

## 5. P2 中期项

### P2-01 引入 property-based / model-based 测试

目标：

- 从样例覆盖升级到性质覆盖

建议范围：

- HLC 比较
- merge 收敛
- 重复同步幂等
- 操作顺序扰动后的最终结果

### P2-02 建立数据修复工具

目标：

- 当本地或远端状态异常时，团队有办法修，不是只能删库重来

建议范围：

- 校验本地 sync metadata
- 校验 conflict logs
- 校验 tombstone 与 serverVersion 一致性
- 输出修复建议或修复脚本

### P2-03 重构服务端存储层

目标：

- 保持薄后端路线，同时把耐久性和诊断能力拉起来

建议方向：

- 保留版本协调职责
- 增强存储抽象
- 减少 JSON 文件单点限制

## 6. 推荐实施顺序

推荐按下面顺序开工：

1. `P0-01` identity
2. `P0-02` sync metadata namespace
3. `P0-03` payload crypto/signature
4. `P0-04` conflict typing
5. `P0-05` conflict recovery
6. `P0-06` merge invariants tests
7. `P0-07` multi-device integration tests
8. `P1-02` recovery loop
9. `P1-04` state machine cleanup
10. `P1-03` server persistence semantics

## 7. 建议如何拆 issue

每个 issue 建议固定包含这五段：

- 背景
- 目标
- 影响文件
- 验收标准
- 测试要求

建议不要创建“优化同步体验”“完善冲突处理”这类太大的 issue，而要拆成：

- `fix: namespace sync dirty flag by vault`
- `feat: persist real vault identity`
- `feat: classify sync conflicts by type`
- `test: add merge invariants coverage`

## 8. 一句话执行建议

先把 identity、payload、conflict、recovery、test 这五条线补硬，再讨论更大的系统演进；否则任何功能扩展都会把原型期欠下的协议债放大。

---

Navigation:
[Docs Home](C:\Users\choom\Desktop\CodeRepo\roy\docs\README.md) |
[Architecture Index](C:\Users\choom\Desktop\CodeRepo\roy\docs\ARCHITECTURE_DOCS_INDEX.md) |
[Quality Iteration Plan](C:\Users\choom\Desktop\CodeRepo\roy\docs\04_Distributed_System_Quality_Iteration_Plan.md)
