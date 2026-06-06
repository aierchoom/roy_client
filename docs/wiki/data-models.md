# 数据模型

**版本**: v1.3.0
**最后更新**: 2026-05-07

---

## 目录

1. [模型概览](#1-模型概览)
2. [核心模型](#2-核心模型)
3. [同步模型](#3-同步模型)
4. [模板模型](#4-模板模型)
5. [枚举定义](#5-枚举定义)
6. [JSON 序列化](#6-json-序列化)

---

## 1. 模型概览

### 1.1 模型关系图

```
┌─────────────────┐       ┌─────────────────┐
│   AccountItem   │       │ AccountTemplate │
├─────────────────┤       ├─────────────────┤
│ - id            │◄──────│ - templateId    │
│ - name          │       │ - title         │
│ - email         │       │ - fields[]      │
│ - templateId    │       │ - category      │
│ - data{}        │       └─────────────────┘
│ - nameHlc       │                │
│ - dataHlc{}     │                ▼
│ - syncStatus    │       ┌─────────────────┐
│ - isDeleted     │       │  AccountField   │
└─────────────────┘       ├─────────────────┤
         │                │ - fieldKey      │
         │                │ - label         │
         ▼                │ - attributes    │
┌─────────────────┐       │ - description   │
│ TotpCredential  │       │ - order         │
├─────────────────┤       │ - labelHlc      │
│ - id            │       │ - attributesHlc │
│ - label         │       └─────────────────┘
│ - config        │                │
│ - linkedAccIds  │                ▼
│ - syncStatus    │       ┌─────────────────┐
└─────────────────┘       │FieldAttributes  │
                          ├─────────────────┤
                          │ - type          │
                          │ - isRequired    │
                          │ - isSecret      │
                          │ - isReference   │
                          │ - ...           │
                          └─────────────────┘
```

---

## 2. 核心模型

### 2.1 AccountItem

账户条目，包含账户的所有数据和同步元数据。

```dart
class AccountItem {
  /// 账户唯一标识
  final String id;

  /// 账户名称
  final String name;

  /// 关联邮箱/备注
  final String email;

  /// 使用的模板 ID
  final String templateId;

  /// 自定义字段数据
  final Map<String, String> data;

  /// 创建时间戳
  final int createdAt;

  // === 同步字段 ===

  /// 名称字段的 HLC 时间戳
  final Hlc nameHlc;

  /// 邮箱字段的 HLC 时间戳
  final Hlc emailHlc;

  /// 各数据字段的 HLC 时间戳
  final Map<String, Hlc> dataHlc;

  /// 服务器版本号
  final int serverVersion;

  /// 同步状态
  final SyncStatus syncStatus;

  /// 是否已删除（墓碑标记）
  final bool isDeleted;

  /// 删除操作的 HLC 时间戳
  final Hlc? deleteHlc;
}
```

**字段说明**:

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 全局唯一标识，通常为时间戳 |
| `name` | String | 账户显示名称 |
| `email` | String | 关联邮箱或备注信息 |
| `templateId` | String | 关联的模板 ID |
| `data` | Map | 模板定义的自定义字段值 |
| `nameHlc` | Hlc | 名称字段的修改时间戳 |
| `dataHlc` | Map | 各数据字段的修改时间戳 |
| `syncStatus` | SyncStatus | 同步状态标记 |
| `isDeleted` | bool | 软删除标记 |

---

### 2.3 TotpCredential

TOTP 凭据，支持 RFC 6238 标准（SHA1/SHA256/SHA512）。

```dart
class TotpCredential {
  /// 唯一标识
  final String id;

  /// 显示标签
  final String label;

  /// TOTP 配置（secret、algorithm、digits、period、issuer、account）
  final TotpConfig config;

  /// 关联的 AccountItem ID 列表
  final List<String> linkedAccountIds;

  /// 创建时间戳
  final int createdAt;

  /// 标签字段的 HLC 时间戳
  final Hlc labelHlc;

  /// 配置字段的 HLC 时间戳
  final Hlc configHlc;

  /// 关联列表的 HLC 时间戳
  final Hlc linksHlc;

  /// 服务器版本号
  final int serverVersion;

  /// 同步状态
  final SyncStatus syncStatus;

  /// 是否已删除（墓碑标记）
  final bool isDeleted;

  /// 删除操作的 HLC 时间戳
  final Hlc? deleteHlc;
}
```

### 2.4 AppNotification

应用内通知，由保险库健康检查等模块生成。

```dart
class AppNotification {
  /// 唯一标识
  final String id;

  /// 通知类型（passwordExpiry / weakPassword）
  final AppNotificationType type;

  /// 标题
  final String title;

  /// 正文
  final String body;

  /// 关联账户 ID（可选）
  final String? accountId;

  /// 创建时间戳
  final int createdAt;

  /// 是否已读
  final bool isRead;

  /// 附加参数（如账户名、分数、天数等）
  final Map<String, dynamic> params;
}
```

### 2.5 LocalSyncChange

本地同步变更箱条目，记录待推送或已推送的变更。

```dart
class LocalSyncChange {
  /// 唯一标识
  final String id;

  /// 所属 vaultId
  final String vaultId;

  /// 实体类型（account / template / totpCredential）
  final LocalSyncEntityType entityType;

  /// 实体 ID
  final String entityId;

  /// 操作类型（create / update / delete）
  final LocalSyncAction action;

  /// 变更标题（用于展示）
  final String title;

  /// 变更前快照 JSON（可选）
  final String? beforeJson;

  /// 变更后快照 JSON（可选）
  final String? afterJson;

  /// 差异信息
  final Map<String, dynamic> diff;

  /// 基准服务器版本
  final int baseServerVersion;

  /// 状态（pendingReview / approved / pushing / pushed / failed / conflict / reverted）
  final LocalSyncStatus status;

  /// 创建时间戳
  final int createdAt;

  /// 更新时间戳
  final int updatedAt;

  /// 审批时间戳（可选）
  final int? approvedAt;

  /// 推送时间戳（可选）
  final int? pushedAt;

  /// 错误信息（可选）
  final String? errorMessage;
}
```

### 2.6 TemplateConflictLog

模板字段级冲突记录，由 CRDT 合并产生。

```dart
class TemplateConflictLog {
  /// 唯一标识
  final String id;

  /// 关联模板 ID
  final String templateId;

  /// 关联字段 key
  final String fieldKey;

  /// 冲突属性名（如 label、type、order、isRequired 等）
  final String attributeName;

  /// 本地值
  final String localValue;

  /// 远程值
  final String remoteValue;

  /// 本地 HLC 时间戳
  final Hlc localHlc;

  /// 远程 HLC 时间戳
  final Hlc remoteHlc;

  /// 保存时间戳
  final int savedAt;
}
```

## 3. 同步模型

### 3.1 Hlc (Hybrid Logical Clock)

混合逻辑时钟，用于分布式系统中的事件排序。

```dart
class Hlc implements Comparable<Hlc> {
  /// 物理时间戳（毫秒）
  final int time;

  /// 逻辑计数器
  final int counter;

  /// 节点/设备标识
  final String nodeId;

  /// 字符串格式: "{time}-{counter}-{nodeId}"
  /// 示例: "1742736000000-5-device_abc123"
}
```

**比较规则**:
1. 先比较 `time`（物理时间）
2. 再比较 `counter`（逻辑计数器）
3. 最后比较 `nodeId`（字典序）

**使用场景**:
- 每个字段修改时生成新的 HLC
- 合并时通过 HLC 决定胜者
- 解决分布式冲突

### 3.2 SyncClock

同步时钟管理器，负责 HLC 的生成和更新。

```dart
class SyncClock {
  /// 当前时钟
  Hlc get current;

  /// 本地写入时调用，获取新的时间戳
  Hlc send();

  /// 接收远程时间戳时调用，校准本地时钟
  void receive(Hlc remote);
}
```

**工作流程**:
```
本地写入:
1. 调用 send()
2. 返回新的 Hlc
3. 用新 Hlc 标记修改的字段

远程同步:
1. 接收远程 Hlc
2. 调用 receive(remoteHlc)
3. 本地时钟向前调整
```

### 3.3 SyncValue

带时间戳的值包装器。

```dart
class SyncValue<T> {
  /// 实际值
  final T value;

  /// 时间戳
  final Hlc hlc;
}
```

### 3.4 SyncStatus

同步状态枚举。

```dart
enum SyncStatus {
  /// 已同步
  synchronized,

  /// 待推送
  pendingPush,

  /// 冲突状态
  conflict,
}
```

---

## 4. 模板模型

### 4.1 AccountTemplate

账户模板定义。

```dart
class AccountTemplate {
  /// 模板唯一标识
  final String templateId;

  /// 模板名称
  final String title;

  /// 副标题/描述
  final String subTitle;

  /// 图标（可选）
  final int? iconCodePoint;

  /// 模板分类
  final TemplateCategory category;

  /// 字段定义列表
  final List<AccountField> fields;

  /// 是否自定义模板
  final bool isCustom;

  /// 同步状态
  final SyncStatus syncStatus;

  /// 模板级 HLC 时间戳
  final Hlc? hlc;

  /// 服务器版本号
  final int serverVersion;

  /// 是否已删除
  final bool isDeleted;

  /// 删除操作的 HLC
  final Hlc? deleteHlc;
}
```

### 4.2 AccountField

模板字段定义。每个字段的独立属性（标签、描述、属性、排序）都有自己的 HLC 时间戳，支持字段级 CRDT 合并。

```dart
class AccountField {
  /// 字段唯一标识（用于数据存储）
  final String fieldKey;

  /// 字段显示名称
  final String label;

  /// 字段描述（可选）
  final String? description;

  /// 字段属性
  final AccountFieldAttributes attributes;

  /// 字段排序
  final int order;

  /// 标签的 HLC 时间戳
  final Hlc labelHlc;

  /// 描述的 HLC 时间戳
  final Hlc descriptionHlc;

  /// 属性的 HLC 时间戳
  final Hlc attributesHlc;

  /// 排序的 HLC 时间戳
  final Hlc orderHlc;
}
```

### 4.3 AccountFieldAttributes

字段属性配置。

```dart
class AccountFieldAttributes {
  /// 字段类型
  final AccountFieldType type;

  /// 是否为主字段
  final bool isPrimary;

  /// 是否必填
  final bool isRequired;

  /// 是否保密（隐藏显示）
  final bool isSecret;

  /// 是否可编辑
  final bool isEditable;

  /// 是否可搜索
  final bool isSearchable;

  /// 是否可复制
  final bool isCopyable;

  /// 是否为引用字段（如 2FA 关联，不存储实际值）
  final bool isReference;

  /// 最大长度
  final int? maxLength;

  /// 最小长度
  final int? minLength;

  /// 验证正则表达式
  final String? regex;

  /// 输入提示
  final String? hint;

  /// 时间格式（仅 type=time 时有效）
  final TimeFieldFormat timeFormat;
}
```

---

## 5. 枚举定义

### 5.1 AccountFieldType

字段类型枚举。

```dart
enum AccountFieldType {
  /// 普通文本
  text,

  /// 密码（加密显示）
  password,

  /// 数字
  number,

  /// 邮箱
  email,

  /// 电话
  phone,

  /// 网址
  url,

  /// 时间/日期
  time,

  /// 自定义（如 2FA 关联控件）
  custom,

  /// 账户关联（引用其他 AccountItem）
  accountLink,

  /// 多行大文本（安全笔记内容、助记词等）
  longText,

  /// 多值列表（换行分隔，UI 为逐行编辑）
  list,

  /// 未知/不兼容类型（降级兼容）
  unknown,
}
```

**类型与 UI 映射**:

| 类型 | UI 控件 | 特殊行为 |
|------|---------|----------|
| `text` | 单行文本框 | 标准输入 |
| `password` | 密码框 + 显隐切换 | `isSecret` 时默认隐藏 |
| `number` | 数字键盘 | 限制数字输入 |
| `email` | 邮箱键盘 | 基础格式校验 |
| `phone` | 电话键盘 | - |
| `url` | URL 键盘 | 可点击跳转 |
| `time` | 日期/时间选择器 | 受 `timeFormat` 控制 |
| `custom` | 自定义控件 | 如 2FA 关联选择器 |
| `accountLink` | 账户选择对话框 | 引用其他 AccountItem ID |
| `longText` | 多行文本框（等宽字体） | `isSecret` 时可折叠隐藏 |
| `list` | 逐行列表编辑器 | 助记词模式支持粘贴自动分词 |
| `unknown` | 纯文本回显 | 降级显示，不可编辑 |

### 5.2 TimeFieldFormat

时间字段格式。

```dart
enum TimeFieldFormat {
  /// 完整格式: YYYY-MM-DD HH:mm
  full,

  /// 仅日期: YYYY-MM-DD
  date,

  /// 月/年: MM/YY
  monthYear,

  /// 仅时间: HH:mm
  time,
}
```

### 5.3 TemplateCategory

模板分类。

```dart
enum TemplateCategory {
  /// 访问凭据：网站、App、API、WiFi、服务器等
  access,

  /// 密文材料：安全笔记、助记词、恢复码、私钥片段等
  secret,

  /// 支付信息
  payment,

  /// 身份与证件信息
  identity,

  /// 授权与许可证信息
  license,

  /// 自定义
  custom,
}
```

---

## 6. JSON 序列化

### 6.1 序列化方法

所有模型都实现了 `toJson()` 和 `fromJson()` 方法：

```dart
// 序列化
final json = account.toJson();
final jsonString = jsonEncode(json);

// 反序列化
final json = jsonDecode(jsonString);
final account = AccountItem.fromJson(json);
```

### 6.2 存储格式示例

**AccountItem JSON**:
```json
{
  "id": "1714205400000",
  "name": "淘宝账户",
  "email": "user@example.com",
  "templateId": "builtin_generic_info",
  "data": {
    "username": "myuser",
    "password": "encrypted_value"
  },
  "createdAt": 1714205400000,
  "nameHlc": "1714205400123-0-device_abc",
  "emailHlc": "1714205400123-0-device_abc",
  "dataHlc": {
    "username": "1714205400123-0-device_abc",
    "password": "1714205400123-0-device_abc"
  },
  "serverVersion": 5,
  "syncStatus": 0,
  "isDeleted": 0,
  "deleteHlc": null
}
```

**AccountTemplate JSON**:
```json
{
  "templateId": "custom_bank",
  "title": "银行卡",
  "subtitle": "银行卡信息模板",
  "category": "payment",
  "isCustom": true,
  "fields": [
    {
      "fieldKey": "card_number",
      "label": "卡号",
      "description": "银行卡号",
      "attributes": {
        "type": "number",
        "isRequired": true,
        "isSecret": false,
        "isEditable": true,
        "isSearchable": true,
        "isCopyable": true
      },
      "order": 0,
      "labelHlc": "0-0-builtin",
      "attributesHlc": "0-0-builtin"
    }
  ],
  "syncStatus": "synchronized",
  "hlc": "1714205400123-0-device_abc",
  "serverVersion": 1,
  "isDeleted": false
}
```

### 6.3 版本兼容性

| 版本 | 变更 |
|------|------|
| v1.0.0 | 初始模型定义 |
| v1.1.0 | 添加 `dataHlc` 字段级时间戳 |
| v1.2.0 | 添加 `totp` 字段类型（后以 `custom` + `isReference` 替代） |
| v1.3.0 | 添加 `longText`、`list`、`accountLink`、`unknown` 字段类型；添加 `note` 模板分类；字段定义引入独立 HLC（`labelHlc`、`descriptionHlc`、`attributesHlc`、`orderHlc`）；`AccountFieldAttributes` 新增 `isReference` |

**向后兼容**:
- 新字段使用默认值
- 缺失的 Hlc 字段使用 `Hlc.zero('local')`
- 未知字段类型降级为 `unknown`

---

## 附录

### A. 模型文件位置

| 模型 | 文件路径 |
|------|----------|
| AccountItem | `lib/models/account_item.dart` |
| AccountTemplate | `lib/models/account_template.dart` |
| TotpCredential | `lib/models/totp_credential.dart` |
| AppNotification | `lib/models/app_notification.dart` |
| LocalSyncChange | `lib/models/local_sync_change.dart` |
| TemplateConflictLog | `lib/models/template_conflict_log.dart` |
| VaultHealthReport | `lib/models/vault_health_report.dart` |
| Hlc / SyncClock / SyncValue | `lib/models/hlc.dart` |

### B. 数据验证规则

```dart
// 账户名称验证
if (name.trim().isEmpty) {
  throw ValidationError('账户名称不能为空');
}

// 字段值验证
if (field.attributes.isRequired && value.isEmpty) {
  throw ValidationError('${field.label} 是必填字段');
}

// 邮箱格式验证
if (field.attributes.type == AccountFieldType.email) {
  final emailRegex = RegExp(r'^[\w-\.]+@[\w-]+\.[a-z]{2,}$');
  if (!emailRegex.hasMatch(value)) {
    throw ValidationError('邮箱格式不正确');
  }
}
```

---

**文档版本**: 1.3
**最后更新**: 2026-05-07
