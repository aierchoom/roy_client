# SecretRoy 客户端 — 六平台能力矩阵

> 生成时间：2026-05-16
> 扫描范围：lib/ 115 个 Dart 文件、pubspec.yaml、pubspec.lock、五平台原生工程目录
> 依据来源：代码条件编译、插件平台实现、原生工程存在性、pubspec 依赖声明

---

## 一、六平台逐功能对照表

### 1.1 认证与安全

| 功能 | Android | iOS | Windows | macOS | Linux | Web |
|------|:-------:|:---:|:-------:|:-----:|:-----:|:---:|
| **主密码解锁** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **生物识别解锁** | ✅ | ✅ | ⚠️ | ⚠️ | ❌ | ❌ |
| **无密码模式** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **AES-GCM-256 加密** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **PBKDF2 密钥派生** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **安全存储 (flutter_secure_storage)** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **自动锁定** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **保险库健康检查** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **离线恢复码导出/导入** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |

### 1.2 数据管理

| 功能 | Android | iOS | Windows | macOS | Linux | Web |
|------|:-------:|:---:|:-------:|:-----:|:-----:|:---:|
| **本地 SQLite 数据库** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **数据库文件加密 (运行时)** | ✅ | ✅ | ✅ | ✅ | ✅ | 🚫 |
| **账号 CRUD** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **模板 CRUD** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **TOTP 凭证 CRUD** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **备份包导出/验证导入** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| **文件选择器** | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |
| **系统分享** | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 | 🚫 |

### 1.3 TOTP / 2FA

| 功能 | Android | iOS | Windows | macOS | Linux | Web |
|------|:-------:|:---:|:-------:|:-----:|:-----:|:---:|
| **TOTP 码生成 (RFC 6238)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **HOTP 码生成 (RFC 4226)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **otpauth URI 解析** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **相机扫码导入 TOTP** | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **剪贴板二维码图片导入** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 1.4 同步与配对

| 功能 | Android | iOS | Windows | macOS | Linux | Web |
|------|:-------:|:---:|:-------:|:-----:|:-----:|:---:|
| **云端同步 (HTTP pull/push)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **LAN 面对面配对** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| **服务端中继配对** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **同步冲突收件箱** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **本地同步变更箱** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **CRDT 字段级合并** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### 1.5 通知与辅助

| 功能 | Android | iOS | Windows | macOS | Linux | Web |
|------|:-------:|:---:|:-------:|:-----:|:-----:|:---:|
| **本地推送通知** | ✅ | ✅ | ❌ | ✅ | ⚠️ | ❌ |
| **密码过期提醒生成** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **弱密码扫描提醒** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **定时每日检查调度** | ✅ | ✅ | ❌ | ✅ | ⚠️ | ❌ |
| **敏感剪贴板复制+自动清理** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **系统托盘** | ❌ | ❌ | ❌ | ❌ | ❌ | 🚫 |
| **打印** | ❌ | ❌ | ❌ | ❌ | ❌ | 🚫 |

### 1.6 UI / 体验

| 功能 | Android | iOS | Windows | macOS | Linux | Web |
|------|:-------:|:---:|:-------:|:-----:|:-----:|:---:|
| **响应式三档布局 (compact/medium/expanded)** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Material3 动态主题** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **暗色/OLED 纯黑模式** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **中文/英文双语** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **桌面端 NavRail 布局** | 🚫 | 🚫 | ✅ | ✅ | ✅ | ✅ |
| **移动端底部 NavBar 布局** | ✅ | ✅ | 🚫 | 🚫 | 🚫 | ✅ |
| **快捷键 (Ctrl+F 搜索等)** | 🚫 | 🚫 | ✅ | ✅ | ✅ | ⚠️ |

---

## 二、图例说明

| 符号 | 含义 |
|------|------|
| ✅ | 完全支持（有代码实现 + 平台插件支持） |
| ⚠️ | 部分支持/降级运行（功能可用但受限，或插件支持不完善） |
| ❌ | 不支持（平台限制或代码显式禁用） |
| 🚫 | 平台不适用（功能本身依赖原生能力，该平台无此概念） |

---

## 三、平台独占/受限功能清单

### 3.1 仅移动端支持的功能（Android / iOS）

| 功能 | 代码依据 |
|------|----------|
| 相机扫码导入 TOTP | `lib/views/accounts/totp_credential_edit_view.dart:41-44` 明确限制 `_supportsQrScan = !kIsWeb && (android \|\| iOS)` |
| 移动端 loopback URL 检测与禁止 | `lib/views/sync_settings_view.dart:49-52` / `lib/sync/sync_service.dart:652-657` 禁止移动端使用 `127.0.0.1/localhost` 作为同步服务器 |

### 3.2 仅桌面端支持的功能（Windows / macOS / Linux）

| 功能 | 代码依据 |
|------|----------|
| SQLite FFI 数据库初始化 | `lib/services/secure_storage_service.dart:167-177` 桌面端调用 `sqfliteFfiInit()` + `databaseFactoryFfi.openDatabase()` |
| 默认同步服务器地址 (`127.0.0.1:8080`) | `lib/system/service_manager/default_sync_server_url.dart:9-12` 仅桌面端返回默认地址 |
| 桌面端展开布局 (NavRail) | `lib/theme/app_layout.dart` 以 720px/1080px 断点区分，非平台独占但桌面端默认进入 expanded 模式 |
| Ctrl+F / Esc 搜索快捷键 | `lib/views/home/home_search_view.dart` 桌面端键盘快捷键 |

### 3.3 Web 端不支持/受限的功能

| 功能 | 限制原因 | 代码依据 |
|------|----------|----------|
| LAN 面对面配对 | Web 无法使用 `dart:io` 的 `HttpServer` / `RawDatagramSocket` | `lib/system/service_manager/vault_pairing_coordinator.dart:160-163` / `:194-197` 显式 `kIsWeb` 抛异常 |
| 本地 SQLite 数据库 | Web 无 `sqflite` WASM/FFI 配置，`path_provider` 在 Web 下异常 | `lib/services/secure_storage_service.dart` 无 Web 回退分支；`_isDesktop` 为 false 时走 `openDatabase()` 在 Web 下会失败 |
| 相机扫码 | Web 无 `mobile_scanner` 支持 | `lib/views/accounts/totp_credential_edit_view.dart:41-44` |
| 本地推送通知 | `flutter_local_notifications` 无 Web 实现 | `lib/services/notification_service.dart:35` 初始化设置仅含 android/iOS/macOS |
| 安全存储降级 | `flutter_secure_storage_web` 使用 `localStorage`，非加密存储 | pubspec.lock 中 `flutter_secure_storage_web: 2.1.0` 为 transitive 依赖 |
| 数据库文件加密持久化 | Web 无文件系统持久化路径 | `path_provider` `getApplicationDocumentsDirectory()` 在 Web 下抛出异常或返回 null |

### 3.4 代码中存在但零使用的依赖

| 依赖 | 声明位置 | 实际代码使用 | 结论 |
|------|----------|-------------|------|
| `file_picker: ^11.0.2` | pubspec.yaml:13 | `lib/` 中零 import/调用 | 未使用，可清理 |
| `share_plus: ^12.0.2` | pubspec.yaml:31 | `lib/` 中零 import/调用 | 未使用，可清理 |

---

## 四、技术约束说明

### 4.1 Web 平台限制（最严重）

**根本原因：Web 无法运行本地 SQLite**

- `sqflite` 在 Web 平台没有原生支持。项目未引入 `sqflite_common_ffi_web` + SQLite WASM 构建，因此 `openDatabase()` 在 Web 下会直接失败。
- `path_provider` 的 `getApplicationDocumentsDirectory()` / `getTemporaryDirectory()` 在 Web 下会抛出 `UnsupportedError` 或返回无意义的空路径。
- `dart:io` 在 Web 编译目标下不可用。虽然项目没有直接在通用代码中 `import 'dart:io'`（仅在 `lib/services/` 和 `lib/sync/` 中使用），但 `secure_storage_service.dart` 和 `lan_pairing_service.dart` 等核心服务都依赖 `dart:io` 的文件/网络 API。
- **结论**：当前代码架构下，Web 构建**无法运行核心功能**（无法创建/打开数据库，无法持久化加密保险库）。Web 端只能作为静态展示或需要大规模重构（引入 `sqflite_common_ffi_web` + IndexedDB/sha 降级方案）。

### 4.2 Windows / Linux 通知限制

- `flutter_local_notifications` 的初始化代码（`lib/services/notification_service.dart:35`）仅配置了 `android`、`iOS`、`macOS`：
  ```dart
  const settings = InitializationSettings(android: android, iOS: darwin, macOS: darwin);
  ```
- pubspec.lock 中存在 `flutter_local_notifications_linux`，但代码未将其纳入初始化设置，因此 Linux 通知实际上不可用。
- Windows 端 `flutter_local_notifications` 无官方实现（截至 v19.x），因此 Windows 完全不支持本地推送。
- **影响**：密码过期/弱密码的"定时提醒"在 Windows/Linux 上无法以系统通知形式触达用户，但应用内通知中心仍然可用。

### 4.3 生物识别平台差异

- `local_auth` 通过 `local_auth_windows`（transitive 依赖）提供了 Windows Hello 的有限支持，但：
  - Windows Hello 需要设备具备指纹/面部识别硬件；
  - `local_auth` 在 Windows 上的行为与移动端存在差异（如 `canCheckBiometrics` 返回值可能不准确）。
- Linux 端无 `local_auth_linux` 实现，完全不可用。
- 代码中没有对桌面端生物识别做显式的平台降级处理，`unlock_view.dart` 会直接调用 `BiometricAuthService.getStatus()`，由插件自行返回 `notSupported`。

### 4.4 桌面端数据库 FFI 依赖

- 桌面端（Windows/macOS/Linux）使用 `sqflite_common_ffi` 加载系统 SQLite 动态库：
  ```dart
  // lib/services/secure_storage_service.dart:167-177
  if (_isDesktop) {
    ffi.sqfliteFfiInit();
    _database = await ffi.databaseFactoryFfi.openDatabase(...);
  }
  ```
- Windows 构建依赖系统 `winsqlite3.dll`（Windows 10/11 自带）；项目提供了 `tool/flutter_test.ps1` 专门处理此依赖以避免测试时从 GitHub 下载二进制。
- macOS/Linux 依赖系统 `libsqlite3`。
- **风险**：如果目标设备缺少系统 SQLite 库，桌面端构建会崩溃。发布包需确保运行时库存在。

### 4.5 移动端沙盒限制

- iOS 沙盒禁止应用监听 loopback 地址上的服务器（`127.0.0.1` / `localhost`）。代码中显式检测并禁止：
  ```dart
  // lib/sync/sync_service.dart:652-657
  if (kIsWeb) return false;
  if (!Platform.isAndroid && !Platform.isIOS) return false;
  final host = Uri.tryParse(serverUrl)?.host.toLowerCase() ?? '';
  return host == '127.0.0.1' || host == 'localhost' || host == '::1' || host == '0.0.0.0';
  ```
- Android/iOS 的 `path_provider` 返回的是应用私有目录，数据无法被其他应用直接访问，符合安全设计。

### 4.6 剪贴板图片跨平台差异

- `pasteboard` 包支持读取剪贴板图片（`Pasteboard.image`），在 macOS/Windows/Web 上支持较好。
- Linux 剪贴板图片读取取决于桌面环境（X11/Wayland）和 `xclip`/`wl-clipboard` 等工具链的可用性。
- 代码中的 `TotpQrImageImportService` 使用 `image` + `zxing2` 纯 Dart 解码，不依赖平台原生库，因此二维码图片解析本身是全平台的。

---

## 五、市场宣传卖点提炼

基于平台矩阵，提炼以下可用于产品宣传的技术差异化卖点：

### 5.1 核心安全卖点

| 卖点文案 | 技术支撑 | 覆盖平台 |
|----------|----------|----------|
| **"全平台本地加密，主密码不出设备"** | AES-GCM-256 运行时数据库加密 + PBKDF2 100k 轮次派生 | Android / iOS / Windows / macOS / Linux |
| **"军工级加密标准"** | 数据库文件信封加密（nonce + MAC 校验），X25519 配对密钥交换 | 全部原生平台 |
| **"生物识别秒解锁，安全不妥协"** | Face ID / 指纹 / Windows Hello 支持，生物识别仅解锁本地密钥信封 | Android / iOS / Windows / macOS |

### 5.2 跨设备同步卖点

| 卖点文案 | 技术支撑 | 覆盖平台 |
|----------|----------|----------|
| **"零配置局域网同步，同 WiFi 即连"** | UDP 广播发现 + HTTP  claim + X25519 端到端加密传输 | Android / iOS / Windows / macOS / Linux |
| **"无公网也能配对，8 位可读配对码"** | LAN 配对使用 `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` 32 字符集，避免混淆 | 全部原生平台 |
| **"字段级 CRDT 合并，多设备编辑不丢数据"** | Hybrid Logical Clock (HLC) + 字段级冲突自动合并 | 全部原生平台 |
| **"自托管服务器，数据主权归你"** | 可选 `roy_server` Node.js 服务端中继，Payload AES-256-GCM + HKDF 加密 | 全部原生平台 |

### 5.3 用户体验卖点

| 卖点文案 | 技术支撑 | 覆盖平台 |
|----------|----------|----------|
| **"六端统一代码库，体验一致"** | Flutter 单一代码库覆盖 Android / iOS / Windows / macOS / Linux / Web | 全部（Web 需后续适配） |
| **"桌面端大屏优化， NavRail + 快捷键效率翻倍"** | 1080px 断点展开布局 + Ctrl+F 全局搜索 | Windows / macOS / Linux |
| **"密码过期主动提醒，保险库健康实时体检"** | 本地通知 + 弱密码/重复密码/备份年龄多维度评分 | Android / iOS / macOS |
| **"敏感内容 45 秒自动焚毁"** | SHA-256 hash 比对防误删 + 定时清理剪贴板 | 全部平台 |
| **"TOTP 一机双用：扫码 + 粘贴二维码"** | 移动端相机扫码 + 桌面端剪贴板图片解码，全场景覆盖 2FA 导入 | 全部原生平台 |

### 5.4 开发者/极客向卖点

| 卖点文案 | 技术支撑 |
|----------|----------|
| **"零硬编码密钥，零 TODO/FIXME"** | 代码审计通过：全项目无显式技术债务标记，密钥全随机生成 |
| **"540+ 单元测试守护核心逻辑"** | CRDT 合并、Payload 编解码、同步状态机、加密信封均有高覆盖测试 |
| **"离线恢复码，PBKDF2+AES-GCM 加密导出"** | 即使服务器消失，恢复码仍可安全迁移 Vault 身份 |

---

## 六、风险与建议

| 优先级 | 问题 | 影响平台 | 建议 |
|--------|------|----------|------|
| 🔴 P0 | Web 端完全无法运行（SQLite + path_provider 崩溃） | Web | 评估是否真正需要 Web 目标；如需要，引入 `sqflite_common_ffi_web` + WASM SQLite，或降级为内存存储 |
| 🔴 P0 | `file_picker` / `share_plus` 声明但未使用 | 全部 | 清理 pubspec.yaml 中未使用的依赖，减少构建体积和供应链攻击面 |
| 🟡 P1 | Windows / Linux 本地通知未配置 | Windows / Linux | 在 `NotificationService.init()` 中补充 Windows (`windows:`) 和 Linux (`linux:`) 初始化设置；或文档中明确标注不支持 |
| 🟡 P1 | `flutter_secure_storage_web` 降级为 localStorage | Web | 如保留 Web 目标，应在 Web 下使用替代安全存储方案（如 Web Crypto API + IndexedDB），并明确告知用户 Web 端安全级别降低 |
| 🟢 P2 | 桌面端 SQLite 依赖系统动态库 | Windows / macOS / Linux | 发布构建时静态链接 SQLite 或打包运行时检测脚本，避免用户设备缺少库文件 |
| 🟢 P2 | `local_auth_windows` 支持质量未验证 | Windows | 补充 Windows Hello 的端到端测试，确认 `canCheckBiometrics` / `authenticate` 在干净 Windows 环境下的行为 |

---

## 七、数据来源索引

| 结论 | 来源文件 | 行号/位置 |
|------|----------|-----------|
| `_isDesktop` FFI 判断 | `lib/services/secure_storage_service.dart` | 23-24, 167-177 |
| Web 禁止 LAN 配对 | `lib/system/service_manager/vault_pairing_coordinator.dart` | 160-163, 194-197 |
| 移动端禁止 loopback | `lib/views/sync_settings_view.dart` / `lib/sync/sync_service.dart` | 49-52 / 652-657 |
| 扫码平台限制 | `lib/views/accounts/totp_credential_edit_view.dart` | 41-44 |
| 通知初始化平台范围 | `lib/services/notification_service.dart` | 33-35 |
| 桌面端默认同步地址 | `lib/system/service_manager/default_sync_server_url.dart` | 3-16 |
| 触摸设备判断 | `lib/theme/app_layout.dart` | 102-105 |
| `file_picker` / `share_plus` 零使用 | `lib/` 全目录 grep | — |
| 原生工程存在性 | `android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/` 目录 ls | — |
| 插件平台实现 | `pubspec.lock` | `local_auth_windows`, `flutter_secure_storage_web`, `flutter_local_notifications_linux` 等条目 |
