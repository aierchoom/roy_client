# 本地数据库二进制加密实现

**Last updated**: 2026-04-28

## 目标

SecretRoy 本地 vault 数据库现在不再以长期明文 SQLite 文件落盘。客户端在二进制文件层对 SQLite 数据库快照进行 AES-GCM-256 加密，长期保存文件为：

- `secret_roy_vault.db.enc`

旧的中间版本明文文件：

- `secret_roy_vault.db`

不再作为有效数据库兼容读取。初始化加密库后会清理该旧明文文件家族，避免旧中间态继续留在磁盘上。

## 加密边界

### 长期落盘

`SecureStorageService` 只把加密后的二进制信封写入应用文档目录。信封格式由 `DatabaseFileCipher` 管理：

- magic: `SROYDB`
- version: `1`
- nonce length
- MAC length
- nonce
- MAC
- ciphertext

加密算法：

- AES-GCM-256
- 每次写入使用随机 nonce
- AEAD MAC 用于解密前完整性校验

### 运行时工作库

SQLite 仍需要真实 SQLite 文件才能被 `sqflite` / `sqflite_common_ffi` 打开。解锁后，客户端会把 `.db.enc` 解密到临时目录中的运行时工作库：

- `secret_roy_vault.runtime.db`

锁定、关闭或重置时，工作库及其 SQLite sidecar 文件会被删除。每次本地写操作后都会重新加密当前工作库快照并原子替换 `.db.enc`。

这意味着：

- 离线拷贝长期数据库文件只能拿到密文。
- App 解锁运行期间，临时目录存在运行时明文工作库；主动驻留在同一设备上的恶意程序仍属于更强威胁模型，需要依赖系统沙盒、磁盘权限和运行时防护。

## 密钥来源

数据库文件密钥不再由主密码直接派生。客户端首次解锁时会生成一个随机 32-byte DB 数据密钥，并把它作为 `database_file_key_envelope_v1` 保存到 secure storage 中。该 envelope 本身使用主密码派生出的包装密钥加密。

`EnhancedCryptoService` 在主密码校验通过后：

1. 读取或创建 `database_key_salt_v1`。
2. 用 PBKDF2-HMAC-SHA256 从主密码派生 256-bit 包装密钥。
3. 解开或创建随机 DB 数据密钥 envelope。
4. 用解出的 DB 数据密钥创建 `DatabaseFileCipher` 并交给 `SecureStorageService`。

相关 secure storage 元数据：

- `database_key_salt_v1`: 包装密钥 KDF salt。
- `database_file_key_envelope_v1`: 当前随机 DB 数据密钥 envelope。
- `database_file_key_envelope_previous_v1`: 主密码变更期间的回退 envelope，用于应对 verifier 与 envelope 更新之间的中断窗口。

解锁顺序现在是：

1. 初始化 identity。
2. 校验或创建主密码 PBKDF2 verifier。
3. 派生包装密钥并解开随机 DB 数据密钥。
4. 初始化并解封本地数据库。
5. 初始化同步服务。

密码错误时不会打开数据库文件。

## 写入与关闭策略

以下操作会在 SQLite 写入完成后触发加密快照持久化：

- `clearAllData`
- `saveAccount`
- `deleteAccount`
- `saveConflictLogs`
- `deleteConflictLog`
- `saveTemplate`
- `deleteTemplate`
- `setSetting`
- `replaceDatabase`

关闭或锁定时：

1. SQLite checkpoint。
2. 关闭 DB 连接。
3. 加密当前 runtime DB。
4. 删除 runtime DB、journal、WAL、SHM、tmp、bak 文件。
5. 清理内存中的 DB cipher。

## 主密码变更

`changeMasterPassword(...)` 成功后不会更换 DB 数据密钥，也不会因为改主密码而重加密整个 SQLite 快照。它会：

1. 用旧主密码解开当前随机 DB 数据密钥。
2. 把当前 envelope 复制到 `database_file_key_envelope_previous_v1`。
3. 用新主密码派生的新包装密钥重包同一个 DB 数据密钥。
4. 更新主密码 verifier。
5. 用新主密码重新解锁并清理 previous envelope。

这样可以把“密码变更”收敛为一次小型密钥重包操作，避免对弱设备做全库重加密，同时保留中断恢复路径。`SecureStorageService.rotateDatabaseCipher(...)` 仍会刷新当前数据库快照，但底层 DB 数据密钥保持稳定。

无密码模式仍然会得到一个随机 DB 数据密钥；这个数据密钥由空密码派生出的包装密钥保护。它可以防止单独拷贝 `.db.enc` 后直接读取，但安全强度显著依赖设备本身和 secure storage 元数据保护。

## 测试覆盖

新增测试覆盖：

- `test/services/database_file_cipher_test.dart`
  - 加密/解密往返
  - 错误密钥拒绝解密
  - 畸形信封拒绝解密
- `test/services/database_file_key_manager_test.dart`
  - 随机 DB 数据密钥在主密码变更后保持稳定
  - DB 数据密钥 envelope 会用新主密码派生的包装密钥重包
  - primary envelope 损坏时可从 previous envelope 恢复并自愈
- `test/services/secure_storage_service_encryption_test.dart`
  - 保存后长期落盘为 `.db.enc`
  - 密文中不包含敏感明文
  - 关闭后删除 runtime 明文工作库
  - 重新解锁后可从 `.db.enc` 恢复账号数据

## 仍需注意

- 本实现是 SQLite 外层二进制信封加密，不是 SQLCipher 页面级加密。
- 运行时解锁状态下存在临时明文 SQLite 工作库。
- 同步 payload 的协议级加密与认证仍以 `docs/security/key-sync-implementation.md` 为准。
- 服务端认证、生产传输安全、证书固定和完整备份恢复仍是后续安全/运维工作。
