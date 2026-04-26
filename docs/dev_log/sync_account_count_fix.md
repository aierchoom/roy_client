# Bug Fix: 同步后账号数量显示0 & 账号列表不刷新

**日期**: 2026-04-18  
**影响文件**: `service_manager.dart`, `security_settings_view.dart`  
**严重性**: 🟠 重要（功能性错误，影响用户体验）

---

## Bug 描述

### Bug 1 — 同步成功提示"账号: 0"

执行同步（推送或拉取）后，SnackBar 提示中的账号数量始终显示为 `0`，
即使本地数据库明明有账号数据。

### Bug 2 — 拉取同步后主页账号列表不显示数据

从服务端拉取并覆盖本地数据库后，账号列表变为空白，
需要手动锁定再解锁才能看到数据。

---

## 根本原因分析

### 关键时序

```
_syncService.syncNow()
  └─ _pullDatabase()
       └─ storageService.replaceDatabase(bytes)
            ├─ _database?.close()   // ① 关闭数据库连接
            └─ _database = null     // ② _database 置为 null
  └─ storageService.loadAccounts()  // ③ isOpen = false → 返回 []
  └─ SyncResult(accountCount: 0)    // ④ 账号数为 0
```

`replaceDatabase()` 在写入新文件前会关闭并置空旧的数据库连接
（这是正确的，避免文件写冲突），但随后 `sync_service.dart` 立即
调用 `loadAccounts()`，此时 `isOpen == false`，方法直接返回空列表。

### Bug 1 的额外叠加原因

`ServiceManager.syncNow()` 在 pull 成功后构造了一个**新的**
`SyncResult.success()` 并返回，但没有传入 `accountCount`，
所以即使 `sync_service` 查出了正确数量，也被覆盖为默认值 `0`：

```dart
// 修复前（有 bug）
return SyncResult.success(pulled: true, version: _syncService.localVersion);
//                                      ↑ accountCount 未传入，默认 0

// 推送分支同样有此问题
return SyncResult.success(pushed: result.pushed, version: _syncService.localVersion);
//                                               ↑ 丢弃了 result.accountCount
```

---

## 修复方案

### `lib/services/service_manager.dart` — `syncNow()` 方法

在 **pull 路径**中：
1. 等待文件系统刷盘（500ms）
2. 重新调用 `initialize()` 打开新数据库
3. 重新调用 `_syncService.initialize()` 从新库读取同步版本
4. **数据库重新打开后**，再查询账号总数
5. 将真实账号数放入返回的 `SyncResult`
6. 调用 `notifyListeners()` 触发 `EnhancedAppProvider.refresh()`

在 **push / 无需同步路径**中：
- 保留 `sync_service` 已查询好的 `result.accountCount`，不再重新构造空值 `SyncResult`

### `lib/views/security_settings_view.dart` — UI 显示文字

同步结果的提示文字按三种情况分别显示：
- `pulled == true` → "拉取成功"
- `pushed == true` → "推送成功"  
- 其他 → "已是最新"

---

## 验证方法

1. 在设备 A 上添加 3 个账号 → 推送同步
2. 在设备 B 上执行同步（拉取）
3. 观察 SnackBar 提示应显示"拉取成功 (账号:3)"
4. 观察主页账号列表应立即显示 3 个账号，无需重启或重新登录
