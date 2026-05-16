# SecretRoy 新开发者快速入门

> 目标读者：第一天入职、已有 Flutter 基础的开发者  
> 阅读时长：10 分钟  
> 版本：2026-05-16

---

## 1. 环境要求（5 分钟检查清单）

| 项目 | 版本要求 | 说明 |
|------|----------|------|
| Flutter SDK | `3.38.3`（stable） | CI 锁定版本，建议严格对齐 |
| Dart SDK | `^3.10.1` | 随 Flutter 自带 |
| Git | 2.0+ | 版本控制 |
| IDE | VS Code 或 Android Studio | 推荐 VS Code |

### 1.1 验证 Flutter 环境

```bash
flutter --version
# 期望输出包含：Flutter 3.38.3 • channel stable

flutter doctor
# 确保 [✓] Flutter、[✓] 至少一个目标平台工具链 为绿色
```

### 1.2 平台 SDK（按需安装）

| 目标平台 | 额外依赖 |
|----------|----------|
| Android | Android SDK 21+、Build Tools 34+、接受许可 `flutter doctor --android-licenses` |
| iOS / macOS | Xcode 15+、CocoaPods 1.12+（仅 macOS） |
| Windows | Visual Studio 2022（"使用 C++ 的桌面开发"工作负载）、Windows 10 SDK |
| Linux | `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` |
| Web | Chrome 浏览器 |

---

## 2. 项目配置（3 分钟）

```bash
# 1. 进入项目根目录
cd roy_client

# 2. 安装依赖
flutter pub get

# 3. 确认代码分析通过（无错误）
flutter analyze lib test
```

### IDE 配置

项目仓库已包含推荐的 VS Code 配置（`.vscode/settings.json`），关键项：

```json
{
  "dart.lineLength": 120,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": "explicit"
  }
}
```

建议安装的 VS Code 扩展：Flutter、Dart。

---

## 3. 第一次运行（2 分钟）

```bash
# 列出可用设备
flutter devices

# 在默认设备运行（中文 locale，无需配置）
flutter run

# 或指定平台
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

首次启动会进入 `UnlockView`：
- 无数据库 → 创建保险库（设置主密码）
- 有数据库 → 输入主密码解锁
- 也可选择「无密码模式」直接体验本地功能

同步服务器不是启动必需项；未配置时本地账号管理仍可完整运行。

---

## 4. 项目结构 5 分钟速览

```
lib/
├── main.dart                 # 应用入口：初始化 ServiceManager、注入 Provider、构建主题
├── core/                     # 最底层工具：AppLogger（统一日志）、CryptoRandom
├── l10n/                     # 国际化：ARB 模板(zh) + 英文(en) + 生成的本地化类
├── models/                   # 数据模型：AccountItem、AccountTemplate、TotpCredential、Hlc 等
│                             #   模型变更需同步改：类定义 + toJson/fromJson + copyWith + 测试
├── providers/                # ChangeNotifier 状态层（3 个）
│   ├── enhanced_app_provider.dart    # 业务数据：accounts/templates/totp/搜索过滤
│   ├── notification_provider.dart    # 通知中心状态
│   └── theme_provider.dart           # 主题模式/种子色/OLED极致黑
├── services/                 # 业务服务层（18 个文件）
│   ├── service_manager.dart          # 全局单例门面，编排所有服务生命周期
│   ├── secure_storage_service.dart   # 加密 SQLite 运行时管理
│   ├── enhanced_crypto_service.dart  # 主密码 PBKDF2、数据库密钥解锁
│   ├── identity_service.dart         # 设备/Vault 身份生成与管理
│   ├── auto_lock_service.dart        # 应用生命周期监听与自动锁定
│   ├── biometric_auth_service.dart   # 生物识别启用/解锁
│   ├── totp_service.dart             # RFC 6238 TOTP 生成
│   ├── sync_service*.dart            # 同步核心（pull/push/conflict）
│   └── ...
├── sync/                     # CRDT 同步核心：合并引擎、Payload 编解码、状态机
├── system/                   # ServiceManager 拆分的协调器（10 个）
│   └── service_manager/
│       ├── vault_unlock_coordinator.dart
│       ├── vault_data_repository.dart
│       ├── sync_coordinator.dart
│       └── ...
├── theme/                    # 设计 Token 体系
│   ├── app_design_tokens.dart        # 颜色/圆角/间距/透明度/阴影/边框
│   ├── app_layout.dart               # 三档断点：compact/medium/expanded
│   ├── app_text_styles.dart          # 跨平台排版系统
│   └── theme.dart                    # Barrel 统一导出
├── utils/                    # 通用工具：字段预设、模板图标、相对时间格式化
├── views/                    # 页面层（24 个文件）
│   ├── home/                 # 主页壳层 + 桌面/移动自适应布局
│   ├── accounts/             # 账号列表/编辑、TOTP 编辑/扫码
│   ├── templates/            # 模板列表/编辑
│   ├── settings/             # 子设置页（通知、体检）
│   ├── sync/                 # 本地同步队列
│   ├── notifications/        # 通知中心
│   └── ...
└── widgets/                  # 可复用组件：AccountListTile、AppHeroCard、PasswordGeneratorSheet 等
```

**关键设计原则**：
- `ServiceManager` 是全局门面，复杂业务已下沉到 `lib/system/` 的 Coordinator。
- 新增 UI 样式优先用 `AppRadii` / `AppSpacing` / `AppAlphas` Token，禁止硬编码 `BorderRadius.circular(<数字>)` 和 `.withAlpha(<数字>)`（CI 红线）。
- 所有 `package:` 导入必须使用 `package:secret_roy/...` 形式，禁止相对 `lib/` 导入。

---

## 5. 常用开发命令速查表

| 命令 | 说明 |
|------|------|
| `flutter pub get` | 安装依赖 |
| `flutter run` | 开发运行（默认中文 locale） |
| `flutter run -d windows` | Windows 桌面端运行 |
| `flutter run -d chrome` | Web 端运行 |
| `flutter analyze` | 静态分析 |
| `dart format .` | 格式化代码（行宽 120） |
| `flutter gen-l10n` | 修改 ARB 后重新生成本地化代码 |

---

## 6. 如何运行测试

### 6.1 标准测试命令

```bash
# 运行全部测试
flutter test

# 运行指定目录
flutter test test/models
flutter test test/services
flutter test test/sync
flutter test test/views

# 运行指定文件
flutter test test/sync/crdt_merge_engine_test.dart

# 按名称过滤
flutter test --name "merge is deterministic"

# 展开输出
flutter test --reporter expanded

# 生成覆盖率
flutter test --coverage
# 覆盖率报告：coverage/lcov.info
```

### 6.2 Windows 特殊测试命令（重要）

Windows 上部分测试依赖 SQLite 原生库，项目提供了 PowerShell 包装脚本：

```powershell
# 运行全部测试（使用系统 winsqlite3.dll，避免从 GitHub 下载）
.\tool\flutter_test.ps1

# 运行指定目录/文件
.\tool\flutter_test.ps1 test\sync
.\tool\flutter_test.ps1 test\services\secure_storage_service_sync_outbox_test.dart
```

该脚本会：
1. 将 `APPDATA` 指向 `.dart_appdata`（隔离 Flutter/Dart 状态）；
2. 临时生成 `pubspec_overrides.yaml` 让 `sqlite3` 使用系统 `winsqlite3.dll`；
3. 测试结束后自动清理 override 文件。

### 6.3 回归测试建议

| 改动范围 | 建议执行的测试 |
|----------|----------------|
| 模型字段变更 | `flutter test test/models` |
| 加密/数据库逻辑 | `flutter test test/services` |
| 同步协议/CRDT | `flutter test test/sync` |
| UI/视图层 | `flutter test test/views` `flutter test test/widgets` |

---

## 7. 遇到问题时的排查路径

### 7.1 构建失败

| 现象 | 排查步骤 |
|------|----------|
| `flutter doctor` 有红色叉号 | 按 doctor 提示安装缺失工具链 |
| Android 编译失败 | `cd ios && pod install`（iOS）；`flutter doctor --android-licenses`（Android） |
| Windows 找不到 Visual Studio | 确认 VS 安装了"使用 C++ 的桌面开发" + Windows 10 SDK |
| 依赖版本冲突 | `flutter pub deps` 查看树；删除 `pubspec.lock` 后 `flutter pub get` |

### 7.2 测试失败

| 现象 | 排查步骤 |
|------|----------|
| Windows 测试因 sqlite3 下载卡住 | 使用 `\.\tool\flutter_test.ps1` |
| 安全存储相关测试失败 | 检查是否污染了真实 `APPDATA`，脚本已做隔离 |
| 单测试文件失败 | 单独运行该文件：`flutter test <path>` |

### 7.3 运行时问题

| 现象 | 排查步骤 |
|------|----------|
| 解锁后列表不显示数据 | 检查 `SecureStorageService.isOpen`、查看 `AppLogger.d()` 输出 |
| 主题/样式未生效 | 确认未使用硬编码 `BorderRadius.circular` 或 `withAlpha`（会被 CI 拦截） |
| 同步失败 | 检查 `SyncCoordinator` 状态、服务器 URL、网络连接 |

### 7.4 日志查看

项目已统一使用 `AppLogger.d()` / `AppLogger.w()` / `AppLogger.e()`，**不要**直接使用 `debugPrint` 或 `print`。

- `d()` / `w()`：仅在 debug 模式输出
- `e()`：release 模式也会输出，用于同步失败、数据损坏等关键问题

---

## 8. 与 `development-setup.md` 的关系

| 文档 | 定位 | 内容侧重 |
|------|------|----------|
| **本文档**（`new-developer-quickstart.md`） | 快速版：第一天上手 | 精简步骤、5 分钟目录速览、命令速查、排查路径 |
| `docs/wiki/development-setup.md` | 完整版：环境详解 | 各操作系统 Flutter 安装细节、IDE 完整配置、`launch.json`、环境变量、FAQ |

**建议阅读顺序**：
1. 先看本文档，10 分钟内跑通项目。
2. 遇到具体平台环境问题时，再查阅 `development-setup.md` 的对应章节。

---

## 附录：启动顺序记忆

```
main()
  → WidgetsFlutterBinding.ensureInitialized()
  → SharedPreferences.getInstance()
  → ServiceManager.instance.initialize()
  → NotificationService.init()
  → runApp(SecretRoyApp)
  → setupLifecycleObserver()
  → MultiProvider 注入 4 个 Provider
  → Consumer2 根据 state 渲染 UnlockView / HomeView
```
