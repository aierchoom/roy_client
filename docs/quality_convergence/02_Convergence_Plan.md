# SecretRoy 代码质量收敛计划 v1

> Current delta (2026-04-28): this plan is a historical baseline from the quality pass. Current key-sync hardening has moved forward: secure link codes use `sroy-secure-v2:` with PBKDF2-HMAC-SHA256 plus AES-GCM-256, and LAN pairing uses 8 readable characters through `LanPairingCodeDialog`. See `../07_Key_Sync_Implementation.md`.

**创建日期**: 2026-04-27
**项目**: SecretRoy - 分布式密码管理器
**架构**: CRDT 同步 + 端到端加密

---

## 一、质量收敛目标

### 1.1 核心目标

1. **可维护性提升**: 降低单文件代码复杂度，提高组件复用率
2. **测试稳定性**: 消除测试警告，确保测试套件可靠运行
3. **可观测性增强**: 补充关键路径的日志输出
4. **技术债务管理**: 评估并规划加密方案迁移路径

### 1.2 约束条件

- 不改变现有业务逻辑
- 保持 100% 测试通过率
- 遵循 Flutter/Dart 最佳实践
- 考虑分布式系统的特殊需求（CRDT、HLC）

---

## 二、Phase 1: 基础质量修复

### 2.1 测试警告修复

**问题定位**:
```
Failed to load dirty templates: Null check operator used on a null value
```

**分析路径**:
1. 检查 `SecureStorageService.loadDirtyTemplates()` 实现
2. 定位测试中的 mock 类继承关系
3. 确认缺失的方法覆盖

**执行步骤**:
```
1. [排查] 定位 null check 失败位置 → verify: 日志追踪
2. [修复] 在 mock 类中添加 loadDirtyTemplates() 覆盖 → verify: 测试通过无警告
3. [验证] 运行完整测试套件 → verify: 37 tests passed
```

**成功标准**: 测试运行无警告输出

### 2.2 空 catch 块日志补充

**目标文件**: `lib/services/lan_pairing_service.dart`

**问题**: 5 处空 catch 块吞噬异常，影响调试

**执行步骤**:
```
1. [定位] 扫描所有空 catch 块位置
2. [补充] 添加 debugPrint 日志输出异常信息
3. [验证] 确保日志格式统一，包含上下文标签
```

**日志格式规范**:
```dart
debugPrint('[LanPairing] <Context>: $e');
```

**成功标准**: 所有 catch 块包含可追踪的日志输出

### 2.3 加密方案评估

**当前方案**:
- 自定义 XOR 流密码加密
- HMAC-SHA256 完整性校验

**评估维度**:
| 维度 | 评估项 |
|------|--------|
| 安全性 | 密钥管理、完整性保护、前向安全 |
| 合规性 | 行业标准对比、审计风险 |
| 性能 | 加解密延迟、内存占用 |
| 兼容性 | 跨平台支持、迁移成本 |

**评估步骤**:
```
1. [审计] 分析当前加密实现代码
2. [对比] 对照 AES-GCM 等标准方案
3. [评估] 分析迁移可行性与风险
4. [输出] 生成迁移建议文档
```

**成功标准**: 输出可执行的迁移路线图

---

## 三、Phase 2: 架构瘦身

### 3.1 拆分策略

**目标文件识别** (行数 > 1500):
| 文件 | 行数 | 优先级 |
|------|------|--------|
| account_edit_view.dart | 2020 | P1 |
| sync_settings_view.dart | 1914 | P1 |
| template_edit_view.dart | 1497 | P2 |

**拆分原则**:
1. **Widget 提取**: 独立 UI 组件移至 `lib/widgets/`
2. **工具类提取**: 通用逻辑移至同目录 `_utils.dart`
3. **命名规范**: 私有类转公共类时移除 `_` 前缀

### 3.2 account_edit_view.dart 拆分计划

**分析**:
- 时间字段处理逻辑可复用
- 样式辅助方法可抽取
- `_buildToneChip` 方法重复调用

**拆分方案**:
```
lib/views/accounts/
├── account_edit_view.dart      # 主视图 (精简后)
└── account_edit_utils.dart     # 工具类 (新建)

lib/widgets/
└── account_edit_widgets.dart   # 组件 (新建)
```

**提取内容**:
- `AccountTimeFieldUtils`: 时间解析与格式化
- `MonthYearInputFormatter`: MM/YY 输入格式化
- `AccountEditStyle`: 样式计算
- `ToneChip`: 彩色标签组件

**目标行数**: < 2000 行

### 3.3 sync_settings_view.dart 拆分计划

**分析**:
- 4 个对话框组件可独立
- 对话框之间无强耦合
- 适合提取为独立 Widget

**拆分方案**:
```
lib/views/
├── sync_settings_view.dart     # 主视图 (精简后)

lib/widgets/
└── sync_settings_dialogs.dart  # 对话框组件 (新建)
```

**提取组件**:
- `SyncInfoChip`: 同步信息标签
- `LanPairingCodeDialog`: 8位码输入
- `VaultLinkCodeDialog`: Vault链接码
- `SyncServerDialog`: 服务器配置

**目标行数**: < 1700 行

### 3.4 template_edit_view.dart 拆分计划

**分析**:
- 字段编辑对话框可独立
- 指标展示组件可复用
- 结果数据类适合独立文件

**拆分方案**:
```
lib/views/templates/
├── template_edit_view.dart     # 主视图 (精简后)

lib/widgets/
└── template_edit_widgets.dart  # 编辑组件 (新建)
```

**提取内容**:
- `EditorMetric`: 指标展示
- `FieldEditorResult`: 编辑结果数据类
- `FieldEditorDialog`: 字段编辑对话框

**目标行数**: < 1200 行

---

## 四、执行时间表

| 阶段 | 任务 | 预计时间 | 状态 |
|------|------|----------|------|
| Phase 1.1 | 测试警告修复 | 30min | 已完成 |
| Phase 1.2 | 空 catch 块日志 | 20min | 已完成 |
| Phase 1.3 | 加密方案评估 | 40min | 已完成 |
| Phase 2.1 | account_edit_view 拆分 | 45min | 已完成 |
| Phase 2.2 | sync_settings_view 拆分 | 45min | 已完成 |
| Phase 2.3 | template_edit_view 拆分 | 40min | 已完成 |
| **总计** | - | **~4h** | **已完成** |

---

## 五、质量验收标准

### 5.1 测试验收

```bash
flutter test --reporter compact
# 预期: 00:XX +37: All tests passed!
```

### 5.2 静态分析

```bash
flutter analyze
# 预期: No issues found.
```

### 5.3 行数验收

| 文件 | 目标行数 | 验收标准 |
|------|----------|----------|
| account_edit_view.dart | < 2000 | 1953 ✓ |
| sync_settings_view.dart | < 1700 | 1617 ✓ |
| template_edit_view.dart | < 1200 | 1176 ✓ |

---

## 六、风险评估

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 拆分破坏现有功能 | 中 | 每步运行测试验证 |
| 私有类重命名导致冲突 | 低 | 使用唯一命名前缀 |
| 新建文件导入遗漏 | 低 | IDE 实时检查 |
| 加密方案评估不全面 | 中 | 多维度分析 + 文档记录 |

---

## 七、后续规划

### 7.1 Phase 3: 测试增强 (建议)

**目标**: 测试用例从 37 提升至 50+

**方向**:
- 新建 Widget 组件的单元测试
- 加密/解密边界条件测试
- 同步冲突场景扩展测试

### 7.2 Phase 4: 文档完善 (建议)

**目标**: 提升代码可读性和新人友好度

**方向**:
- 核心组件 API 文档
- 分布式同步架构图更新
- 贡献者指南

---

## 八、附录

### A. 项目结构概览

```
lib/
├── models/           # 数据模型
├── services/         # 业务服务
│   ├── lan_pairing_service.dart
│   └── ...
├── views/            # 视图层
│   ├── accounts/
│   │   ├── account_edit_view.dart
│   │   └── account_edit_utils.dart
│   ├── templates/
│   │   └── template_edit_view.dart
│   └── sync_settings_view.dart
├── widgets/          # 可复用组件
│   ├── account_edit_widgets.dart
│   ├── sync_settings_dialogs.dart
│   └── template_edit_widgets.dart
└── providers/        # 状态管理
```

### B. 关键技术栈

- **框架**: Flutter 3.x
- **状态管理**: Provider
- **同步引擎**: CRDT + HLC
- **加密**: PBKDF2 master verifier + AES-GCM secure link code
- **存储**: SharedPreferences + SecureStorage

---

**计划文档版本**: v1.0
**最后更新**: 2026-04-28
