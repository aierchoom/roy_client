import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_roy/views/notes/quick_note_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Pre-populates SharedPreferences with a single note and makes it active.
  Future<void> seedNote(String content) async {
    final prefs = await SharedPreferences.getInstance();
    const noteId = 'note_test_1';
    final note = {
      'id': noteId,
      'content': content,
      'createdAt': '2026-01-01T00:00:00.000',
      'updatedAt': '2026-01-01T00:00:00.000',
    };
    await prefs.setString('quick_notes_v1', jsonEncode([note]));
    await prefs.setString('quick_notes_active_id_v1', noteId);
  }

  /// Pumps the widget and waits for async _loadNotes to finish.
  Future<void> pumpQuickNote(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: QuickNoteView()));
    // Process async _loadNotes → pump to resolve futures, then setState.
    await tester.runAsync(() => tester.pump(const Duration(milliseconds: 100)));
    // Rebuild after setState, then post-frame _editBlock.
    await tester.pump();
    await tester.pump();
  }

  Finder previewInkWellFor(Finder child) {
    return find.ancestor(of: child, matching: find.byType(InkWell)).first;
  }

  Finder toolbarChipFor(IconData icon) {
    return find
        .ancestor(of: find.byIcon(icon), matching: find.byType(ActionChip))
        .first;
  }

  Finder iconButtonFor(IconData icon) {
    return find
        .ancestor(of: find.byIcon(icon), matching: find.byType(IconButton))
        .first;
  }

  Finder previewText(String text) {
    return find.descendant(
      of: find.byType(MarkdownBody).first,
      matching: find.text(text, findRichText: true),
    );
  }

  Future<void> pumpCompactWithKeyboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = FakeViewPadding(bottom: 280);
    addTearDown(tester.view.reset);
    await pumpQuickNote(tester);
  }

  // ---------------------------------------------------------------------------
  // 1. Numbered list continuation
  // ---------------------------------------------------------------------------

  group('Numbered list continuation', () {
    testWidgets('1. text + Enter produces 2. in new block', (tester) async {
      await pumpQuickNote(tester);

      // Should start with one editing TextField (empty block).
      expect(find.byType(TextField), findsOneWidget);

      // Enter "1. first" with a trailing newline to trigger the split.
      await tester.enterText(find.byType(TextField), '1. first\n');
      await tester.pump(); // rebuild after _handleBlockChanged
      await tester.pump(); // post-frame focus callback

      // The original text is now previewed, and "2. " is the new editing block.
      expect(find.text('1. first'), findsOneWidget);
      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '2. ');
      // Cursor must be at the end of the prefix, not at offset 0.
      expect(editingField.controller!.selection.baseOffset, 3);
    });

    testWidgets('1) text + Enter produces 2) in new block', (tester) async {
      await pumpQuickNote(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1) task\n');
      await tester.pump();
      await tester.pump();

      expect(find.text('1) task'), findsOneWidget);
      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '2) ');
      expect(editingField.controller!.selection.baseOffset, 3);
    });

    testWidgets('indented 1. text + Enter preserves indentation', (
      tester,
    ) async {
      await pumpQuickNote(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  1. indent\n');
      await tester.pump();
      await tester.pump();

      // MarkdownBody renders formatted output, not raw source.
      // Verify the preview shows "indent" (the content), and the editing
      // field has the continued prefix "  2. ".
      expect(find.text('indent'), findsOneWidget);
      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '  2. ');
      expect(editingField.controller!.selection.baseOffset, 5);
    });

    testWidgets('empty 1.  + Enter exits list (no continuation)', (
      tester,
    ) async {
      await pumpQuickNote(tester);
      expect(find.byType(TextField), findsOneWidget);

      // Type "1. " then Enter → should clear, not produce "2. "
      await tester.enterText(find.byType(TextField), '1. \n');
      await tester.pump();
      await tester.pump();

      // "1. " text should be cleared (bare continuation exit).
      // The editing block should be empty, not "2. "
      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '');
    });

    testWidgets('empty 1) + Enter exits list (no continuation)', (
      tester,
    ) async {
      await pumpQuickNote(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1) \n');
      await tester.pump();
      await tester.pump();

      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '');
    });

    testWidgets('9. text increments to 10. correctly', (tester) async {
      await pumpQuickNote(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '9. step\n');
      await tester.pump();
      await tester.pump();

      expect(find.text('9. step'), findsOneWidget);
      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '10. ');
      expect(editingField.controller!.selection.baseOffset, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Todo checkbox toggle
  // ---------------------------------------------------------------------------

  group('Todo checkbox toggle', () {
    testWidgets('unchecked → checked on checkbox tap', (tester) async {
      // Seed a note where the first block is "- [ ] task" and the second is
      // empty so the task block renders in preview mode.
      await seedNote('- [ ] Buy milk\n');
      await pumpQuickNote(tester);

      // The task block should be in preview mode with a Checkbox.
      expect(find.byType(Checkbox), findsOneWidget);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, false);

      // Tap the checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Now the checkbox should be checked.
      final updated = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(updated.value, true);
    });

    testWidgets('checked → unchecked on checkbox tap', (tester) async {
      await seedNote('- [x] Done task\n');
      await pumpQuickNote(tester);

      expect(find.byType(Checkbox), findsOneWidget);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, true);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final updated = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(updated.value, false);
    });

    testWidgets('checkbox toggle persists state in SharedPreferences', (
      tester,
    ) async {
      await seedNote('- [ ] Persist me\n');
      await pumpQuickNote(tester);

      // Toggle the checkbox.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Pump the 450ms save timer.
      await tester.pump(const Duration(milliseconds: 500));

      // Read back from SharedPreferences to verify persistence.
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('quick_notes_v1');
      expect(encoded, isNotNull);
      final notes = jsonDecode(encoded!) as List;
      final content = notes.first['content'] as String;
      expect(content, contains('- [x] Persist me'));
    });

    testWidgets('uppercase [X] is recognized as checked', (tester) async {
      await seedNote('- [X] Uppercase task\n');
      await pumpQuickNote(tester);

      expect(find.byType(Checkbox), findsOneWidget);
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, true);

      // Toggle should go to unchecked.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final updated = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(updated.value, false);
    });

    testWidgets('tapping text area enters edit mode', (tester) async {
      await seedNote('- [ ] Tap text\n');
      await pumpQuickNote(tester);

      // The task block is in preview with a Checkbox, and the trailing empty
      // block is in edit mode.
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap the preview text area's interactive ancestor.
      await tester.tap(previewInkWellFor(find.byType(MarkdownBody).first));
      await tester.pump();
      await tester.pump();

      // The task block should now be in edit mode.
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.length, 1);
      expect(textFields.first.controller!.text, '- [ ] Tap text');
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Focus-loss auto-render
  // ---------------------------------------------------------------------------

  group('Focus-loss auto-render', () {
    testWidgets('editing block renders as preview on focus loss', (
      tester,
    ) async {
      await pumpQuickNote(tester);

      // Should start with a TextField (edit mode).
      expect(find.byType(TextField), findsOneWidget);

      // Simulate focus loss.
      FocusManager.instance.primaryFocus?.unfocus();

      // Pump past the 80ms delay in _onBlockFocusLost.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(); // process setState from _finishEditing

      // No TextField should be visible (all blocks in preview mode).
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping preview block switches edit to that block', (
      tester,
    ) async {
      await seedNote('First block\n');
      await pumpQuickNote(tester);

      // Two blocks: "First block" (preview) + "" (editing).
      // Tap the preview block's interactive ancestor.
      await tester.tap(previewInkWellFor(find.byType(MarkdownBody).first));
      await tester.pump();
      await tester.pump();

      // Now "First block" should be editing.
      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      expect(textFields.length, 1);
      expect(textFields.first.controller!.text, 'First block');
    });

    testWidgets('tapping blank paper adds new editing block', (tester) async {
      await pumpQuickNote(tester);

      // Initially one editing block.
      expect(find.byType(TextField), findsOneWidget);

      // Tap somewhere in the paper to trigger _continueAtEnd.
      await tester.tapAt(const Offset(200, 600));
      await tester.pump();
      await tester.pump();

      // There should still be exactly one TextField (the new editing block).
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('toolbar button works after format toggle', (tester) async {
      await pumpQuickNote(tester);

      // Type some text in the editing block.
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      // Toggle the format toolbar open.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      // Let the toolbar animation settle.
      await tester.pump(const Duration(milliseconds: 200));

      // Verify the Bold toolbar button is visible.
      expect(find.byIcon(Icons.format_bold), findsOneWidget);

      // Tap the List button.
      await tester.tap(toolbarChipFor(Icons.format_list_bulleted));
      await tester.pump();

      // The edit block should still be active with the prefix applied.
      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '- hello');
    });
  });

  group('Preview cursor positioning', () {
    testWidgets('left-side preview tap places cursor near start', (
      tester,
    ) async {
      await seedNote('abcdefghij\n');
      await pumpQuickNote(tester);

      final preview = previewInkWellFor(find.byType(MarkdownBody).first);
      final topLeft = tester.getTopLeft(preview);
      final height = tester.getSize(preview).height;

      await tester.tapAt(topLeft + Offset(20, height / 2));
      await tester.pump();
      await tester.pump();

      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, 'abcdefghij');
      expect(editingField.controller!.selection.baseOffset, lessThan(4));
    });

    testWidgets('right-side preview tap places cursor near end', (
      tester,
    ) async {
      await seedNote('abcdefghij\n');
      await pumpQuickNote(tester);

      final preview = previewInkWellFor(find.byType(MarkdownBody).first);
      final topLeft = tester.getTopLeft(preview);
      final size = tester.getSize(preview);

      await tester.tapAt(topLeft + Offset(size.width - 20, size.height / 2));
      await tester.pump();
      await tester.pump();

      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, 'abcdefghij');
      expect(editingField.controller!.selection.baseOffset, greaterThan(6));
    });
  });

  group('Code block editing', () {
    testWidgets('toolbar inserts fenced code block and edits code line', (
      tester,
    ) async {
      await pumpQuickNote(tester);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(toolbarChipFor(Icons.developer_mode));
      await tester.pump();
      await tester.pump();

      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, 'code');
      expect(editingField.controller!.selection.baseOffset, 4);
      expect(find.text('```'), findsNWidgets(2));
    });

    testWidgets('fenced task text renders as code, not checkbox', (
      tester,
    ) async {
      await seedNote('```\n- [ ] code task\n```\n');
      await pumpQuickNote(tester);

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('- [ ] code task'), findsOneWidget);
    });
  });

  group('Mobile keyboard toolbar', () {
    testWidgets('compact keyboard toolbar applies task prefix and done', (
      tester,
    ) async {
      await pumpCompactWithKeyboard(tester);
      await tester.enterText(find.byType(TextField), 'call');
      await tester.pump();

      await tester.tap(iconButtonFor(Icons.checklist));
      await tester.pump();

      var editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '- [ ] call');

      await tester.tap(iconButtonFor(Icons.check_outlined));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
    });
  });

  group('Preview link actions', () {
    testWidgets('link tap opens actions without entering edit mode', (
      tester,
    ) async {
      await seedNote('[Docs](https://example.com)\n');
      await pumpQuickNote(tester);

      await tester.tap(previewText('Docs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Edit link'), findsOneWidget);
      final editingFields = tester.widgetList<TextField>(
        find.byType(TextField),
      );
      expect(
        editingFields.any(
          (field) => field.controller?.text == '[Docs](https://example.com)',
        ),
        false,
      );

      await tester.tap(find.text('Copy link'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboard?.text, 'https://example.com');
    });

    testWidgets('edit link action focuses markdown source at link start', (
      tester,
    ) async {
      await seedNote('[Docs](https://example.com)\n');
      await pumpQuickNote(tester);

      await tester.tap(previewText('Docs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Edit link'));
      await tester.pump();
      await tester.pump();

      final editingField = tester.widget<TextField>(find.byType(TextField));
      expect(editingField.controller!.text, '[Docs](https://example.com)');
      expect(editingField.controller!.selection.baseOffset, 0);
    });
  });

  group('Long document scroll follow', () {
    testWidgets('opening a long note keeps the trailing editor visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final content = List.generate(80, (index) => 'Line $index').join('\n');
      await seedNote(content);
      await pumpQuickNote(tester);

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      final fieldFinder = find.byType(TextField);
      expect(fieldFinder, findsOneWidget);
      expect(tester.getBottomLeft(fieldFinder).dy, lessThan(700));

      await tester.enterText(fieldFinder, 'tail');
      await tester.pump(const Duration(milliseconds: 250));

      expect(fieldFinder, findsOneWidget);
      expect(tester.getBottomLeft(fieldFinder).dy, lessThan(700));
    });
  });

  group('Product polish actions', () {
    testWidgets('copy menu copies the current paragraph', (tester) async {
      await seedNote('Alpha paragraph\n');
      await pumpQuickNote(tester);

      await tester.tap(previewInkWellFor(find.byType(MarkdownBody).first));
      await tester.pump();
      await tester.pump();

      await tester.tap(iconButtonFor(Icons.copy_all_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Copy current paragraph'));
      await tester.pump();

      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboard?.text, 'Alpha paragraph');
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('copy menu still supports copying the whole note', (
      tester,
    ) async {
      await seedNote('Alpha\nBeta\n');
      await pumpQuickNote(tester);

      await tester.tap(iconButtonFor(Icons.copy_all_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Copy all Markdown'));
      await tester.pump();

      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      expect(clipboard?.text, 'Alpha\nBeta');
    }, timeout: const Timeout(Duration(seconds: 30)));

    testWidgets('recent note delete action is hidden behind more menu', (
      tester,
    ) async {
      await seedNote('Alpha\n');
      await pumpQuickNote(tester);

      await tester.tap(iconButtonFor(Icons.history_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.more_horiz_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      await tester.tap(find.byIcon(Icons.more_horiz_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
