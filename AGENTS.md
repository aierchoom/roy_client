<!-- From: c:\Users\choom\Desktop\CodeRepo\roy\roy_client\AGENTS.md -->
# SecretRoy 项目指南（AI Agent 版）

> 本文档面向 AI 编程助手，概括项目架构、技术栈、构建方式、代码组织与开发惯例。
> 项目主要文档语言为中文，代码注释中英混合；本文档以中文撰写，保留关键英文术语。

---

## 项目概览

**SecretRoy** 是一个基于 Flutter 的本地优先密码管理器原型。核心设计哲学：

- **本地优先**：所有数据默认保存在本地加密 SQLite 中，不依赖网络即可工作。
- **可选同步**：用户可选择通过自托管的 `roy_server`（Node.js）在多设备间同步。
- **加密存储**：本地数据库以 AES-GCM-256 二进制信封加密长期落盘；解锁时解密到临时运行时工作文件。
- **CRDT 同步**：使用 Hybrid Logical Clock（HLC）和字段级 CRDT 合并引擎处理多设备冲突。
- **当前状态**：架构骨架成型、客户端能力较强，但尚未达到可直接投产的安全产品级别。

主要支持平台：Android、iOS、Windows、macOS、Linux、Web。

---

## 技术栈与关键依赖

| 层级 | 技术 |
|------|------|
| 框架 | Flutter 3.x / Dart ^3.10.1 |
| 状态管理 | `provider`（ChangeNotifier） |
| 本地数据库 | `sqflite` / `sqflite_common_ffi`（桌面端） |
| 加密 | `cryptography`（AES-GCM-256、PBKDF2、HKDF、X25519）、`crypto` |
| 安全存储 | `flutter_secure_storage` |
| 生物识别 | `local_auth` |
| 网络同步 | `http` |
| 二维码 | `mobile_scanner`、`zxing2` |
| TOTP | 自建 RFC 6238 实现（SHA1/SHA256/SHA512） |
| 剪贴板 | `pasteboard` |
| 文件选择 | `file_picker` |
| 国际化 | `flutter_localizations` + ARB |
| 字体 | `google_fonts`（Noto Sans SC） |
| 其他 | `archive`、`image`、`share_plus`、`shared_preferences`、`uuid` |

---

## 项目结构

```text
lib/
├── core/               # 基础工具（AppLogger 等）
├── l10n/               # ARB 国际化文件（zh 为主模板，en 为英文）
├── main.dart           # 应用入口：初始化 ServiceManager、Provider、主题
├── models/             # 数据模型：AccountItem、AccountTemplate、Hlc、TOTPCredential、LocalSyncChange、VaultHealthReport 等
├── providers/          # Provider 状态层（EnhancedAppProvider、ThemeProvider）
├── services/           # 业务服务层
│   ├── auto_lock_service.dart
│   ├── biometric_auth_service.dart
│   ├── database_file_cipher.dart
│   ├── database_file_key_manager.dart
│   ├── enhanced_crypto_service.dart
│   ├── identity_service.dart
│   ├── lan_pairing_service.dart
│   ├── secure_storage_service.dart
│   ├── sensitive_clipboard_service.dart
│   ├── service_manager.dart
│   ├── totp_import_service.dart
│   ├── totp_qr_image_import_service.dart
│   ├── totp_service.dart
│   ├── vault_health_calculator.dart
│   ├── vault_pairing_crypto.dart
│   └── vault_pairing_service.dart
├── sync/               # 同步核心：CRDT 合并、Payload 编解码、SyncService（pull/push/conflict）、TOTPCredential 合并
├── system/             # 系统级辅助模块：ServiceManager 的拆分逻辑、持久化 helper、 narrowly-focused coordinators
│   └── service_manager/
│       ├── default_sync_server_url.dart
│       ├── password_tools.dart
│       ├── sync_server_url_store.dart
│       └── vault_dump_coordinator.dart
├── theme/              # 设计令牌与主题扩展（Material3 + 自定义 Token）
│   ├── app_design_tokens.dart
│   ├── app_layout.dart      # 跨平台三档断点（compact/medium/expanded）
│   ├── app_text_styles.dart # 跨平台排版系统
│   └── theme.dart           # Barrel 统一导出
├── utils/              # 通用工具与常量（field_presets.dart、template_icons.dart）
├── views/              # 页面
│   ├── accounts/       # 账号编辑、列表、TOTP 列表/编辑/扫码
│   ├── home/           # 主页及桌面/移动自适应布局
│   ├── settings/       # 保险库健康检查
│   ├── sync/           # 本地同步队列
│   ├── templates/      # 模板列表与编辑
│   ├── appearance_settings_view.dart
│   ├── conflict_inbox_view.dart
│   ├── password_tools_view.dart
│   ├── release_note_view.dart
│   ├── security_settings_view.dart
│   ├── settings_view.dart
│   ├── sync_settings_view.dart
│   └── unlock_view.dart
└── widgets/            # 可复用组件（AccountListTile、AppHeroCard、AppNavBar、AppNavRail、PasswordGeneratorSheet 等）

test/
├── models/             # 模型序列化与兼容性测试
├── services/           # 加密、存储、身份、TOTP、剪贴板、配对测试
├── sync/               # CRDT、状态机、配对、Payload 编解码、冲突恢复、多设备同步测试
├── system/             # VaultDumpCoordinator、导入回滚测试
├── theme/              # Design Token 与布局断点测试
├── utils/              # 字段预设测试
├── views/              # UnlockView 测试
└── widgets/            # 可复用组件测试

integration_test/       # 端到端冒烟测试（smoke_happy_path、smoke_full_workflows）

docs/                   # 项目文档（architecture、security、sync、product、wiki 等）
tool/                   # 开发工具脚本（flutter_test.ps1、check_style_tokens.py、各种 fix 脚本等）
```

---

## 构建与运行命令

```bash
# 安装依赖
flutter pub get

# 开发运行（默认中文 locale）
flutter run

# 指定平台运行
flutter run -d windows
flutter run -d android
flutter run -d chrome

# 静态分析
flutter analyze

# 代码格式化（项目使用 120 字符行宽）
dart format .

# 生成国际化代码（如修改了 ARB）
flutter gen-l10n
```

### Windows 本地测试特殊命令

Windows 上部分测试依赖 SQLite 原生库，项目提供了 PowerShell 包装脚本：

```powershell
# 运行全部测试（使用 winsqlite3.dll，避免从 GitHub 下载 sqlite3 二进制）
.\tool\flutter_test.ps1

# 运行指定测试目录/文件
.\tool\flutter_test.ps1 test\sync
.\tool\flutter_test.ps1 test\services\secure_storage_service_sync_outbox_test.dart
```

该脚本会：
1. 将 `APPDATA` 指向 `.dart_appdata`（隔离 Flutter/Dart 状态）；
2. 临时生成 `pubspec_overrides.yaml` 让 `sqlite3` 使用系统 `winsqlite3.dll`；
3. 测试结束后自动清理 override 文件。

### 标准测试命令

```bash
# 运行全部测试
flutter test

# 运行指定文件或目录
flutter test test/sync/sync_state_machine_test.dart
flutter test test/models

# 按测试名称过滤
flutter test --name "merge is deterministic"

# 展开输出
flutter test --reporter expanded
```

### 发布构建

```bash
# 本地 Windows + Android 发布构建（带混淆与符号分离）
.\build_release.bat
```

或手动：

```bash
# Windows
flutter build windows --obfuscate --split-debug-info=build\windows\symbols

# Android（按 ABI 分包）
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build\app\symbols
```

---

## 代码风格与约定

### 格式化

- **行宽**：120 字符（`.vscode/settings.json` 已配置）。
- **保存时自动格式化**：VS Code 已开启 `editor.formatOnSave` 与 `source.organizeImports`。
- 提交前建议运行 `dart format .`。

### Linter 规则

`analysis_options.yaml` 继承 `package:flutter_lints/flutter.yaml`，但显式**关闭了**以下规则：

- `prefer_const_constructors: false`
- `prefer_final_fields: false`
- `use_key_in_widget_constructors: false`
- `prefer_const_literals_to_create_immutables: false`
- `prefer_const_constructors_in_immutables: false`
- `avoid_print: false`

同时**开启**了：

- `avoid_relative_lib_imports: true`（强制使用 `package:` 导入项目内部文件）
- `invalid_case_patterns: true`

> 注意：`avoid_print` 虽被关闭，但项目中已统一使用 `AppLogger.d()`（在 `lib/core/app_logger.dart`）替代裸 `debugPrint`，以便未来集中管控日志。

### 命名与组织

- 模型类使用手写的 `toJson()` / `fromJson()`，**不依赖代码生成**（当前未使用 `json_serializable` / `build_runner`）。
- 模型字段变更时，必须同步更新：模型类本身、`toJson`、`fromJson`、相关测试、以及 `copyWith`。
- 服务层以 `Service` 后缀命名，核心状态通过 `ChangeNotifier` 暴露。
- `ServiceManager`（`lib/services/service_manager.dart`）是全局单例，负责统筹所有服务的生命周期与解锁状态；新服务接入时应避免继续膨胀其职责，优先拆分到 `lib/system/`。
- 导入顺序：Dart SDK → Flutter SDK → 第三方包 → 项目内部（按 `package:` 路径）。

### 样式 Token 红线

项目使用 `tool/check_style_tokens.py` 在 CI 中扫描 `lib/` 目录，防止以下硬编码债务回流：

- `BorderRadius.circular(<数字>)`（应使用 `AppRadii.*`）
- `.withAlpha(<数字>)`（应使用 `AppAlphas.*`）
- `AppBreakpoints.isDesktop`（ legacy，应使用 `AppLayout`）

`lib/theme/` 和 `lib/widgets/` 目录被排除在扫描外（Token 定义处允许硬编码）。

---

## 测试策略

### 当前覆盖

- **测试文件数**：38
- **测试用例数**：120+
- **覆盖范围**：models、services、sync、system、theme、utils、views、widgets
- **Widget 测试**：少量，包括 `account_list_tile_test.dart`、`app_hero_card_test.dart`、`app_nav_test.dart`、`app_option_tile_test.dart`、`app_selectable_scrollable_test.dart`、`app_settings_test.dart`
- **集成测试**：`integration_test/smoke_happy_path_test.dart`、`smoke_full_workflows_test.dart`

### 重点测试领域

| 领域 | 关键测试文件 |
|------|-------------|
| 模型兼容性 | `test/models/*_test.dart`（验证 JSON 解析 fallback、字段兼容性） |
| 本地加密存储 | `test/services/database_file_cipher_test.dart`、`secure_storage_service_encryption_test.dart` |
| 同步变更箱 | `test/services/secure_storage_service_sync_outbox_test.dart`（create→update→delete 合并规则） |
| 身份与配对 | `test/services/identity_service_test.dart`、`test/sync/lan_pairing_service_test.dart`、`vault_pairing_crypto_test.dart` |
| CRDT 合并 | `test/sync/crdt_merge_engine_test.dart`、`crdt_merge_invariants_test.dart` |
| 同步状态机 | `test/sync/sync_state_machine_test.dart`、`multi_device_sync_test.dart` |
| Payload 安全 | `test/sync/sync_payload_codec_test.dart`（篡改拒绝、vault 隔离、旧格式兼容） |
| 冲突恢复 | `test/sync/sync_conflict_recovery_test.dart`、`sync_recovery_loop_test.dart` |
| TOTP | `test/services/totp_service_test.dart`（RFC 6238 标准向量）、`totp_import_service_test.dart`、`totp_qr_image_import_service_test.dart` |
| 敏感剪贴板 | `test/services/sensitive_clipboard_service_test.dart`（定时清理、SHA-256 hash 防误删） |
| 主题 Token | `test/theme/app_design_tokens_test.dart`、`app_layout_test.dart` |
| 系统辅助 | `test/system/vault_dump_coordinator_test.dart`、`vault_import_rollback_test.dart` |

### 测试中的常见模式

1. **临时目录隔离**：涉及 `SecureStorageService` 的测试应传入测试 cipher 与独立 `deviceId`，避免污染真实数据。
2. **ChangeNotifier 状态观察**：监听 `addListener(() => states.add(service.state))` 验证状态迁移。
3. **回归建议**：改动模型后至少跑 `flutter test test/models`；改动加密/数据库后跑 `flutter test test/services`；改动同步协议后跑 `flutter test test/sync`。

### 已知缺口

- 端到端 UI 流程测试较少（仅 2 个集成冒烟测试）。
- 缺少真实网络环境下的客户端/服务端联合测试。
- 部分设置页、模板编辑页主要依赖手动验证。

---

## 安全注意事项

### 本地数据安全

- 长期数据库文件：`secret_roy_vault.db.enc`（AES-GCM-256 二进制信封）。
- DB 数据密钥：随机 32 字节，由主密码派生的包装密钥保护。
- 主密码验证：PBKDF2-HMAC-SHA256（100,000 轮）。
- 遗留明文 verifier 会在成功验证后自动迁移到 PBKDF2。
- 运行时工作库位于临时目录，理论上应在锁定时清理。

### 同步安全

- 同步 Payload 使用 `sroy-sync:` 前缀的 AES-256-GCM + HKDF 信封（`SyncPayloadCodec`）。
- 设备身份（`IdentityService`）在首次初始化时自动生成 `deviceId`、`vaultId` 等。
- LAN 配对使用 8 位可读字符（`ABCDEFGHJKLMNPQRSTUVWXYZ23456789`），非 6 位数字码。
- 离线恢复码使用 `sroy-recovery:` 前缀 + PBKDF2 + AES-GCM-256。

### Agent 必须遵守的红线

1. **不要**在代码中引入真实的密钥、盐值或硬编码密码。
2. **不要**降低 PBKDF2 迭代次数或移除加密 envelope。
3. **不要**将敏感数据（主密码、DB 密钥、身份私钥）以明文形式输出到日志或异常信息。
4. 修改 `analysis_options.yaml` 中的 linter 规则时，需评估是否会导致安全相关代码（如 `avoid_print`）被意外忽略。
5. 新增同步或加密逻辑时，必须配套编写对应的篡改/隔离/兼容性测试。

---

## 部署与 CI/CD

`.github/workflows/build-packages.yml`：

- **触发条件**：`main`/`master` 分支的 push、tag（`v*`）、PR、手动触发（`workflow_dispatch`）。
- **Validate Job**：`flutter pub get` → `dart analyze lib test` → `python3 tool/check_style_tokens.py` → `flutter test`（Ubuntu）。
- **Android Minimal APK**：分 ABI 构建 release APK，上传 artifact（保留 14 天）。
- **Windows Portable**：构建 Windows release，打包为 ZIP，上传 artifact（保留 14 天）。

> 服务端代码位于同级目录 `../roy_server/`（Node.js），不属于本仓库。

---

## 国际化

- 模板 ARB 文件：`lib/l10n/app_zh.arb`
- 输出文件：`lib/l10n/app_localizations.dart`
- 当前支持中文（`zh`，默认）与英文（`en`）。
- 修改 ARB 后运行 `flutter gen-l10n` 重新生成本地化代码。

---

## 常用开发路径速查

| 任务 | 路径/命令 |
|------|----------|
| 应用入口 | `lib/main.dart` |
| 全局服务统筹 | `lib/services/service_manager.dart` |
| 本地数据库与加密 | `lib/services/secure_storage_service.dart` |
| 同步核心 | `lib/sync/sync_service.dart`（含 `sync_service_pull.dart`、`sync_service_push.dart`、`sync_service_conflict.dart`） |
| CRDT 合并 | `lib/sync/crdt_merge_engine.dart` |
| 密码学服务 | `lib/services/enhanced_crypto_service.dart` |
| 设备身份 | `lib/services/identity_service.dart` |
| TOTP 服务 | `lib/services/totp_service.dart` |
| 主题系统（Token/排版/布局） | `lib/theme/theme.dart` |
| 跨平台断点与布局 | `lib/theme/app_layout.dart` |
| 跨平台排版系统 | `lib/theme/app_text_styles.dart` |
| 项目 TODO | `docs/todo.md` |
| 架构概览 | `docs/architecture/00-executive-summary.md` |
| 测试指南 | `docs/wiki/testing-guide.md` |
| 开发环境搭建 | `docs/wiki/development-setup.md` |

---

## 给 AI Agent 的关键提示

1. **改模型要改全**：模型、JSON、测试、UI 引用四方联动。
2. **ServiceManager 是集中点**：新增服务时考虑是否应拆分到 `lib/system/` 而非直接膨胀单例。
3. **测试即文档**：高价值逻辑（加密、同步、CRDT）必须以测试形式保留行为契约。
4. **日志统一入口**：调试输出请使用 `AppLogger.d()`，不要直接 `debugPrint` 或 `print`。
5. **保持中文为主界面语言**：新增 UI 文案时，优先在 `app_zh.arb` 中添加，并在 `app_en.arb` 中补充英文。
6. **样式优先用 Token**：新增 UI 样式时，优先使用 `AppRadii`、`AppSpacing`、`AppSurfaces`、`AppTextStyles`，避免硬编码魔法数字。
7. **禁止相对 lib 导入**：项目内文件必须使用 `package:secret_roy/...` 形式导入，`analysis_options.yaml` 已开启 `avoid_relative_lib_imports: true`。
