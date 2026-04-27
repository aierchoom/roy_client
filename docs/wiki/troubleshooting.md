# 故障排除指南

**版本**: v1.1.0
**最后更新**: 2026-04-28

---

## 目录

1. [常见问题](#1-常见问题)
2. [同步问题](#2-同步问题)
3. [加密与安全](#3-加密与安全)
4. [平台特定问题](#4-平台特定问题)
5. [性能问题](#5-性能问题)
6. [日志与调试](#6-日志与调试)

---

## 1. 常见问题

### 1.1 应用无法启动

**症状**: 点击应用图标后闪退或无响应

**排查步骤**:

1. 检查系统版本兼容性
2. 清除应用数据
3. 重新安装应用

**Android**:
```bash
adb logcat | grep -i flutter
```

**iOS**:
```bash
# 在 Xcode 中查看日志
```

**桌面端**:
```bash
# 从命令行运行查看日志
flutter run -d windows
```

### 1.2 数据丢失

**可能原因**:
- 应用数据被清除
- 主密码遗忘
- 存储文件损坏

**解决方案**:
1. 检查是否有备份
2. 尝试从同步服务器恢复
3. 检查 Vault 文件完整性

### 1.3 界面显示异常

**症状**: UI 元素错位、文字溢出、颜色异常

**排查**:
1. 检查系统字体设置
2. 切换深色/浅色模式
3. 检查屏幕缩放设置

---

## 2. 同步问题

### 2.1 无法连接服务器

**错误信息**: `Connection refused`, `Timeout`, `Network unreachable`

**排查步骤**:

```
1. 检查服务器地址格式
   ✓ https://sync.example.com
   ✓ http://192.168.1.100:8080
   ✗ sync.example.com (缺少协议)
   ✗ http://localhost:8080 (手机端不可用)

2. 检查网络连接
   - ping 服务器地址
   - 检查防火墙设置

3. 检查服务器状态
   - 确认服务器正在运行
   - 检查服务器日志
```

**手机端特殊问题**:

手机端不能使用 `localhost` 或 `127.0.0.1`，请使用：
- 电脑的局域网 IP（如 `192.168.1.100`）
- 确保手机和电脑在同一局域网

### 2.2 同步状态一直显示 "同步中"

**可能原因**:
- 同步服务挂起
- 网络不稳定
- 大量数据同步

**解决方案**:
1. 点击"取消同步"
2. 重新触发同步
3. 检查网络稳定性

### 2.3 同步冲突

**症状**: 账户显示冲突标记，需要人工审阅

**处理方式**:
1. 进入冲突收件箱
2. 查看冲突详情
3. 选择保留的版本
4. 确认解决

**冲突原因**:
- 多设备同时修改同一账户
- 离线编辑后同步
- 网络延迟导致版本不一致

### 2.4 服务器存储错误

**错误信息**: `vault file is unreadable`, `failed to persist vault`

**排查**:

服务端问题：
```
1. 检查 vault 文件权限
   ls -la /path/to/vault.json

2. 检查磁盘空间
   df -h

3. 检查文件格式
   cat vault.json | jq .

4. 检查服务器日志
   tail -f /var/log/secretroy/error.log
```

客户端处理：
- 等待一段时间后重试
- 联系服务器管理员
- 尝试其他同步方式

### 2.5 局域网配对失败

**症状**: 无法发现设备、配对码无效

**排查**:
1. 确保设备在同一局域网
2. 检查防火墙是否阻止 UDP 广播
3. 确认配对码正确（8 位可读字符，允许字母和 2-9）
4. 检查是否有其他应用占用端口

**端口要求**:
- UDP 广播: 37677
- HTTP 服务: 动态分配

---

## 3. 加密与安全

### 3.1 忘记主密码

**现状**: 主密码无法找回

**预防措施**:
- 设置密码提示
- 使用密码管理器存储
- 定期导出备份

**数据恢复**:
- 如果有未锁定的设备，立即导出数据
- 重置应用并重新创建 Vault

### 3.2 生物识别失败

**症状**: 指纹/面容识别不工作

**排查**:
1. 检查系统生物识别设置
2. 重新录入生物特征
3. 使用主密码解锁

**Android 特定**:
- 检查是否添加了指纹
- 检查应用权限

**iOS 特定**:
- 检查 Face ID 权限设置

### 3.3 加密数据无法解密

**错误信息**: `Decryption failed`, `Invalid HMAC`

**可能原因**:
- 主密码错误
- 数据损坏
- 版本不兼容

**解决方案**:
1. 确认主密码正确
2. 尝试在其他设备解密
3. 从备份恢复

---

## 4. 平台特定问题

### 4.1 Android

#### 应用崩溃

```bash
# 获取崩溃日志
adb logcat -d | grep -i flutter > crash.log

# 检查内存使用
adb shell dumpsys meminfo <package_name>
```

#### 存储权限

Android 11+ 需要在应用内请求存储权限：
1. 设置 → 应用 → SecretRoy → 权限
2. 启用存储权限

#### 通知不显示

1. 检查通知权限
2. 检查省电模式设置
3. 关闭应用自适应电池

### 4.2 iOS

#### Keychain 问题

如果 Keychain 数据损坏：
1. 设置 → 通用 → 传输或还原 iPhone → 抹掉所有内容和设置
2. 重新安装应用

#### iCloud 同步冲突

如果使用 iCloud 同步：
1. 检查 iCloud 存储空间
2. 确保登录正确的 Apple ID
3. 尝试关闭再开启 iCloud 同步

### 4.3 Windows

#### 安装失败

1. 检查是否有杀毒软件阻止
2. 以管理员权限运行安装程序
3. 检查系统版本（Windows 10+）

#### 启动失败

```powershell
# 检查依赖
where flutter
where dart

# 清理并重新构建
flutter clean
flutter pub get
flutter build windows
```

### 4.4 macOS

#### 无法打开应用

1. 系统偏好设置 → 安全性与隐私 → 允许从以下位置下载的应用
2. 右键点击应用 → 打开

#### Keychain 访问问题

1. 打开钥匙串访问
2. 找到 SecretRoy 相关条目
3. 检查访问权限

### 4.5 Linux

#### 依赖缺失

```bash
# Ubuntu/Debian
sudo apt-get install \
  libgtk-3-0 liblzma5 libstdc++6

# 如果使用 Snap
snap install secretroy
```

#### 权限问题

```bash
# 检查文件权限
ls -la ~/.config/secretroy/

# 修复权限
chmod -R u+rw ~/.config/secretroy/
```

---

## 5. 性能问题

### 5.1 应用启动慢

**优化措施**:
1. 减少启动时加载的数据量
2. 清理旧的同步历史
3. 检查设备存储空间

### 5.2 同步速度慢

**影响因素**:
- 数据量大小
- 网络延迟
- 服务器性能

**优化建议**:
1. 使用局域网同步
2. 定期清理无用账户
3. 选择更近的服务器

### 5.3 内存占用高

**排查**:
```bash
# Android
adb shell dumpsys meminfo <package>

# iOS (Xcode)
Debug Navigator → Memory
```

**优化**:
1. 关闭不使用的视图
2. 定期清理缓存
3. 重启应用

---

## 6. 日志与调试

### 6.1 启用调试模式

**移动端**:
```dart
// 在 main.dart 中
void main() {
  debugPrint('Debug mode enabled');
  runApp(MyApp());
}
```

**查看日志**:
```bash
# Android/iOS
flutter logs

# 或使用 adb
adb logcat | grep -i flutter
```

### 6.2 同步日志

同步服务会输出详细日志：

```
[Sync] Initialized. Vault: vault_xxx, Version: 0
[Sync] >>> Pull Phase Start (Vault: vault_xxx, Since: 0)
[Sync] Received 0 items. Server Max Version: 0
[Sync] <<< Pull Phase Completed. Processed: 0, Version: 0
[Sync] >>> Push Phase Start. Items to push: 1
[Sync] <<< Push Phase Completed. Success items: 1
```

**日志级别**:
- `>>>` 开始操作
- `<<<` 操作完成
- `Error:` 错误信息
- `Warning:` 警告信息

### 6.3 CRDT 合并日志

```
[CRDT] Merging local vault (5 accounts) with remote (3 accounts)
[CRDT] Conflict detected: account_123.name
  - Local:  "Account A" (HLC: 1714205400123-0-device_a)
  - Remote: "Account B" (HLC: 1714205400456-0-device_b)
[CRDT] Winner: Remote (newer HLC)
```

### 6.4 错误代码参考

| 错误代码 | 含义 | 解决方案 |
|----------|------|----------|
| `E001` | 网络连接失败 | 检查网络 |
| `E002` | 服务器不可达 | 检查服务器地址 |
| `E003` | 认证失败 | 重新配对 |
| `E004` | 数据解密失败 | 检查主密码 |
| `E005` | 存储写入失败 | 检查存储空间 |
| `E006` | 版本不兼容 | 升级应用 |

---

## 附录

### A. 常用诊断命令

```bash
# 检查 Flutter 环境
flutter doctor -v

# 检查设备连接
flutter devices

# 查看应用日志
flutter logs

# 清理构建缓存
flutter clean

# 重新获取依赖
flutter pub get
```

### B. 重置应用

**移动端**:
1. 设置 → 应用 → SecretRoy → 存储 → 清除数据
2. 卸载并重新安装

**桌面端**:
1. 删除配置目录
   - Windows: `%APPDATA%\secretroy\`
   - macOS: `~/Library/Application Support/secretroy/`
   - Linux: `~/.config/secretroy/`
2. 重新安装

### C. 获取支持

1. 查看本文档
2. 搜索 GitHub Issues
3. 提交新 Issue（附日志）

**提交 Issue 模板**:
```
**环境信息**:
- 应用版本:
- 平台:
- 系统版本:

**问题描述**:


**复现步骤**:
1.
2.
3.

**日志输出**:
```

---

**文档版本**: 1.0
**最后更新**: 2026-04-28
