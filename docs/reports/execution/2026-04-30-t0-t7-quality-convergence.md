# T0-T7 质量收敛执行报告

**日期**: 2026-04-30
**任务**: T0-T7 断代质量收敛
**状态**: 已完成

## 目标

对本地出站同步审阅、vault/device identity、同步元数据隔离、payload AEAD、冲突类型、冲突恢复、CRDT 不变量和最小双设备同步这些连续迭代做一次横向质量收敛，确认断代后的代码、测试、文档和任务状态能够互相解释。

## 范围

- `docs/product/iteration-tasks.md`
- `docs/product/application-characteristics.md`
- `docs/reports/execution/**`
- `lib/services/identity_service.dart`
- `lib/services/secure_storage_service.dart`
- `lib/services/service_manager.dart`
- `lib/sync/**`
- `lib/views/home/home_search_view.dart`
- `lib/views/conflict_inbox_view.dart`
- `test/services/identity_service_test.dart`
- `test/sync/**`

## 收敛检查

- 任务清单中 T0-T7 均为完成，T8 为下一项进行中。
- T0-T7 对应执行报告已落到 `docs/reports/execution/` 并进入报告索引。
- `application-characteristics.md` 已记录当前同步、冲突、CRDT merge 和双设备同步的测试基准。
- 本轮未继续扩大 T8 实现，只把 T7 中发现的 interrupted pull marker 边界记录为 T8 风险。

## 验证

已通过：

- `dart analyze lib test`
- `flutter test test\services\identity_service_test.dart test\sync\sync_service_identity_test.dart test\sync\sync_payload_codec_test.dart test\sync\sync_state_machine_test.dart test\sync\sync_conflict_recovery_test.dart test\sync\sync_recovery_loop_test.dart test\sync\crdt_merge_engine_test.dart test\sync\crdt_merge_invariants_test.dart test\sync\multi_device_sync_test.dart`
- `flutter test`

全量测试结果：

```text
76 passed, 1 skipped
```

跳过项为 Windows runner 下不稳定的 UDP broadcast discovery 测试，LAN direct claim 路径仍由非广播测试覆盖。

## 风险记录

- 当前工作区包含 T0-T7 的连续未提交变更；提交前仍需要做一次 staged diff 检查，避免把工具缓存或无关本地文件带入。
- 本次收敛在 `roy_client` 内完成；服务端 T4 conflict type 变更的 `node --test test/index.test.js` 未在本轮客户端收敛命令中复跑。
- T7 中观察到：离线期间如果主动触发 sync 并留下 interrupted pull marker，恢复时会进入 T8 的中断恢复语义，不应混同为普通双设备离线编辑场景。

## 后续

- T8 应优先把 pull 中断、push 中断、数据库替换中断建成独立测试场景。
- T8 需要明确 interrupted pull marker 遇到本地 `pendingPush` 时的恢复策略，避免版本号和本地待推送状态互相打架。
- 提交前建议再次执行 `git status --short` 和 `git diff --stat`，确认 `.dart_appdata/` 等本地工具状态没有进入提交范围。
