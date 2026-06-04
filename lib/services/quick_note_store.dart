import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quick_note.dart';

class QuickNoteStore {
  static const String _notesKey = 'quick_notes_v1';
  static const String _activeNoteIdKey = 'quick_notes_active_id_v1';
  static const String _legacyDraftKey = 'quick_note_markdown_draft_v1';

  Future<QuickNotesSnapshot> load() async {
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
    final preferences = await SharedPreferences.getInstance();
    final notes = await _loadNotes(preferences);
    final note = _newNote();
    notes.insert(0, note);
    await _saveNotes(preferences, notes);
    await preferences.setString(_activeNoteIdKey, note.id);
    return note;
  }

  Future<void> saveNote(QuickNote note) async {
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

  QuickNote _newNote({String content = ''}) {
    final now = DateTime.now();
    return QuickNote(
      id: 'note_${now.microsecondsSinceEpoch}',
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
