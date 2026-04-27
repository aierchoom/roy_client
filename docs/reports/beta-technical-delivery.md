# SecretRoy Beta 技术交付文档

更新日期：2026-04-19

## 1. 交付目标

本次交付目标不是把项目包装成“已完成产品”，而是把它从开发原型收敛到一个**更适合功能性 Beta 测试**的状态，重点控制以下四类风险：

- 代码质量收敛
- 文件与数据安全
- 程序执行稳定性
- 误删文件、数据损坏、程序崩溃风险

## 2. 本次实际交付内容

### 客户端

已修改模块：

- `roy_client/lib/services/enhanced_crypto_service.dart`
- `roy_client/lib/services/identity_service.dart`
- `roy_client/lib/services/secure_storage_service.dart`
- `roy_client/lib/services/service_manager.dart`
- `roy_client/lib/sync/sync_service.dart`
- `roy_client/lib/services/biometric_auth_service.dart`
- `roy_client/lib/views/security_settings_view.dart`

新增测试：

- `roy_client/test/sync/crdt_merge_engine_test.dart`

### 服务端

已修改模块：

- `roy_server/index.js`
- `roy_server/package.json`

新增测试：

- `roy_server/test/index.test.js`

### 文档

新增交付文档：

- `docs/security/beta-risk-register.md`
- `docs/reports/beta-technical-delivery.md`

## 3. 关键改动说明

### 3.1 解锁链路收敛

处理内容：

- 主密码不再是“任意输入都能解锁”
- 生物识别与密码解锁统一到同一条内部解锁流程
- 启用生物识别前会校验当前输入的主密码

价值：

- 解决了“表面有锁、实际没校验”的伪安全问题
- 修复了生物识别在状态机里自锁死的问题

说明：

- 当前仍然不是安全级密码学实现，只是把解锁流程从“失效”修到“可用”

### 3.2 本地数据库容灾改造

处理内容：

- 打开数据库失败时不再直接删库
- 自动保留损坏副本，供后续人工恢复
- 替换数据库文件时改为 temp/backup/rename 流程

价值：

- 显著降低因为偶发异常、损坏或迁移失败导致的直接丢数风险

### 3.3 同步删除与冲突收敛

处理内容：

- 增加“待同步账户”查询
- pull 阶段可读取含 tombstone 的本地记录
- push 阶段会把删除记录一起推送
- 增加 conflict merge 的自动化测试

价值：

- 修复最容易产生“删不干净、远端复活、跨设备不一致”的 Beta 级数据风险

### 3.4 身份隔离

处理内容：

- 新安装实例不再默认使用同一组固定测试 vault/key
- 默认生成独立 mock identity

价值：

- 避免多个新安装实例无意间写到同一个共享 vault

注意：

- 历史开发环境若已经写入旧固定值，不会自动迁移，Beta 前建议清理旧测试数据

### 3.5 服务端写入安全与可测试性

处理内容：

- 为 push 请求增加结构校验、重复项校验、大小限制
- JSON vault 保存改为原子写
- 增加 `/healthz`
- 服务端代码改为可导出函数，支持自动化测试

价值：

- 降低非法请求、脏写、半写入导致的数据损坏概率
- 为后续持续回归提供最基础的自动验证能力

## 4. 验证结果

### 静态检查

客户端：

- 已运行 Dart analyze
- 结果：`No issues found`

### 自动化测试

客户端：

- 已运行 `flutter test test/sync/crdt_merge_engine_test.dart`
- 结果：`All tests passed`

服务端：

- 已运行 `node --test`
- 结果：3 条测试全部通过

## 5. 当前 Beta 判定

### 功能 Beta

判定：**可进入**

适用范围：

- 内部测试
- 单人使用
- 受控环境下的同步验证
- CRUD、模板、删除、冲突、同步流程测试

### 安全 Beta / 外部公测

判定：**暂不建议进入**

阻塞原因：

- 本地数据库未真正加密
- 同步 payload 未真正加密
- 服务端未做认证授权
- 主密码方案仍是过渡实现，不符合密码管理器产品要求

## 6. 推荐的下一阶段工作

### 第一优先级

- 把 `EnhancedCryptoService` 从 mock 过渡到真实 KDF + 加密实现
- 禁止服务端在无认证状态下读写 vault
- 统一切到 HTTPS/TLS

### 第二优先级

- 为旧共享测试 Vault 提供一次性迁移或重置指引
- 增加客户端服务层与同步链路的集成测试
- 增加损坏数据库恢复与回滚测试

### 第三优先级

- 清理未使用依赖
- 整理已有历史文档中的乱码与过时描述
- 为 Beta 测试补齐安装、回滚与数据恢复 SOP

## 7. 交付结论

本次交付已经把项目中最容易导致真实事故的几处代码风险收敛到一个明显更稳的水平，特别是在以下方面取得了实质性改善：

- 不再自动删库
- 删除同步不再漏推
- 生物识别解锁恢复可用
- 新安装实例默认隔离
- 服务端写入从“直接覆盖”提升到“原子落盘”

但从产品属性上看，这个项目目前仍更适合被定义为：

**“可做功能性 Beta 测试的本地优先密码库原型”**

而不是：

**“可对外发布的安全密码管理器 Beta”**
