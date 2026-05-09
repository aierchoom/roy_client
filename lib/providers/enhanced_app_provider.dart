import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:secret_roy/core/app_logger.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../models/local_sync_change.dart';
import '../models/template_conflict_log.dart';
import '../models/totp_credential.dart';
import '../services/secure_storage_service.dart';
import '../services/service_manager.dart';
import '../sync/sync_service.dart';

class EnhancedAppProvider extends ChangeNotifier {
  final SecureStorageService _storageService;
  final ServiceManager _serviceManager;

  List<AccountItem> _accounts = [];
  List<AccountTemplate> _customTemplates = [];
  List<TotpCredential> _totpCredentials = [];
  List<LocalSyncChange> _localSyncChanges = [];
  List<TemplateConflictLog> _templateConflictLogs = [];
  String _searchQuery = '';
  Set<String> _selectedTags = {};
  bool _isLoading = false;
  String? _initError;
  int _conflictCount = 0;
  StreamSubscription<StorageChangeEvent>? _storageSubscription;
  bool _disposed = false;

  EnhancedAppProvider(this._storageService, this._serviceManager) {
    _init();
    _serviceManager.addListener(_onServiceManagerStateChanged);
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  List<AccountTemplate> get allTemplates => [
    ...basicAccountTemplates,
    ..._customTemplates,
  ];
  List<AccountItem> get allAccounts => _accounts;
  List<AccountItem> get accountItems => _accounts
      .where((a) => _templateCategoryOf(a.templateId) != TemplateCategory.note)
      .toList();
  List<AccountItem> get secureNoteItems => _accounts
      .where((a) => _templateCategoryOf(a.templateId) == TemplateCategory.note)
      .toList();
  List<TotpCredential> get totpCredentials => _totpCredentials;
  List<AccountTemplate> get customTemplates => _customTemplates;
  List<LocalSyncChange> get localSyncChanges => _localSyncChanges;
  List<TemplateConflictLog> get templateConflictLogs => _templateConflictLogs;
  String get searchQuery => _searchQuery;
  Set<String> get selectedTags => _selectedTags;
  bool get isLoading => _isLoading;
  String? get initError => _initError;
  int get conflictCount => _conflictCount;

  List<AccountItem> get accounts {
    if (_searchQuery.isEmpty && _selectedTags.isEmpty) return _accounts;

    final normalizedQuery = _searchQuery.toLowerCase();
    return _accounts.where((account) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          account.name.toLowerCase().contains(normalizedQuery) ||
          account.email.toLowerCase().contains(normalizedQuery);
      final matchesTags =
          _selectedTags.isEmpty || _selectedTags.contains(account.templateId);
      return matchesQuery && matchesTags;
    }).toList();
  }

  AccountTemplate? getTemplate(String templateId) {
    for (final template in _customTemplates) {
      if (template.templateId == templateId) return template;
    }
    for (final template in basicAccountTemplates) {
      if (template.templateId == templateId) return template;
    }
    return null;
  }

  TemplateCategory _templateCategoryOf(String templateId) {
    return getTemplate(templateId)?.category ?? TemplateCategory.custom;
  }

  AccountItem? getAccount(String id) {
    try {
      return _accounts.firstWhere((account) => account.id == id);
    } catch (_) {
      // firstWhere not found is the idiomatic way to return null for missing items.
      return null;
    }
  }

  List<TotpCredential> totpCredentialsForAccount(String accountId) {
    return _totpCredentials
        .where((credential) => credential.isLinkedToAccount(accountId))
        .toList(growable: false);
  }

  String? resolveAccountName(String accountId) {
    final account = getAccount(accountId);
    return account?.name;
  }

  List<AccountItem> accountsLinkedTo(String accountId) {
    return _accounts
        .where((account) {
          if (account.id == accountId) return false;
          for (final value in account.data.values) {
            if (value?.toString() == accountId) return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  SyncState get syncState => _serviceManager.syncState;
  bool get isSyncConnected => _serviceManager.isSyncConnected;

  Future<void> _init() async {
    _setLoading(true);

    try {
      await _loadData();
      _storageSubscription = _storageService.onChange.listen(_onStorageChange);
    } catch (e) {
      AppLogger.e('Failed to initialize app provider: $e');
      _initError = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadData() async {
    if (!_storageService.isOpen) return;

    _accounts = List<AccountItem>.of(await _storageService.loadAccounts());
    _totpCredentials = List<TotpCredential>.of(
      await _storageService.loadTotpCredentials(),
    );
    _customTemplates = List<AccountTemplate>.of(
      await _storageService.loadCustomTemplates(),
    );
    _localSyncChanges = List<LocalSyncChange>.of(
      await _serviceManager.loadOpenLocalSyncChanges(),
    );
    // Count total conflict logs across all accounts and templates
    int count = 0;
    for (final acc in _accounts) {
      final logs = await _storageService.getConflictLogs(acc.id);
      count += logs.length;
    }
    _templateConflictLogs = await _storageService.getTemplateConflictLogs();
    count += _templateConflictLogs.length;
    _conflictCount = count;
    _notify();
  }

  void _onServiceManagerStateChanged() {
    if (_serviceManager.isUnlocked) {
      unawaited(refresh());
      _storageSubscription?.cancel();
      _storageSubscription = _storageService.onChange.listen(_onStorageChange);
      return;
    }

    _accounts = [];
    _customTemplates = [];
    _totpCredentials = [];
    _localSyncChanges = [];
    _templateConflictLogs = [];
    _notify();
  }

  void _onStorageChange(StorageChangeEvent event) {
    unawaited(_loadData());
  }

  Future<void> refresh() async {
    _setLoading(true);
    _accounts = [];
    _customTemplates = [];
    _totpCredentials = [];
    _localSyncChanges = [];
    _templateConflictLogs = [];
    _notify();

    await _loadData();
    _setLoading(false);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _notify();
  }

  void clearSearch() {
    _searchQuery = '';
    _notify();
  }

  void toggleTag(String templateId) {
    if (_selectedTags.contains(templateId)) {
      _selectedTags.remove(templateId);
    } else {
      _selectedTags.add(templateId);
    }
    _notify();
  }

  void setTags(Set<String> tags) {
    _selectedTags = Set<String>.from(tags);
    _notify();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTags.clear();
    _notify();
  }

  Future<void> addAccount(AccountItem item) async {
    _setLoading(true);

    try {
      await _serviceManager.saveAccount(item);
      _accounts.insert(0, item);
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateAccount(AccountItem item) async {
    _setLoading(true);

    try {
      await _serviceManager.saveAccount(item);
      final index = _accounts.indexWhere((account) => account.id == item.id);
      if (index != -1) {
        _accounts[index] = item;
        _notify();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAccount(String id) async {
    _setLoading(true);

    try {
      await _serviceManager.deleteAccount(id);
      _accounts.removeWhere((account) => account.id == id);
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addTotpCredential(TotpCredential credential) async {
    _setLoading(true);

    try {
      await _serviceManager.saveTotpCredential(credential);
      _totpCredentials.insert(0, credential);
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateTotpCredential(TotpCredential credential) async {
    _setLoading(true);

    try {
      await _serviceManager.saveTotpCredential(credential);
      final index = _totpCredentials.indexWhere(
        (item) => item.id == credential.id,
      );
      if (index != -1) {
        _totpCredentials[index] = credential;
      } else {
        _totpCredentials.insert(0, credential);
      }
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteTotpCredential(String id) async {
    _setLoading(true);

    try {
      await _serviceManager.deleteTotpCredential(id);
      _totpCredentials.removeWhere((credential) => credential.id == id);
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addCustomTemplate(AccountTemplate template) async {
    _setLoading(true);

    try {
      await _serviceManager.saveTemplate(template);
      _customTemplates.insert(0, template);
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCustomTemplate(AccountTemplate template) async {
    _setLoading(true);

    try {
      await _serviceManager.saveTemplate(template);
      final index = _customTemplates.indexWhere(
        (item) => item.templateId == template.templateId,
      );
      if (index != -1) {
        _customTemplates[index] = template;
        _notify();
      }
    } finally {
      _setLoading(false);
    }
  }

  int countAccountsByTemplate(String templateId) {
    return _accounts
        .where((account) => account.templateId == templateId)
        .length;
  }

  Future<void> deleteCustomTemplate(String templateId) async {
    _setLoading(true);

    try {
      await _serviceManager.deleteTemplate(templateId);
      _customTemplates.removeWhere(
        (template) => template.templateId == templateId,
      );
      _notify();
    } finally {
      _setLoading(false);
    }
  }

  String generatePassword({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSpecial = true,
  }) {
    return ServiceManager.generatePassword(
      length: length,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSpecial: includeSpecial,
    );
  }

  int calculatePasswordStrength(String password) {
    return ServiceManager.calculatePasswordStrength(password);
  }

  String getPasswordStrengthLevel(int score) {
    return ServiceManager.getPasswordStrengthLevel(score);
  }

  Future<SyncResult> syncNow() async {
    return _serviceManager.syncNow();
  }

  Future<SyncResult> pushAllLocalSyncChanges() async {
    final result = await _serviceManager.approveAndSyncLocalChanges();
    await _loadData();
    return result;
  }

  Future<SyncResult> pushLocalSyncChange(String changeId) async {
    final result = await _serviceManager.approveAndSyncLocalChanges(
      changeIds: [changeId],
    );
    await _loadData();
    return result;
  }

  Future<void> discardLocalSyncChange(String changeId) async {
    await _serviceManager.discardLocalSyncChange(changeId);
    await _loadData();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _serviceManager.removeListener(_onServiceManagerStateChanged);
    _storageSubscription?.cancel();
    super.dispose();
  }
}
