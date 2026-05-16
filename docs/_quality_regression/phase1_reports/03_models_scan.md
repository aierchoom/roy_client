[stage] runner_started
[stage] agent_built
[stage] context_restored
[stage] context_ready
[stage] run_soul_start
[tool] Glob
[tool] Shell
[tool_result] success
[tool_result] success
[tool] ReadFile
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool] ReadFile
[tool_result] success
[tool_result] success
[tool] Grep
[tool] Grep
[tool_result] success
[tool] Grep
[tool_result] success
[tool_result] success
[tool] ReadFile
[tool_result] success
# SecretRoy 数据模型 Schema 手册

> 扫描范围：`lib/models/`（8 个文件，12 个核心类/枚举）  
> 扫描时间：2026-05-16  
> 关联外部依赖：`lib/services/totp_service.dart`（`TotpConfig`、`TotpException`）

---

## 一、模型总览表

| # | 类/枚举名 | 所在文件 | 类型 | 序列化方式 | copyWith | 关联模型 |
|---|-----------|--------|------|-----------|----------|----------|
| 1 | `Hlc` | `hlc.dart` | 数据类 | `toString()` / `parse()` | ❌ | 被所有模型引用 |
| 2 | `SyncValue<T>` | `hlc.dart` | 泛型包装 | `toJson()` / `fromJson()` / `fromPrimitiveJson()` | ❌ | 引用 `Hlc` |
| 3 | `SyncStatus` | `account_item.dart` | 枚举 | `name` / `syncStatusFromJson()` | - | `AccountItem`、`AccountTemplate`、`TotpCredential` |
| 4 | `AccountFieldMeta` | `account_item.dart` | 数据类 | `toJson()` / `fromJson()` | ❌ | 被 `AccountItem` 引用 |
| 5 | `AccountItem` | `account_item.dart` | 核心实体 | `toJson()` / `fromJson()` | ✅ 完整 | `Hlc`、`AccountFieldMeta`、`AccountTemplate`、`SyncStatus` |
| 6 | `AccountFieldType` | `account_template.dart` | 枚举 | `name` / `fieldTypeFromString()` | - | 被 `AccountFieldAttributes` 使用 |
| 7 | `TimeFieldFormat` | `account_template.dart` | 枚举 | `name` | - | 被 `AccountFieldAttributes` 使用 |
| 8 | `TemplateCategory` | `account_template.dart` | 枚举 | `name` / `templateCategoryFromString()` | - | 被 `AccountTemplate` 使用 |
| 9 | `AccountFieldAttributes` | `account_template.dart` | 数据类 | `toJson()` / `fromJson()` | ❌ | 被 `AccountField` 引用 |
| 10 | `AccountField` | `account_template.dart` | 数据类 | `toJson()` / `fromJson()` / `toExportJson()` | ✅ 完整 | `Hlc`、`AccountFieldAttributes` |
| 11 | `AccountTemplate` | `account_template.dart` | 核心实体 | `toJson()` / `fromJson()` / `toExportJson()` | ✅ 完整 | `AccountField`、`Hlc`、`SyncStatus`、`TemplateCategory` |
| 12 | `TotpCredential` | `totp_credential.dart` | 核心实体 | `toJson()` / `fromJson()` | ✅ 完整 | `Hlc`、`SyncStatus`、`TotpConfig`（外文件） |
| 13 | `LocalSyncChange` | `local_sync_change.dart` | 同步实体 | `toDatabaseRow()` / `fromDatabaseRow()` | ⚠️ 部分 | 独立 |
| 14 | `LocalSyncEntityType` | `local_sync_change.dart` | 枚举 | `name` / `localSyncEntityTypeFromString()` | - | 被 `LocalSyncChange` 使用 |
| 15 | `LocalSyncAction` | `local_sync_change.dart` | 枚举 | `name` / `localSyncActionFromString()` | - | 被 `LocalSyncChange` 使用 |
| 16 | `LocalSyncStatus` | `local_sync_change.dart` | 枚举 | `name` / `localSyncStatusFromString()` | - | 被 `LocalSyncChange` 使用 |
| 17 | `TemplateConflictLog` | `template_conflict_log.dart` | 日志实体 | `toJson()` / `fromJson()` | ❌ | `Hlc` |
| 18 | `AppNotification` | `app_notification.dart` | 通知实体 | `toRow()` / `fromRow()` | ⚠️ 部分 | 独立 |
| 19 | `AppNotificationType` | `app_notification.dart` | 枚举 | `name` | - | 被 `AppNotification` 使用 |
| 20 | `VaultHealthGrade` | `vault_health_report.dart` | 枚举 | 无 | - | 被 `VaultHealthReport` 使用 |
| 21 | `VaultHealthRiskLevel` | `vault_health_report.dart` | 枚举 | 无 | - | 被 `VaultHealthItem` 使用 |
| 22 | `VaultHealthActionType` | `vault_health_report.dart` | 枚举 | 无 | - | 被 `VaultHealthAction` 使用 |
| 23 | `VaultHealthAction` | `vault_health_report.dart` | 数据类 | 无 | ❌ | 被 `VaultHealthItem` 使用 |
| 24 | `VaultHealthItem` | `vault_health_report.dart` | 数据类 | 无 | ❌ | `VaultHealthAction`、`VaultHealthRiskLevel` |
| 25 | `VaultHealthReport` | `vault_health_report.dart` | 聚合类 | 无 | ❌ | `VaultHealthItem`、`VaultHealthGrade` |

---

## 二、模型关联图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              模型依赖关系                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────┐         ┌──────────────┐          ┌──────────────────┐      │
│   │   Hlc    │◄────────│  AccountItem  │          │ AccountTemplate  │      │
│   └──────────┘         └──────────────┘          └──────────────────┘      │
│        ▲                 │  ▲                       │  ▲                    │
│        │                 │  │ fieldMeta              │  │ fields             │
│        │                 │  └──────────┐            │  └──────────┐         │
│        │                 │             ▼            │             ▼         │
│        │                 │    ┌─────────────┐       │    ┌─────────────┐    │
│        │                 │    │AccountFieldMeta│     │    │ AccountField │    │
│        │                 │    └─────────────┘       │    └─────────────┘    │
│        │                 │                          │           │           │
│        │                 │                          │           ▼           │
│        │                 │                          │   ┌─────────────────┐ │
│        │                 │                          │   │AccountFieldAttrs│ │
│        │                 │                          │   └─────────────────┘ │
│        │                 │                          │                       │
│   ┌────┴─────┐          │                    ┌─────┴─────┐                 │
│   │SyncValue │          │                    │ SyncStatus │                 │
│   └──────────┘          │                    └────────────┘                 │
│                         │                                                   │
│   ┌──────────────┐      │                    ┌──────────────┐              │
│   │TotpCredential│◄─────┘                    │TemplateConflictLog│         │
│   └──────────────┘                           └──────────────┘              │
│        │  ▲                                       ▲                        │
│        │  │ linkedAccountIds (string refs)        │ localHlc / remoteHlc   │
│        │  │                                       │                        │
│   ┌────┴──┴────┐                            ┌────┴────┐                   │
│   │ TotpConfig │ (lib/services/)             │   Hlc   │                   │
│   └────────────┘                            └─────────┘                   │
│                                                                             │
│   ┌──────────────┐     ┌─────────────────┐     ┌──────────────────────┐   │
│   │LocalSyncChange│     │ AppNotification │     │   VaultHealthReport   │   │
│   └──────────────┘     └─────────────────┘     └──────────────────────┘   │
│        │                                              │                     │
│   ┌────┴────┐                                    ┌───┴────┐               │
│   │3 enums  │                                    │3 enums │               │
│   └─────────┘                                    │2 子类  │               │
│                                                  └────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、详细 Schema

### 3.1 `Hlc`（混合逻辑时钟）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `time` | `int` | 否 | - | 物理时间戳（ms since epoch） |
| `counter` | `int` | 否 | - | 逻辑计数器（同毫秒冲突时递增） |
| `nodeId` | `String` | 否 | - | 节点标识（设备 ID） |

**序列化格式**：`"$time-$counter-$nodeId"`  
**兼容性处理**：`parse()` 支持 `nodeId` 含任意数量 `-`；解析失败返回 `Hlc.zero('__corrupted__')`，可通过 `isCorrupted` 检测。

---

### 3.2 `SyncValue<T>`（同步元数据包装器）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `value` | `T` | 否 | - | 原始值 |
| `hlc` | `Hlc` | 否 | - | 版本时钟 |

**JSON 格式**：
```json
{"v": <T>, "hlc": "1234567890-0-deviceA"}
```

**兼容性**：
- `fromJson(Map, T Function(dynamic))`：泛型反序列化
- `fromPrimitiveJson(Map)`：基本类型暴力强转（非类型安全）

---

### 3.3 `SyncStatus`（枚举）

| 值 | 含义 |
|----|------|
| `synchronized` | 已与服务器同步 |
| `pendingPush` | 有待推送的本地变更 |
| `conflict` | 存在同步冲突 |

**序列化**：`toJson` 输出 `name`（String）。  
**反序列化**：`syncStatusFromJson()` 支持：
- `SyncStatus` 实例透传
- `int` 按索引映射（越界 fallback）
- `String` 先尝试 `int.parse`，再按 `name` 匹配
- 默认 fallback：`pendingPush`

---

### 3.4 `AccountFieldMeta`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `type` | `String` | 否 | `'text'` | 字段 UI 类型 |
| `label` | `String` | 否 | `''` | 显示标签 |
| `sourceTemplateId` | `String?` | 是 | `null` | 来源模板 ID |
| `sourceTemplateVersion` | `int?` | 是 | `null` | 来源模板版本 |

**JSON 格式**：
```json
{"type": "text", "label": "用户名", "sourceTemplateId": "tpl_001", "sourceTemplateVersion": 1}
```

**兼容性**：`fromJson` 对 `type`、`label` 提供 fallback。

**⚠️ 风险**：无 `copyWith` 方法。

---

### 3.5 `AccountItem`（核心账户实体）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | `DateTime.now().millisecondsSinceEpoch.toString()` | 唯一 ID |
| `name` | `String` | 否 | `''` | 账户名称 |
| `email` | `String` | 否 | `''` | 邮箱 |
| `templateId` | `String` | 否 | `''` | 关联模板 ID |
| `templateVersion` | `int` | 否 | `0` | 模板版本 |
| `data` | `Map<String, dynamic>` | 否 | `{}` | 自定义字段数据 |
| `fieldMeta` | `Map<String, AccountFieldMeta>` | 否 | `{}` | 字段元数据映射 |
| `createdAt` | `int` | 否 | `DateTime.now().millisecondsSinceEpoch` | 创建时间 |
| `modifiedAt` | `int` | 否 | `0` | 修改时间 |
| `lastEditedBy` | `String?` | 是 | `null` | 最后编辑者 |
| `lastEditedAt` | `int?` | 是 | `null` | 最后编辑时间 |
| `nameHlc` | `Hlc` | 否 | - | name 字段的 HLC |
| `emailHlc` | `Hlc` | 否 | - | email 字段的 HLC |
| `dataHlc` | `Map<String, Hlc>` | 否 | `{}` | 各 data 字段的 HLC |
| `serverVersion` | `int` | 否 | `0` | 服务器版本号 |
| `syncStatus` | `SyncStatus` | 否 | `pendingPush` | 同步状态 |
| `isDeleted` | `bool` | 否 | `false` | 软删除标记 |
| `deleteHlc` | `Hlc?` | 是 | `null` | 删除操作的 HLC |
| `isPinned` | `bool` | 否 | `false` | 置顶标记 |
| `pinHlc` | `Hlc?` | 是 | `null` | 置顶操作的 HLC |

**JSON 输出示例**：
```json
{
  "id": "1715770000000",
  "name": "GitHub",
  "email": "user@example.com",
  "template": "builtin_generic_info",
  "templateId": "builtin_generic_info",
  "templateVersion": 1,
  "data": {"website": "https://github.com", "username": "user"},
  "fieldMeta": {"website": {"type": "url", "label": "网站"}},
  "createdAt": 1715770000000,
  "modifiedAt": 0,
  "lastEditedBy": null,
  "lastEditedAt": null,
  "nameHlc": "1715770000000-0-local",
  "emailHlc": "1715770000000-0-local",
  "dataHlc": {"website": "1715770000000-0-local"},
  "serverVersion": 0,
  "syncStatus": "pendingPush",
  "isDeleted": false,
  "deleteHlc": null,
  "isPinned": false,
  "pinHlc": null
}
```

**`fromJson` 兼容性处理**：
- `templateId`：优先读 `template`（旧字段名），fallback 到 `templateId`
- `isDeleted`：支持 `1` 或 `true`（兼容 SQLite bool 存储）
- `isPinned`：支持 `1` 或 `true`
- `id`、`name`、`email`、`createdAt`：缺失时回退到当前时间戳
- `fieldMeta`：缺失时为空 Map
- `dataHlc`：缺失时为空 Map
- `nameHlc`、`emailHlc`：缺失时回退 `Hlc.zero('local')`

**`copyWith`**：✅ 完整，覆盖全部 19 个字段。

**版本风险**：
- `isPinned` / `pinHlc` 为较新增字段，旧数据缺失时默认 `false` / `null`
- `templateId` 字段名从旧 `template` 迁移而来，双字段输出以保持向后兼容

---

### 3.6 `AccountFieldAttributes`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `type` | `AccountFieldType` | 否 | - | 字段类型 |
| `isPrimary` | `bool` | 否 | `false` | 是否主字段 |
| `isRequired` | `bool` | 否 | `false` | 是否必填 |
| `isSecret` | `bool` | 否 | `false` | 是否敏感（隐藏） |
| `isEditable` | `bool` | 否 | `true` | 是否可编辑 |
| `isSearchable` | `bool` | 否 | `false` | 是否可搜索 |
| `isCopyable` | `bool` | 否 | `true` | 是否可复制 |
| `isReference` | `bool` | 否 | `false` | 是否引用（如 TOTP 关联） |
| `maxLength` | `int?` | 是 | `null` | 最大长度 |
| `minLength` | `int?` | 是 | `null` | 最小长度 |
| `regex` | `String?` | 是 | `null` | 校验正则 |
| `hint` | `String?` | 是 | `null` | 输入提示 |
| `timeFormat` | `TimeFieldFormat` | 否 | `full` | 时间字段显示格式 |

**JSON 输出示例**：
```json
{
  "type": "url",
  "isPrimary": true,
  "isRequired": true,
  "isSecret": false,
  "isEditable": true,
  "isSearchable": true,
  "isCopyable": true,
  "isReference": false,
  "maxLength": null,
  "minLength": null,
  "regex": null,
  "hint": "https://example.com",
  "timeFormat": "full"
}
```

**兼容性处理**：
- `type`：缺失 fallback 到 `text`，未知值 fallback 到 `AccountFieldType.unknown`
- `isEditable`：缺失 fallback `true`（`!= false`）
- `isCopyable`：缺失 fallback `true`（`!= false`）
- `timeFormat`：缺失 fallback `TimeFieldFormat.full`

**⚠️ 风险**：无 `copyWith` 方法。

---

### 3.7 `AccountField`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `fieldKey` | `String` | 否 | `''` | 字段键 |
| `label` | `String` | 否 | `''` | 显示标签 |
| `description` | `String?` | 是 | `null` | 描述 |
| `attributes` | `AccountFieldAttributes` | 否 | - | 属性 |
| `order` | `int` | 否 | `0` | 排序 |
| `labelHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | label 的 HLC |
| `descriptionHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | description 的 HLC |
| `attributesHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | attributes 的 HLC |
| `orderHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | order 的 HLC |

**JSON 输出示例**：
```json
{
  "fieldKey": "website",
  "label": "网站",
  "description": null,
  "attributes": {"type": "url", "isPrimary": true, ...},
  "order": 0,
  "labelHlc": "0-0-local",
  "descriptionHlc": "0-0-local",
  "attributesHlc": "0-0-local",
  "orderHlc": "0-0-local"
}
```

**兼容性处理**：
- 四个 HLC 字段缺失时均 fallback 到 `Hlc.zero('local')`
- `attributes` 缺失时 fallback 到空 Map `{}`

**导出格式**（`toExportJson`）：不包含 HLC 字段，用于模板导出。

**`copyWith`**：✅ 完整，覆盖全部 9 个字段。

---

### 3.8 `AccountTemplate`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `templateId` | `String` | 否 | `'custom_${ms}'` | 模板 ID |
| `version` | `int` | 否 | `1` | 版本号 |
| `title` | `String` | 否 | `'Untitled Template'` | 标题 |
| `subTitle` | `String` | 否 | `''` | 副标题 |
| `iconCodePoint` | `int?` | 是 | `null` | 图标 Unicode codePoint |
| `category` | `TemplateCategory` | 否 | `inferTemplateCategory(...)` | 分类 |
| `fields` | `List<AccountField>` | 否 | `[]` | 字段列表 |
| `isCustom` | `bool` | 否 | `false` | 是否自定义模板 |
| `createdAt` | `int?` | 是 | `null` | 创建时间 |
| `modifiedAt` | `int?` | 是 | `null` | 修改时间 |
| `lastEditedBy` | `String?` | 是 | `null` | 最后编辑者 |
| `lastEditedAt` | `int?` | 是 | `null` | 最后编辑时间 |
| `syncStatus` | `SyncStatus` | 否 | `pendingPush` | 同步状态 |
| `hlc` | `Hlc?` | 是 | `null` | 模板整体 HLC |
| `serverVersion` | `int` | 否 | `0` | 服务器版本号 |
| `isDeleted` | `bool` | 否 | `false` | 软删除标记 |
| `deleteHlc` | `Hlc?` | 是 | `null` | 删除 HLC |

**JSON 输出示例**：
```json
{
  "templateId": "custom_1715770000000",
  "version": 1,
  "title": "API 服务",
  "subtitle": "存储 API Key、Token 和端点信息",
  "icon": 58715,
  "category": "custom",
  "fields": [...],
  "createdAt": null,
  "modifiedAt": null,
  "lastEditedBy": null,
  "lastEditedAt": null,
  "syncStatus": "pendingPush",
  "hlc": null,
  "serverVersion": 0,
  "isDeleted": false,
  "deleteHlc": null
}
```

**兼容性处理**：
- `subTitle`：优先读旧字段名 `subtitle`，fallback 到 `subTitle`
- `icon`：支持 `int` 或 `String`（自动 `int.tryParse`）
- `category`：**智能推断**：缺失时根据 `iconCodePoint`、`title`、`fields` 内容推断分类（含中英文关键词匹配）
- `syncStatus`：fallback 为 `synchronized`（注意与 `AccountItem` 的 `pendingPush` 不同）
- `templateId`：缺失时自动生成 `custom_${timestamp}`
- `isDeleted`：仅支持 `true`（无 `== 1` 兼容，与 `AccountItem` 不一致）

**导出格式**（`toExportJson`**）：不包含 `syncStatus`、`hlc`、`serverVersion`、`isDeleted`、`deleteHlc`、`createdAt`、`modifiedAt`、`lastEditedBy`、`lastEditedAt`，纯净模板数据。

**`copyWith`**：✅ 完整，覆盖全部 16 个字段。

**版本风险**：
- `category` 为智能推断字段，旧数据无显式分类时依赖推断逻辑
- `subTitle` 旧字段名为 `subtitle`，已做双 key 兼容

---

### 3.9 `TotpCredential`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | `DateTime.now().millisecondsSinceEpoch.toString()` | 唯一 ID |
| `label` | `String` | 否 | `''` | 自定义标签 |
| `config` | `TotpConfig` | 否 | - | TOTP 配置（含 secret、issuer、algorithm 等） |
| `linkedAccountIds` | `List<String>` | 否 | `[]` | 关联账户 ID 列表（去重+trim） |
| `createdAt` | `int` | 否 | `DateTime.now().millisecondsSinceEpoch` | 创建时间 |
| `labelHlc` | `Hlc` | 否 | `Hlc.zero('local')` | label 的 HLC |
| `configHlc` | `Hlc` | 否 | `Hlc.zero('local')` | config 的 HLC |
| `linksHlc` | `Hlc` | 否 | `Hlc.zero('local')` | links 的 HLC |
| `serverVersion` | `int` | 否 | `0` | 服务器版本号 |
| `syncStatus` | `SyncStatus` | 否 | `pendingPush` | 同步状态 |
| `isDeleted` | `bool` | 否 | `false` | 软删除标记 |
| `deleteHlc` | `Hlc?` | 是 | `null` | 删除 HLC |

**JSON 输出示例**：
```json
{
  "id": "1715770000000",
  "label": "GitHub 2FA",
  "config": {"secret": "JBSWY3DPEHPK3PXP", "issuer": "GitHub", "algorithm": "SHA1", "digits": 6, "period": 30},
  "linkedAccountIds": ["acc_001"],
  "createdAt": 1715770000000,
  "labelHlc": "0-0-local",
  "configHlc": "0-0-local",
  "linksHlc": "0-0-local",
  "serverVersion": 0,
  "syncStatus": "pendingPush",
  "isDeleted": false,
  "deleteHlc": null
}
```

**兼容性处理**：
- `config`：支持 `TotpConfig` 实例、`Map<String, dynamic>`、`Map`、`String`（OTP URI），通过 `_readConfig()` 统一处理
- `linkedAccountIds`：支持 `List<dynamic>`，通过 `_readLinkedAccountIds()` 统一转为 `List<String>` 并去重 trim
- `isDeleted`：支持 `1` 或 `true`（与 `AccountItem` 一致）
- `labelHlc`、`configHlc`、`linksHlc`：缺失 fallback `Hlc.zero('local')`

**`copyWith`**：✅ 完整，覆盖全部 12 个字段。

---

### 3.10 `LocalSyncChange`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | - | 变更 ID |
| `vaultId` | `String` | 否 | `''` | 保险库 ID |
| `entityType` | `LocalSyncEntityType` | 否 | `account` | 实体类型 |
| `entityId` | `String` | 否 | `''` | 实体 ID |
| `action` | `LocalSyncAction` | 否 | `update` | 操作类型 |
| `title` | `String` | 否 | `''` | 变更标题 |
| `beforeJson` | `String?` | 是 | `null` | 变更前 JSON 快照 |
| `afterJson` | `String?` | 是 | `null` | 变更后 JSON 快照 |
| `diff` | `Map<String, dynamic>` | 否 | `{}` | 差异数据 |
| `baseServerVersion` | `int` | 否 | `0` | 基准服务器版本 |
| `status` | `LocalSyncStatus` | 否 | `pendingReview` | 同步状态 |
| `createdAt` | `int` | 否 | `0` | 创建时间 |
| `updatedAt` | `int` | 否 | `0` | 更新时间 |
| `approvedAt` | `int?` | 是 | `null` | 批准时间 |
| `pushedAt` | `int?` | 是 | `null` | 推送时间 |
| `errorMessage` | `String?` | 是 | `null` | 错误信息 |

**数据库 Row 输出示例**：
```json
{
  "id": "uuid",
  "vault_id": "vault_001",
  "entity_type": "account",
  "entity_id": "acc_001",
  "action": "update",
  "title": "修改密码",
  "before_json": "{\"name\":\"old\"}",
  "after_json": "{\"name\":\"new\"}",
  "diff_json": "{\"changed_fields\":[\"name\"]}",
  "base_server_version": 5,
  "status": "pendingReview",
  "created_at": 1715770000000,
  "updated_at": 1715770000000,
  "approved_at": null,
  "pushed_at": null,
  "error_message": null
}
```

**兼容性处理**：
- 三个枚举均有 `fromString` 方法，未知值 fallback 到默认值并打印 `AppLogger.w` 警告
- `diff_json` 为空时存储为 `null`
- `is_read` / `is_deleted` 等 SQLite bool 风格不在此模型中，纯 Dart bool

**`copyWith`**：⚠️ **部分**，仅支持 `status`、`approvedAt`、`pushedAt`、`errorMessage`（生命周期字段）。不可变身份字段（`id`、`entityType`、`action`、`diff` 等）不提供修改。

---

### 3.11 `TemplateConflictLog`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | `Uuid().v4()` | 日志 ID（自动生成） |
| `templateId` | `String` | 否 | - | 模板 ID |
| `fieldKey` | `String` | 否 | - | 字段键 |
| `attributeName` | `String` | 否 | - | 冲突属性名 |
| `localValue` | `String` | 否 | - | 本地值 |
| `remoteValue` | `String` | 否 | - | 远程值 |
| `localHlc` | `Hlc` | 否 | - | 本地版本 HLC |
| `remoteHlc` | `Hlc` | 否 | - | 远程版本 HLC |
| `savedAt` | `int` | 否 | `DateTime.now().millisecondsSinceEpoch` | 保存时间 |

**JSON 输出示例**：
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "templateId": "tpl_001",
  "fieldKey": "label",
  "attributeName": "label",
  "localValue": "网站",
  "remoteValue": "Website",
  "localHlc": "1715770000000-0-deviceA",
  "remoteHlc": "1715770000001-0-deviceB",
  "savedAt": 1715770000000
}
```

**兼容性处理**：
- `fromJson` 为**严格模式**，无任何 fallback。缺失字段将抛出 `TypeError`。
- `id` 构造时自动生成，但 `fromJson` 要求必须存在。

**⚠️ 风险**：无 `copyWith` 方法；`fromJson` 零容错。

---

### 3.12 `AppNotification`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | - | 通知 ID |
| `type` | `AppNotificationType` | 否 | - | 类型 |
| `title` | `String` | 否 | `''` | 标题 |
| `body` | `String` | 否 | `''` | 正文 |
| `accountId` | `String?` | 是 | `null` | 关联账户 ID |
| `createdAt` | `int` | 否 | `0` | 创建时间 |
| `isRead` | `bool` | 否 | `false` | 是否已读 |
| `params` | `Map<String, dynamic>` | 否 | `{}` | 扩展参数 |

**数据库 Row 输出示例**：
```json
{
  "id": "notif_001",
  "type": "weakPassword",
  "title": "",
  "body": "",
  "account_id": "acc_001",
  "created_at": 1715770000000,
  "is_read": 0,
  "params": "{\"accountName\":\"GitHub\",\"score\":45}"
}
```

**兼容性处理**：
- `type`：未知值 fallback 到 `passwordExpiry`
- `isRead`：从 row 读取时 `== 1`（兼容 SQLite int bool）
- `params`：JSON 解析失败静默 swallow，回退 `{}`

**`copyWith`**：⚠️ **部分**，仅支持 `isRead`。

---

### 3.13 `VaultHealthReport`（聚合类，无序列化）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `score` | `int` | 否 | - | 健康评分（0-100） |
| `grade` | `VaultHealthGrade` | 否 | - | 评级（excellent/good/warning/critical） |
| `items` | `List<VaultHealthItem>` | 否 | - | 检查项列表 |
| `calculatedAt` | `DateTime` | 否 | - | 计算时间 |

**子类 `VaultHealthItem`**：
| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | - | 检查项 ID |
| `title` | `String` | 否 | - | 标题 |
| `riskLevel` | `VaultHealthRiskLevel` | 否 | - | 风险等级 |
| `isPass` | `bool` | 否 | - | 是否通过 |
| `description` | `String` | 否 | - | 描述 |
| `action` | `VaultHealthAction?` | 是 | `null` | 建议操作 |

**子类 `VaultHealthAction`**：
| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `type` | `VaultHealthActionType` | 否 | - | 操作类型 |
| `targetId` | `String?` | 是 | `null` | 单个目标 ID |
| `targetIds` | `List<String>` | 否 | `[]` | 多个目标 ID |

**⚠️ 风险**：
- 该类**无任何序列化方法**（无 `toJson` / `fromJson` / `toRow` / `fromRow`）。
- 无 `copyWith` 方法。
- 为纯内存聚合对象，生命周期仅限单次健康检查计算。

---

## 四、JSON 兼容性矩阵

| 模型 | 旧字段名兼容 | 缺失字段 fallback | 类型容错（int/String/bool） | 零容错字段 |
|------|-------------|------------------|---------------------------|----------|
| `Hlc` | - | 解析失败 → `zero('__corrupted__')` | `String` only | - |
| `SyncValue<T>` | - | - | - | `v`, `hlc` |
| `SyncStatus` | - | `pendingPush` | `int` / `String` / `SyncStatus` | - |
| `AccountFieldMeta` | - | `type='text'`, `label=''` | - | - |
| `AccountItem` | `template`→`templateId` | 大量 fallback（见 3.5） | `isDeleted`: `1`或`true` | - |
| `AccountFieldAttributes` | - | 多个 bool: `false`/`true` 语义 | - | - |
| `AccountField` | - | 4 个 HLC → `zero('local')` | - | - |
| `AccountTemplate` | `subtitle`→`subTitle` | 智能推断 `category` | `icon`: `int`/`String` | - |
| `TotpCredential` | - | 3 个 HLC → `zero('local')` | `isDeleted`: `1`或`true` | - |
| `LocalSyncChange` | - | 3 个枚举有 fallback | - | `id` |
| `TemplateConflictLog` | - | **无 fallback** | - | **全部字段** |
| `AppNotification` | - | `type`→`passwordExpiry` | `isRead`: `==1` | `id` |
| `VaultHealthReport` | N/A | N/A | N/A | N/A |

---

## 五、copyWith 完整性检查

| 模型 | copyWith | 覆盖字段数 | 总字段数 | 完整性 | 备注 |
|------|---------|-----------|---------|--------|------|
| `AccountItem` | ✅ | 19 | 19 | 100% | - |
| `AccountFieldMeta` | ❌ | 0 | 4 | 0% | 建议补充 |
| `AccountFieldAttributes` | ❌ | 0 | 13 | 0% | 建议补充 |
| `AccountField` | ✅ | 9 | 9 | 100% | - |
| `AccountTemplate` | ✅ | 16 | 16 | 100% | - |
| `TotpCredential` | ✅ | 12 | 12 | 100% | - |
| `LocalSyncChange` | ⚠️ | 4 | 16 | 25% | 仅生命周期字段可变更 |
| `TemplateConflictLog` | ❌ | 0 | 9 | 0% | 建议补充 |
| `AppNotification` | ⚠️ | 1 | 8 | 12.5% | 仅 `isRead` 可变更 |
| `VaultHealthReport` | ❌ | 0 | 4 | 0% | 纯聚合对象 |
| `VaultHealthItem` | ❌ | 0 | 6 | 0% | 纯聚合对象 |
| `VaultHealthAction` | ❌ | 0 | 3 | 0% | 纯聚合对象 |

---

## 六、TODO / FIXME / HACK 清单

**`lib/models/` 目录内**：**零条**  
> 经全文扫描，8 个模型文件中未出现 `TODO`、`FIXME`、`HACK`、`XXX` 注释。

---

## 七、版本兼容性风险清单

| 风险等级 | 位置 | 说明 |
|---------|------|------|
| 🔴 **高** | `AccountItem.templateId` | `toJson` 同时输出 `template` 和 `templateId`，但 `fromJson` 优先读旧字段 `template`。未来应逐步淘汰双字段输出。 |
| 🔴 **高** | `AccountTemplate.fromJson` | `category` 依赖智能推断（含中英文关键词 + iconCodePoint + fields 内容）。若推断逻辑变更，旧数据反序列化后分类可能不一致。 |
| 🟡 **中** | `AccountItem.isPinned` / `pinHlc` | 较新增字段，旧数据缺失时默认 `false`/`null`。需确认 UI/数据库层是否正确处理 `null`。 |
| 🟡 **中** | `TemplateConflictLog.fromJson` | **零容错**：任何字段缺失或类型错误均抛出异常。与项目中其他模型的宽容策略不一致。 |
| 🟡 **中** | `TotpCredential.config` | 反序列化时 `_readConfig` 支持 `TotpConfig`/`Map`/`String` 三种输入，但 `String` 走 `TotpService.parseConfig`，若 URI 格式非法会抛 `TotpException`。 |
| 🟡 **中** | `LocalSyncChange` 枚举 fallback | 未知枚举值均 fallback 到默认值，但会打印 `AppLogger.w`。大量非法数据可能导致日志噪音。 |
| 🟢 **低** | `AccountTemplate.subTitle` | `fromJson` 兼容旧 `subtitle` 字段名，风险可控。 |
| 🟢 **低** | `VaultHealthReport` | 无序列化，纯内存对象，无持久化兼容性风险。 |

---

## 八、关键发现与建议

1. **copyWith 缺口**：`AccountFieldMeta`、`AccountFieldAttributes`、`TemplateConflictLog` 三个高频使用的模型缺少 `copyWith`，在 UI 状态更新或 CRDT 合并时容易因手动构造对象导致 HLC 丢失。
2. **布尔值存储不一致**：`AccountItem` 和 `TotpCredential` 的 `isDeleted` 支持 `1` 或 `true`，但 `AccountTemplate` 的 `isDeleted` 仅支持 `true`。若三者在同一 SQLite 表中存储，可能存在兼容性问题。
3. **`TemplateConflictLog` 反序列化过于严格**：与其他模型的宽容策略不一致，建议为各字段补充 fallback（如 `id` 缺失时生成 UUID）。
4. **无 TODO/FIXME**：代码整洁度良好，但可能意味着部分已知问题未标记（如上述 `fromJson` 严格性差异）。
5. **`VaultHealthReport` 无序列化**：当前为纯内存对象，若未来需要持久化健康检查历史，需补充 `toJson` / `fromJson`。[stage] run_soul_finished

[summary]
# SecretRoy 数据模型 Schema 手册

> 扫描范围：`lib/models/`（8 个文件，12 个核心类/枚举）  
> 扫描时间：2026-05-16  
> 关联外部依赖：`lib/services/totp_service.dart`（`TotpConfig`、`TotpException`）

---

## 一、模型总览表

| # | 类/枚举名 | 所在文件 | 类型 | 序列化方式 | copyWith | 关联模型 |
|---|-----------|--------|------|-----------|----------|----------|
| 1 | `Hlc` | `hlc.dart` | 数据类 | `toString()` / `parse()` | ❌ | 被所有模型引用 |
| 2 | `SyncValue<T>` | `hlc.dart` | 泛型包装 | `toJson()` / `fromJson()` / `fromPrimitiveJson()` | ❌ | 引用 `Hlc` |
| 3 | `SyncStatus` | `account_item.dart` | 枚举 | `name` / `syncStatusFromJson()` | - | `AccountItem`、`AccountTemplate`、`TotpCredential` |
| 4 | `AccountFieldMeta` | `account_item.dart` | 数据类 | `toJson()` / `fromJson()` | ❌ | 被 `AccountItem` 引用 |
| 5 | `AccountItem` | `account_item.dart` | 核心实体 | `toJson()` / `fromJson()` | ✅ 完整 | `Hlc`、`AccountFieldMeta`、`AccountTemplate`、`SyncStatus` |
| 6 | `AccountFieldType` | `account_template.dart` | 枚举 | `name` / `fieldTypeFromString()` | - | 被 `AccountFieldAttributes` 使用 |
| 7 | `TimeFieldFormat` | `account_template.dart` | 枚举 | `name` | - | 被 `AccountFieldAttributes` 使用 |
| 8 | `TemplateCategory` | `account_template.dart` | 枚举 | `name` / `templateCategoryFromString()` | - | 被 `AccountTemplate` 使用 |
| 9 | `AccountFieldAttributes` | `account_template.dart` | 数据类 | `toJson()` / `fromJson()` | ❌ | 被 `AccountField` 引用 |
| 10 | `AccountField` | `account_template.dart` | 数据类 | `toJson()` / `fromJson()` / `toExportJson()` | ✅ 完整 | `Hlc`、`AccountFieldAttributes` |
| 11 | `AccountTemplate` | `account_template.dart` | 核心实体 | `toJson()` / `fromJson()` / `toExportJson()` | ✅ 完整 | `AccountField`、`Hlc`、`SyncStatus`、`TemplateCategory` |
| 12 | `TotpCredential` | `totp_credential.dart` | 核心实体 | `toJson()` / `fromJson()` | ✅ 完整 | `Hlc`、`SyncStatus`、`TotpConfig`（外文件） |
| 13 | `LocalSyncChange` | `local_sync_change.dart` | 同步实体 | `toDatabaseRow()` / `fromDatabaseRow()` | ⚠️ 部分 | 独立 |
| 14 | `LocalSyncEntityType` | `local_sync_change.dart` | 枚举 | `name` / `localSyncEntityTypeFromString()` | - | 被 `LocalSyncChange` 使用 |
| 15 | `LocalSyncAction` | `local_sync_change.dart` | 枚举 | `name` / `localSyncActionFromString()` | - | 被 `LocalSyncChange` 使用 |
| 16 | `LocalSyncStatus` | `local_sync_change.dart` | 枚举 | `name` / `localSyncStatusFromString()` | - | 被 `LocalSyncChange` 使用 |
| 17 | `TemplateConflictLog` | `template_conflict_log.dart` | 日志实体 | `toJson()` / `fromJson()` | ❌ | `Hlc` |
| 18 | `AppNotification` | `app_notification.dart` | 通知实体 | `toRow()` / `fromRow()` | ⚠️ 部分 | 独立 |
| 19 | `AppNotificationType` | `app_notification.dart` | 枚举 | `name` | - | 被 `AppNotification` 使用 |
| 20 | `VaultHealthGrade` | `vault_health_report.dart` | 枚举 | 无 | - | 被 `VaultHealthReport` 使用 |
| 21 | `VaultHealthRiskLevel` | `vault_health_report.dart` | 枚举 | 无 | - | 被 `VaultHealthItem` 使用 |
| 22 | `VaultHealthActionType` | `vault_health_report.dart` | 枚举 | 无 | - | 被 `VaultHealthAction` 使用 |
| 23 | `VaultHealthAction` | `vault_health_report.dart` | 数据类 | 无 | ❌ | 被 `VaultHealthItem` 使用 |
| 24 | `VaultHealthItem` | `vault_health_report.dart` | 数据类 | 无 | ❌ | `VaultHealthAction`、`VaultHealthRiskLevel` |
| 25 | `VaultHealthReport` | `vault_health_report.dart` | 聚合类 | 无 | ❌ | `VaultHealthItem`、`VaultHealthGrade` |

---

## 二、模型关联图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              模型依赖关系                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌──────────┐         ┌──────────────┐          ┌──────────────────┐      │
│   │   Hlc    │◄────────│  AccountItem  │          │ AccountTemplate  │      │
│   └──────────┘         └──────────────┘          └──────────────────┘      │
│        ▲                 │  ▲                       │  ▲                    │
│        │                 │  │ fieldMeta              │  │ fields             │
│        │                 │  └──────────┐            │  └──────────┐         │
│        │                 │             ▼            │             ▼         │
│        │                 │    ┌─────────────┐       │    ┌─────────────┐    │
│        │                 │    │AccountFieldMeta│     │    │ AccountField │    │
│        │                 │    └─────────────┘       │    └─────────────┘    │
│        │                 │                          │           │           │
│        │                 │                          │           ▼           │
│        │                 │                          │   ┌─────────────────┐ │
│        │                 │                          │   │AccountFieldAttrs│ │
│        │                 │                          │   └─────────────────┘ │
│        │                 │                          │                       │
│   ┌────┴─────┐          │                    ┌─────┴─────┐                 │
│   │SyncValue │          │                    │ SyncStatus │                 │
│   └──────────┘          │                    └────────────┘                 │
│                         │                                                   │
│   ┌──────────────┐      │                    ┌──────────────┐              │
│   │TotpCredential│◄─────┘                    │TemplateConflictLog│         │
│   └──────────────┘                           └──────────────┘              │
│        │  ▲                                       ▲                        │
│        │  │ linkedAccountIds (string refs)        │ localHlc / remoteHlc   │
│        │  │                                       │                        │
│   ┌────┴──┴────┐                            ┌────┴────┐                   │
│   │ TotpConfig │ (lib/services/)             │   Hlc   │                   │
│   └────────────┘                            └─────────┘                   │
│                                                                             │
│   ┌──────────────┐     ┌─────────────────┐     ┌──────────────────────┐   │
│   │LocalSyncChange│     │ AppNotification │     │   VaultHealthReport   │   │
│   └──────────────┘     └─────────────────┘     └──────────────────────┘   │
│        │                                              │                     │
│   ┌────┴────┐                                    ┌───┴────┐               │
│   │3 enums  │                                    │3 enums │               │
│   └─────────┘                                    │2 子类  │               │
│                                                  └────────┘               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、详细 Schema

### 3.1 `Hlc`（混合逻辑时钟）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `time` | `int` | 否 | - | 物理时间戳（ms since epoch） |
| `counter` | `int` | 否 | - | 逻辑计数器（同毫秒冲突时递增） |
| `nodeId` | `String` | 否 | - | 节点标识（设备 ID） |

**序列化格式**：`"$time-$counter-$nodeId"`  
**兼容性处理**：`parse()` 支持 `nodeId` 含任意数量 `-`；解析失败返回 `Hlc.zero('__corrupted__')`，可通过 `isCorrupted` 检测。

---

### 3.2 `SyncValue<T>`（同步元数据包装器）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `value` | `T` | 否 | - | 原始值 |
| `hlc` | `Hlc` | 否 | - | 版本时钟 |

**JSON 格式**：
```json
{"v": <T>, "hlc": "1234567890-0-deviceA"}
```

**兼容性**：
- `fromJson(Map, T Function(dynamic))`：泛型反序列化
- `fromPrimitiveJson(Map)`：基本类型暴力强转（非类型安全）

---

### 3.3 `SyncStatus`（枚举）

| 值 | 含义 |
|----|------|
| `synchronized` | 已与服务器同步 |
| `pendingPush` | 有待推送的本地变更 |
| `conflict` | 存在同步冲突 |

**序列化**：`toJson` 输出 `name`（String）。  
**反序列化**：`syncStatusFromJson()` 支持：
- `SyncStatus` 实例透传
- `int` 按索引映射（越界 fallback）
- `String` 先尝试 `int.parse`，再按 `name` 匹配
- 默认 fallback：`pendingPush`

---

### 3.4 `AccountFieldMeta`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `type` | `String` | 否 | `'text'` | 字段 UI 类型 |
| `label` | `String` | 否 | `''` | 显示标签 |
| `sourceTemplateId` | `String?` | 是 | `null` | 来源模板 ID |
| `sourceTemplateVersion` | `int?` | 是 | `null` | 来源模板版本 |

**JSON 格式**：
```json
{"type": "text", "label": "用户名", "sourceTemplateId": "tpl_001", "sourceTemplateVersion": 1}
```

**兼容性**：`fromJson` 对 `type`、`label` 提供 fallback。

**⚠️ 风险**：无 `copyWith` 方法。

---

### 3.5 `AccountItem`（核心账户实体）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | `DateTime.now().millisecondsSinceEpoch.toString()` | 唯一 ID |
| `name` | `String` | 否 | `''` | 账户名称 |
| `email` | `String` | 否 | `''` | 邮箱 |
| `templateId` | `String` | 否 | `''` | 关联模板 ID |
| `templateVersion` | `int` | 否 | `0` | 模板版本 |
| `data` | `Map<String, dynamic>` | 否 | `{}` | 自定义字段数据 |
| `fieldMeta` | `Map<String, AccountFieldMeta>` | 否 | `{}` | 字段元数据映射 |
| `createdAt` | `int` | 否 | `DateTime.now().millisecondsSinceEpoch` | 创建时间 |
| `modifiedAt` | `int` | 否 | `0` | 修改时间 |
| `lastEditedBy` | `String?` | 是 | `null` | 最后编辑者 |
| `lastEditedAt` | `int?` | 是 | `null` | 最后编辑时间 |
| `nameHlc` | `Hlc` | 否 | - | name 字段的 HLC |
| `emailHlc` | `Hlc` | 否 | - | email 字段的 HLC |
| `dataHlc` | `Map<String, Hlc>` | 否 | `{}` | 各 data 字段的 HLC |
| `serverVersion` | `int` | 否 | `0` | 服务器版本号 |
| `syncStatus` | `SyncStatus` | 否 | `pendingPush` | 同步状态 |
| `isDeleted` | `bool` | 否 | `false` | 软删除标记 |
| `deleteHlc` | `Hlc?` | 是 | `null` | 删除操作的 HLC |
| `isPinned` | `bool` | 否 | `false` | 置顶标记 |
| `pinHlc` | `Hlc?` | 是 | `null` | 置顶操作的 HLC |

**JSON 输出示例**：
```json
{
  "id": "1715770000000",
  "name": "GitHub",
  "email": "user@example.com",
  "template": "builtin_generic_info",
  "templateId": "builtin_generic_info",
  "templateVersion": 1,
  "data": {"website": "https://github.com", "username": "user"},
  "fieldMeta": {"website": {"type": "url", "label": "网站"}},
  "createdAt": 1715770000000,
  "modifiedAt": 0,
  "lastEditedBy": null,
  "lastEditedAt": null,
  "nameHlc": "1715770000000-0-local",
  "emailHlc": "1715770000000-0-local",
  "dataHlc": {"website": "1715770000000-0-local"},
  "serverVersion": 0,
  "syncStatus": "pendingPush",
  "isDeleted": false,
  "deleteHlc": null,
  "isPinned": false,
  "pinHlc": null
}
```

**`fromJson` 兼容性处理**：
- `templateId`：优先读 `template`（旧字段名），fallback 到 `templateId`
- `isDeleted`：支持 `1` 或 `true`（兼容 SQLite bool 存储）
- `isPinned`：支持 `1` 或 `true`
- `id`、`name`、`email`、`createdAt`：缺失时回退到当前时间戳
- `fieldMeta`：缺失时为空 Map
- `dataHlc`：缺失时为空 Map
- `nameHlc`、`emailHlc`：缺失时回退 `Hlc.zero('local')`

**`copyWith`**：✅ 完整，覆盖全部 19 个字段。

**版本风险**：
- `isPinned` / `pinHlc` 为较新增字段，旧数据缺失时默认 `false` / `null`
- `templateId` 字段名从旧 `template` 迁移而来，双字段输出以保持向后兼容

---

### 3.6 `AccountFieldAttributes`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `type` | `AccountFieldType` | 否 | - | 字段类型 |
| `isPrimary` | `bool` | 否 | `false` | 是否主字段 |
| `isRequired` | `bool` | 否 | `false` | 是否必填 |
| `isSecret` | `bool` | 否 | `false` | 是否敏感（隐藏） |
| `isEditable` | `bool` | 否 | `true` | 是否可编辑 |
| `isSearchable` | `bool` | 否 | `false` | 是否可搜索 |
| `isCopyable` | `bool` | 否 | `true` | 是否可复制 |
| `isReference` | `bool` | 否 | `false` | 是否引用（如 TOTP 关联） |
| `maxLength` | `int?` | 是 | `null` | 最大长度 |
| `minLength` | `int?` | 是 | `null` | 最小长度 |
| `regex` | `String?` | 是 | `null` | 校验正则 |
| `hint` | `String?` | 是 | `null` | 输入提示 |
| `timeFormat` | `TimeFieldFormat` | 否 | `full` | 时间字段显示格式 |

**JSON 输出示例**：
```json
{
  "type": "url",
  "isPrimary": true,
  "isRequired": true,
  "isSecret": false,
  "isEditable": true,
  "isSearchable": true,
  "isCopyable": true,
  "isReference": false,
  "maxLength": null,
  "minLength": null,
  "regex": null,
  "hint": "https://example.com",
  "timeFormat": "full"
}
```

**兼容性处理**：
- `type`：缺失 fallback 到 `text`，未知值 fallback 到 `AccountFieldType.unknown`
- `isEditable`：缺失 fallback `true`（`!= false`）
- `isCopyable`：缺失 fallback `true`（`!= false`）
- `timeFormat`：缺失 fallback `TimeFieldFormat.full`

**⚠️ 风险**：无 `copyWith` 方法。

---

### 3.7 `AccountField`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `fieldKey` | `String` | 否 | `''` | 字段键 |
| `label` | `String` | 否 | `''` | 显示标签 |
| `description` | `String?` | 是 | `null` | 描述 |
| `attributes` | `AccountFieldAttributes` | 否 | - | 属性 |
| `order` | `int` | 否 | `0` | 排序 |
| `labelHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | label 的 HLC |
| `descriptionHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | description 的 HLC |
| `attributesHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | attributes 的 HLC |
| `orderHlc` | `Hlc` | 否 | `Hlc(0,0,'local')` | order 的 HLC |

**JSON 输出示例**：
```json
{
  "fieldKey": "website",
  "label": "网站",
  "description": null,
  "attributes": {"type": "url", "isPrimary": true, ...},
  "order": 0,
  "labelHlc": "0-0-local",
  "descriptionHlc": "0-0-local",
  "attributesHlc": "0-0-local",
  "orderHlc": "0-0-local"
}
```

**兼容性处理**：
- 四个 HLC 字段缺失时均 fallback 到 `Hlc.zero('local')`
- `attributes` 缺失时 fallback 到空 Map `{}`

**导出格式**（`toExportJson`）：不包含 HLC 字段，用于模板导出。

**`copyWith`**：✅ 完整，覆盖全部 9 个字段。

---

### 3.8 `AccountTemplate`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `templateId` | `String` | 否 | `'custom_${ms}'` | 模板 ID |
| `version` | `int` | 否 | `1` | 版本号 |
| `title` | `String` | 否 | `'Untitled Template'` | 标题 |
| `subTitle` | `String` | 否 | `''` | 副标题 |
| `iconCodePoint` | `int?` | 是 | `null` | 图标 Unicode codePoint |
| `category` | `TemplateCategory` | 否 | `inferTemplateCategory(...)` | 分类 |
| `fields` | `List<AccountField>` | 否 | `[]` | 字段列表 |
| `isCustom` | `bool` | 否 | `false` | 是否自定义模板 |
| `createdAt` | `int?` | 是 | `null` | 创建时间 |
| `modifiedAt` | `int?` | 是 | `null` | 修改时间 |
| `lastEditedBy` | `String?` | 是 | `null` | 最后编辑者 |
| `lastEditedAt` | `int?` | 是 | `null` | 最后编辑时间 |
| `syncStatus` | `SyncStatus` | 否 | `pendingPush` | 同步状态 |
| `hlc` | `Hlc?` | 是 | `null` | 模板整体 HLC |
| `serverVersion` | `int` | 否 | `0` | 服务器版本号 |
| `isDeleted` | `bool` | 否 | `false` | 软删除标记 |
| `deleteHlc` | `Hlc?` | 是 | `null` | 删除 HLC |

**JSON 输出示例**：
```json
{
  "templateId": "custom_1715770000000",
  "version": 1,
  "title": "API 服务",
  "subtitle": "存储 API Key、Token 和端点信息",
  "icon": 58715,
  "category": "custom",
  "fields": [...],
  "createdAt": null,
  "modifiedAt": null,
  "lastEditedBy": null,
  "lastEditedAt": null,
  "syncStatus": "pendingPush",
  "hlc": null,
  "serverVersion": 0,
  "isDeleted": false,
  "deleteHlc": null
}
```

**兼容性处理**：
- `subTitle`：优先读旧字段名 `subtitle`，fallback 到 `subTitle`
- `icon`：支持 `int` 或 `String`（自动 `int.tryParse`）
- `category`：**智能推断**：缺失时根据 `iconCodePoint`、`title`、`fields` 内容推断分类（含中英文关键词匹配）
- `syncStatus`：fallback 为 `synchronized`（注意与 `AccountItem` 的 `pendingPush` 不同）
- `templateId`：缺失时自动生成 `custom_${timestamp}`
- `isDeleted`：仅支持 `true`（无 `== 1` 兼容，与 `AccountItem` 不一致）

**导出格式**（`toExportJson`**）：不包含 `syncStatus`、`hlc`、`serverVersion`、`isDeleted`、`deleteHlc`、`createdAt`、`modifiedAt`、`lastEditedBy`、`lastEditedAt`，纯净模板数据。

**`copyWith`**：✅ 完整，覆盖全部 16 个字段。

**版本风险**：
- `category` 为智能推断字段，旧数据无显式分类时依赖推断逻辑
- `subTitle` 旧字段名为 `subtitle`，已做双 key 兼容

---

### 3.9 `TotpCredential`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | `DateTime.now().millisecondsSinceEpoch.toString()` | 唯一 ID |
| `label` | `String` | 否 | `''` | 自定义标签 |
| `config` | `TotpConfig` | 否 | - | TOTP 配置（含 secret、issuer、algorithm 等） |
| `linkedAccountIds` | `List<String>` | 否 | `[]` | 关联账户 ID 列表（去重+trim） |
| `createdAt` | `int` | 否 | `DateTime.now().millisecondsSinceEpoch` | 创建时间 |
| `labelHlc` | `Hlc` | 否 | `Hlc.zero('local')` | label 的 HLC |
| `configHlc` | `Hlc` | 否 | `Hlc.zero('local')` | config 的 HLC |
| `linksHlc` | `Hlc` | 否 | `Hlc.zero('local')` | links 的 HLC |
| `serverVersion` | `int` | 否 | `0` | 服务器版本号 |
| `syncStatus` | `SyncStatus` | 否 | `pendingPush` | 同步状态 |
| `isDeleted` | `bool` | 否 | `false` | 软删除标记 |
| `deleteHlc` | `Hlc?` | 是 | `null` | 删除 HLC |

**JSON 输出示例**：
```json
{
  "id": "1715770000000",
  "label": "GitHub 2FA",
  "config": {"secret": "JBSWY3DPEHPK3PXP", "issuer": "GitHub", "algorithm": "SHA1", "digits": 6, "period": 30},
  "linkedAccountIds": ["acc_001"],
  "createdAt": 1715770000000,
  "labelHlc": "0-0-local",
  "configHlc": "0-0-local",
  "linksHlc": "0-0-local",
  "serverVersion": 0,
  "syncStatus": "pendingPush",
  "isDeleted": false,
  "deleteHlc": null
}
```

**兼容性处理**：
- `config`：支持 `TotpConfig` 实例、`Map<String, dynamic>`、`Map`、`String`（OTP URI），通过 `_readConfig()` 统一处理
- `linkedAccountIds`：支持 `List<dynamic>`，通过 `_readLinkedAccountIds()` 统一转为 `List<String>` 并去重 trim
- `isDeleted`：支持 `1` 或 `true`（与 `AccountItem` 一致）
- `labelHlc`、`configHlc`、`linksHlc`：缺失 fallback `Hlc.zero('local')`

**`copyWith`**：✅ 完整，覆盖全部 12 个字段。

---

### 3.10 `LocalSyncChange`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | - | 变更 ID |
| `vaultId` | `String` | 否 | `''` | 保险库 ID |
| `entityType` | `LocalSyncEntityType` | 否 | `account` | 实体类型 |
| `entityId` | `String` | 否 | `''` | 实体 ID |
| `action` | `LocalSyncAction` | 否 | `update` | 操作类型 |
| `title` | `String` | 否 | `''` | 变更标题 |
| `beforeJson` | `String?` | 是 | `null` | 变更前 JSON 快照 |
| `afterJson` | `String?` | 是 | `null` | 变更后 JSON 快照 |
| `diff` | `Map<String, dynamic>` | 否 | `{}` | 差异数据 |
| `baseServerVersion` | `int` | 否 | `0` | 基准服务器版本 |
| `status` | `LocalSyncStatus` | 否 | `pendingReview` | 同步状态 |
| `createdAt` | `int` | 否 | `0` | 创建时间 |
| `updatedAt` | `int` | 否 | `0` | 更新时间 |
| `approvedAt` | `int?` | 是 | `null` | 批准时间 |
| `pushedAt` | `int?` | 是 | `null` | 推送时间 |
| `errorMessage` | `String?` | 是 | `null` | 错误信息 |

**数据库 Row 输出示例**：
```json
{
  "id": "uuid",
  "vault_id": "vault_001",
  "entity_type": "account",
  "entity_id": "acc_001",
  "action": "update",
  "title": "修改密码",
  "before_json": "{\"name\":\"old\"}",
  "after_json": "{\"name\":\"new\"}",
  "diff_json": "{\"changed_fields\":[\"name\"]}",
  "base_server_version": 5,
  "status": "pendingReview",
  "created_at": 1715770000000,
  "updated_at": 1715770000000,
  "approved_at": null,
  "pushed_at": null,
  "error_message": null
}
```

**兼容性处理**：
- 三个枚举均有 `fromString` 方法，未知值 fallback 到默认值并打印 `AppLogger.w` 警告
- `diff_json` 为空时存储为 `null`
- `is_read` / `is_deleted` 等 SQLite bool 风格不在此模型中，纯 Dart bool

**`copyWith`**：⚠️ **部分**，仅支持 `status`、`approvedAt`、`pushedAt`、`errorMessage`（生命周期字段）。不可变身份字段（`id`、`entityType`、`action`、`diff` 等）不提供修改。

---

### 3.11 `TemplateConflictLog`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | `Uuid().v4()` | 日志 ID（自动生成） |
| `templateId` | `String` | 否 | - | 模板 ID |
| `fieldKey` | `String` | 否 | - | 字段键 |
| `attributeName` | `String` | 否 | - | 冲突属性名 |
| `localValue` | `String` | 否 | - | 本地值 |
| `remoteValue` | `String` | 否 | - | 远程值 |
| `localHlc` | `Hlc` | 否 | - | 本地版本 HLC |
| `remoteHlc` | `Hlc` | 否 | - | 远程版本 HLC |
| `savedAt` | `int` | 否 | `DateTime.now().millisecondsSinceEpoch` | 保存时间 |

**JSON 输出示例**：
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "templateId": "tpl_001",
  "fieldKey": "label",
  "attributeName": "label",
  "localValue": "网站",
  "remoteValue": "Website",
  "localHlc": "1715770000000-0-deviceA",
  "remoteHlc": "1715770000001-0-deviceB",
  "savedAt": 1715770000000
}
```

**兼容性处理**：
- `fromJson` 为**严格模式**，无任何 fallback。缺失字段将抛出 `TypeError`。
- `id` 构造时自动生成，但 `fromJson` 要求必须存在。

**⚠️ 风险**：无 `copyWith` 方法；`fromJson` 零容错。

---

### 3.12 `AppNotification`

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | - | 通知 ID |
| `type` | `AppNotificationType` | 否 | - | 类型 |
| `title` | `String` | 否 | `''` | 标题 |
| `body` | `String` | 否 | `''` | 正文 |
| `accountId` | `String?` | 是 | `null` | 关联账户 ID |
| `createdAt` | `int` | 否 | `0` | 创建时间 |
| `isRead` | `bool` | 否 | `false` | 是否已读 |
| `params` | `Map<String, dynamic>` | 否 | `{}` | 扩展参数 |

**数据库 Row 输出示例**：
```json
{
  "id": "notif_001",
  "type": "weakPassword",
  "title": "",
  "body": "",
  "account_id": "acc_001",
  "created_at": 1715770000000,
  "is_read": 0,
  "params": "{\"accountName\":\"GitHub\",\"score\":45}"
}
```

**兼容性处理**：
- `type`：未知值 fallback 到 `passwordExpiry`
- `isRead`：从 row 读取时 `== 1`（兼容 SQLite int bool）
- `params`：JSON 解析失败静默 swallow，回退 `{}`

**`copyWith`**：⚠️ **部分**，仅支持 `isRead`。

---

### 3.13 `VaultHealthReport`（聚合类，无序列化）

| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `score` | `int` | 否 | - | 健康评分（0-100） |
| `grade` | `VaultHealthGrade` | 否 | - | 评级（excellent/good/warning/critical） |
| `items` | `List<VaultHealthItem>` | 否 | - | 检查项列表 |
| `calculatedAt` | `DateTime` | 否 | - | 计算时间 |

**子类 `VaultHealthItem`**：
| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `id` | `String` | 否 | - | 检查项 ID |
| `title` | `String` | 否 | - | 标题 |
| `riskLevel` | `VaultHealthRiskLevel` | 否 | - | 风险等级 |
| `isPass` | `bool` | 否 | - | 是否通过 |
| `description` | `String` | 否 | - | 描述 |
| `action` | `VaultHealthAction?` | 是 | `null` | 建议操作 |

**子类 `VaultHealthAction`**：
| 字段 | 类型 | 可空 | 默认值 | 含义 |
|------|------|------|--------|------|
| `type` | `VaultHealthActionType` | 否 | - | 操作类型 |
| `targetId` | `String?` | 是 | `null` | 单个目标 ID |
| `targetIds` | `List<String>` | 否 | `[]` | 多个目标 ID |

**⚠️ 风险**：
- 该类**无任何序列化方法**（无 `toJson` / `fromJson` / `toRow` / `fromRow`）。
- 无 `copyWith` 方法。
- 为纯内存聚合对象，生命周期仅限单次健康检查计算。

---

## 四、JSON 兼容性矩阵

| 模型 | 旧字段名兼容 | 缺失字段 fallback | 类型容错（int/String/bool） | 零容错字段 |
|------|-------------|------------------|---------------------------|----------|
| `Hlc` | - | 解析失败 → `zero('__corrupted__')` | `String` only | - |
| `SyncValue<T>` | - | - | - | `v`, `hlc` |
| `SyncStatus` | - | `pendingPush` | `int` / `String` / `SyncStatus` | - |
| `AccountFieldMeta` | - | `type='text'`, `label=''` | - | - |
| `AccountItem` | `template`→`templateId` | 大量 fallback（见 3.5） | `isDeleted`: `1`或`true` | - |
| `AccountFieldAttributes` | - | 多个 bool: `false`/`true` 语义 | - | - |
| `AccountField` | - | 4 个 HLC → `zero('local')` | - | - |
| `AccountTemplate` | `subtitle`→`subTitle` | 智能推断 `category` | `icon`: `int`/`String` | - |
| `TotpCredential` | - | 3 个 HLC → `zero('local')` | `isDeleted`: `1`或`true` | - |
| `LocalSyncChange` | - | 3 个枚举有 fallback | - | `id` |
| `TemplateConflictLog` | - | **无 fallback** | - | **全部字段** |
| `AppNotification` | - | `type`→`passwordExpiry` | `isRead`: `==1` | `id` |
| `VaultHealthReport` | N/A | N/A | N/A | N/A |

---

## 五、copyWith 完整性检查

| 模型 | copyWith | 覆盖字段数 | 总字段数 | 完整性 | 备注 |
|------|---------|-----------|---------|--------|------|
| `AccountItem` | ✅ | 19 | 19 | 100% | - |
| `AccountFieldMeta` | ❌ | 0 | 4 | 0% | 建议补充 |
| `AccountFieldAttributes` | ❌ | 0 | 13 | 0% | 建议补充 |
| `AccountField` | ✅ | 9 | 9 | 100% | - |
| `AccountTemplate` | ✅ | 16 | 16 | 100% | - |
| `TotpCredential` | ✅ | 12 | 12 | 100% | - |
| `LocalSyncChange` | ⚠️ | 4 | 16 | 25% | 仅生命周期字段可变更 |
| `TemplateConflictLog` | ❌ | 0 | 9 | 0% | 建议补充 |
| `AppNotification` | ⚠️ | 1 | 8 | 12.5% | 仅 `isRead` 可变更 |
| `VaultHealthReport` | ❌ | 0 | 4 | 0% | 纯聚合对象 |
| `VaultHealthItem` | ❌ | 0 | 6 | 0% | 纯聚合对象 |
| `VaultHealthAction` | ❌ | 0 | 3 | 0% | 纯聚合对象 |

---

## 六、TODO / FIXME / HACK 清单

**`lib/models/` 目录内**：**零条**  
> 经全文扫描，8 个模型文件中未出现 `TODO`、`FIXME`、`HACK`、`XXX` 注释。

---

## 七、版本兼容性风险清单

| 风险等级 | 位置 | 说明 |
|---------|------|------|
| 🔴 **高** | `AccountItem.templateId` | `toJson` 同时输出 `template` 和 `templateId`，但 `fromJson` 优先读旧字段 `template`。未来应逐步淘汰双字段输出。 |
| 🔴 **高** | `AccountTemplate.fromJson` | `category` 依赖智能推断（含中英文关键词 + iconCodePoint + fields 内容）。若推断逻辑变更，旧数据反序列化后分类可能不一致。 |
| 🟡 **中** | `AccountItem.isPinned` / `pinHlc` | 较新增字段，旧数据缺失时默认 `false`/`null`。需确认 UI/数据库层是否正确处理 `null`。 |
| 🟡 **中** | `TemplateConflictLog.fromJson` | **零容错**：任何字段缺失或类型错误均抛出异常。与项目中其他模型的宽容策略不一致。 |
| 🟡 **中** | `TotpCredential.config` | 反序列化时 `_readConfig` 支持 `TotpConfig`/`Map`/`String` 三种输入，但 `String` 走 `TotpService.parseConfig`，若 URI 格式非法会抛 `TotpException`。 |
| 🟡 **中** | `LocalSyncChange` 枚举 fallback | 未知枚举值均 fallback 到默认值，但会打印 `AppLogger.w`。大量非法数据可能导致日志噪音。 |
| 🟢 **低** | `AccountTemplate.subTitle` | `fromJson` 兼容旧 `subtitle` 字段名，风险可控。 |
| 🟢 **低** | `VaultHealthReport` | 无序列化，纯内存对象，无持久化兼容性风险。 |

---

## 八、关键发现与建议

1. **copyWith 缺口**：`AccountFieldMeta`、`AccountFieldAttributes`、`TemplateConflictLog` 三个高频使用的模型缺少 `copyWith`，在 UI 状态更新或 CRDT 合并时容易因手动构造对象导致 HLC 丢失。
2. **布尔值存储不一致**：`AccountItem` 和 `TotpCredential` 的 `isDeleted` 支持 `1` 或 `true`，但 `AccountTemplate` 的 `isDeleted` 仅支持 `true`。若三者在同一 SQLite 表中存储，可能存在兼容性问题。
3. **`TemplateConflictLog` 反序列化过于严格**：与其他模型的宽容策略不一致，建议为各字段补充 fallback（如 `id` 缺失时生成 UUID）。
4. **无 TODO/FIXME**：代码整洁度良好，但可能意味着部分已知问题未标记（如上述 `fromJson` 严格性差异）。
5. **`VaultHealthReport` 无序列化**：当前为纯内存对象，若未来需要持久化健康检查历史，需补充 `toJson` / `fromJson`。
