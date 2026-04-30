# 本地出站同步审阅长期测试维护文档

**功能点**: 本地出站同步审阅
**适用项目**: `roy_client`
**维护目标**: 防止本机误删、误改在用户未审阅前自动扩散到其他设备
**最后更新**: 2026-04-30
**状态**: 第一版实现已落地，长链路测试已纳入 T0-T8 当前回归基线；测试生命周期拆分仍作为长期维护项保留

## 1. 功能结论

本功能的长期业务原则是：

```text
本机产生的普通数据变更，必须先进入本机待审队列。
用户确认后，才允许推送到同步服务器。
其他可信客户端拉取到已经推送的远端变更，可以直接应用。
```

明确不做：

- 不做远端删除审阅。
- 不把 diff 当作服务端 patch。
- 不让启动同步、周期同步、手动普通同步绕过本地待审队列。

## 2. 当前代码边界

| 层级 | 文件 | 长期关注点 |
|---|---|---|
| 模型 | `lib/models/local_sync_change.dart` | 本地待审变更状态、动作和实体类型 |
| 存储 | `lib/services/secure_storage_service.dart` | `local_sync_changes` 表、变更合并、状态流转、撤销 |
| 服务门面 | `lib/services/service_manager.dart` | 编辑/删除入口不自动同步，记录 outbox，手动批准后推送 |
| 同步状态机 | `lib/sync/sync_service.dart` | `_runPushPhase()` 只推送 approved 变更 |
| 状态提供 | `lib/providers/enhanced_app_provider.dart` | 首页读取待同步变更、触发推送和撤销 |
| 首页 UI | `lib/views/home/home_search_view.dart` | 展示待同步变更、删除风险提示、单项/全部推送 |
| 执行报告 | `docs/reports/execution/2026-04-29-local-outbound-sync-review.md` | 本轮实现记录和已知残留 |

## 3. 业务不变量

这些规则属于 P0 级回归红线。

### 3.1 本地编辑不能自动推送

账号或模板保存后：

```text
必须发生：
本地数据写入
syncStatus = pendingPush
local_sync_changes 新增或合并一条 pendingReview 记录

禁止发生：
立即调用 syncNow()
立即向服务器 POST
```

### 3.2 本地删除不能自动扩散

账号或模板删除后：

```text
必须发生：
本地记录进入 tombstone
首页展示 delete 类型待同步变更
用户确认推送前，其他设备不应收到删除
```

### 3.3 启动/周期同步不能绕过待审队列

即使应用启动后自动连接同步服务器，或者周期同步触发 `syncNow()`：

```text
pull 阶段可以执行
push 阶段只能推送 approved 变更
pendingReview 变更必须继续留在本机
```

### 3.4 用户批准后才能推送

用户点击单项推送或推送全部后：

```text
pendingReview/failed/conflict -> approved
SyncService 执行 pull
SyncService 只 push approved 对应实体
服务器确认后 -> pushed
本地实体 -> synchronized
```

### 3.5 可信客户端模型

其他客户端已经推送到服务器的远端删除，本机拉取时可以直接应用。

唯一例外：

```text
本机对同一实体已有未推送修改
-> 进入现有冲突处理
```

## 4. 本地 outbox 状态机

### 4.1 状态定义

| 状态 | 含义 | 是否允许 push |
|---|---|---|
| `pendingReview` | 用户尚未确认 | 否 |
| `approved` | 用户已确认，等待同步服务推送 | 是 |
| `pushing` | 正在推送 | 否 |
| `pushed` | 已被服务器接受 | 否 |
| `failed` | 推送失败，可重试 | 是，需再次批准或直接重试 |
| `conflict` | 推送遇到版本冲突 | 是，但应先处理冲突 |
| `reverted` | 已撤销 | 否 |

### 4.2 动作定义

| 动作 | 触发场景 | UI 表达 |
|---|---|---|
| `create` | 新增账号或模板 | 新增 |
| `update` | 修改账号或模板 | 修改 |
| `delete` | 删除账号或模板 | 删除，必须高风险提示 |

### 4.3 合并规则

| 连续操作 | 期望结果 |
|---|---|
| create -> update | 保持 create，更新 after 快照 |
| create -> delete | 取消 outbox 记录，并删除本地草稿 |
| update -> update | 合并为一条 update，保留最早 before，更新 after |
| update -> delete | 转为 delete，保留最早 before |
| delete -> push | 服务器接受 tombstone 后标记 pushed |
| delete -> discard | 恢复 before 快照，删除 outbox 记录 |

## 5. 回归测试矩阵

### 5.1 账号新增

| 步骤 | 预期 |
|---|---|
| 新建账号并保存 | 首页出现 1 条“新增账号”待同步变更 |
| 不点击推送，触发同步 | 服务器不收到该账号 POST |
| 点击单项推送 | 服务器收到该账号，outbox 变为 pushed |
| 其他客户端同步 | 可拉取到该账号 |

### 5.2 账号修改

| 步骤 | 预期 |
|---|---|
| 修改账号名称或字段 | 首页出现“修改账号” |
| 连续修改同一账号两次 | 首页仍只有 1 条该账号变更 |
| 查看详情 | 展示变更字段摘要 |
| 点击撤销 | 本地账号恢复到 before 快照 |

### 5.3 账号删除

| 步骤 | 预期 |
|---|---|
| 删除已同步账号 | 账号从普通列表隐藏，首页出现“删除账号” |
| 不推送直接启动另一客户端 | 另一客户端不应删除该账号 |
| 点击推送删除 | 服务器收到 tombstone |
| 另一客户端同步 | 账号被删除或隐藏 |

### 5.4 新建后未推送又删除

| 步骤 | 预期 |
|---|---|
| 新建账号，不推送 | 首页出现 create |
| 删除该账号 | create 被取消，本地草稿被清理 |
| 再触发同步 | 不向服务器推送 create 或 delete |

### 5.5 模板修改

| 步骤 | 预期 |
|---|---|
| 新建自定义模板 | 首页出现“新增模板” |
| 修改模板字段 | 首页出现或合并“修改模板” |
| 删除未被引用模板 | 首页出现“删除模板” |
| 删除被账号引用模板 | 应继续被 ServiceManager 阻止 |

### 5.6 手动普通同步

| 步骤 | 预期 |
|---|---|
| 有 pendingReview 变更时点击普通同步 | 只执行 pull，不 push 未审阅变更 |
| 远端有新数据 | 本机可正常拉取 |
| 本机待审变更仍存在 | 首页仍显示待同步变更 |

### 5.7 推送失败

| 步骤 | 预期 |
|---|---|
| 批准变更后服务器返回 5xx | outbox 标记 failed |
| 本地实体仍保持 pendingPush | 数据不丢失 |
| 首页继续显示失败变更 | 用户可重试 |

### 5.8 版本冲突

| 步骤 | 预期 |
|---|---|
| 本机批准推送时服务器返回 409 | outbox 标记 conflict |
| SyncService 进入现有冲突恢复链路 | 生成或保留冲突记录 |
| 不应标记 pushed | 不应标记 synchronized |

### 5.9 密钥链接和导入后的边界

当前本轮只完成出站闸门，导入链路仍是后续重点。

长期期望：

| 场景 | 预期 |
|---|---|
| vault dump 导入包含 serverVersion = 0 数据 | 应进入待同步队列 |
| vault dump 导入包含 pendingPush 数据 | 应保留或重建待同步状态 |
| vault dump 导入包含 tombstone | 应作为待审删除展示 |
| 导入后用户不推送 | 不应自动扩散导入数据 |

## 6. 自动化测试维护

### 6.1 必须长期保留的测试

| 文件 | 维护目标 |
|---|---|
| `test/sync/sync_state_machine_test.dart` | 验证未审阅变更不会 push，approved 变更才允许 push |
| `test/sync/multi_device_sync_test.dart` | 验证多设备拉取、删除、冲突主链路 |
| `test/sync/sync_conflict_recovery_test.dart` | 验证 409、remote missing、冲突恢复行为 |
| `test/sync/sync_recovery_loop_test.dart` | 验证中断恢复不会破坏 pending/approved 状态 |

### 6.2 本轮已通过命令

```powershell
$env:APPDATA=(Join-Path (Get-Location) '.dart_appdata')
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
```

```powershell
$env:APPDATA=(Join-Path (Get-Location) '.dart_appdata')
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\sync_state_machine_test.dart --reporter expanded --timeout 30s
```

### 6.3 长链路测试维护风险

以下测试曾在当前 Windows 环境出现过无输出超时，当前 T0-T8 质量收敛中已复跑通过，但仍应作为后续维护重点：

```text
test/sync/multi_device_sync_test.dart
test/sync/sync_conflict_recovery_test.dart
test/sync/sync_recovery_loop_test.dart
```

维护要求：

1. 不把超时简单当作业务通过。
2. 继续关注 server/listener 生命周期，确保每个测试能独立关闭 `HttpServer`。
3. 优先把“未审阅不 push”加入多设备场景：
   - 设备 A 删除但不推送
   - 设备 B 同步后仍保留账号
   - 设备 A 批准推送
   - 设备 B 同步后删除账号

## 7. 手工回归清单

每次改动以下文件后，至少走一遍本清单：

- `service_manager.dart`
- `secure_storage_service.dart`
- `sync_service.dart`
- `home_search_view.dart`
- `vault_dump_coordinator.dart`
- 任意密钥链接导入流程

### 7.1 单设备基础流

1. 新建账号。
   预期：首页出现待同步新增。
2. 修改账号。
   预期：同一账号变更合并，不重复堆叠。
3. 删除账号。
   预期：首页出现删除类待同步变更，并有风险提示。
4. 撤销删除。
   预期：账号恢复，待同步删除消失。
5. 推送全部。
   预期：同步成功后待同步区域消失。

### 7.2 双设备误删保护流

1. 设备 A、设备 B 同步到同一账号。
2. 设备 A 删除该账号，但不推送。
3. 设备 B 执行同步。
   预期：设备 B 仍保留该账号。
4. 设备 A 推送删除。
5. 设备 B 再次同步。
   预期：设备 B 删除该账号。

### 7.3 冲突流

1. 设备 A 修改账号但不推送。
2. 设备 B 修改同一账号并推送。
3. 设备 A 批准推送。
   预期：进入冲突恢复或冲突记录，不应静默覆盖。

### 7.4 导入后同步流

1. 通过面对面链接或远程配对导入 vault。
2. 检查首页是否出现需要用户确认的普通数据变更。
3. 不推送时启动同步。
   预期：不会自动扩散本地导入数据。
4. 用户确认推送。
   预期：服务器才收到对应数据。

## 8. 数据检查方法

### 8.1 本地数据库重点表

| 表 | 检查点 |
|---|---|
| `accounts` | `sync_status`, `is_deleted`, `server_version` |
| `templates` | `sync_status`, `is_deleted`, `server_version` |
| `local_sync_changes` | `entity_type`, `action`, `status`, `before_json`, `after_json` |
| `settings` | `sync_dirty_$vaultId`, `sync_version_$vaultId` |

### 8.2 服务器请求检查

重点观察：

```text
GET /vaults/:vaultId/sync
POST /vaults/:vaultId/sync
```

有 pendingReview 变更时：

```text
允许 GET
禁止 POST 未审阅实体
```

用户批准后：

```text
允许 POST approved 实体
```

## 9. 变更准入规则

改动合入前，必须回答：

1. 是否引入了新的 `syncNow()` 调用点？
2. 该调用点是否可能在用户未确认时 push 本地变更？
3. 是否新增了账号/模板写入路径？
4. 新写入路径是否记录 `local_sync_changes`？
5. 删除路径是否支持撤销或至少保留 before 快照？
6. 启动同步、周期同步、手动同步是否仍只 push approved 变更？
7. 文档和测试是否同步更新？

如果第 1 或第 2 条回答不清楚，不允许合入。

## 10. 后续维护任务

| 优先级 | 任务 | 目的 |
|---|---|---|
| P0 | 拆分并修复长链路同步测试超时 | 让多设备边界可持续验证 |
| P0 | 增加“设备 A 未推送删除，设备 B 不受影响”的自动化测试 | 固化误删保护核心价值 |
| P1 | vault dump 导入后重建 outbox/syncStatus | 完成密钥链接后的普通数据同步闭环 |
| P1 | 增加字段级 before/after 审阅视图 | 提升用户审阅质量 |
| P1 | 增加待同步数量角标或更明显提醒 | 避免用户长期忘记推送 |
| P2 | 为 `local_sync_changes` 增加历史归档策略 | 避免长期 pushed 记录无限增长 |

## 11. 维护者注意事项

- 不要把 `pendingPush` 直接等同于“可以推送”。
- 推送资格来自 `local_sync_changes.status == approved`。
- diff 是用户审阅材料，不是服务端补丁协议。
- 远端删除审阅不是本功能目标；冲突处理才是入站例外。
- 测试中如果需要模拟旧行为，应明确命名为 legacy 或 approved fixture，避免误导。
