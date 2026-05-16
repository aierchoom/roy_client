# Docs 目录清理计划

> 生成时间: 2026-05-16
> 基于 4 个并行 Agent 对 docs/ 全部 124 个 Markdown 文件的扫描结果

---

## 一、扫描范围

| Agent | 负责范围 | 文件数 | 状态 |
|---|---|---|---|
| A1 | `docs/reports/execution/` + 根报告 | 34 | 完成 |
| A2 | `docs/guides/` + `docs/beginner/` + `docs/features/` + `docs/plans/` | 25 | 完成 |
| A3 | `docs/qa/` + `docs/wiki/` + 根级 | 19 | 完成 |
| A4 | `docs/architecture/` + `docs/product/` + `docs/security/` + `docs/sync/` | 34 | 完成 |

---

## 二、清理动作汇总

### 2.1 直接删除（7份）

| 文件 | 删除理由 |
|---|---|
| `reports/execution/2026-04-28-legacy-documentation-prune.md` | 纯文档删除清单，无任何决策价值 |
| `reports/execution/2026-04-28-project-todo-linkage.md` | 创建 TODO 并加链接，过于琐碎 |
| `features/account-templates/manual-test-report.md` | 声称通过了不存在的测试文件，失去可信性 |
| `plans/secure-note-integration-plan.md` | 内容 100% 已实现，无独立保留价值 |
| `architecture/04-enterprise-improvement-plan.md` | 核心证据全部失效（测试数、vaultId、base64 payload 等） |
| `product/whitepaper.md` | 密码学方案（Ed25519/XChaCha20）与当前实现（AES-GCM-256/HKDF）完全不符 |
| `sync/sync-protocol.md` | 数据模型过时（SyncValue 包装器），且 `sync-protocol-updated.md` 已逐条纠正 7 处差异 |

### 2.2 归档到 `reports/execution/archived/`（15份）

| 文件 | 归档理由 |
|---|---|
| `2026-04-28-app-usability-quality-convergence.md` | 普通 crash 修复记录，有追溯价值但非核心决策 |
| `2026-04-28-builtin-template-simplification.md` | 内置模板产品调整，已实现 |
| `2026-04-30-full-iteration-quality-convergence.md` | 元收敛报告，信息被各子报告覆盖 |
| `2026-04-30-t0-t7-quality-convergence.md` | 早期质量收敛，已被后续迭代覆盖 |
| `2026-04-30-t0-t7-quality-convergence-rerun.md` | 与上条重复 |
| `2026-04-30-code-scan-global-roadmap.md` | 路线图刷新，路线图本身已在 `docs/product/` 维护 |
| `2026-04-30-minimal-two-device-sync.md` | 双设备同步测试执行记录 |
| `2026-04-30-totp-service-foundation.md` | TOTP 子阶段执行记录（8个 TOTP 报告除可行性外均归档） |
| `2026-04-30-totp-template-field.md` | TOTP 子阶段执行记录 |
| `2026-04-30-totp-account-index.md` | TOTP 子阶段执行记录 |
| `2026-04-30-totp-decoupled-credentials.md` | TOTP 子阶段执行记录 |
| `2026-04-30-totp-disclosure-health-check.md` | TOTP 子阶段执行记录 |
| `2026-04-30-totp-qr-import.md` | TOTP 子阶段执行记录 |
| `2026-04-30-totp-ui-sync-closure.md` | TOTP 子阶段执行记录 |
| `2026-05-07-quality-convergence.md` | 最近的循环依赖/import 清理，内容琐碎 |

### 2.3 合并后删除（3份）

| 源文件 | 目标/去向 | 策略 |
|---|---|---|
| `wiki/architecture-overview.md` | `wiki/code-walkthrough.md` 附录 | 将"技术栈"和"相关文档"并入，然后删除 |
| `plans/lan-sync-implementation-issues.md` | `plans/lan-sync-implementation-guide.md` | 将剩余未解决问题作为"已知问题"追加，然后删除 |
| `architecture/05-distributed-system-quality-iteration-plan.md` + `06-distributed-system-implementation-backlog.md` | `architecture/archive/` | P0 已全部完成，合并归档 |

### 2.4 建议更新但本次不执行（13份）

- `architecture/00-executive-summary.md` — 刷新 Testability 评分
- `architecture/03-risks-and-roadmap.md` — 标注已完成项
- `architecture/architecture-deep-dive.md` — 更新 payload 加密描述
- `product/application-characteristics.md` — 刷新测试基线
- `beginner/app_flow.md` — 解锁流程委托给 Coordinator
- `beginner/architecture.md` — 补充 system/ 协调器层
- `beginner/example_feature.md` — 合并式保存逻辑
- `guides/technical-documentation.md` — 内置模板表补全
- `guides/flutter-node-beginner-tutorial.md` — 修正安全定性错误
- `features/account-templates/implementation-plan.md` — 标注已实现项
- `features/account-templates/regression-test-plan.md` — 更新自动化覆盖
- `plans/lan-sync-implementation-guide.md` — 更新待完成项勾选
- `plans/styles-optimization-plan.md` — 更新实际达成状态
- `wiki/api-reference.md` — 补全 4 个 TODO
- `wiki/data-models.md` — 删除虚构 Vault 类，补充缺失模型
- `wiki/development-setup.md` — Flutter 版本精确到 3.38.3
- `wiki/home.md` — 修正文件名和路径
- `wiki/quick-start-guide.md` + `user-manual.md` — 4 个标签页
- `wiki/testing-guide.md` — 修正测试统计数据
- `wiki/troubleshooting.md` — 日志示例改用 AppLogger

---

## 三、预期结果

| 指标 | 清理前 | 清理后 |
|---|---|---|
| docs/ 总 Markdown 文件 | 124 | ~109（-15 直接删除/合并） |
| execution/ 根目录文件 | 34 | 19 + 15 archived |
| 直接删除 | — | 7 |
| 归档 | — | 17（15 execution + 2 architecture） |
| 合并后删除 | — | 2 |
