# 本地密钥数据链接质量收敛报告

| 项目 | 内容 |
|---|---|
| 状态 | 已收敛 |
| 日期 | 2026-04-29 |
| 范围 | 服务器中转配对、面对面链接、LAN 直连加固、导入一致性、恢复路线入口文案、恢复路线文档 |

## 目标

对本轮本地密钥数据链接相关迭代做一次整体质量收敛，确认实现、测试、产品文案和风险口径已经对齐，重点避免服务器读取 vault 密钥包、LAN 配对窗口外可领取密钥包、误覆盖本地数据和用户误用内部兼容码。

## 收敛矩阵

| 优先级 | 功能点 | 收敛结论 | 主要证据 |
|---|---|---|---|
| P0 | 服务器中转配对改为接收端公钥加密 | 通过 | 新设备 join 提交 `requester_public_key`；旧设备 approve 使用 `VaultPairingCrypto.encryptBundle()` 生成 `sroy-pairing:`；服务端 approve 拒绝 `sroy-link:` 明文包；新设备用本地临时私钥解密后导入 |
| P1 | 面对面链接收口为 8 位临时配对码 | 通过 | `LanPairingService` 默认生成 8 位可读码；host 只在打开配对码窗口期间存在；成功领取、关闭、超时或停止后销毁 hosted bundle；设置页不再突出原始链接码入口 |
| P1 | LAN 直连配对加固 | 通过 | LAN TTL 默认 3 分钟；成功领取后一次性销毁；错误码次数达到上限后停止；广播不包含配对码；UI 在打开和加入前提示可信局域网；claim 必须携带临时公钥并只接收 `wrapped_transfer_code` |
| P1 | 导入一致性保护 | 通过 | `ServiceManager` 导入前先 preview 和验证 dump；非 clean device 必须 `forceOverwrite`；dump 导入失败会抛错；失败时回滚已写入的 vault identity |
| P2 | 恢复路线入口和文案整理 | 通过 | 设置页区分面对面链接、远程配对、离线恢复码、内部兼容码；内部 `sroy-link:` 只作为承载格式说明，不作为普通恢复入口 |
| P2 | 文档同步更新 | 通过 | `docs/sync/vault-recovery-routes.md` 和安全文档记录每条恢复路线、风险等级、适用场景、验收方式；协议前缀统一为 `sroy-link:`、`sroy-recovery:`、`sroy-pairing:` |

## 残留扫描

已扫描客户端 `lib/test/docs` 和服务端 `system/test`：

- 未发现旧的 secure/link/pairing 带版本协议前缀。
- 未发现“旧恢复码兼容导入”类残留口径。
- 仅保留一处“这不是 6 位数字码”的纠偏说明，作为防止旧文档误读的风险提示。
- 服务端没有 `transfer_code` 明文字段，只保存和返回 `wrapped_vault_bundle`。
- LAN claim 缺少 `requester_public_key` 时拒绝请求，不再回退明文 `transfer_code`。
- 远程配对 bundle 成功领取后服务端删除 pairing session 和密文 bundle。

## 验证

- `dart analyze lib test`：通过，无问题。
- `flutter test --reporter expanded --timeout 30s`：通过，`61 passed, 1 skipped`。
- `node --test`：通过，`28 passed`。

跳过项说明：

- `test/sync/lan_pairing_service_test.dart` 中 UDP 广播发现用例在 Windows 测试运行器中标记为 skipped；LAN 直接 claim、一次性领取、加密返回、TTL 和错误次数限制仍由同文件其他用例覆盖。

## 风险说明

- LAN claim 仍是本地 HTTP，不是 TLS；面对面和家庭/办公可信局域网可接受，公共 Wi-Fi 不建议使用，UI 已提示；claim payload 已强制走临时公钥加密。
- 服务器中转配对仍暴露会话元数据、设备 ID、公钥和密文包；当前目标是服务器不能读取 vault 密钥材料，而不是隐藏所有元数据。
- `sroy-link:` 仍是 bearer secret；它只应存在于 LAN 或远程配对的外层保护流程内部，不应变成用户手动复制保存的入口。
- 远程配对码 TTL 仍按服务器配对会话配置控制，和 LAN 直连 3 分钟 TTL 是两条不同链路。

## 后续建议

- 给 LAN 和远程配对补充端到端手工测试记录，覆盖两台真实设备或模拟两进程环境。
- 如需提升远程配对的可恢复性，可在 UI 层明确说明 bundle 一次性领取失败后需要重新配对。
