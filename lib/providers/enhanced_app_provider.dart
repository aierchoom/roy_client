import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/account_item.dart';
import '../models/account_template.dart';
import '../services/secure_storage_service.dart';
import '../services/service_manager.dart';
import '../sync/sync_service.dart';

class EnhancedAppProvider extends ChangeNotifier {
  final SecureStorageService _storageService;
  final ServiceManager _serviceManager;

  List<AccountItem> _accounts = [];
  List<AccountTemplate> _customTemplates = [];
  String _searchQuery = '';
  Set<String> _selectedTags = {};
  bool _isLoading = false;
  int _conflictCount = 0;
  StreamSubscription<StorageChangeEvent>? _storageSubscription;

  EnhancedAppProvider(this._storageService, this._serviceManager) {
    _init();
    _serviceManager.addListener(_onServiceManagerStateChanged);
  }

  List<AccountTemplate> get allTemplates => [
    ...basicAccountTemplates,
    ..._customTemplates,
  ];
  List<AccountItem> get allAccounts => _accounts;
  List<AccountTemplate> get customTemplates => _customTemplates;
  String get searchQuery => _searchQuery;
  Set<String> get selectedTags => _selectedTags;
  bool get isLoading => _isLoading;
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
    for (final template in allTemplates) {
      if (template.templateId == templateId) {
        return template;
      }
    }
    return null;
  }

  AccountItem? getAccount(String id) {
    try {
      return _accounts.firstWhere((account) => account.id == id);
    } catch (_) {
      return null;
    }
  }

  SyncState get syncState => _serviceManager.syncState;
  bool get isSyncConnected => _serviceManager.isSyncConnected;

  Future<void> _init() async {
    _setLoading(true);

    try {
      await _loadData();
      _storageSubscription = _storageService.onChange.listen(_onStorageChange);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize app provider: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadData() async {
    if (!_storageService.isOpen) return;

    _accounts = List<AccountItem>.of(await _storageService.loadAccounts());
    _customTemplates = List<AccountTemplate>.of(
      await _storageService.loadCustomTemplates(),
    );
    // Count total conflict logs across all accounts
    int count = 0;
    for (final acc in _accounts) {
      final logs = await _storageService.getConflictLogs(acc.id);
      count += logs.length;
    }
    _conflictCount = count;
    notifyListeners();
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
    notifyListeners();
  }

  void _onStorageChange(StorageChangeEvent event) {
    unawaited(_loadData());
  }

  Future<void> refresh() async {
    _setLoading(true);
    _accounts = [];
    _customTemplates = [];
    notifyListeners();

    await _loadData();
    _setLoading(false);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  void toggleTag(String templateId) {
    if (_selectedTags.contains(templateId)) {
      _selectedTags.remove(templateId);
    } else {
      _selectedTags.add(templateId);
    }
    notifyListeners();
  }

  void setTags(Set<String> tags) {
    _selectedTags = Set<String>.from(tags);
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTags.clear();
    notifyListeners();
  }

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

  Future<void> updateAccount(AccountItem item) async {
    _setLoading(true);

    try {
      await _serviceManager.saveAccount(item);
      final index = _accounts.indexWhere((account) => account.id == item.id);
      if (index != -1) {
        _accounts[index] = item;
        notifyListeners();
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
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addCustomTemplate(AccountTemplate template) async {
    _setLoading(true);

    try {
      await _serviceManager.saveTemplate(template);
      _customTemplates.insert(0, template);
      notifyListeners();
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
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  int countAccountsByTemplate(String templateId) {
    return _accounts.where((account) => account.templateId == templateId).length;
  }

  Future<void> deleteCustomTemplate(String templateId) async {
    _setLoading(true);

    try {
      await _serviceManager.deleteTemplate(templateId);
      _customTemplates.removeWhere(
        (template) => template.templateId == templateId,
      );
      notifyListeners();
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _serviceManager.removeListener(_onServiceManagerStateChanged);
    _storageSubscription?.cancel();
    super.dispose();
  }
}
