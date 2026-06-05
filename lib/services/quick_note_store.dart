import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/account_item.dart';
import '../models/quick_note.dart';
import 'service_manager.dart';

class QuickNoteStore {
  static const String _notesKey = 'quick_notes_v1';
  static const String _activeNoteIdKey = 'quick_notes_active_id_v1';
  static const String _legacyDraftKey = 'quick_note_markdown_draft_v1';
  static int _noteSequence = 0;

  final ServiceManager? _serviceManager;

  QuickNoteStore({ServiceManager? serviceManager})
    : _serviceManager = serviceManager;

  ServiceManager? get _vaultManager {
    final manager = _serviceManager;
    if (manager == null) return null;
    if (!manager.isUnlocked || !manager.storageService.isOpen) return null;
    return manager;
  }

  Future<QuickNotesSnapshot> load() async {
    final manager = _vaultManager;
    if (manager != null) {
      return _loadFromVault(manager);
    }
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_notesKey);
    var notes = <QuickNote>[];

    if (encoded != null && encoded.isNotEmpty) {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        notes = decoded
            .whereType<Map>()
            .map((item) => QuickNote.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }

    if (notes.isEmpty) {
      final legacyDraft = preferences.getString(_legacyDraftKey) ?? '';
      notes = [_newNote(content: legacyDraft)];
      await _saveNotes(preferences, notes);
      await preferences.setString(_activeNoteIdKey, notes.first.id);
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final storedActiveId = preferences.getString(_activeNoteIdKey);
    final activeNoteId = notes.any((note) => note.id == storedActiveId)
        ? storedActiveId!
        : notes.first.id;
    await preferences.setString(_activeNoteIdKey, activeNoteId);

    return QuickNotesSnapshot(notes: notes, activeNoteId: activeNoteId);
  }

  Future<QuickNote> createNote() async {
    final manager = _vaultManager;
    if (manager != null) {
      final preferences = await SharedPreferences.getInstance();
      final note = _newNote();
      await manager.storageService.saveQuickNote(
        note.copyWith(syncStatus: SyncStatus.synchronized),
        isSyncMerge: true,
      );
      await preferences.setString(_activeNoteIdKey, note.id);
      return note;
    }
    final preferences = await SharedPreferences.getInstance();
    final notes = await _loadNotes(preferences);
    final note = _newNote();
    notes.insert(0, note);
    await _saveNotes(preferences, notes);
    await preferences.setString(_activeNoteIdKey, note.id);
    return note;
  }

  Future<void> saveNote(QuickNote note) async {
    final manager = _vaultManager;
    if (manager != null) {
      final preferences = await SharedPreferences.getInstance();
      final existing = await manager.storageService.getQuickNoteById(
        note.id,
        includeDeleted: true,
      );
      final updated = note.copyWith(
        updatedAt: DateTime.now(),
        serverVersion: existing?.serverVersion ?? note.serverVersion,
      );
      await manager.saveQuickNote(updated);
      await preferences.setString(_activeNoteIdKey, updated.id);
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    final notes = await _loadNotes(preferences);
    final index = notes.indexWhere((item) => item.id == note.id);
    final updated = note.copyWith(updatedAt: DateTime.now());
    if (index >= 0) {
      notes[index] = updated;
    } else {
      notes.insert(0, updated);
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveNotes(preferences, notes);
    await preferences.setString(_activeNoteIdKey, updated.id);
  }

  Future<QuickNotesSnapshot> deleteNote(String noteId) async {
    final manager = _vaultManager;
    if (manager != null) {
      final preferences = await SharedPreferences.getInstance();
      await manager.deleteQuickNote(noteId);
      var notes = await manager.loadQuickNotes();
      if (notes.isEmpty) {
        final fallback = _newNote();
        await manager.storageService.saveQuickNote(
          fallback.copyWith(syncStatus: SyncStatus.synchronized),
          isSyncMerge: true,
        );
        notes = [fallback];
      }
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final activeNoteId = notes.first.id;
      await preferences.setString(_activeNoteIdKey, activeNoteId);
      return QuickNotesSnapshot(notes: notes, activeNoteId: activeNoteId);
    }
    final preferences = await SharedPreferences.getInstance();
    final notes = await _loadNotes(preferences);
    notes.removeWhere((note) => note.id == noteId);
    if (notes.isEmpty) {
      notes.add(_newNote());
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await _saveNotes(preferences, notes);
    final activeNoteId = notes.first.id;
    await preferences.setString(_activeNoteIdKey, activeNoteId);
    return QuickNotesSnapshot(notes: notes, activeNoteId: activeNoteId);
  }

  Future<QuickNotesSnapshot> pruneEmptyNotes({String? keepNoteId}) async {
    final manager = _vaultManager;
    if (manager != null) {
      final preferences = await SharedPreferences.getInstance();
      var notes = await manager.loadQuickNotes();
      for (final note in notes) {
        if (note.id != keepNoteId && note.content.trim().isEmpty) {
          await manager.deleteQuickNote(note.id);
        }
      }
      notes = await manager.loadQuickNotes();
      if (notes.isEmpty) {
        final fallback = _newNote();
        await manager.storageService.saveQuickNote(
          fallback.copyWith(syncStatus: SyncStatus.synchronized),
          isSyncMerge: true,
        );
        notes = [fallback];
      }
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final storedActiveId = preferences.getString(_activeNoteIdKey);
      final activeNoteId = notes.any((note) => note.id == storedActiveId)
          ? storedActiveId!
          : notes.first.id;
      await preferences.setString(_activeNoteIdKey, activeNoteId);
      return QuickNotesSnapshot(notes: notes, activeNoteId: activeNoteId);
    }
    final preferences = await SharedPreferences.getInstance();
    final notes = await _loadNotes(preferences);
    notes.removeWhere(
      (note) => note.id != keepNoteId && note.content.trim().isEmpty,
    );
    if (notes.isEmpty) {
      notes.add(_newNote());
    }
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final storedActiveId = preferences.getString(_activeNoteIdKey);
    final activeNoteId = notes.any((note) => note.id == storedActiveId)
        ? storedActiveId!
        : notes.first.id;
    await _saveNotes(preferences, notes);
    await preferences.setString(_activeNoteIdKey, activeNoteId);
    return QuickNotesSnapshot(notes: notes, activeNoteId: activeNoteId);
  }

  Future<void> setActiveNote(String noteId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeNoteIdKey, noteId);
  }

  Future<QuickNotesSnapshot> _loadFromVault(ServiceManager manager) async {
    final preferences = await SharedPreferences.getInstance();
    var notes = await manager.loadQuickNotes();

    if (notes.isEmpty) {
      final legacyDraft = preferences.getString(_legacyDraftKey) ?? '';
      if (legacyDraft.trim().isNotEmpty) {
        final migrated = _newNote(content: legacyDraft);
        await manager.saveQuickNote(migrated);
        notes = [migrated];
      } else {
        notes = [_newNote()];
      }
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final storedActiveId = preferences.getString(_activeNoteIdKey);
    final activeNoteId = notes.any((note) => note.id == storedActiveId)
        ? storedActiveId!
        : notes.first.id;
    await preferences.setString(_activeNoteIdKey, activeNoteId);

    return QuickNotesSnapshot(notes: notes, activeNoteId: activeNoteId);
  }

  QuickNote _newNote({String content = ''}) {
    final now = DateTime.now();
    return QuickNote(
      id: 'note_${now.microsecondsSinceEpoch}_${_noteSequence++}',
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<QuickNote>> _loadNotes(SharedPreferences preferences) async {
    final encoded = preferences.getString(_notesKey);
    if (encoded == null || encoded.isEmpty) return [];
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => QuickNote.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _saveNotes(
    SharedPreferences preferences,
    List<QuickNote> notes,
  ) async {
    await preferences.setString(
      _notesKey,
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
  }
}
