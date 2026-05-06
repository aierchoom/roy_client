# SecretRoy 业务说明文档

**版本**: v1.0.0
**最后更新**: 2026-05-06
**适用对象**: 产品经理、开发者、测试、运营

---

## 1. 产品定位

SecretRoy 是一款**本地优先的个人敏感信息保险库**。核心承诺是：

> "你的数据首先属于你自己，保存在你自己的设备上，加密后可选同步到你自有的其他设备。"

### 1.1 价值主张

| 用户痛点 | SecretRoy 的解法 |
|---|---|
| 不信任云端密码管理器 | 本地加密 SQLite，主密码只有用户知道 |
| 多设备密码不同步 | 自托管同步服务器，端到端加密传输 |
| 误删/改密码后无法恢复 | CRDT 冲突日志 + 本地审阅队列 |
| 2FA 分散在各 Authenticator 里 | 独立 TOTP 凭据，与账号模板关联 |
| 换设备迁移痛苦 | 面对面链接 / 离线恢复码 / 远程配对 |

### 1.2 明确不做

- 不做企业管理员控制台、团队共享、SSO
- 不做云端托管账号系统
- 不做浏览器自动填充插件（当前阶段）
- 不做暗网监控、密码泄露查询

---

## 2. 核心业务流程

### 2.1 解锁与 Session 生命周期

用户每次打开应用，必须先解锁才能访问保险库。

```mermaid
flowchart TD
    A[用户打开 App] --> B{本地是否有加密数据库?}
    B -->|否| C[首次启动向导<br/>创建主密码]
    B -->|是| D[解锁页面]
    D --> E{用户选择解锁方式}
    E -->|主密码| F[PBKDF2 校验]
    E -->|生物识别| G[读取加密存储的主密码<br/>AES-256-GCM 解密]
    E -->|无密码模式| H[空密码直接解锁]
    F --> I{校验通过?}
    G --> I
    H --> I
    I -->|否| J[提示错误，留在解锁页]
    I -->|是| K[解封数据库文件密钥]
    K --> L[解密临时 runtime SQLite]
    L --> M[加载账号/模板/同步状态]
    M --> N[进入首页]
    N --> O{自动锁定计时器}
    O -->|超时或手动锁定| P[关闭 runtime DB<br/>清理内存明文]
    P --> D
```

**关键业务规则**:
- 解锁期间，数据库以明文形式存在于临时文件 `secret_roy_vault.runtime.db`。
- 锁定或应用退后台超时时，必须删除该临时文件。
- 生物识别只解锁设备本地的加密主密码副本，不替代主密码本身。
- 无密码模式自动禁用生物识别（因为空密码 + 生物识别 = 零安全）。

---

### 2.2 账号创建与本地审阅

SecretRoy 的核心差异点：**保存账号后不会自动推送到服务器**，而是进入本地审阅队列，由用户确认后才允许同步。

```mermaid
flowchart TD
    A[用户点击 + 新建账号] --> B[选择模板，填写字段]
    B --> C[点击保存]
    C --> D[写入加密本地数据库]
    D --> E{用户是否开启同步?}
    E -->|否| F[结束，纯本地账号]
    E -->|是| G[生成 LocalSyncChange 记录<br/>状态: pendingReview]
    G --> H[首页待同步卡片展示该变更]
    H --> I{用户操作}
    I -->|点击推送| J[状态改为 approved]
    I -->|点击撤销| K[删除本地变更和 outbox<br/>回滚账号状态]
    I -->|不做任何事| L[保持 pendingReview<br/>不自动推送]
    J --> M[下次同步时进入 push phase]
```

**关键业务规则**:
- `create -> delete`: 直接取消 outbox，删除本地草稿，不留下痕迹。
- `update -> update`: 合并为一条 update，保留最早的 `before` 快照。
- `update -> delete`: 转为 delete，保留最早的 `before` 快照。
- 启动同步、周期同步、手动同步**都不能绕过** `pendingReview` 状态。

---

### 2.3 多设备同步与冲突处理

同步采用 **Pull -> Merge -> Push** 三段式，服务端仅作为无状态密文中转站。

```mermaid
flowchart TD
    subgraph 客户端A
        A1[用户编辑账号X<br/>状态: pendingReview] --> A2[用户批准推送]
        A2 --> A3[SyncService.push<br/>携带 expected_base_version]
    end

    subgraph 服务端
        S1[接收 push 请求] --> S2{version 匹配?}
        S2 -->|是| S3[接受变更<br/>version + 1]
        S2 -->|否| S4[返回 409 Conflict<br/>携带冲突类型]
    end

    subgraph 客户端B
        B1[用户编辑同一账号X] --> B2[尝试 push]
        B2 --> S1
        S4 --> B3[收到 409]
        B3 --> B4[重新 pull 远端最新版本]
        B4 --> B5[CrdtMergeEngine 字段级合并]
        B5 --> B6{是否有同一字段冲突?}
        B6 -->|否| B7[自动合并<br/>状态: pendingPush]
        B6 -->|是| B8[自动合并 + 生成 ConflictLog<br/>状态: conflict]
        B8 --> B9[冲突箱展示<br/>用户可手动 restore]
    end

    A3 --> S1
```

**冲突类型与处理策略**:

| 冲突类型 | 触发场景 | 自动处理 | 用户可见 |
|---|---|---|---|
| `remote_missing` | 推送时远端记录已被删除 | 生成冲突记录，用户选择覆盖远端或接受删除 | 冲突箱 |
| `stale_base_version` | 本地 base version 落后于远端 | 重新 pull + CRDT merge | 仅当字段冲突时进冲突箱 |
| `concurrent_edit` | 多设备同时编辑同一记录 | 字段级 HLC 合并，冲突字段进 conflict log | 冲突箱（若同一字段） |
| `concurrent_delete` | 一方删除，一方编辑 | Tombstone 优先：删除 HLC 大者胜出 | Toast 提示 |
| `invalid_payload` | payload 被篡改或格式错误 | 同步失败，进入 protocolError | 同步设置页错误状态 |

---

### 2.4 TOTP 2FA 全流程

TOTP 在 SecretRoy 中是**独立加密对象**，不与账号字段耦合，通过模板字段建立关联。

```mermaid
flowchart TD
    subgraph 导入
        I1[用户获取 TOTP 来源] --> I2{来源类型}
        I2 -->|手机扫码| I3[mobile_scanner 相机扫码]
        I2 -->|桌面粘贴图片| I4[pasteboard + zxing2 解码]
        I2 -->|otpauth URI 文本| I5[直接解析文本]
        I3 --> I6[解析 otpauth:// 参数]
        I4 --> I6
        I5 --> I6
        I6 --> I7[创建 TotpCredential<br/>存入加密 totp_credentials 表]
    end

    subgraph 关联
        L1[用户编辑账号] --> L2[模板含 2FA 字段]
        L2 --> L3[展示关联 2FA 面板]
        L3 --> L4{用户操作}
        L4 -->|选择已有| L5[建立 linkedAccountIds 关联]
        L4 -->|新建| L6[跳转新建 TOTP 流程]
        L4 -->|取消关联| L7[移除 linkedAccountIds]
    end

    subgraph 使用
        U1[首页账号列表] --> U2{账号是否关联 TOTP?}
        U2 -->|是| U3[列表显示 2FA 已配置图标]
        U2 -->|否| U4[不显示]
        U3 --> U5[用户进入 2FA 标签页]
        U5 --> U6[TotpService.generateCode]
        U6 --> U7[显示 6 位验证码 + 倒计时]
        U7 --> U8[用户点击复制]
        U8 --> U9[SensitiveClipboardService.copy<br/>45秒后自动清理]
    end

    subgraph 同步
        Y1[账号或 TOTP 变更] --> Y2[进入 local_sync_changes outbox]
        Y2 --> Y3[用户批准后 push]
        Y3 --> Y4[SyncPayloadCodec 加密为 sroy-sync: AEAD]
        Y4 --> Y5[服务端只存密文]
        Y5 --> Y6[其他设备 pull 后解密并合并]
    end
```

**关键业务规则**:
- TOTP secret **绝不**进入账号 `data` 字段、搜索摘要、账号列表明文或服务端明文。
- 未审阅的 TOTP credential **不会自动 push**。
- 删除账号**不会级联删除**关联的 TOTP credential（独立对象）。
- TOTP 凭据冲突走独立的 `TotpCredentialMergeEngine`，字段级 HLC 合并。

---

### 2.5 设备配对与密钥恢复

新设备加入已有 Vault 时，必须安全地传递 `vaultId` + `privateKey` + `symmetricKey` + `vaultApiToken`，同时保留新设备独立的 `deviceId`。

```mermaid
flowchart TD
    subgraph 面对面链接
        F1[主机设备: 设置 -> 数据同步<br/>点击显示临时码] --> F2[生成 8 位可读码<br/>+ UDP 广播本机 endpoint]
        F2 --> F3[主机展示弹窗，等待领取]
        F3 --> F4[加入设备: 输入 8 位码]
        F4 --> F5[HTTP claim + 发送临时公钥]
        F5 --> F6[主机用临时公钥加密<br/>vault identity payload]
        F6 --> F7[加入设备解密并导入]
        F7 --> F8[生成新 deviceId<br/>保留原 vaultId]
    end

    subgraph 远程配对
        R1[已有设备创建配对会话] --> R2[服务端生成会话<br/>显示配对码]
        R2 --> R3[新设备输入配对码<br/>提交加入请求]
        R3 --> R4[已有设备收到请求<br/>手动批准]
        R4 --> R5[服务端用 X25519 + AES-GCM<br/>加密返回 pairing bundle]
        R5 --> R6[新设备解密 bundle<br/>导入 vault identity]
    end

    subgraph 离线恢复码
        O1[已有设备导出] --> O2[sroy-recovery: 格式<br/>PBKDF2 + AES-GCM-256 + zlib]
        O2 --> O3[用户保存恢复码和恢复密码<br/>分开放置]
        O3 --> O4[新设备导入恢复码]
        O4 --> O5[输入恢复密码解密]
        O5 --> O6[预览并确认覆盖]
        O6 --> O7[导入 vault identity]
    end
```

**关键业务规则**:
- 密钥同步**只共享 vault 身份**，接收设备保留自己的 `deviceId`。
- `sroy-link:` 是内部兼容码，**不作为普通用户恢复入口**。
- 导入前必须**预览**（显示账号数、模板数、vaultId），用户确认覆盖后才写入。
- 新 vault 首次连接服务器时自动获得 `vaultApiToken`，后续同步必须携带 `X-Vault-Token`。

---

### 2.6 备份、恢复与导入

```mermaid
flowchart TD
    subgraph 加密导出
        E1[用户触发导出] --> E2[VaultDumpCoordinator 打包]
        E2 --> E3[包含: 账号 + 模板 + vault identity]
        E3 --> E4[用户输入导出密码]
        E4 --> E5[PBKDF2 派生密钥<br/>AES-GCM-256 加密]
        E5 --> E6[生成加密文件或二维码]
    end

    subgraph 导入/恢复
        I1[用户选择导入来源] --> I2{来源类型}
        I2 -->|加密 dump| I3[输入导出密码解密]
        I2 -->|配对导入| I4[面对面/远程配对]
        I2 -->|CSV| I5[解析并映射字段]
        I3 --> I6[预览导入内容]
        I4 --> I6
        I5 --> I6
        I6 --> I7{是否覆盖当前?}
        I7 -->|是| I8[替换本地数据]
        I7 -->|否| I9[取消导入]
        I8 --> I10[生成 local_sync_changes outbox<br/>状态: pendingReview]
        I10 --> I11[用户需在首页审阅后推送]
    end
```

**关键业务规则**:
- 导入后**不自动标记为 synchronized**，而是进入 outbox 审阅队列。
- 覆盖前必须明确确认，禁止半成功状态。
- 加密 dump 的导出密码**独立于主密码**，用户可自选。

---

## 3. 用户旅程地图

### 3.1 新用户首次启动

| 阶段 | 用户行为 | 系统响应 | 业务目标 |
|---|---|---|---|
| 发现 | 搜索/推荐了解到 SecretRoy | 展示"本地优先"价值 | 建立信任心智 |
| 安装 | 下载并打开 App | 检测是否首次启动 | - |
| 创建 | 设置主密码 | PBKDF2 派生，创建加密数据库 | 安全基底 |
| 首增 | 添加第一个账号 | 使用网站模板，快速保存 | 激活价值 |
| 探索 | 浏览设置、模板、安全页 | 展示生物识别、自动锁定、同步选项 | 功能发现 |
| 留存 | 日常查看/复制密码 | 快速解锁、敏感剪贴板自动清理 | 习惯养成 |

### 3.2 多设备用户同步旅程

| 阶段 | 用户行为 | 系统响应 | 业务目标 |
|---|---|---|---|
| 认知 | 意识到需要在第二台设备使用 | 设置页展示配对选项 | 功能发现 |
| 选择 | 判断网络环境 | 局域网 -> 面对面链接；异地 -> 远程配对 | 降低门槛 |
| 执行 | 按步骤完成配对 | 安全传递 vault identity，保留 deviceId | 安全连接 |
| 验证 | 第二台设备执行首次同步 | pull 远端数据，解密，合并 | 数据一致性 |
| 日常 | 双设备编辑 | outbox 审阅 + CRDT 合并 + 冲突箱 | 无缝协作 |

---

## 4. 关键业务指标（建议）

| 指标 | 定义 | 目标值 |
|---|---|---|
| 解锁成功率 | 用户输入主密码/生物识别后成功进入首页的比例 | > 99.5% |
| 同步冲突率 | 每次同步触发冲突恢复的比例 | < 5% |
| outbox 积压率 | pendingReview 超过 7 天未处理的比例 | < 10% |
| TOTP 导入成功率 | 扫码/粘贴/文本导入成功创建凭据的比例 | > 95% |
| 配对完成率 | 开始配对流程到成功导入 identity 的比例 | > 90% |
| 主密码遗忘率 | 用户因忘记主密码而重置/丢失数据的比例 | 无法直接统计，依赖用户反馈 |

---

## 5. 附录：术语表

| 术语 | 说明 |
|---|---|
| **Vault** | 逻辑上的数据保险库，由 `vaultId` 唯一标识，可跨多设备同步 |
| **Device** | 物理设备，由 `deviceId` 唯一标识，不随 vault 共享 |
| **Local-first** | 本地状态与本地持久化优先，网络同步是后置协调动作 |
| **Outbox** | 本地待同步变更队列（`local_sync_changes`），用户批准后才会推送 |
| **HLC** | Hybrid Logical Clock，混合逻辑时钟，用于分布式事件排序 |
| **Tombstone** | 软删除标记，用于删除状态传播 |
| **Conflict Inbox** | 供用户查看和恢复冲突值的 UI 入口 |
| **AEAD** | Authenticated Encryption with Associated Data，当前同步 payload 使用 AES-256-GCM + HKDF |
| **Thin Sync Backend** | 只承担同步协调与版本秩序的薄后端，不接触明文 |

---

**文档版本**: 1.0
**最后更新**: 2026-05-06
