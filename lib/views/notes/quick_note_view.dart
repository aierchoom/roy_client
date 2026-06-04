import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/quick_note.dart';
import '../../services/quick_note_store.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive_page.dart';

class QuickNoteView extends StatefulWidget {
  const QuickNoteView({super.key});

  @override
  State<QuickNoteView> createState() => _QuickNoteViewState();
}

class _QuickNoteViewState extends State<QuickNoteView> {
  final QuickNoteStore _store = QuickNoteStore();
  final List<_MarkdownBlock> _blocks = [];
  List<QuickNote> _notes = [];
  String? _activeNoteId;
  int _nextBlockId = 0;
  int _editingIndex = 0;
  bool _showTools = false;
  bool _splittingBlock = false;
  bool _loadingNote = true;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _blocks.add(_createBlock(''));
    _loadNotes();
  }

  @override
  void dispose() {
    unawaited(_persistActiveNote(_plainMarkdown));
    _saveTimer?.cancel();
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  int get _characterCount =>
      _blocks.fold(0, (sum, block) => sum + block.text.characters.length);

  String get _plainMarkdown {
    return _blocks.map((block) => block.text).join('\n').trimRight();
  }

  String get _displayTitle {
    for (final block in _blocks) {
      final title = _stripMarkdown(block.text).trim();
      if (title.isNotEmpty) return title;
    }
    return '';
  }

  _MarkdownBlock _createBlock(String text) {
    final block = _MarkdownBlock(
      id: 'quick-note-${_nextBlockId++}',
      text: text,
    );
    block.controller.addListener(() => _handleBlockChanged(block));
    return block;
  }

  _MarkdownBlock? get _activeBlock {
    if (_editingIndex < 0 || _editingIndex >= _blocks.length) return null;
    return _blocks[_editingIndex];
  }

  Future<void> _loadNotes() async {
    final snapshot = await _store.load();
    if (!mounted) return;

    _notes = snapshot.notes;
    _activeNoteId = snapshot.activeNoteId;
    _loadNoteContent(_activeNote?.content ?? '');
    _loadingNote = false;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editBlock(
        _editingIndex,
        cursorOffset: _blocks[_editingIndex].text.length,
      );
    });
  }

  QuickNote? get _activeNote {
    final activeNoteId = _activeNoteId;
    if (activeNoteId == null) return null;
    for (final note in _notes) {
      if (note.id == activeNoteId) return note;
    }
    return null;
  }

  void _loadNoteContent(String content) {
    for (final block in _blocks) {
      block.dispose();
    }
    _blocks.clear();

    final lines = content.isEmpty ? [''] : content.split('\n');
    _blocks.addAll(lines.map(_createBlock));
    if (_blocks.isEmpty || _blocks.last.text.trim().isNotEmpty) {
      _blocks.add(_createBlock(''));
    }
    _editingIndex = _blocks.length - 1;
  }

  void _scheduleDraftSave() {
    if (_loadingNote) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 450), () async {
      await _persistActiveNote(_plainMarkdown);
    });
  }

  Future<void> _persistActiveNote(String content) async {
    final activeNote = _activeNote;
    if (activeNote == null) return;
    final updated = activeNote.copyWith(content: content);
    await _store.saveNote(updated);
    if (!mounted) return;
    final snapshot = await _store.pruneEmptyNotes(keepNoteId: updated.id);
    if (!mounted) return;
    setState(() {
      _notes = snapshot.notes;
      _activeNoteId = updated.id;
    });
  }

  String _stripMarkdown(String value) {
    return value
        .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
        .replaceFirst(RegExp(r'^\s*-\s+\[[ xX]\]\s+'), '')
        .replaceFirst(RegExp(r'^\s*[-*]\s+'), '')
        .replaceFirst(RegExp(r'^\s*>\s?'), '')
        .replaceAll(RegExp(r'[*_`~]'), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match.group(1) ?? '',
        );
  }

  String _continuationPrefix(String value) {
    final task = RegExp(r'^(\s*-\s+\[[ xX]\]\s+).+').firstMatch(value);
    if (task != null) return task.group(1)!;

    final unordered = RegExp(r'^(\s*[-*]\s+).+').firstMatch(value);
    if (unordered != null) return unordered.group(1)!;

    final quote = RegExp(r'^(>\s?).+').firstMatch(value);
    if (quote != null) return quote.group(1)!;

    return '';
  }

  bool _isBareContinuation(String value) {
    return RegExp(r'^\s*[-*]\s*$').hasMatch(value) ||
        RegExp(r'^\s*-\s+\[[ xX]\]\s*$').hasMatch(value) ||
        RegExp(r'^>\s*$').hasMatch(value);
  }

  void _handleBlockChanged(_MarkdownBlock block) {
    if (_splittingBlock) return;
    final index = _blocks.indexOf(block);
    if (index < 0) return;

    final text = block.text;
    if (!text.contains('\n')) {
      setState(() {});
      _scheduleDraftSave();
      return;
    }

    final caret = block.controller.selection.baseOffset.clamp(0, text.length);
    final parts = text.split('\n');
    var targetPartIndex = 0;
    var partStart = 0;
    for (var i = 0, offset = 0; i < parts.length; i++) {
      final end = offset + parts[i].length;
      if (caret <= end || i == parts.length - 1) {
        targetPartIndex = i;
        partStart = offset;
        break;
      }
      offset = end + 1;
    }

    final inserted = parts.skip(1).map(_createBlock).toList();
    if (parts.length == 2 && parts[1].isEmpty) {
      if (_isBareContinuation(parts.first)) {
        parts[0] = '';
        inserted.clear();
        targetPartIndex = 0;
      } else {
        final prefix = _continuationPrefix(parts.first);
        if (prefix.isNotEmpty) {
          inserted
            ..clear()
            ..add(_createBlock(prefix));
          targetPartIndex = 1;
        }
      }
    }
    final nextIndex = index + targetPartIndex;
    final nextOffset = (caret - partStart).clamp(
      0,
      targetPartIndex == 0
          ? parts.first.length
          : inserted[targetPartIndex - 1].text.length,
    );

    _splittingBlock = true;
    block.controller.value = TextEditingValue(
      text: parts.first,
      selection: TextSelection.collapsed(offset: parts.first.length),
    );
    _blocks.insertAll(index + 1, inserted);
    _editingIndex = nextIndex;
    _splittingBlock = false;

    setState(() {});
    _scheduleDraftSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nextBlock = _blocks[nextIndex];
      nextBlock.focusNode.requestFocus();
      nextBlock.controller.selection = TextSelection.collapsed(
        offset: nextOffset,
      );
    });
  }

  void _editBlock(int index, {int? cursorOffset}) {
    if (index < 0 || index >= _blocks.length) return;
    setState(() => _editingIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final block = _blocks[index];
      block.focusNode.requestFocus();
      block.controller.selection = TextSelection.collapsed(
        offset: cursorOffset ?? block.text.length,
      );
    });
  }

  void _finishEditing() {
    setState(() => _editingIndex = -1);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _continueAtEnd() {
    if (_blocks.isEmpty) {
      setState(() {
        _blocks.add(_createBlock(''));
        _editingIndex = 0;
      });
      _editBlock(0);
      return;
    }

    final lastIndex = _blocks.length - 1;
    if (_blocks[lastIndex].text.trim().isEmpty) {
      _editBlock(lastIndex);
      return;
    }

    setState(() {
      _blocks.add(_createBlock(''));
      _editingIndex = _blocks.length - 1;
    });
    _editBlock(_editingIndex);
  }

  Future<void> _createNewNote() async {
    await _persistActiveNote(_plainMarkdown);
    await _store.pruneEmptyNotes(keepNoteId: _activeNoteId);
    final note = await _store.createNote();
    final snapshot = await _store.load();
    if (!mounted) return;
    setState(() {
      _notes = snapshot.notes;
      _activeNoteId = note.id;
      _loadingNote = true;
      _loadNoteContent('');
      _loadingNote = false;
    });
    _editBlock(_editingIndex);
  }

  Future<void> _switchNote(QuickNote note) async {
    await _persistActiveNote(_plainMarkdown);
    await _store.pruneEmptyNotes(keepNoteId: note.id);
    await _store.setActiveNote(note.id);
    final snapshot = await _store.load();
    if (!mounted) return;
    setState(() {
      _notes = snapshot.notes;
      _activeNoteId = note.id;
      _loadingNote = true;
      _loadNoteContent(note.content);
      _loadingNote = false;
    });
    _editBlock(_editingIndex);
  }

  Future<void> _openNotesSheet() async {
    await _persistActiveNote(_plainMarkdown);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _QuickNoteListSheet(
        notes: _notes,
        activeNoteId: _activeNoteId,
        onCreateNote: () async {
          Navigator.pop(context);
          await _createNewNote();
        },
        onSelectNote: (note) async {
          Navigator.pop(context);
          await _switchNote(note);
        },
        onDeleteNote: (note) async {
          final sheetNavigator = Navigator.of(context);
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(context.text('删除随手记', 'Delete note')),
              content: Text(
                context.text(
                  '这条随手记会从本地移除。',
                  'This note will be removed locally.',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.text('取消', 'Cancel')),
                ),
                FilledButton.tonal(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.text('删除', 'Delete')),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          final snapshot = await _store.deleteNote(note.id);
          if (!mounted) return;
          sheetNavigator.pop();
          final nextActiveNote = snapshot.notes.firstWhere(
            (item) => item.id == snapshot.activeNoteId,
            orElse: () => snapshot.notes.first,
          );
          setState(() {
            _notes = snapshot.notes;
            _activeNoteId = snapshot.activeNoteId;
            _loadingNote = true;
            _loadNoteContent(nextActiveNote.content);
            _loadingNote = false;
          });
          _editBlock(_editingIndex);
        },
      ),
    );
  }

  Future<void> _copyMarkdown() async {
    await Clipboard.setData(ClipboardData(text: _plainMarkdown));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.text('Markdown 已复制', 'Markdown copied'))),
    );
  }

  void _removeEmptyBlock(int index) {
    if (_blocks.length <= 1 || index <= 0 || index >= _blocks.length) return;
    final previous = _blocks[index - 1];
    final removed = _blocks.removeAt(index);
    removed.dispose();
    setState(() => _editingIndex = index - 1);
    _scheduleDraftSave();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      previous.focusNode.requestFocus();
      previous.controller.selection = TextSelection.collapsed(
        offset: previous.text.length,
      );
    });
  }

  void _replaceSelection(String replacement, {int? cursorOffset}) {
    final block = _activeBlock;
    if (block == null) {
      _continueAtEnd();
      return;
    }

    final selection = block.controller.selection;
    final text = block.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final nextText = text.replaceRange(start, end, replacement);
    final nextOffset = start + (cursorOffset ?? replacement.length);
    block.controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: nextOffset.clamp(0, nextText.length),
      ),
    );
    block.focusNode.requestFocus();
  }

  void _surroundSelection(String before, String after, String placeholder) {
    final block = _activeBlock;
    if (block == null) {
      _continueAtEnd();
      return;
    }

    final selection = block.controller.selection;
    final text = block.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = start == end ? placeholder : text.substring(start, end);
    _replaceSelection(
      '$before$selected$after',
      cursorOffset: start == end ? before.length + selected.length : null,
    );
  }

  void _insertLinePrefix(String prefix) {
    final block = _activeBlock;
    if (block == null) {
      _continueAtEnd();
      return;
    }

    final selection = block.controller.selection;
    final text = block.text;
    final caret = selection.isValid ? selection.start : text.length;
    final lineStart = text.lastIndexOf('\n', caret > 0 ? caret - 1 : 0) + 1;
    block.controller.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: caret + prefix.length),
    );
    block.focusNode.requestFocus();
  }

  void _insertLink() {
    final block = _activeBlock;
    if (block == null) {
      _continueAtEnd();
      return;
    }

    final selection = block.controller.selection;
    final text = block.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = start == end
        ? context.text('链接文字', 'Link text')
        : text.substring(start, end);
    final replacement = '[$selected](https://)';
    _replaceSelection(replacement, cursorOffset: replacement.length - 1);
  }

  MarkdownStyleSheet _markdownStyle(ThemeData theme) {
    final colors = theme.colorScheme;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.78),
      h1: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
      h2: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      blockquote: theme.textTheme.bodyLarge?.copyWith(
        color: colors.onSurfaceVariant,
        height: 1.72,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.primary.withAlpha(AppAlphas.tint),
        border: Border(left: BorderSide(color: colors.primary, width: 2)),
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: colors.primary.withAlpha(AppAlphas.tint),
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.primary.withAlpha(AppAlphas.tint),
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = AppLayout.of(context);
    final colors = theme.colorScheme;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final pageBackground = Color.alphaBlend(
      colors.primary.withAlpha(AppAlphas.tint),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge(_blocks.map((block) => block.controller)),
          builder: (context, _) {
            return AdaptivePage(
              tabletMaxWidth: 860,
              desktopMaxWidth: 900,
              padding: EdgeInsets.fromLTRB(
                layout.isCompact ? AppSpacing.md : AppSpacing.xxl,
                layout.isCompact ? AppSpacing.sm : AppSpacing.xl,
                layout.isCompact ? AppSpacing.md : AppSpacing.xxl,
                keyboardVisible ? AppSpacing.md : AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!keyboardVisible || !layout.isCompact)
                    _QuickNoteTopBar(
                      title: _displayTitle,
                      characterCount: _characterCount,
                      editing: _editingIndex >= 0,
                      showTools: _showTools,
                      noteCount: _notes.length,
                      onNewNoteTap: _createNewNote,
                      onNotesTap: _openNotesSheet,
                      onCopyTap: _copyMarkdown,
                      onDoneTap: _finishEditing,
                      onToolsTap: () =>
                          setState(() => _showTools = !_showTools),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: _showTools ? 46 : 0,
                    curve: Curves.easeOut,
                    child: _showTools
                        ? _buildToolbar()
                        : const SizedBox.shrink(),
                  ),
                  SizedBox(
                    height: (!keyboardVisible || !layout.isCompact)
                        ? (layout.isCompact ? AppSpacing.sm : AppSpacing.md)
                        : 0,
                  ),
                  Expanded(
                    child: _DocumentPaper(
                      compact: layout.isCompact,
                      onBlankTap: _continueAtEnd,
                      child: _buildBlockList(theme, layout),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBlockList(ThemeData theme, AppLayoutData layout) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? AppSpacing.lg : AppSpacing.xxl,
        vertical: layout.isCompact ? AppSpacing.md : AppSpacing.xl,
      ),
      itemCount: _blocks.length + 1,
      separatorBuilder: (context, index) => const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index == _blocks.length) {
          return _AppendBlockSpace(onTap: _continueAtEnd);
        }

        final block = _blocks[index];
        if (index == _editingIndex) {
          return _EditableMarkdownBlock(
            key: ValueKey('${block.id}-editor'),
            block: block,
            onBackspaceEmpty: () => _removeEmptyBlock(index),
          );
        }

        return _PreviewMarkdownBlock(
          key: ValueKey('${block.id}-preview'),
          text: block.text,
          styleSheet: _markdownStyle(theme),
          onTap: () => _editBlock(index),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ToolButton(
            icon: Icons.title,
            label: 'H2',
            onTap: () => _insertLinePrefix('## '),
          ),
          _ToolButton(
            icon: Icons.format_bold,
            label: context.text('粗体', 'Bold'),
            onTap: () =>
                _surroundSelection('**', '**', context.text('重点', 'Important')),
          ),
          _ToolButton(
            icon: Icons.format_list_bulleted,
            label: context.text('列表', 'List'),
            onTap: () => _insertLinePrefix('- '),
          ),
          _ToolButton(
            icon: Icons.checklist,
            label: context.text('待办', 'Task'),
            onTap: () => _insertLinePrefix('- [ ] '),
          ),
          _ToolButton(
            icon: Icons.format_quote,
            label: context.text('引用', 'Quote'),
            onTap: () => _insertLinePrefix('> '),
          ),
          _ToolButton(
            icon: Icons.code,
            label: context.text('代码', 'Code'),
            onTap: () => _surroundSelection('`', '`', 'code'),
          ),
          _ToolButton(
            icon: Icons.link,
            label: context.text('链接', 'Link'),
            onTap: _insertLink,
          ),
        ],
      ),
    );
  }
}

class _MarkdownBlock {
  final String id;
  final _MarkdownEditingController controller;
  final FocusNode focusNode;

  _MarkdownBlock({required this.id, required String text})
    : controller = _MarkdownEditingController(text: text),
      focusNode = FocusNode();

  String get text => controller.text;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _MarkdownEditingController extends TextEditingController {
  _MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (withComposing &&
        value.composing.isValid &&
        !value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final colors = theme.colorScheme;
    final mutedStyle = baseStyle.copyWith(
      color: colors.onSurfaceVariant.withAlpha(AppAlphas.medium),
      fontWeight: FontWeight.w600,
    );
    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (var index = 0; index < lines.length; index++) {
      if (index > 0) spans.add(const TextSpan(text: '\n'));
      spans.addAll(_lineSpans(context, lines[index], baseStyle, mutedStyle));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  List<InlineSpan> _lineSpans(
    BuildContext context,
    String line,
    TextStyle baseStyle,
    TextStyle mutedStyle,
  ) {
    final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      final level = heading.group(1)!.length;
      final content = heading.group(2)!;
      final contentStyle = switch (level) {
        1 => Theme.of(context).textTheme.headlineMedium,
        2 => Theme.of(context).textTheme.headlineSmall,
        _ => Theme.of(context).textTheme.titleLarge,
      };
      return [
        TextSpan(text: '${heading.group(1)} ', style: mutedStyle),
        ..._inlineSpans(
          context,
          content,
          (contentStyle ?? baseStyle).copyWith(fontWeight: FontWeight.w800),
          mutedStyle,
        ),
      ];
    }

    final quote = RegExp(r'^(>\s?)(.*)$').firstMatch(line);
    if (quote != null) {
      return [
        TextSpan(text: quote.group(1), style: mutedStyle),
        ..._inlineSpans(
          context,
          quote.group(2)!,
          baseStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
          mutedStyle,
        ),
      ];
    }

    final task = RegExp(r'^(\s*-\s+\[[ xX]\]\s+)(.*)$').firstMatch(line);
    if (task != null) {
      return [
        TextSpan(text: task.group(1), style: mutedStyle),
        ..._inlineSpans(context, task.group(2)!, baseStyle, mutedStyle),
      ];
    }

    final list = RegExp(r'^(\s*(?:[-*]|\d+\.)\s+)(.*)$').firstMatch(line);
    if (list != null) {
      return [
        TextSpan(text: list.group(1), style: mutedStyle),
        ..._inlineSpans(context, list.group(2)!, baseStyle, mutedStyle),
      ];
    }

    return _inlineSpans(context, line, baseStyle, mutedStyle);
  }

  List<InlineSpan> _inlineSpans(
    BuildContext context,
    String source,
    TextStyle baseStyle,
    TextStyle mutedStyle,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*|\[[^\]]+\]\([^)]+\))',
    );
    var cursor = 0;

    for (final match in pattern.allMatches(source)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: source.substring(cursor, match.start)));
      }

      final token = match.group(0)!;
      if (token.startsWith('**') && token.endsWith('**')) {
        spans
          ..add(TextSpan(text: '**', style: mutedStyle))
          ..add(
            TextSpan(
              text: token.substring(2, token.length - 2),
              style: baseStyle.copyWith(fontWeight: FontWeight.w800),
            ),
          )
          ..add(TextSpan(text: '**', style: mutedStyle));
      } else if (token.startsWith('`') && token.endsWith('`')) {
        spans
          ..add(TextSpan(text: '`', style: mutedStyle))
          ..add(
            TextSpan(
              text: token.substring(1, token.length - 1),
              style: baseStyle.copyWith(
                fontFamily: 'monospace',
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withAlpha(AppAlphas.tint),
              ),
            ),
          )
          ..add(TextSpan(text: '`', style: mutedStyle));
      } else if (token.startsWith('*') && token.endsWith('*')) {
        spans
          ..add(TextSpan(text: '*', style: mutedStyle))
          ..add(
            TextSpan(
              text: token.substring(1, token.length - 1),
              style: baseStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          )
          ..add(TextSpan(text: '*', style: mutedStyle));
      } else {
        final link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)$').firstMatch(token);
        if (link == null) {
          spans.add(TextSpan(text: token));
        } else {
          spans
            ..add(TextSpan(text: '[', style: mutedStyle))
            ..add(
              TextSpan(
                text: link.group(1),
                style: baseStyle.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
            ..add(TextSpan(text: '](${link.group(2)})', style: mutedStyle));
        }
      }

      cursor = match.end;
    }

    if (cursor < source.length) {
      spans.add(TextSpan(text: source.substring(cursor)));
    }

    return spans;
  }
}

class _QuickNoteListSheet extends StatelessWidget {
  final List<QuickNote> notes;
  final String? activeNoteId;
  final Future<void> Function() onCreateNote;
  final Future<void> Function(QuickNote note) onSelectNote;
  final Future<void> Function(QuickNote note) onDeleteNote;

  const _QuickNoteListSheet({
    required this.notes,
    required this.activeNoteId,
    required this.onCreateNote,
    required this.onSelectNote,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  context.text('最近随手记', 'Recent notes'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onCreateNote,
                  icon: const Icon(Icons.add_outlined),
                  label: Text(context.text('新建', 'New')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: notes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final selected = note.id == activeNoteId;
                  return Material(
                    color: selected
                        ? colors.primary.withAlpha(AppAlphas.tint)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                      leading: Icon(
                        selected ? Icons.edit_note : Icons.edit_note_outlined,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      title: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${note.preview} · ${_formatTime(note.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        onPressed: () => onDeleteNote(note),
                        tooltip: context.text('删除', 'Delete'),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      onTap: () => onSelectNote(note),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return '${value.month}/${value.day}';
  }
}

class _QuickNoteTopBar extends StatelessWidget {
  final String title;
  final int characterCount;
  final bool editing;
  final bool showTools;
  final int noteCount;
  final VoidCallback onNewNoteTap;
  final VoidCallback onNotesTap;
  final VoidCallback onCopyTap;
  final VoidCallback onDoneTap;
  final VoidCallback onToolsTap;

  const _QuickNoteTopBar({
    required this.title,
    required this.characterCount,
    required this.editing,
    required this.showTools,
    required this.noteCount,
    required this.onNewNoteTap,
    required this.onNotesTap,
    required this.onCopyTap,
    required this.onDoneTap,
    required this.onToolsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Icon(Icons.edit_note_outlined, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title.isEmpty ? context.text('随手记', 'Quick Note') : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            characterCount == 0
                ? context.text('直接写', 'Just write')
                : context.text('$characterCount 字符', '$characterCount chars'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _TopBarButton(
            icon: Icons.note_add_outlined,
            selected: false,
            tooltip: context.text('新建随手记', 'New note'),
            onTap: onNewNoteTap,
          ),
          _TopBarButton(
            icon: Icons.history_outlined,
            selected: false,
            tooltip: context.text('最近随手记', 'Recent notes'),
            onTap: onNotesTap,
            badgeLabel: noteCount > 1 ? '$noteCount' : null,
          ),
          _TopBarButton(
            icon: Icons.copy_all_outlined,
            selected: false,
            tooltip: context.text('复制 Markdown', 'Copy Markdown'),
            onTap: onCopyTap,
          ),
          _TopBarButton(
            icon: showTools
                ? Icons.keyboard_hide_outlined
                : Icons.add_circle_outline,
            selected: showTools,
            tooltip: context.text('格式', 'Format'),
            onTap: onToolsTap,
          ),
          if (editing)
            _TopBarButton(
              icon: Icons.check_outlined,
              selected: false,
              tooltip: context.text('完成当前段落', 'Finish current paragraph'),
              onTap: onDoneTap,
            ),
        ],
      ),
    );
  }
}

class _EditableMarkdownBlock extends StatelessWidget {
  final _MarkdownBlock block;
  final VoidCallback onBackspaceEmpty;

  const _EditableMarkdownBlock({
    super.key,
    required this.block,
    required this.onBackspaceEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            block.text.isEmpty) {
          onBackspaceEmpty();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          autofocus: true,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          cursorColor: colors.primary,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.78),
          decoration: InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            hoverColor: Colors.transparent,
            hintText: context.text('记点什么…', 'Jot something…'),
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant.withAlpha(AppAlphas.high),
              height: 1.78,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isCollapsed: true,
          ),
        ),
      ),
    );
  }
}

class _PreviewMarkdownBlock extends StatelessWidget {
  final String text;
  final MarkdownStyleSheet styleSheet;
  final VoidCallback onTap;

  const _PreviewMarkdownBlock({
    super.key,
    required this.text,
    required this.styleSheet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox(height: AppSpacing.sm);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      splashColor: Theme.of(
        context,
      ).colorScheme.primary.withAlpha(AppAlphas.tint),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        child: MarkdownBody(
          data: text,
          selectable: false,
          styleSheet: styleSheet,
        ),
      ),
    );
  }
}

class _AppendBlockSpace extends StatelessWidget {
  final VoidCallback onTap;

  const _AppendBlockSpace({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: const SizedBox(height: 140),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;
  final String? badgeLabel;

  const _TopBarButton({
    required this.icon,
    required this.selected,
    required this.tooltip,
    required this.onTap,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 20),
          if (badgeLabel != null)
            Positioned(
              right: -8,
              top: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  badgeLabel!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? theme.colorScheme.primary.withAlpha(AppAlphas.tint)
            : Colors.transparent,
        minimumSize: const Size(36, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Color.alphaBlend(
          colors.primary.withAlpha(AppAlphas.tint),
          colors.surface,
        ),
        side: BorderSide(color: colors.primary.withAlpha(AppAlphas.low)),
        visualDensity: VisualDensity.compact,
        labelStyle: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    );
  }
}

class _DocumentPaper extends StatelessWidget {
  final Widget child;
  final bool compact;
  final VoidCallback onBlankTap;

  const _DocumentPaper({
    required this.child,
    required this.compact,
    required this.onBlankTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final paperColor = Color.alphaBlend(
      colors.primary.withAlpha(AppAlphas.tint),
      colors.surface,
    );

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onBlankTap,
      child: Container(
        decoration: BoxDecoration(
          color: paperColor,
          borderRadius: BorderRadius.circular(
            compact ? AppRadii.panel : AppRadii.xl,
          ),
          border: Border.all(color: colors.primary.withAlpha(AppAlphas.subtle)),
          boxShadow: AppShadows.card(theme, depth: compact ? 0.06 : 0.12),
        ),
        child: child,
      ),
    );
  }
}
