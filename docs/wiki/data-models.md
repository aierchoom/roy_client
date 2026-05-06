# 数据模型

**版本**: v1.2.0
**最后更新**: 2026-05-01

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
│     Vault       │       │ AccountTemplate │
├─────────────────┤       ├─────────────────┤
│ - vaultId       │       │ - templateId    │
│ - accounts[]    │──────→│ - title         │
│ - templates[]   │──────→│ - fields[]      │
│ - version       │       │ - category      │
└─────────────────┘       └─────────────────┘
         │                         │
         │                         │
         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐
│   AccountItem   │       │  AccountField   │
├─────────────────┤       ├─────────────────┤
│ - id            │       │ - fieldKey      │
│ - name          │       │ - label         │
│ - email         │       │ - attributes    │
│ - templateId    │       │ - description   │
│ - data{}        │       └─────────────────┘
│ - nameHlc       │               │
│ - dataHlc{}     │               ▼
└─────────────────┘       ┌─────────────────┐
                          │ FieldAttributes │
                          ├─────────────────┤
                          │ - type          │
                          │ - isRequired    │
                          │ - isSecret      │
                          │ - ...           │
                          └─────────────────┘
```

---

## 2. 核心模型

### 2.1 Vault

Vault 是顶层容器，包含所有账户和模板数据。

```dart
class Vault {
  /// Vault 唯一标识
  final String vaultId;

  /// 所有账户列表
  final List<AccountItem> accounts;

  /// 所有模板列表
  final List<AccountTemplate> templates;

  /// 同步版本号
  final int version;

  /// 最后同步时间
  final DateTime? lastSyncAt;

  /// Vault 加密密钥（内存中）
  final String? encryptionKey;
}
```

**JSON 示例**:
```json
{
  "vaultId": "vault_abc123",
  "accounts": [...],
  "templates": [...],
  "version": 42,
  "lastSyncAt": "2026-04-27T10:30:00Z"
}
```

### 2.2 AccountItem

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
  final String? icon;

  /// 模板分类
  final TemplateCategory category;

  /// 字段定义列表
  final List<AccountField> fields;

  /// 是否自定义模板
  final bool isCustom;
}
```

### 4.2 AccountField

模板字段定义。

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

  /// 2FA 关联控件（仅表示关联关系，不保存 TOTP secret）
  totp,

  /// 自定义
  custom,
}
```

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
  /// 登录凭据
  login,

  /// 支付信息
  payment,

  /// 联系人
  contact,

  /// 身份信息
  identity,

  /// 工作相关
  work,

  /// 购物
  shopping,

  /// 金融
  finance,

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
  "templateId": "builtin_generic",
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
  "subTitle": "银行卡信息模板",
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
      }
    },
    {
      "fieldKey": "cvv",
      "label": "CVV",
      "attributes": {
        "type": "password",
        "isRequired": false,
        "isSecret": true
      }
    }
  ]
}
```

### 6.3 版本兼容性

| 版本 | 变更 |
|------|------|
| v1.0.0 | 初始模型定义 |
| v1.1.0 | 添加 `dataHlc` 字段级时间戳 |
| v1.2.0 | 添加 `totp` 字段类型 |

**向后兼容**:
- 新字段使用默认值
- 缺失的 Hlc 字段使用 `Hlc.zero('local')`

---

## 附录

### A. 模型文件位置

| 模型 | 文件路径 |
|------|----------|
| Vault | `lib/models/vault.dart` |
| AccountItem | `lib/models/account_item.dart` |
| AccountTemplate | `lib/models/account_template.dart` |
| Hlc | `lib/models/hlc.dart` |

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

**文档版本**: 1.2
**最后更新**: 2026-05-01
