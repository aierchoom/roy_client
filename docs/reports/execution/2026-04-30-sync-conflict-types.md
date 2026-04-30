# 同步冲突类型正式化执行报告

**日期**: 2026-04-30
**任务**: T4 冲突类型正式化
**状态**: 已完成

## 目标

把同步冲突从单一 HTTP 409 或自然语言错误，收敛为客户端可分支处理的机器可读协议类型。

## 实施内容

- 服务端保留并测试以下冲突类型：
  - `remote_missing`
  - `stale_base_version`
  - `concurrent_edit`
  - `concurrent_delete`
- 服务端新增 `SyncPayloadValidationError`。
- 同步 push payload 不符合最低 opaque envelope 要求时，服务端返回：

```json
{
  "error": "Invalid encrypted payload envelope for item item_1",
  "conflict_type": "invalid_payload",
  "item_id": "item_1"
}
```

- 服务端只校验 `sroy-sync:` envelope 形态，不解密、不理解账号明文。
- 客户端 `_SyncHttpException` 解析 `conflict_type` 和 `item_id`。
- 客户端对 `invalid_payload` 给出明确失败状态，避免落入普通 HTTP 错误或无意义重试。

## 验证

已通过：

- `node --test test/index.test.js`
- `dart analyze lib test`
- `flutter test test/sync/sync_state_machine_test.dart --reporter expanded --timeout 30s`

## 文档同步

- `docs/product/iteration-tasks.md` 已将 T4 标记完成，并将 T5 标记进行中。
- `docs/product/application-characteristics.md` 已新增同步冲突类型基准。

## 剩余关注

- T5 需要继续扩展每一种冲突类型的恢复策略，而不是只停留在“能识别类型”。
- `invalid_payload` 当前属于不可自动修复错误，后续可结合本地 outbox 失败原因在 UI 上进一步展示。
