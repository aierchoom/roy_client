# 崩溃恢复闭环执行报告

**日期**: 2026-04-30
**任务**: T8 崩溃恢复闭环
**状态**: 已完成

## 目标

让同步中途失败成为可回放、可恢复的正式场景，尤其避免恢复阶段把本地待推送编辑误转成冲突，或因为部分成功导致版本号错乱。

## 范围

- `lib/sync/sync_service.dart`
- `lib/services/secure_storage_service.dart`
- `test/sync/sync_recovery_loop_test.dart`
- `test/services/secure_storage_service_encryption_test.dart`
- `docs/product/iteration-tasks.md`
- `docs/product/application-characteristics.md`

## 本轮执行重点

1. 明确 `pull` 中断恢复：
   - `pull` marker 恢复时应从 marker 的 `localVersion` 继续拉增量。
   - 不应无条件拉全量快照。
   - 如果远端没有新版本，本地 `pendingPush` 应保持可推送。
2. 保留 `push` 中断恢复：
   - `push` marker 仍通过快照恢复，避免重复提交已经可能被服务端接受的 payload。
3. 补充恢复闭环测试：
   - interrupted pull + 本地 pendingPush + 远端无更新 -> 恢复后继续 push。
   - 既有 pull marker / push marker / marker 清理测试继续通过。
4. 明确数据库替换中断恢复：
   - 启动前如果发现加密数据库主文件缺失但 `.bak` 存在，先恢复 `.bak`。
   - 如果 `.tmp` 是中断残留，在主文件恢复后清理，避免下一次启动误读半写入文件。

## 执行命令

1. 格式化：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' format lib\sync\sync_service.dart test\sync\sync_recovery_loop_test.dart
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' format lib\services\secure_storage_service.dart test\services\secure_storage_service_encryption_test.dart
```

2. 定向测试：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\sync_recovery_loop_test.dart
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\services\secure_storage_service_encryption_test.dart
```

3. 同步相关回归：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\sync\sync_state_machine_test.dart test\sync\sync_conflict_recovery_test.dart test\sync\multi_device_sync_test.dart test\sync\sync_recovery_loop_test.dart
```

4. 静态分析：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
```

5. 全量测试：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test
```

## 通过标准

- interrupted pull 恢复不会把无远端新版本的本地 `pendingPush` 变成 `conflict`。
- interrupted push 仍不重复 post。
- 加密数据库替换在主文件已挪到 `.bak`、`.tmp` 残留时，重启后恢复到一致库文件。
- 恢复成功后 `sync_recovery_$vaultId` 清空。
- 定向测试、同步相关回归和静态分析通过。

## 执行结果

- 实现：已完成。
  - `pull` marker 恢复改为从 marker 的 `localVersion` 拉取增量，不再无条件拉全量快照。
  - `push` marker 保持快照恢复语义，避免重复提交可能已被服务端接受的 payload。
  - 加密数据库启动准备阶段会恢复中断原子写留下的 `.bak`，并清理 `.tmp`。
- 定向测试：已通过。
  - `test/sync/sync_recovery_loop_test.dart`：4 tests passed。
  - `test/services/secure_storage_service_encryption_test.dart`：3 tests passed。
- 同步相关回归：已通过，24 tests passed。
- 静态分析：已通过，`No issues found!`。
- 全量测试：已通过，78 passed, 1 skipped；跳过项仍是 Windows runner 下不稳定的 UDP broadcast discovery。
- 执行插曲：一次非提升权限的 Flutter 存储测试无输出超时，清理残留 `dart` 进程后用同一 APPDATA 路径复跑通过。

## 风险记录

- 数据库替换中断本轮覆盖文件级原子替换恢复；如果未来要记录 vault dump import 的业务级“导入中/导入完成”阶段，可在 `VaultDumpCoordinator` 外层再增加 import marker。
- 本轮不改变 conflict recovery 的用户决策语义。
