import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/services/quick_note_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QuickNoteStore', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load creates an empty note when storage is empty', () async {
      final store = QuickNoteStore();

      final snapshot = await store.load();

      expect(snapshot.notes, hasLength(1));
      expect(snapshot.notes.single.content, isEmpty);
      expect(snapshot.activeNoteId, snapshot.notes.single.id);
    });

    test('load migrates legacy single draft into first note', () async {
      SharedPreferences.setMockInitialValues({
        'quick_note_markdown_draft_v1': '# Legacy draft',
      });
      final store = QuickNoteStore();

      final snapshot = await store.load();

      expect(snapshot.notes, hasLength(1));
      expect(snapshot.notes.single.content, '# Legacy draft');
      expect(snapshot.notes.single.title, 'Legacy draft');
    });

    test('createNote makes new note active', () async {
      final store = QuickNoteStore();
      final initial = await store.load();

      final created = await store.createNote();
      final snapshot = await store.load();

      expect(snapshot.notes.length, initial.notes.length + 1);
      expect(snapshot.activeNoteId, created.id);
      expect(snapshot.notes.any((note) => note.id == created.id), isTrue);
    });

    test('saveNote updates content and keeps note active', () async {
      final store = QuickNoteStore();
      final snapshot = await store.load();
      final note = snapshot.notes.single.copyWith(content: '## Updated note');

      await store.saveNote(note);
      final updated = await store.load();

      expect(updated.activeNoteId, note.id);
      expect(updated.notes.first.content, '## Updated note');
      expect(updated.notes.first.title, 'Updated note');
    });

    test(
      'deleteNote removes selected note and preserves a fallback note',
      () async {
        final store = QuickNoteStore();
        final created = await store.createNote();
        await store.saveNote(created.copyWith(content: 'Delete me'));

        final snapshot = await store.deleteNote(created.id);

        expect(snapshot.notes.any((note) => note.id == created.id), isFalse);
        expect(snapshot.notes, isNotEmpty);
        expect(
          snapshot.notes.any((note) => note.id == snapshot.activeNoteId),
          isTrue,
        );
      },
    );

    test('pruneEmptyNotes removes empty notes except kept note', () async {
      final store = QuickNoteStore();
      final empty = await store.createNote();
      final keepEmpty = await store.createNote();
      final filled = await store.createNote();
      await store.saveNote(filled.copyWith(content: 'Keep content'));

      final snapshot = await store.pruneEmptyNotes(keepNoteId: keepEmpty.id);

      expect(snapshot.notes.any((note) => note.id == empty.id), isFalse);
      expect(snapshot.notes.any((note) => note.id == keepEmpty.id), isTrue);
      expect(snapshot.notes.any((note) => note.id == filled.id), isTrue);
    });
  });
}
