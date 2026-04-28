# 功能拆解示例：新增账号并刷新列表

本文用“新增账号”这条典型功能，把 SecretRoy 的 UI、Provider、Service、数据库和 UI 刷新串起来。

## 1. 先看完整流程

```text
用户点击新增按钮
↓
AccountListView._openEditor()
↓
Navigator.push(AccountEditView)
↓
用户填写账号信息
↓
AccountEditView._save()
↓
创建 AccountItem
↓
Navigator.pop(item)
↓
AccountListView 收到 item
↓
EnhancedAppProvider.addAccount(item)
↓
ServiceManager.saveAccount(item)
↓
SecureStorageService.saveAccount(item)
↓
SQLite 写入账号
↓
加密数据库落盘
↓
SyncService.markDirty()
↓
Provider 更新状态并 notifyListeners()
↓
AccountListView 重新 build
↓
新账号显示在列表中
```

这条链路是理解项目架构最好的入口，因为它包含：

- 页面操作。
- 页面跳转和返回数据。
- Provider 状态更新。
- Service 业务处理。
- 本地数据库写入。
- 同步标记。
- UI 自动刷新。

对应到你读代码时最该记住的六步：

```text
用户操作：点击账号列表右下角新增按钮
↓
触发方法：AccountListView._openEditor()
↓
调用 service：EnhancedAppProvider.addAccount() 调用 ServiceManager.saveAccount()
↓
获取数据：SecureStorageService 写入后，Provider 再次 loadAccounts()
↓
更新状态：EnhancedAppProvider 更新 _accounts 并 notifyListeners()
↓
刷新 UI：AccountListView 重新 build，显示新账号
```

## 2. 第一步：用户点击新增按钮

位置：

- `lib/views/accounts/account_list_view.dart`

账号列表页右下角有一个 `GreenAddButton`：

```dart
GreenAddButton(
  heroTag: 'add-account-fab',
  onPressed: () => _openEditor(context),
  tooltip: _text(context, '新建账户', 'Add Account'),
)
```

用户点击后，调用 `_openEditor(context)`。

这一步的作用：

```text
把用户操作转换成页面方法调用
```

## 3. 第二步：打开账号编辑页

`_openEditor` 里使用 `Navigator.push`：

```dart
Future<void> _openEditor(BuildContext context, {AccountItem? initial}) async {
  final result = await Navigator.push<AccountItem>(
    context,
    MaterialPageRoute(builder: (_) => AccountEditView(initial: initial)),
  );

  if (result == null || !context.mounted) return;

  final provider = context.read<EnhancedAppProvider>();
  if (initial == null) {
    await provider.addAccount(result);
    return;
  }

  await provider.updateAccount(result);
}
```

新手要注意两点：

1. `Navigator.push` 会打开新页面。
2. `await` 表示当前页面会等编辑页关闭，并接收编辑页返回的数据。

流程：

```text
AccountListView
↓
打开 AccountEditView
↓
等待用户保存或取消
```

如果用户取消，`result == null`，什么都不保存。

如果用户保存，`result` 就是一条 `AccountItem`。

## 4. 第三步：编辑页收集表单数据

位置：

- `lib/views/accounts/account_edit_view.dart`

`AccountEditView` 是 `StatefulWidget`，因为它要保存输入框控制器和当前选择的模板：

```dart
final _nameCtrl = TextEditingController();
final _emailCtrl = TextEditingController();
String? _pickedTag;
final Map<String, TextEditingController> _fieldCtrls = {};
```

这些变量分别代表：

- `_nameCtrl`：账号名称输入框。
- `_emailCtrl`：邮箱输入框。
- `_pickedTag`：当前选择的模板 ID。
- `_fieldCtrls`：模板字段对应的输入框，比如“内容”“密码”“API Key”。

编辑页会根据模板动态生成字段：

```text
读取当前模板
↓
遍历 template.fields
↓
为每个字段创建 TextEditingController
↓
build 时画出对应输入框
```

项目中的默认模板是“通用信息”，字段大致是：

```text
content：需要保管的敏感信息
```

## 5. 第四步：保存时创建 AccountItem

用户点击保存按钮后，编辑页调用 `_save()`。

简化后的逻辑：

```dart
void _save() {
  final name = _nameCtrl.text.trim();
  if (name.isEmpty) {
    // 提示用户必须填写账号名称
    return;
  }

  _persistVisibleFieldDrafts();

  final item = AccountItem(
    id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    name: name,
    email: _emailCtrl.text.trim(),
    templateId: _pickedTag ?? '',
    data: data,
    createdAt: widget.initial?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    syncStatus: widget.initial?.syncStatus ?? SyncStatus.pendingPush,
    isDeleted: false,
  );

  Navigator.of(context).pop(item);
}
```

这一步的作用：

```text
把输入框里的零散文本
↓
整理成项目统一的数据模型 AccountItem
```

`AccountItem` 是数据层模型，里面最重要的是：

```text
id：账号唯一 ID
name：账号名称
email：邮箱或登录名
templateId：使用哪个模板
data：模板字段的具体值
createdAt：创建时间
syncStatus：同步状态
```

例如用户填写：

```text
名称：GitHub
邮箱：me@example.com
内容：github_pat_xxx
模板：通用信息
```

就会变成类似这样的对象：

```dart
AccountItem(
  id: '1777370000000',
  name: 'GitHub',
  email: 'me@example.com',
  templateId: 'generic_info',
  data: {
    'content': 'github_pat_xxx',
  },
  createdAt: 1777370000000,
  syncStatus: SyncStatus.pendingPush,
  isDeleted: false,
)
```

最后这句很关键：

```dart
Navigator.of(context).pop(item);
```

它不是普通关闭页面，而是“带着保存结果返回上一页”。

## 6. 第五步：账号列表页接收返回结果

回到 `AccountListView._openEditor()`：

```dart
final result = await Navigator.push<AccountItem>(...);

if (result == null || !context.mounted) return;

final provider = context.read<EnhancedAppProvider>();
if (initial == null) {
  await provider.addAccount(result);
  return;
}

await provider.updateAccount(result);
```

因为这次是新增，`initial == null`，所以调用：

```dart
await provider.addAccount(result);
```

这一步的作用：

```text
页面不直接写数据库
↓
页面把数据交给 Provider
↓
Provider 负责后续保存和刷新
```

## 7. 第六步：Provider 调用 service

位置：

- `lib/providers/enhanced_app_provider.dart`

核心代码：

```dart
Future<void> addAccount(AccountItem item) async {
  _setLoading(true);

  try {
    await _serviceManager.saveAccount(item);
    _accounts.insert(0, item);
    notifyListeners();
  } finally {
    _setLoading(false);
  }
}
```

这一步做三件事：

1. `_setLoading(true)`：告诉 UI 正在保存。
2. `_serviceManager.saveAccount(item)`：把保存动作交给业务层。
3. `_accounts.insert(0, item)` 和 `notifyListeners()`：让页面立刻显示新账号。

流程：

```text
EnhancedAppProvider.addAccount
↓
显示 loading 状态
↓
调用 ServiceManager.saveAccount
↓
保存成功后更新内存列表
↓
notifyListeners 刷新 UI
```

这里的 Provider 像一个“前台数据管家”：它不负责数据库细节，但它知道 UI 当前要显示哪些账号。

## 8. 第七步：ServiceManager 完成业务动作

位置：

- `lib/services/service_manager.dart`

核心代码：

```dart
Future<void> saveAccount(AccountItem account) async {
  if (!isUnlocked) return;
  await _secureStorageService.saveAccount(account);
  await _syncService.markDirty();
  unawaited(_syncService.syncNow());
}
```

这一步很重要。它说明“保存账号”在业务上不只是写数据库。

完整动作是：

```text
确认保险库已解锁
↓
写入本地加密数据库
↓
标记本地有待同步数据
↓
后台尝试同步
```

如果保险库没有解锁，`isUnlocked` 为 false，保存会直接返回，不会写入数据。

## 9. 第八步：SecureStorageService 写入数据库

位置：

- `lib/services/secure_storage_service.dart`

简化后的保存逻辑：

```dart
Future<void> saveAccount(AccountItem account, {bool isSyncMerge = false}) async {
  if (!isOpen) return;

  AccountItem itemToSave = account;

  if (!isSyncMerge) {
    // 本地保存时，给改动字段打 HLC 时间戳，并标记 pendingPush
  }

  await _database!.insert(
    'accounts',
    {
      'id': itemToSave.id,
      'name': itemToSave.name,
      'email': itemToSave.email,
      'template_id': itemToSave.templateId,
      'data': jsonEncode(itemToSave.data),
      'sync_status': itemToSave.syncStatus.index,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  await _persistAfterMutation();
  _notifyChange(StorageChangeEvent(...));
}
```

这一步做了几件底层工作：

1. 判断数据库是否已经打开。
2. 如果是本地保存，为同步字段打时间戳。
3. 把 `AccountItem` 转成 SQLite 行。
4. 写入 `accounts` 表。
5. 把运行期数据库重新加密落盘。
6. 发出 `StorageChangeEvent`。

数据在这一层会变成数据库字段：

```text
AccountItem.name       → accounts.name
AccountItem.email      → accounts.email
AccountItem.templateId → accounts.template_id
AccountItem.data       → accounts.data(JSON 字符串)
AccountItem.syncStatus → accounts.sync_status
```

## 10. 第九步：同步标记

保存数据库后，`ServiceManager` 会调用：

```dart
await _syncService.markDirty();
unawaited(_syncService.syncNow());
```

意思是：

```text
本地有新变化
↓
写入 sync_dirty 标记
↓
如果同步服务器可用，后台尝试推送
```

如果没有配置同步服务器，账号仍然已经保存在本地。同步失败不会阻止本地列表展示。

## 11. 第十步：Provider 重新加载数据库变化

`EnhancedAppProvider` 初始化时订阅了存储变化：

```dart
_storageSubscription = _storageService.onChange.listen(_onStorageChange);
```

当 `SecureStorageService.saveAccount()` 发出事件后：

```dart
void _onStorageChange(StorageChangeEvent event) {
  unawaited(_loadData());
}
```

`_loadData()` 会重新读数据库：

```dart
_accounts = List<AccountItem>.of(await _storageService.loadAccounts());
_customTemplates = List<AccountTemplate>.of(
  await _storageService.loadCustomTemplates(),
);
notifyListeners();
```

所以新增账号后，UI 更新有两层保障：

```text
Provider 先把新账号插入内存列表
↓
UI 立即刷新
↓
StorageChangeEvent 触发重新读取数据库
↓
UI 和数据库最终保持一致
```

## 12. 第十一步：账号列表重新 build

`AccountListView` 里有：

```dart
final provider = context.watch<EnhancedAppProvider>();
```

这表示它订阅了 `EnhancedAppProvider`。当 Provider 调用 `notifyListeners()` 后：

```text
notifyListeners()
↓
AccountListView.build()
↓
_buildGroups(provider)
↓
_buildAccountPanel(context, provider)
↓
AccountListTile(...)
```

账号列表会按模板分组：

```dart
for (final template in templates) {
  final items = filtered
      .where((account) => account.templateId == template.templateId)
      .toList();
  if (items.isEmpty) continue;
  groups.add(_AccountGroup(template: template, accounts: items));
}
```

最后每条账号显示为 `AccountListTile`：

```dart
AccountListTile(
  account: account,
  template: accountTemplate,
  onEdit: () => _openEditor(context, initial: account),
  onDelete: () => _deleteAccount(context, account),
)
```

用户看到的结果就是：刚保存的账号出现在列表中。

## 13. 数据流总结

用一句话描述：

```text
用户输入的数据先变成 AccountItem，
再通过 Provider 交给 ServiceManager，
ServiceManager 写入 SecureStorageService，
SecureStorageService 写入 SQLite 并加密落盘，
最后 Provider 通知 UI 重新展示。
```

更完整的图：

```text
输入框文本
↓
AccountEditView._save()
↓
AccountItem
↓
Navigator.pop(item)
↓
AccountListView
↓
EnhancedAppProvider.addAccount(item)
↓
ServiceManager.saveAccount(item)
↓
SecureStorageService.saveAccount(item)
↓
accounts 表
↓
secret_roy_vault.db.enc
↓
StorageChangeEvent
↓
EnhancedAppProvider._loadData()
↓
notifyListeners()
↓
AccountListView.build()
↓
AccountListTile
```

## 14. 新手调试这个功能时看哪里

如果点击新增按钮没有反应，先看：

- `AccountListView` 的 `GreenAddButton.onPressed`
- `_openEditor(context)`

如果编辑页保存后没有返回，先看：

- `AccountEditView._save()`
- `Navigator.of(context).pop(item)`

如果返回了但没有保存，先看：

- `EnhancedAppProvider.addAccount`
- `ServiceManager.saveAccount`

如果数据库没有写入，先看：

- `SecureStorageService.isOpen`
- `SecureStorageService.saveAccount`
- App 是否已经解锁

如果数据库写了但列表没有刷新，先看：

- `EnhancedAppProvider.notifyListeners()`
- `AccountListView` 是否使用 `context.watch<EnhancedAppProvider>()`
- `_storageService.onChange.listen(_onStorageChange)` 是否正常订阅

## 15. 同一个结构可以套到其他功能

模板新增、账号删除、账号编辑都和新增账号类似。

例如删除账号：

```text
用户长按或菜单点击删除
↓
AccountListView._deleteAccount()
↓
确认弹窗
↓
EnhancedAppProvider.deleteAccount(id)
↓
ServiceManager.deleteAccount(id)
↓
SecureStorageService.deleteAccount(id)
↓
标记软删除 + pendingPush
↓
SyncService.markDirty()
↓
notifyListeners()
↓
列表刷新
```

掌握“新增账号”的链路后，再读其他功能会轻松很多。
