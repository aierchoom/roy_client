# T0-T7 质量收敛重跑执行报告

**日期**: 2026-04-30
**任务**: T0-T7 断代质量收敛重跑
**状态**: 已完成

## 目标

先生成可执行报告，再按报告重跑质量收敛命令，确认 T0-T7 连续迭代在当前工作区仍然满足分析、目标测试和全量测试基准。

## 范围

- 本地出站同步审阅：T0
- vault/device identity：T1
- 同步元数据 vault 隔离：T2
- 同步 payload AEAD/E2EE：T3
- 冲突类型正式化：T4
- 冲突恢复路径扩展：T5
- CRDT merge 不变量：T6
- 最小双设备集成测试：T7

## 执行命令

1. 静态分析：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze lib test
```

2. T0-T7 定向测试集：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test test\services\identity_service_test.dart test\sync\sync_service_identity_test.dart test\sync\sync_payload_codec_test.dart test\sync\sync_state_machine_test.dart test\sync\sync_conflict_recovery_test.dart test\sync\sync_recovery_loop_test.dart test\sync\crdt_merge_engine_test.dart test\sync\crdt_merge_invariants_test.dart test\sync\multi_device_sync_test.dart
```

3. 全量测试：

```powershell
$env:APPDATA=(Resolve-Path .).Path + '\.dart_appdata'; & 'F:\FlutterSDK\flutter\bin\flutter.bat' test
```

## 通过标准

- `dart analyze lib test` 无 issue。
- T0-T7 定向测试集全部通过。
- `flutter test` 全量通过；允许保留 Windows UDP broadcast discovery 的既有 skip。
- 如果任一命令失败，先记录失败命令、失败输出和影响范围，再决定是否修复。

## 执行结果

- 静态分析：通过，`No issues found!`
- T0-T7 定向测试集：通过，`All tests passed!`
- 全量测试：通过，`All tests passed!`

全量测试结果：

```text
76 passed, 1 skipped
```

跳过项为 Windows test runner 下不稳定的 UDP broadcast discovery 测试；LAN direct claim 路径仍由非广播测试覆盖。

## 执行结论

T0-T7 在当前工作区通过同一轮静态分析、目标测试和全量测试。当前可继续进入 T8 崩溃恢复闭环，但 T8 应单独处理 interrupted pull/push marker 与本地 `pendingPush` 的交互，不应回写到 T7 完成项。

## 风险预置

- Dart/Flutter 命令在 Windows 下可能因 AppData 或 Pub cache 权限失败；本报告统一使用 repo-local `APPDATA`。
- 本轮只做质量收敛验证，不继续扩大 T8 实现。
- 若 T7 的离线/中断边界暴露新问题，应归档到 T8 崩溃恢复闭环，而不是混入 T7 完成项。
