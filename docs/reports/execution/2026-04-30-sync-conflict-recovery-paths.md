# 同步冲突恢复路径扩展执行报告

**日期**: 2026-04-30
**任务**: T5 冲突恢复路径扩展
**状态**: 已完成

## 目标

让主要同步冲突类型不只“能识别”，还要进入明确、可解释、可测试的恢复路径。

## 实施内容

- `SyncService` 将冲突处理拆成明确分支：
  - `remote_missing`
  - `stale_base_version`
  - `concurrent_edit`
  - `concurrent_delete`
- `remote_missing` 保持现有冲突箱决策路径，生成 `record.remote_missing`。
- `stale_base_version` 重新拉取最新快照并执行 CRDT merge。
- `concurrent_edit` 重新拉取最新快照，字段级冲突进入 conflict inbox。
- `concurrent_delete` 保持 tombstone 优先；远端删除胜出时给出明确同步提示。
- 冲突箱条目增加冲突类型、来源节点和建议动作展示。

## 验证

已通过：

- `dart analyze lib test`
- `flutter test test/sync/sync_conflict_recovery_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/sync_state_machine_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/multi_device_sync_test.dart --reporter expanded --timeout 30s`
- `flutter test test/sync/crdt_merge_engine_test.dart --reporter expanded --timeout 30s`

## 文档同步

- `docs/product/iteration-tasks.md` 已将 T5 标记完成，并将 T6 标记进行中。
- `docs/product/application-characteristics.md` 已新增冲突恢复路径基准。

## 剩余关注

- T6 需要继续补 CRDT merge 不变量测试，防止未来调整合并逻辑时破坏收敛性。
- 冲突箱目前仍基于 `ConflictLog.fieldKey` 表达冲突类型，后续可评估是否引入更结构化的 conflict model。
