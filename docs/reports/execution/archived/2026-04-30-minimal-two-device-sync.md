# 最小双设备集成测试执行报告

**日期**: 2026-04-30
**任务**: T7 最小双设备集成测试
**状态**: 已完成

## 目标

用自动化测试覆盖两台可信客户端围绕同一 vault 的最小同步链路，减少多设备新增、编辑、删除和离线恢复对人工点击验证的依赖。

## 范围

- `test/sync/multi_device_sync_test.dart`
- `docs/product/iteration-tasks.md`
- `docs/product/application-characteristics.md`

## 实施内容

- 复用内存 vault server 和两个内存客户端副本，保持测试不依赖外部服务。
- 为内存服务端增加请求计数和临时不可用开关，方便定位同步阶段。
- 补充离线编辑恢复场景：
  - A 和 B 先同步同一条账号。
  - A 在离线期间写入本地 `pendingPush` 修改。
  - 离线期间不接触服务器，服务器版本不变。
  - 网络恢复后 A push 成功。
  - B 再次 pull 后得到 A 的离线修改。
- 现有场景继续覆盖：
  - A 新增、B 拉取。
  - A/B 并发编辑不同字段后进入可审阅冲突状态。
  - A 删除、B 修改时 tombstone 胜出。
- 每个场景断言最终数据、`syncStatus`、服务器版本、tombstone 或 conflict log。

## 验证

已通过：

- `flutter test test\sync\multi_device_sync_test.dart`

## 文档同步

- `docs/product/iteration-tasks.md` 已将 T7 标记完成，并将 T8 标记进行中。
- `docs/product/application-characteristics.md` 已补充双设备同步必测方向和 T7 验证记录。
- `docs/reports/execution/README.md` 已加入本报告索引。

## 风险记录

- 本轮覆盖的是“离线期间本地修改，恢复网络后推送”的 T7 场景。
- 如果离线期间主动触发 sync 并留下 interrupted pull marker，后续恢复行为属于 T8 崩溃/中断恢复闭环，需要单独建模和测试。

## 后续

- T8 继续覆盖 pull 中断、push 中断、数据库替换中断，以及恢复标记如何避免版本号错乱或误把本地待推送编辑转成冲突。
