# CRDT merge 不变量测试执行报告

**日期**: 2026-04-30
**任务**: T6 CRDT merge 不变量测试
**状态**: 已完成

## 目标

给 `CrdtMergeEngine` 建立长期回归护栏，确保后续调整字段级合并、墓碑处理或冲突日志时，能快速暴露收敛性问题。

## 范围

- `test/sync/crdt_merge_invariants_test.dart`
- `docs/product/iteration-tasks.md`
- `docs/product/application-characteristics.md`

## 实施内容

- 扩展 CRDT merge 不变量测试：
  - 相同输入重复 merge 必须得到相同输出。
  - merge 后 data key 与 dataHlc key 必须一致，不产生非法空字段。
  - 本地新墓碑不能被远端旧更新复活。
  - 双方都删除时，最新 tombstone 稳定胜出。
  - conflict log 只保存被覆盖值，不改变主合并结果。
  - 双端交错字段胜出后，合并结果可保持 `pendingPush` 并再次推送。
- 补充对模板、创建时间、远端版本、最终 `syncStatus` 的断言。

## 验证

已通过：

- `flutter test test\sync\crdt_merge_invariants_test.dart`

## 文档同步

- `docs/product/iteration-tasks.md` 已将 T6 标记完成，并将 T7 标记进行中。
- `docs/product/application-characteristics.md` 已补充 CRDT merge 必测方向和 T6 验证记录。
- `docs/reports/execution/README.md` 已加入本报告索引。

## 风险记录

- 本轮只补测试，不修改 `CrdtMergeEngine` 行为。
- 当前不变量覆盖账号记录合并；模板 CRDT 合并仍由既有测试覆盖，后续如扩展模板字段级合并，需要新增对应不变量。

## 后续

- T7 继续拆分最小双设备集成测试，让新增、拉取、并发编辑、删除冲突和离线恢复可以定位到具体同步阶段。
