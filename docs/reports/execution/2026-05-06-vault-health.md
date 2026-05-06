# Vault Health 本地体检面板

**Status**: Completed
**Date**: 2026-05-06
**Scope**: 纯客户端改动；设置页新增 Vault Health 入口、体检计算服务、数据模型、UI 面板与单元测试
**Baseline**: Stage 1 Step 1

---

## Goal

在设置页提供一个**只读、离线可用、不上传数据**的 Vault Health 体检面板，把加密、备份、凭据风险和待同步状态变成可见产品能力，让用户在 10 秒内理解自己的安全态势，并获得可执行的下一步。

---

## Scope

- `lib/models/vault_health_report.dart` — 体检数据模型（评分、等级、风险项、动作）
- `lib/services/vault_health_calculator.dart` — 13 项指标计算与评分算法
- `lib/views/settings/vault_health_view.dart` — 体检结果展示页面
- `lib/views/settings_view.dart` — 设置列表新增 Vault Health 入口
- `test/services/vault_health_calculator_test.dart` — 计算服务单元测试

---

## Changes

### 1. `lib/models/vault_health_report.dart` (new)

定义体检面板的核心数据契约：

- `VaultHealthGrade` — 优秀 / 良好 / 需关注 / 危险
- `VaultHealthRiskLevel` — 高 / 中 / 低
- `VaultHealthActionType` — 可执行动作枚举（跳转编辑页、跳转 outbox、跳转冲突箱、导出、同步设置）
- `VaultHealthItem` — 单项体检结果（id、标题、风险等级、是否通过、描述、动作）
- `VaultHealthReport` — 完整报告（总分、等级、项目列表、计算时间），提供按风险等级筛选的 getter

### 2. `lib/services/vault_health_calculator.dart` (new)

体检计算服务，分两类共 13 项指标：

**A. 保险库运行体检**

| 指标 | 检查内容 | 风险等级 |
|---|---|---|
| 本地数据库加密 | `.db.enc` 文件是否存在 | 高 |
| 备份年龄 | 最近一次同步时间是否超过 30 天 | 高 |
| Vault 身份完整性 | `vaultId`/`deviceId` 是否完整 | 高 |
| 同步认证状态 | `vaultApiToken` 是否存在 | 低 |
| 待同步变更 | `local_sync_changes` pendingReview 数量 | 中 |
| 同步冲突 | 未处理的 conflict log 数量 | 中 |

**B. 账号安全体检（静态方法，便于独立测试）**

| 指标 | 检查内容 | 风险等级 |
|---|---|---|
| 弱密码 | 密码强度 < 40 | 高 |
| 重复密码 | 两个及以上账号使用相同密码 | 高 |
| 陈旧记录 | 超过 180 天未修改 | 中 |
| 不完整记录 | 缺少 URL | 低 |
| 缺少 2FA | 网站模板账号未关联 TOTP 凭据 | 中 |

**评分算法**

- 起始 100 分
- 高风险未通过：-15
- 中风险未通过：-8
- 低风险未通过：-3
- 最低 0 分，最高 100 分

等级映射：90-100 优秀，70-89 良好，50-69 需关注，0-49 危险。

### 3. `lib/views/settings/vault_health_view.dart` (new)

体检结果展示页：

- 顶部：评分圆环 + 等级标签 + 总状态提示
- 中段：按风险等级分组展示未通过项（高 / 中 / 低）
- 每项卡片：图标、标题、描述、风险 Chip、可点击动作
- 全部通过时展示绿色通过横幅
- 右上角刷新按钮重新计算
- 底部显示体检时间

### 4. `lib/views/settings_view.dart`

在设置列表的"安全设置"与"数据同步"之间插入 Vault Health 入口，符合用户心智模型。

### 5. `test/services/vault_health_calculator_test.dart` (new)

29 项单元测试，覆盖：

| 测试组 | 场景 |
|---|---|
| `calculateScore` | 全通过 100 分、单风险扣分、混合扣分、下限 0 |
| `scoreToGrade` | 边界值 90/89/70/69/50/49/0 |
| `checkWeakPasswords` | 空密码忽略、已删除忽略、弱密码失败、强密码通过 |
| `checkReusedPasswords` | 无重用通过、重用失败、空密码忽略、已删除忽略 |
| `checkStaleRecords` | 近期通过、>180 天失败、已删除忽略 |
| `checkIncompleteRecords` | 有 URL 通过、缺失 URL 失败、已删除忽略 |
| `checkMissing2FA` | 无 TOTP 字段忽略、已关联通过、未关联失败、已删除忽略 |

---

## Validation

```bash
flutter analyze lib test  # 0 issues
flutter test                # 187 passed, 1 skipped
```

跳过项仍是 Windows runner 下不稳定的 UDP broadcast discovery。

---

## Risk Notes

- **动作未完全路由**：`_handleAction()` 中的导航动作目前为 TODO 桩代码，实际路由需在后续首页/冲突箱/outbox 页面结构稳定后补全。
- **备份年龄依赖同步时间戳**：当前使用 `sync_last_time_$vaultId` 作为备份时间参考。如果用户只通过加密导出备份而不使用同步，该指标会误报为未备份。后续可补充"最近一次加密导出时间"作为 fallback。
- **陈旧记录使用 `createdAt`**：当前以账号创建时间判断陈旧程度，而非 `modified_at`。如果账号创建后从未修改，`createdAt` 仍然有效；但未来若引入显式 `modifiedAt` 字段，应优先使用后者。
- **2FA 检测依赖模板字段类型**：只有模板中包含 `AccountFieldType.totp` 字段的账号才会被纳入缺少 2FA 检测。若用户为不支持 2FA 的模板手动添加 TOTP 关联，不会触发此项检测（这是预期行为）。

---

## Follow-ups

- 补全 `_handleAction()` 中的页面跳转路由（账号编辑、outbox、冲突箱、导出、同步设置）
- 考虑在首页聚合 Vault Health 评分卡片，让用户无需进入设置即可感知安全状态
- 评估是否将"最近一次加密导出时间"纳入备份年龄检查
- 考虑为 Vault Health 添加定时后台计算缓存，避免每次进入页面都重新扫描全部账号
