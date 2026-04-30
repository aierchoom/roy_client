# 本地出站同步审阅执行报告

| 项目 | 内容 |
|---|---|
| 日期 | 2026-04-29 |
| 类型 | 同步安全 / 产品链路 / 客户端实现 |
| 范围 | 账号、模板、本地密钥链接导入后的普通数据同步边界 |
| 结论 | 本轮只拦截本机出站推送，不增加远端删除审阅 |

## 1. 背景

原链路里，用户在本机编辑或删除账号后，`ServiceManager` 会立即触发
`_syncService.syncNow()`。这会让误删、误改在用户还没有复核前就上传到同步
服务器，其他可信客户端启动后会拉取并应用该结果。

新的业务边界是：

1. 每个客户端都是可信终端。
2. 本机产生的编辑和删除，必须先进入本机待审队列。
3. 用户确认推送后，服务器保存该变更。
4. 其他客户端拉取到已确认变更后可以直接应用，除非它们本地已有冲突。
5. 不做远端删除审阅，避免把可信客户端模型复杂化。

## 2. 当前实现链路

### 2.1 本地编辑链路

```text
UI 保存账号/模板
-> EnhancedAppProvider
-> ServiceManager.saveAccount/saveTemplate
-> SecureStorageService 写入本地 SQLite
-> 记录 local_sync_changes
-> SyncService.markDirty()
-> 等待用户在首页确认推送
```

本轮已移除普通保存后的自动 `syncNow()`。

### 2.2 本地删除链路

```text
UI 删除账号/模板
-> ServiceManager.deleteAccount/deleteTemplate
-> SecureStorageService 写入 tombstone
-> 记录 delete 类型 local_sync_changes
-> 首页提示这是删除类变更
-> 用户确认后才允许推送 tombstone
```

如果记录是“本机新建但还没推送，随后又删除”，系统会取消这条 outbox
变更并硬删除本地草稿，不再向服务器推送一个无意义 tombstone。

### 2.3 启动和周期同步链路

启动、连接和周期同步仍可以执行 `syncNow()`，但 `_runPushPhase()` 只读取
`approved` 状态的本地变更。未审阅变更即使处于 `pendingPush`，也不会进入
POST 请求。

```text
syncNow()
-> pull 远端已确认变更
-> 只 push approved 本地变更
-> pendingReview 本地变更继续留在首页
```

## 3. 执行分线

### 分线 A：出站推送收口

改动目标：

- 普通编辑和删除不再自动推送。
- 手动同步、启动同步、周期同步都不能绕过本地审阅队列。

落点：

- `lib/services/service_manager.dart`
- `lib/sync/sync_service.dart`

验收：

- 保存账号后本地 dirty，但服务器不会收到 POST。
- 删除账号后首页出现待同步删除项。
- 用户点“推送”后才会上传。

### 分线 B：本地 outbox 数据模型

新增模型和存储表：

- `lib/models/local_sync_change.dart`
- `local_sync_changes` SQLite 表

核心字段：

- `entity_type`: account/template
- `entity_id`
- `action`: create/update/delete
- `before_json`
- `after_json`
- `diff_json`
- `status`: pendingReview/approved/pushing/pushed/failed/conflict/reverted
- `base_server_version`

合并规则：

- 同一实体连续编辑合并为一条 update。
- create 后 delete 取消变更并删除本地草稿。
- update 后 delete 转成 delete，并保留最初 before 快照。
- delete 变更可以在首页撤销。

### 分线 C：首页审阅入口

改动目标：

- 首页出现待同步变更区域。
- 用户可以查看变更摘要、推送单项、推送全部、撤销本地变更。
- 删除类变更使用更强风险提示。

落点：

- `lib/views/home/home_search_view.dart`
- `lib/providers/enhanced_app_provider.dart`

当前展示：

- 变更数量
- 账号/模板名称
- 新增、修改、删除动作
- 变更字段摘要
- 推送和撤销入口

### 分线 D：同步状态机改造

`SyncService._runPushPhase()` 现在只处理 approved changes：

```text
loadApprovedLocalSyncChanges()
-> 提取 approved account/template id
-> 过滤 pendingPush 数据
-> POST approved 数据
-> 成功后标记 pushed
-> 失败后标记 failed/conflict
```

`sync_dirty_$vaultId` 不再简单等同于“本地是否有 pendingPush 数据”，而是结合
open outbox 变更判断。只要还有 pendingReview/approved/pushing/failed/conflict
变更，dirty 状态就保持为 true。

### 分线 E：密钥链接和导入后续边界

本轮实现给密钥链接后的普通数据同步建立了出站闸门。后续还需要继续收敛：

1. vault dump 导入时不要把所有导入账号无条件标记为 synchronized。
2. 如果导入数据里有 `serverVersion = 0` 或 `pendingPush`，应生成待同步队列。
3. 如果导入包里有 tombstone，应作为本机待审删除展示，而不是静默推送。
4. 导入完成后首页需要明确提示“有导入数据等待同步确认”。

这条是下一轮密钥同步健壮性收敛重点。

## 4. 不做事项

本轮明确不做远端删除审阅。

原因：

- 你的业务模型是“每个客户端可信”。
- 已经经过某个客户端本机审阅并推送的删除，其他客户端可以直接接受。
- 只有本地存在未推送修改时，才进入冲突处理。

## 5. 风险和剩余问题

1. 用户可能长期忘记推送，需要后续增加更明显的角标或提醒。
2. 当前 diff 还是摘要级，尚未做完整字段级 before/after 展示。
3. vault dump 导入后的 syncStatus/outbox 生成还需要下一轮继续做。
4. 当前推送仍是实体快照模型，diff 只用于用户审阅，不用于服务端 patch。
5. 账号和模板如果出现相同实体 ID，outbox 状态更新必须继续按 entity type + entity id 组合匹配。

## 6. 本轮验证

已通过：

- `dart analyze lib test`
- `flutter test test/sync/sync_state_machine_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/multi_device_sync_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_conflict_recovery_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_recovery_loop_test.dart --reporter expanded --timeout 30s`

其中状态机测试新增覆盖：

- 未审阅本地变更不会发起 push POST。
- 未审阅数据保留 `pendingPush`。
- 同步状态提示本地变更仍等待审阅。
- approved outbox 状态按 `entityType + entityId` 匹配，避免账号和模板同 ID 时误标记。

`docs/product/application-characteristics.md` 已检查并同步更新测试残留状态。
