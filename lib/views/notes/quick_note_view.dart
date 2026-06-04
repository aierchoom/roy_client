import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../l10n/app_text_extension.dart';
import '../../models/quick_note.dart';
import '../../services/quick_note_store.dart';
import '../../theme/theme.dart';
import '../../widgets/adaptive_page.dart';

const Duration _draftSaveDelay = Duration(milliseconds: 450);
const Duration _focusLossDelay = Duration(milliseconds: 80);
const Duration _scrollFollowDelay = Duration(milliseconds: 120);

class QuickNoteView extends StatefulWidget {
  const QuickNoteView({super.key});

  @override
  State<QuickNoteView> createState() => _QuickNoteViewState();
}

class _QuickNoteViewState extends State<QuickNoteView> {
  final QuickNoteStore _store = QuickNoteStore();
  final List<_MarkdownBlock> _blocks = [];
  final ScrollController _scrollController = ScrollController();
  List<QuickNote> _notes = [];
  String? _activeNoteId;
  int _nextBlockId = 0;
  int _editingIndex = 0;
  bool _showTools = false;
  bool _splittingBlock = false;
  bool _loadingNote = true;
  bool _ensureVisibleQueued = false;
  Timer? _saveTimer;
  Timer? _focusLossTimer;

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
    _focusLossTimer?.cancel();
    _scrollController.dispose();
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
    _saveTimer = Timer(_draftSaveDelay, () async {
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

    final ordered = RegExp(r'^(\s*)(\d+)([.)]\s+).+').firstMatch(value);
    if (ordered != null) {
      final indent = ordered.group(1)!;
      final num = int.parse(ordered.group(2)!) + 1;
      final delim = ordered.group(3)!;
      return '$indent$num$delim';
    }

    final quote = RegExp(r'^(>\s?).+').firstMatch(value);
    if (quote != null) return quote.group(1)!;

    return '';
  }

  bool _isBareContinuation(String value) {
    return RegExp(r'^\s*[-*]\s*$').hasMatch(value) ||
        RegExp(r'^\s*-\s+\[[ xX]\]\s*$').hasMatch(value) ||
        RegExp(r'^\s*\d+[.)]\s*$').hasMatch(value) ||
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
      if (index == _editingIndex) {
        _queueEnsureBlockVisible(index);
      }
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
    var continuationGenerated = false;
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
          continuationGenerated = true;
        }
      }
    }
    final nextIndex = index + targetPartIndex;
    final nextOffset = continuationGenerated
        ? inserted.first.text.length
        : (caret - partStart).clamp(
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
      _ensureBlockVisible(nextIndex);
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
      _ensureBlockVisible(index);
    });
  }

  void _queueEnsureBlockVisible(int index) {
    if (_ensureVisibleQueued) return;
    _ensureVisibleQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisibleQueued = false;
      if (!mounted) return;
      _ensureBlockVisible(index);
    });
  }

  void _ensureBlockVisible(int index, {int attempt = 0}) {
    if (index < 0 || index >= _blocks.length) return;
    final context = _blocks[index].itemKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: _scrollFollowDelay,
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      return;
    }
    if (_scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        final denominator = math.max(1, _blocks.length - 1);
        final target = maxExtent * (index / denominator);
        _scrollController.jumpTo(target.clamp(0.0, maxExtent));
      }
    }
    if (attempt >= 3) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureBlockVisible(index, attempt: attempt + 1);
    });
  }

  void _editBlockAtPreviewTap(
    int index, {
    required double localX,
    required double width,
    int rawPrefixLength = 0,
    double horizontalPadding = AppSpacing.lg,
  }) {
    if (index < 0 || index >= _blocks.length) return;
    final text = _blocks[index].text;
    final prefixLength = rawPrefixLength > 0
        ? rawPrefixLength
        : _previewCursorPrefixLength(text);
    final offset = _estimateCursorOffsetForTap(
      text,
      localX: localX,
      width: width,
      rawPrefixLength: prefixLength.clamp(0, text.length),
      horizontalPadding: horizontalPadding,
    );
    _editBlock(index, cursorOffset: offset);
  }

  void _finishEditing() {
    setState(() => _editingIndex = -1);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _restoreActiveBlockFocus() {
    if (_editingIndex < 0 || _editingIndex >= _blocks.length) return;
    _blocks[_editingIndex].focusNode.requestFocus();
  }

  void _toggleTools() {
    setState(() => _showTools = !_showTools);
    _restoreActiveBlockFocus();
  }

  void _toggleTask(int index) {
    if (index < 0 || index >= _blocks.length) return;
    final block = _blocks[index];
    final text = block.text;
    final match = RegExp(r'^(\s*-\s+)\[([ xX])\](.*)$').firstMatch(text);
    if (match == null) return;
    final newCheck = match.group(2)!.trim().isEmpty ? 'x' : ' ';
    block.controller.text = '${match.group(1)}[$newCheck]${match.group(3)}';
    setState(() {});
    _scheduleDraftSave();
  }

  void _onBlockFocusLost(int blockIndex) {
    _focusLossTimer?.cancel();
    _focusLossTimer = Timer(_focusLossDelay, () {
      if (!mounted) return;
      if (_editingIndex != blockIndex) return;
      final block = _blocks[blockIndex];
      if (block.focusNode.hasFocus) return;
      _finishEditing();
    });
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

  Future<void> _openCopyActions() async {
    final activeBlock = _activeBlock;
    final paragraph = activeBlock?.text.trimRight();
    final hasParagraph = paragraph != null && paragraph.trim().isNotEmpty;
    final action = await showModalBottomSheet<_CopyAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                enabled: hasParagraph,
                leading: const Icon(Icons.notes_outlined),
                title: Text(
                  context.text('澶嶅埗褰撳墠娈佃惤', 'Copy current paragraph'),
                ),
                subtitle: Text(
                  hasParagraph
                      ? paragraph
                      : context.text('褰撳墠娈佃惤涓虹┖', 'Current paragraph is empty'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: hasParagraph
                    ? () => Navigator.pop(sheetContext, _CopyAction.paragraph)
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(
                  context.text('澶嶅埗鏁寸瘒 Markdown', 'Copy all Markdown'),
                ),
                subtitle: Text(
                  _displayTitle.isEmpty
                      ? context.text('闅忔墜璁?', 'Quick Note')
                      : _displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetContext, _CopyAction.markdown),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _CopyAction.paragraph:
        if (!hasParagraph) return;
        await _copyToClipboard(
          paragraph,
          context.text('褰撳墠娈佃惤宸插鍒?', 'Current paragraph copied'),
        );
        return;
      case _CopyAction.markdown:
        await _copyToClipboard(
          _plainMarkdown,
          context.text('Markdown 宸插鍒?', 'Markdown copied'),
        );
        return;
    }
  }

  Future<void> _copyToClipboard(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.text('Markdown 已复制', 'Markdown copied'))),
    );
  }

  Future<void> _openLinkActions(
    int blockIndex, {
    required String label,
    required String href,
  }) async {
    final action = await showModalBottomSheet<_LinkAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(context.text('复制链接', 'Copy link')),
                subtitle: Text(
                  href,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetContext, _LinkAction.copy),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.text('编辑链接', 'Edit link')),
                subtitle: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetContext, _LinkAction.edit),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _LinkAction.copy:
        await Clipboard.setData(ClipboardData(text: href));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.text('链接已复制', 'Link copied'))),
        );
        break;
      case _LinkAction.edit:
        if (blockIndex < 0 || blockIndex >= _blocks.length) return;
        final source = _blocks[blockIndex].text;
        final markdown = '[$label]($href)';
        final offset = source.indexOf(markdown);
        _editBlock(
          blockIndex,
          cursorOffset: offset < 0 ? source.length : offset,
        );
        break;
    }
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

  void _insertCodeBlock() {
    final block = _activeBlock;
    if (block == null) {
      _continueAtEnd();
      return;
    }

    final selection = block.controller.selection;
    final text = block.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = start == end ? 'code' : text.substring(start, end);
    _replaceSelection('```\n$selected\n```', cursorOffset: 4 + selected.length);
  }

  List<_CodeLineKind> _codeLineKinds() {
    final kinds = <_CodeLineKind>[];
    var inFence = false;
    for (final block in _blocks) {
      final isFence = block.text.trimLeft().startsWith('```');
      if (isFence) {
        kinds.add(_CodeLineKind.fence);
        inFence = !inFence;
      } else {
        kinds.add(inFence ? _CodeLineKind.body : _CodeLineKind.none);
      }
    }
    return kinds;
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
                      onCopyTap: _openCopyActions,
                      onDoneTap: _finishEditing,
                      onToolsTap: _toggleTools,
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
                  if (keyboardVisible && layout.isCompact)
                    _MobileInputToolbar(
                      onListTap: () => _insertLinePrefix('- '),
                      onTaskTap: () => _insertLinePrefix('- [ ] '),
                      onBoldTap: () => _surroundSelection(
                        '**',
                        '**',
                        context.text('重点', 'Important'),
                      ),
                      onDoneTap: _finishEditing,
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
    final codeLineKinds = _codeLineKinds();
    return ListView.separated(
      controller: _scrollController,
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
        final codeLineKind = codeLineKinds[index];
        if (index == _editingIndex) {
          return _EditableMarkdownBlock(
            key: block.itemKey,
            block: block,
            onBackspaceEmpty: () => _removeEmptyBlock(index),
            onFocusLost: () => _onBlockFocusLost(index),
          );
        }

        return _PreviewMarkdownBlock(
          key: block.itemKey,
          text: block.text,
          codeLineKind: codeLineKind,
          styleSheet: _markdownStyle(theme),
          onTapAt: (localX, width, rawPrefixLength, horizontalPadding) =>
              _editBlockAtPreviewTap(
                index,
                localX: localX,
                width: width,
                rawPrefixLength: rawPrefixLength,
                horizontalPadding: horizontalPadding,
              ),
          onToggleTask: () => _toggleTask(index),
          onLinkTap: (label, href) =>
              _openLinkActions(index, label: label, href: href),
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
            icon: Icons.developer_mode,
            label: context.text('代码块', 'Block'),
            onTap: _insertCodeBlock,
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
  final GlobalKey itemKey = GlobalKey();
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

enum _CodeLineKind { none, fence, body }

enum _LinkAction { copy, edit }

enum _CopyAction { paragraph, markdown }

enum _NoteListAction { delete }

int _previewCursorPrefixLength(String text) {
  final heading = RegExp(r'^\s*#{1,6}\s+').firstMatch(text);
  if (heading != null) return heading.end;

  final task = RegExp(r'^\s*-\s+\[[ xX]\]\s*').firstMatch(text);
  if (task != null) return task.end;

  final list = RegExp(r'^\s*(?:[-*]|\d+[.)])\s+').firstMatch(text);
  if (list != null) return list.end;

  final quote = RegExp(r'^>\s?').firstMatch(text);
  if (quote != null) return quote.end;

  return 0;
}

int _estimateCursorOffsetForTap(
  String text, {
  required double localX,
  required double width,
  required int rawPrefixLength,
  required double horizontalPadding,
}) {
  if (text.isEmpty) return 0;
  final prefixLength = rawPrefixLength.clamp(0, text.length);
  final body = text.substring(prefixLength);
  if (body.isEmpty) return text.length;

  final contentWidth = math.max(1.0, width - horizontalPadding * 2);
  final contentX = (localX - horizontalPadding).clamp(0.0, contentWidth);
  final ratio = contentX / contentWidth;
  return prefixLength + (body.length * ratio).round().clamp(0, body.length);
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

    final list = RegExp(r'^(\s*(?:[-*]|\d+[.)])\s+)(.*)$').firstMatch(line);
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

class _QuickNoteListSheet extends StatefulWidget {
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
  State<_QuickNoteListSheet> createState() => _QuickNoteListSheetState();
}

class _QuickNoteListSheetState extends State<_QuickNoteListSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QuickNote> get _filteredNotes {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.notes;
    return widget.notes.where((note) {
      return note.title.toLowerCase().contains(query) ||
          note.preview.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final filteredNotes = _filteredNotes;

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
                  onPressed: widget.onCreateNote,
                  icon: const Icon(Icons.add_outlined),
                  label: Text(context.text('新建', 'New')),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                filled: true,
                fillColor: Color.alphaBlend(
                  colors.primary.withAlpha(AppAlphas.tint),
                  colors.surface,
                ),
                prefixIcon: const Icon(Icons.search_outlined),
                hintText: context.text('搜索随手记', 'Search notes'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.button),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: filteredNotes.isEmpty
                  ? _QuickNoteEmptyResult(onCreateNote: widget.onCreateNote)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredNotes.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final note = filteredNotes[index];
                        final selected = note.id == widget.activeNoteId;
                        return Material(
                          color: selected
                              ? colors.primary.withAlpha(AppAlphas.tint)
                              : colors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.button,
                              ),
                            ),
                            leading: Icon(
                              selected
                                  ? Icons.edit_note
                                  : Icons.edit_note_outlined,
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
                            trailing: PopupMenuButton<_NoteListAction>(
                              onSelected: (action) {
                                switch (action) {
                                  case _NoteListAction.delete:
                                    widget.onDeleteNote(note);
                                    break;
                                }
                              },
                              tooltip: context.text('删除', 'Delete'),
                              icon: const Icon(Icons.more_horiz_outlined),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: _NoteListAction.delete,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.delete_outline),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(context.text('鍒犻櫎', 'Delete')),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => widget.onSelectNote(note),
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

class _QuickNoteEmptyResult extends StatelessWidget {
  final Future<void> Function() onCreateNote;

  const _QuickNoteEmptyResult({required this.onCreateNote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_outlined,
            color: theme.colorScheme.onSurfaceVariant,
            size: 36,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.text('没有找到随手记', 'No notes found'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: onCreateNote,
            icon: const Icon(Icons.add_outlined),
            label: Text(context.text('新建一条', 'Create one')),
          ),
        ],
      ),
    );
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
  final VoidCallback onFocusLost;

  const _EditableMarkdownBlock({
    super.key,
    required this.block,
    required this.onBackspaceEmpty,
    required this.onFocusLost,
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
      onFocusChange: (hasFocus) {
        if (!hasFocus) onFocusLost();
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
  final _CodeLineKind codeLineKind;
  final MarkdownStyleSheet styleSheet;
  final void Function(
    double localX,
    double width,
    int rawPrefixLength,
    double horizontalPadding,
  )
  onTapAt;
  final VoidCallback? onToggleTask;
  final void Function(String label, String href)? onLinkTap;

  const _PreviewMarkdownBlock({
    super.key,
    required this.text,
    required this.codeLineKind,
    required this.styleSheet,
    required this.onTapAt,
    this.onToggleTask,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox(height: AppSpacing.sm);

    if (codeLineKind != _CodeLineKind.none) {
      return _buildCodePreview(context);
    }

    final taskMatch = RegExp(r'^(\s*-\s+)\[([ xX])\]\s*(.*)$').firstMatch(text);
    if (taskMatch != null && onToggleTask != null) {
      return _buildTaskPreview(context, taskMatch);
    }

    return _buildMarkdownPreview(context);
  }

  Widget _buildTaskPreview(BuildContext context, RegExpMatch taskMatch) {
    final isChecked = taskMatch.group(2)!.trim().toLowerCase() == 'x';
    final content = taskMatch.group(3)!;
    final leadingSpaces = text.length - text.trimLeft().length;
    final indentWidth = leadingSpaces * 8.0;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg + indentWidth,
        right: AppSpacing.lg,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isChecked,
              onChanged: (_) => onToggleTask!(),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InkWell(
                  onTapUp: (details) => onTapAt(
                    details.localPosition.dx,
                    constraints.maxWidth,
                    text.length - content.length,
                    0,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  splashColor: Theme.of(
                    context,
                  ).colorScheme.primary.withAlpha(AppAlphas.tint),
                  highlightColor: Colors.transparent,
                  child: MarkdownBody(
                    data: content.isEmpty ? ' ' : content,
                    selectable: false,
                    styleSheet: styleSheet,
                    onTapLink: _handleLinkTap,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownPreview(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          onTapUp: (details) => onTapAt(
            details.localPosition.dx,
            constraints.maxWidth,
            0,
            AppSpacing.lg,
          ),
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
              onTapLink: _handleLinkTap,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCodePreview(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isFence = codeLineKind == _CodeLineKind.fence;
    final label = isFence && text.trimLeft().length > 3
        ? text.trimLeft().substring(3).trim()
        : '';
    final display = isFence ? (label.isEmpty ? '```' : '``` $label') : text;

    return LayoutBuilder(
      builder: (context, constraints) {
        return InkWell(
          onTapUp: (details) => onTapAt(
            details.localPosition.dx,
            constraints.maxWidth,
            0,
            AppSpacing.lg,
          ),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          splashColor: colors.primary.withAlpha(AppAlphas.tint),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(
                  isFence ? AppAlphas.subtle : AppAlphas.tint,
                ),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  display.isEmpty ? ' ' : display,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: isFence ? colors.onSurfaceVariant : colors.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleLinkTap(String text, String? href, String title) {
    if (href == null || href.isEmpty) return;
    onLinkTap?.call(text, href);
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

class _MobileInputToolbar extends StatelessWidget {
  final VoidCallback onListTap;
  final VoidCallback onTaskTap;
  final VoidCallback onBoldTap;
  final VoidCallback onDoneTap;

  const _MobileInputToolbar({
    required this.onListTap,
    required this.onTaskTap,
    required this.onBoldTap,
    required this.onDoneTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            colors.primary.withAlpha(AppAlphas.tint),
            colors.surface,
          ),
          borderRadius: BorderRadius.circular(AppRadii.button),
          border: Border.all(color: colors.primary.withAlpha(AppAlphas.low)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MobileInputButton(
                icon: Icons.format_list_bulleted,
                tooltip: context.text('列表', 'List'),
                onTap: onListTap,
              ),
              _MobileInputButton(
                icon: Icons.checklist,
                tooltip: context.text('待办', 'Task'),
                onTap: onTaskTap,
              ),
              _MobileInputButton(
                icon: Icons.format_bold,
                tooltip: context.text('粗体', 'Bold'),
                onTap: onBoldTap,
              ),
              _MobileInputButton(
                icon: Icons.check_outlined,
                tooltip: context.text('完成', 'Done'),
                onTap: onDoneTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileInputButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MobileInputButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      color: colors.onSurfaceVariant,
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 36),
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
