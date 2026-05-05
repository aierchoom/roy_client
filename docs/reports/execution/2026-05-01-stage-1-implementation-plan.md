# Stage 1 实施计划：同步状态机清理 + 全局敏感复制策略收敛

**日期**: 2026-05-01  
**范围**: T9 同步状态机清理、T12 全局敏感复制策略收敛  
**依赖**: 无外部依赖，纯客户端改动  
**状态**: 已完成

---

## 1. 要做什么（What）

Stage 1 包含两个独立但可串行执行的任务。它们都是纯客户端改动，不依赖服务端变更，也不改动任何同步协议或加密边界。

### 1.1 T12 — 全局敏感复制策略收敛

**现状**：只有 TOTP 验证码复制使用了 `SensitiveClipboardService`（45 秒自动清理）。密码生成器、账号详情复制、配对码、恢复码等仍直接调用 `Clipboard.setData`，敏感内容长期停留在系统剪贴板。

**目标**：建立统一的分级敏感复制策略，让高风险复制（密码、配对码、恢复码）和 TOTP 验证码一样具备定时清理能力，同时解决"清理时误删用户后续复制内容"的隐患。

### 1.2 T9 — 同步状态机清理

**现状**：`SyncService` 只暴露 5 个状态：`offline`、`syncing`、`synced`、`error`、`conflictRecovery`。其中 `error` 混合了网络超时、协议解析失败、payload 被篡改、服务器 503 等完全不同的失败语义。UI 层（`sync_settings_view.dart`）被迫通过解析 `errorMessage` 字符串来猜测内部失败原因。

**目标**：
1. 拆分混合的 `error` 状态为可解释的具体失败类型
2. 明确每个状态的进入条件、退出条件和有效迁移路径
3. 让 UI 只消费稳定的、无需猜测的状态枚举
4. 清理 UI 层中基于字符串匹配的脆弱推断逻辑

---

## 2. 会得到什么（Outcome）

### 2.1 T12 产出

| 产出物 | 说明 |
|--------|------|
| 统一的 `SensitiveClipboardService` | 支持高风险/中风险/低风险三级策略，不再只处理 TOTP |
| 全量 `Clipboard.setData` 调用审计表 | 文档化每个复制入口的风险等级和归属页面 |
| "误删保护"机制 | 清理前检查剪贴板当前内容是否仍是自己写入的那条，避免误删用户后续复制 |
| 回归测试 | `sensitive_clipboard_service_test.dart` 覆盖"定时清理"和"不覆盖用户后续复制" |
| 更新后的调用点 | `password_generator_sheet.dart`、`account_list_tile.dart`、`sync_settings_view.dart` 等走统一策略 |

### 2.2 T9 产出

| 产出物 | 说明 |
|--------|------|
| 状态迁移图 | 写入本文档和 `docs/sync/sync-protocol.md` 的附录 |
| 新的 `SyncState` 枚举 | 拆分 `error` 为 `networkUnreachable`、`protocolError`、`serverError`、`authError` 等 |
| 简化的 `sync_settings_view.dart` | 删除所有基于字符串解析的状态推断代码 |
| 扩展的状态机回归测试 | `sync_state_machine_test.dart` 覆盖每个新状态的进入、退出和非法迁移 |
| 稳定的 UI 状态契约 | UI 层与 SyncService 之间形成"状态即事实"的契约，不再依赖 error message 的措辞 |

### 2.3 基线保证

- `dart analyze lib test` 0 issues
- `flutter test` 120 passed, 1 skipped（UDP broadcast discovery 跳过项不变）
- 不引入任何新的第三方依赖

---

## 3. 怎么做（How）— 详细步骤

### 3.1 执行顺序

```
Step 0: 代码扫描与现状记录 ✅
Step 1: T12 敏感复制策略实施 ✅
Step 2: T12 验收与提交 ✅
Step 3: T9 同步状态机现状分析 ✅
Step 4: T9 状态拆分与契约设计 ✅
Step 5: T9 实现与测试 ✅
Step 6: T9 验收与提交 ✅
Step 7: Stage 1 收口文档更新 ✅
```

---

### 3.2 Step 0: 代码扫描与现状记录

**目的**：在实施前建立精确的现状快照，避免遗漏调用点。

**操作**：
1. 搜索全项目中所有 `Clipboard.setData` 调用：
   ```bash
   grep -rn "Clipboard.setData" lib/
   ```
2. 搜索全项目中所有 `SensitiveClipboardService` 的引用：
   ```bash
   grep -rn "SensitiveClipboardService" lib/
   ```
3. 记录每个调用点的上下文：所属页面、复制内容类型、当前是否已有清理策略。
4. 搜索 `SyncService` 中所有状态赋值和 `notifyListeners` 调用，画出当前隐式状态迁移路径。
5. 搜索 `sync_settings_view.dart` 中所有基于 `errorMessage` 或 `state` 的条件分支。

**产出**：
- `Clipboard.setData` 调用点清单（写入本实施计划附录）
- 当前隐式状态迁移路径图（写入本实施计划附录）

---

### 3.3 Step 1: T12 敏感复制策略实施

#### 3.3.1 扩展 `SensitiveClipboardService`

**当前实现**：
```dart
class SensitiveClipboardService {
  static Future<void> copyTotpCode(String code) { ... }
}
```

**目标实现**：
```dart
enum ClipboardRiskLevel {
  high,    // 密码、恢复码、配对码、TOTP secret
  medium,  // vault ID、服务器地址
  low,     // 普通 UI 文案，不清理
}

class SensitiveClipboardService {
  static Future<void> copy({
    required String text,
    ClipboardRiskLevel level = ClipboardRiskLevel.high,
    Duration clearAfter = const Duration(seconds: 45),
  }) async;

  /// 清理时检查剪贴板当前内容是否仍是自己写入的 hash，
  /// 避免误删用户后续复制的内容。
  static Future<void> _clearIfUnchanged({
    required String expectedText,
    required Duration delay,
  }) async;
}
```

**实现细节**：
1. `copy` 方法先写入剪贴板，然后对 `high` 和 `medium` 级别启动定时清理
2. `_clearIfUnchanged` 在延迟后读取当前剪贴板内容，计算 hash 并与写入时的 hash 比对
3. 只有当 hash 匹配时才执行清理；不匹配则说明用户已复制其他内容，直接放弃清理
4. 使用 `dart:developer` 的 `postEvent` 或 `debugPrint` 在 kDebugMode 下记录清理决策（仅调试用）

#### 3.3.2 替换各调用点

按 Step 0 的清单逐个替换：

| 文件 | 当前复制内容 | 风险等级 | 替换方式 |
|------|-------------|---------|---------|
| `widgets/password_generator_sheet.dart` | 生成的密码 | `high` | `SensitiveClipboardService.copy(text: password)` |
| `views/accounts/account_list_tile.dart` | 账号密码 | `high` | `SensitiveClipboardService.copy(text: password)` |
| `views/accounts/account_edit_view.dart` | 账号密码/邮箱 | `high`/`medium` | 按字段类型区分 |
| `views/sync_settings_view.dart` | 配对码/恢复码 | `high` | `SensitiveClipboardService.copy(text: code)` |
| `widgets/account_list_tile.dart` | 复制全部 | `high` | `SensitiveClipboardService.copy(text: fullRecord)` |

**注意**：
- 不清理普通非敏感 UI 文本（如"已复制到剪贴板"的 Toast 文案）
- 不改动 TOTP 验证码的现有调用路径，只把 `copyTotpCode` 内部改为走新的统一 `copy` 方法

#### 3.3.3 补回归测试

在 `test/services/sensitive_clipboard_service_test.dart` 中新增：

```dart
group('high-risk clipboard cleanup', () {
  test('clears sensitive text after delay', () async { ... });
  test('does not clear if user copied something else', () async { ... });
  test('medium-risk also clears but can use different duration', () async { ... });
});
```

**测试策略**：
- 使用模拟剪贴板（mock `Clipboard` platform channel）避免污染真实系统剪贴板
- 测试用 `FakeAsync` 控制时间，避免真实等待 45 秒

---

### 3.4 Step 2: T12 验收与提交

**验收检查表**：
- [x] `dart analyze lib test` 0 issues
- [x] `flutter test` 通过，新增测试不失败
- [x] 手动验证：复制密码后等待 45 秒，剪贴板被清空
- [x] 手动验证：复制密码后立刻复制一段其他文字，45 秒后新文字仍在剪贴板
- [x] 所有修改的 `Clipboard.setData` 调用点已走 `SensitiveClipboardService`

**提交信息**：
```
feat: converge sensitive clipboard policy (T12)

- Extend SensitiveClipboardService to support risk-level-based cleanup
- Add hash-based "clear only if unchanged" protection
- Replace raw Clipboard.setData in password generator, account tile,
  account edit, sync settings with unified service
- Add regression tests for cleanup and non-overwrite behavior
```

---

### 3.5 Step 3: T9 同步状态机现状分析

**目的**：在动手改代码前，先理解当前 SyncService 的真实状态迁移逻辑。

**操作**：
1. 在 `lib/sync/sync_service.dart` 中搜索所有 `_updateState(...)` 调用，记录每个调用点的上下文和触发条件
2. 在 `lib/views/sync_settings_view.dart` 中搜索所有 `syncState`、`syncErrorMessage`、`syncStatusNote` 的读取点，画出 UI 如何消费这些状态
3. 识别出当前 UI 基于字符串推断的具体案例：
   - 哪些 error message 被 UI 用来判断"是否网络问题"
   - 哪些 error message 被 UI 用来判断"是否协议错误"
   - 哪些 error message 被 UI 用来判断"是否需要去冲突箱"

**产出**：
- 当前隐式状态迁移路径图（附录 B）
- UI 消费状态清单（附录 C）

---

### 3.6 Step 4: T9 状态拆分与契约设计

#### 3.6.1 设计新状态枚举

```dart
enum SyncState {
  /// 未配置服务器或用户手动断开
  disconnected,

  /// 正在连接/握手
  connecting,

  /// 正在拉取远端更新
  pulling,

  /// 正在推送已批准的本地变更
  pushing,

  /// 同步完成，本地与远端一致
  idle,

  /// 网络不可达（可自动恢复）
  networkUnreachable,

  /// 服务端返回 5xx 或存储不可用
  serverError,

  /// 服务端拒绝认证/授权
  authError,

  /// 协议解析失败或 payload 校验失败
  protocolError,

  /// 冲突恢复中（由冲突箱驱动，不是自动重试）
  conflictRecovery,
}
```

**设计原则**：
- `disconnected` / `idle` 是稳定状态，UI 可以安全展示
- `connecting` / `pulling` / `pushing` 是进行中状态，UI 显示进度
- `networkUnreachable` / `serverError` / `authError` / `protocolError` 是具体失败状态，UI 根据状态直接展示对应文案，无需解析字符串
- `conflictRecovery` 保留，但明确只有用户操作才能进入此状态

#### 3.6.2 设计状态迁移规则

```text
disconnected --(connect())--> connecting
connecting --(success)--> pulling
pulling --(success)--> pushing
pushing --(success)--> idle

connecting / pulling / pushing --(network error)--> networkUnreachable
connecting / pulling / pushing --(5xx)--> serverError
connecting / pulling / pushing --(auth failure)--> authError
connecting / pulling / pushing --(parse/payload error)--> protocolError

networkUnreachable --(retry)--> connecting
serverError --(retry)--> connecting
authError --(user fixes url/key)--> connecting
protocolError --(user reviews)--> disconnected / idle

idle --(markDirty + periodic sync)--> pulling
idle --(user clicks sync)--> connecting
```

**非法迁移（必须断言或忽略）**：
- `disconnected` 不能直接到 `idle`（必须经过一次成功同步）
- `networkUnreachable` 不能自动迁移到 `idle`（必须显式重试）
- `conflictRecovery` 只能在用户操作后进入和退出

#### 3.6.3 设计 UI 契约

SyncService 暴露给 UI 的契约：

```dart
class SyncService extends ChangeNotifier {
  SyncState get state;
  String? get statusLabel;      // 人类可读的状态说明，不是错误详情
  DateTime? get lastSyncTime;   // 最后一次成功同步时间
  bool get hasPendingChanges;   // 是否有 approved 但未 push 的变更
  int get pendingChangeCount;   // 待同步变更数量（用于首页 badge）
  
  // 不再暴露 raw errorMessage 给 UI
  // String? get errorMessage;  // ❌ 删除或改为内部字段
}
```

UI 层的消费规则：
- 根据 `state` 直接决定展示什么图标、文案和按钮
- 不再解析 `errorMessage.contains(...)`
- 对于需要用户决策的状态（`authError`、`protocolError`），`statusLabel` 给出明确的下一步动作

---

### 3.7 Step 5: T9 实现与测试

#### 3.7.1 修改 `SyncService`

1. 替换 `enum SyncState` 为新定义
2. 修改 `_updateState(SyncState newState)`，增加迁移合法性检查（debug 模式下断言非法迁移）
3. 修改 `_handleGlobalSyncError`，根据异常类型映射到具体状态：
   - `SocketException` / `TimeoutException` → `networkUnreachable`
   - `http.ClientException` + 状态码 5xx → `serverError`
   - `_SyncHttpException` + 认证相关 → `authError`
   - `_SyncProtocolException` / `SyncPayloadException` → `protocolError`
4. 删除或私有化 `_errorMessage` 的公开 getter，改为只提供 `statusLabel`
5. 保留 `recoveryPhase` 的 `@visibleForTesting` getter 不变

#### 3.7.2 简化 `sync_settings_view.dart`

1. 删除所有基于 `syncErrorMessage?.contains(...)` 的条件分支
2. 改为基于 `syncState` 的 `switch` 或 `if/else`：
   ```dart
   switch (syncState) {
     case SyncState.idle:
       return _buildIdleStatus();
     case SyncState.networkUnreachable:
       return _buildNetworkErrorStatus();
     case SyncState.serverError:
       return _buildServerErrorStatus();
     case SyncState.authError:
       return _buildAuthErrorStatus();
     // ...
   }
   ```
3. 保留重试按钮的显式触发，但不再依赖"错误字符串匹配"来决定是否显示

#### 3.7.3 扩展回归测试

在 `test/sync/sync_state_machine_test.dart` 中新增：

```dart
group('state transition validity', () {
  test('disconnected -> connecting is valid', () { ... });
  test('disconnected -> idle is invalid', () { ... });
  test('networkUnreachable -> connecting on retry', () { ... });
});

group('error classification', () {
  test('socket exception maps to networkUnreachable', () { ... });
  test('5xx response maps to serverError', () { ... });
  test('invalid payload maps to protocolError', () { ... });
});
```

---

### 3.8 Step 6: T9 验收与提交

**验收检查表**：
- [x] `dart analyze lib test` 0 issues
- [x] `flutter test` 通过，状态机测试和冲突恢复测试不失败
- [x] `sync_settings_view.dart` 中不存在任何 `.contains('SocketException')` 或类似字符串匹配
- [x] 多设备同步测试（`multi_device_sync_test.dart`）通过
- [x] 手动验证：断开网络后状态显示为 `networkUnreachable`，文案明确提示"检查网络"而非技术错误
- [x] 手动验证：服务器 503 后状态显示为 `serverError`，文案明确提示"服务端暂时不可用"

**提交信息**：
```
feat: clean up sync state machine semantics (T9)

- Split monolithic error state into networkUnreachable, serverError,
  authError, protocolError
- Add state transition guard and illegal migration assertions
- Replace UI string-parsing with explicit state-based rendering
- Expand sync_state_machine_test.dart with transition and classification tests
- Update sync-protocol.md with state machine diagram
```

---

### 3.9 Step 7: Stage 1 收口

**操作**：
1. [x] 运行全量测试：`flutter test` → 120 passed / 1 skipped
2. [x] 运行静态分析：`dart analyze lib test` → 0 issues
3. [x] 更新本文档的执行记录，标记各步骤完成状态
4. [x] 检查 `application-characteristics.md` 的全局功能地图（无需更新，T9/T12 未改变功能地图边界）
5. [x] 检查 `iteration-tasks.md` 的 Stage 1 状态已标记为"完成"

---

## 4. 风险与回滚策略

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| T12 的 hash 比对在特定平台剪贴板 API 行为不一致 | 清理策略在某些平台失效或误清理 | 使用 Flutter 标准 `Clipboard` API；平台差异在测试中覆盖 Android/iOS/Desktop/Web |
| T9 状态拆分导致现有 UI 遗漏某些边界状态 | 用户看到空白或默认文案 | 保留一个 `_buildFallbackStatus()` 兜底；断言覆盖所有枚举值 |
| T9 改动影响多设备同步测试 | 已有回归测试失败 | 每次修改后即时运行 `multi_device_sync_test.dart`；失败则回退 |
| 状态迁移断言在 release 模式下被忽略 | 非法迁移只在 debug 模式下抛出 | 在单元测试中强制覆盖非法迁移路径 |

**回滚方式**：
- T12 和 T9 分别独立提交，互不影响。若某任务验收失败，只回滚该任务的 commit，不影响另一任务。
- 回滚命令：`git revert <commit-hash>`

---

## 5. 附录

### 附录 A：Step 0 扫描产出模板

#### A.1 Clipboard.setData 调用点清单

| 文件 | 行号 | 复制内容 | 当前风险等级 | 计划策略 |
|------|------|---------|-------------|---------|
| (待 Step 0 扫描后填充) | | | | |

#### A.2 当前隐式状态迁移路径

| 起点状态 | 触发条件 | 终点状态 | 代码位置 |
|---------|---------|---------|---------|
| (待 Step 0 扫描后填充) | | | |

#### A.3 UI 字符串推断清单

| UI 文件 | 推断条件 | 推断目的 | 新状态替代方案 |
|--------|---------|---------|-------------|
| (待 Step 0 扫描后填充) | | | |

---

## 6. 审阅确认

请在下方勾选确认项，或提出修改意见：

- [ ] 阶段范围合理（T9 + T12，不涉及服务端）
- [ ] 执行顺序可接受（先做 T12，再做 T9）
- [ ] T12 的风险分级策略合理（high/medium/low）
- [ ] T12 "不覆盖用户后续复制"的实现方案可接受
- [ ] T9 的新状态枚举覆盖所有现有场景
- [ ] T9 不再暴露 `errorMessage` 给 UI 的决策可接受
- [ ] 验收标准足够明确
- [ ] 回滚策略合理

**审阅意见**：（如有修改需求请在此填写）
