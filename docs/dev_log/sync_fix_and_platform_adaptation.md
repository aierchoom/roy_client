# 开发归档：同步系统修复与多平台适配记录 (2026-04-13)

## 1. 问题背景
在测试 SecretRoy 的零知识同步功能时，发现应用在 Windows 平台下存在严重的初始化死锁和崩溃现象，导致同步链路无法打通。

## 2. 核心挑战与解决路径

### 2.1 启动死锁 (UI Loading Deadlock)
- **现象**：当数据库自动解锁失败时，页面始终悬停在加载动画，不显示错误信息。
- **原因**：`UnlockView` 的 `_unlockWithNoPassword` 异步方法在抛出异常或逻辑失败时，未能正确将 `_isLoading` 设回 `false`。
- **修复**：在 `ServiceManager` 状态监测点增加了状态重置逻辑，确保错误信息能穿透加载层展示给用户。

### 2.2 Windows 数据库兼容性 (Plugin Missing implementation)
- **现象**：在 Windows 运行报错 `No implementation found for method openDatabase on channel ...sqflite_sqlcipher`。
- **原因**：`sqflite_sqlcipher` 仅支持移动端。桌面端（Windows）需要使用基于 `ffi` 的标准 SQLite。
- **方案**：
    - 引入 `sqflite_common_ffi` 兼容桌面端。
    - **平台分流策略**：在 `SecureStorageService` 中检测运行环境。移动端继续沿用 SQLCipher 的物理加锁；Windows 切换至 FFI 驱动，并配合 `EnhancedCryptoService` 实现**字段级 AES-256-GCM 加密**，确保数据资产安全。

### 2.3 `SyncService` 生命周期与 Late 初始化冲突
- **现象**：高频触发“锁定-解锁”循环或重启应用时，报错 `LateInitializationError: Field '_deviceId' has already been initialized`。
- **原因**：`late final` 变量不允许二次赋值，而应用生命周期变化（锁定后重新登录）会重走 `initialize()` 逻辑。
- **修复**：
    - 将 `_deviceId` 改为普通变量并增加幂等保护。
    - 在 `SyncService` 引入 `reset()` 机制，在 `ServiceManager` 锁定时主动清空敏感密钥对和缓存状态。

### 2.4 首次同步“无动作”逻辑修正
- **现象**：新库首次点击同步时，服务器反馈成功但无数据推送。
- **原因**：向量时钟在两端均为空 `{}` 时被 `compare` 函数判定为 `equal`（相等），从而触发了“无需同步”的分支。
- **修复**：在同步判断入口增加“边界探测”：如果 `ClockRelation.equal` 且本地有数据、服务器 Checkpoint 为 0，则判定为“首次冷启动同步”，强制触发推送逻辑。

## 3. 产出物
- **Windows 版**：修复了所有导致崩溃的插件调用，主链路已打通。
- **Android 版**：补全了 `INTERNET` 权限，生成了可用的 Release APK。
- **文档**：更新了同步白皮书与加密模型说明。

## 4. 后续建议
- 针对 iOS 平台，需要额外配置 `associated-domains` 权限以支持未来的通用链接同步（如有需求）。
- 定期清理 `sync_server` 的旧事件日志以保证查询性能。
