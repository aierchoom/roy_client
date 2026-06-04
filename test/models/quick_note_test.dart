import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/models/quick_note.dart';

void main() {
  group('QuickNote', () {
    test('derives title from first non-empty markdown line', () {
      final note = QuickNote(
        id: 'note-1',
        content: '\n\n## Project idea\n- next step',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      expect(note.title, 'Project idea');
      expect(note.preview, 'Project idea · next step');
    });

    test('strips common markdown markers in title and preview', () {
      final note = QuickNote(
        id: 'note-2',
        content: '- [ ] **Call** `[team]`\n> [Docs](https://example.com)',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      expect(note.title, 'Call [team]');
      expect(note.preview, 'Call [team] · Docs');
    });

    test('falls back for empty content', () {
      final note = QuickNote(
        id: 'note-3',
        content: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      expect(note.title, '随手记');
      expect(note.preview, '空白笔记');
    });

    test('round trips json and tolerates missing dates', () {
      final note = QuickNote(
        id: 'note-4',
        content: '# Saved',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      final decoded = QuickNote.fromJson(note.toJson());
      expect(decoded.id, note.id);
      expect(decoded.content, note.content);
      expect(decoded.createdAt, note.createdAt);
      expect(decoded.updatedAt, note.updatedAt);

      final fallback = QuickNote.fromJson({'content': 'Loose note'});
      expect(fallback.id, startsWith('note_'));
      expect(fallback.content, 'Loose note');
    });
  });
}
