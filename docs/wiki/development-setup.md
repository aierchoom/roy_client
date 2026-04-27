# 开发环境搭建

**版本**: v1.1.0
**最后更新**: 2026-04-27

---

## 目录

1. [环境要求](#1-环境要求)
2. [安装步骤](#2-安装步骤)
3. [项目配置](#3-项目配置)
4. [运行与调试](#4-运行与调试)
5. [常见问题](#5-常见问题)

---

## 1. 环境要求

### 1.1 操作系统

| 平台 | 最低版本 |
|------|----------|
| Windows | Windows 10 64-bit |
| macOS | macOS 10.14 (Mojave) |
| Linux | Ubuntu 20.04 / Debian 11 |

### 1.2 软件依赖

| 软件 | 版本要求 | 用途 |
|------|----------|------|
| Flutter SDK | 3.16+ | 跨平台框架 |
| Dart SDK | 3.2+ | 编程语言 |
| Git | 2.0+ | 版本控制 |
| VS Code / Android Studio | 最新版 | IDE |

### 1.3 平台特定要求

#### Android 开发
- Android SDK 21+ (Android 5.0+)
- Android Build Tools 34+
- NDK (可选)

#### iOS 开发 (仅 macOS)
- Xcode 15+
- CocoaPods 1.12+
- Apple Developer 账户 (真机调试)

#### Windows 开发
- Visual Studio 2022 (C++ 工作负载)
- Windows 10 SDK

#### macOS 开发
- Xcode 15+
- CocoaPods

#### Linux 开发
```bash
# Ubuntu/Debian
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

---

## 2. 安装步骤

### 2.1 安装 Flutter SDK

#### Windows

```powershell
# 下载 Flutter SDK
# https://docs.flutter.dev/get-started/install/windows

# 或使用 Chocolatey
choco install flutter

# 添加到 PATH
$env:Path += ";C:\flutter\bin"
```

#### macOS

```bash
# 使用 Homebrew
brew install flutter

# 或手动下载
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"
```

#### Linux

```bash
# 使用 Snap
sudo snap install flutter --classic

# 或手动下载
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/development/flutter/bin"
```

### 2.2 验证安装

```bash
# 检查 Flutter 版本
flutter --version

# 检查环境
flutter doctor
```

预期输出：
```
Doctor summary (to see all details, run flutter doctor -v):
[✓] Flutter (Channel stable, 3.x.x, on Microsoft Windows)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.x)
[✓] Chrome - develop for the web
[✓] Visual Studio - develop for Windows (Visual Studio Community 2022)
[✓] Android Studio (version 2023.x)
[✓] VS Code (version 1.x)
[✓] Connected device (3 available)
[✓] Network resources
```

### 2.3 克隆项目

```bash
# 克隆仓库
git clone https://github.com/your-org/secret-roy.git
cd secret-roy/roy_client

# 安装依赖
flutter pub get
```

### 2.4 IDE 配置

#### VS Code

1. 安装扩展：
   - Flutter
   - Dart
   - Awesome Flutter Snippets

2. 推荐设置 (`settings.json`)：
```json
{
  "dart.lineLength": 100,
  "dart.previewFlutterUiGuides": true,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit"
  }
}
```

#### Android Studio

1. 安装 Flutter 和 Dart 插件
2. 配置 Flutter SDK 路径
3. 启用 Dart 支持

---

## 3. 项目配置

### 3.1 项目结构

```
roy_client/
├── lib/                    # 源代码
├── test/                   # 测试代码
├── docs/                   # 文档
├── assets/                 # 资源文件
├── pubspec.yaml           # 依赖配置
├── analysis_options.yaml  # 代码分析规则
└── README.md              # 项目说明
```

### 3.2 依赖安装

```bash
# 安装所有依赖
flutter pub get

# 升级依赖
flutter pub upgrade

# 仅升级主要依赖
flutter pub upgrade --major-versions
```

### 3.3 代码生成

当前 `pubspec.yaml` 没有配置 `build_runner` / `json_serializable`。模型序列化以手写
`toJson()` / `fromJson()` 为主；除非后续重新加入代码生成依赖，否则不需要运行生成命令。

### 3.4 国际化配置

项目支持中文和英文：

```bash
# 生成本地化代码（如果使用 flutter_localizations）
flutter gen-l10n
```

---

## 4. 运行与调试

### 4.1 运行应用

```bash
# 列出可用设备
flutter devices

# 在指定设备运行
flutter run -d <device_id>

# 在 Chrome 运行
flutter run -d chrome

# 在 Windows 运行
flutter run -d windows

# 在 macOS 运行
flutter run -d macos

# 在 Linux 运行
flutter run -d linux
```

### 4.2 调试模式

```bash
# 调试模式运行（默认）
flutter run

# Profile 模式（性能分析）
flutter run --profile

# Release 模式
flutter run --release
```

### 4.3 热重载

运行时使用快捷键：
- `r` - 热重载
- `R` - 热重启
- `q` - 退出
- `d` - Detach

### 4.4 运行测试

```bash
# 运行所有测试
flutter test

# 运行指定测试文件
flutter test test/services/sync_service_test.dart

# 运行测试并生成覆盖率
flutter test --coverage

# 查看覆盖率报告
genhtml coverage/lcov.info -o coverage/html
```

### 4.5 静态分析

```bash
# 运行 Dart 分析
flutter analyze

# 检查代码格式
dart format --set-exit-if-changed .

# 修复格式问题
dart format .
```

---

## 5. 常见问题

### Q1: flutter doctor 显示 Android licenses 未接受

```bash
# 接受所有 Android 许可
flutter doctor --android-licenses
```

### Q2: iOS 编译失败

```bash
# 更新 CocoaPods
cd ios
pod repo update
pod install
cd ..
```

### Q3: Windows 编译找不到 Visual Studio

确保安装了 Visual Studio 并包含：
- "使用 C++ 的桌面开发" 工作负载
- Windows 10 SDK

### Q4: 依赖版本冲突

```bash
# 查看依赖树
flutter pub deps

# 强制解决冲突
flutter pub get --offline
```

### Q5: 热重载不生效

某些情况需要热重启 (`R`) 而不是热重载 (`r`)：
- 修改了 `main()` 函数
- 添加了新的全局变量
- 修改了枚举定义

### Q6: 测试运行缓慢

```bash
# 使用并行测试
flutter test --concurrency=4

# 使用持久测试运行器
flutter test -r
```

---

## 附录

### A. 常用命令速查

| 命令 | 说明 |
|------|------|
| `flutter create` | 创建新项目 |
| `flutter pub get` | 安装依赖 |
| `flutter run` | 运行应用 |
| `flutter test` | 运行测试 |
| `flutter build` | 构建应用 |
| `flutter clean` | 清理构建缓存 |
| `flutter upgrade` | 升级 Flutter |
| `flutter doctor` | 检查环境 |

### B. 环境变量

```bash
# Flutter SDK 路径
export FLUTTER_ROOT=/path/to/flutter

# Android SDK 路径
export ANDROID_SDK_ROOT=/path/to/android-sdk

# Pub cache 路径
export PUB_CACHE=/path/to/pub-cache
```

### C. VS Code launch.json

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Debug)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart"
    },
    {
      "name": "Flutter (Profile)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "flutterMode": "profile"
    },
    {
      "name": "Flutter (Release)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "flutterMode": "release"
    }
  ]
}
```

---

**文档版本**: 1.0
**最后更新**: 2026-04-27
