import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_comment_draft_store.dart';
import 'package:tree_launcher/features/jira/domain/jira_constants.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_wiki_text.dart';

/// Writes a comment on [issueKey]: wiki markup with a small formatting
/// toolbar, `@` to mention someone who can see the issue, a preview, and a
/// choice between everyone and the Consultants role. What is typed is saved
/// as a draft as it is typed, and comes back when the issue is opened again.
class JiraCommentComposer extends StatefulWidget {
  const JiraCommentComposer({
    super.key,
    required this.issueKey,
    required this.service,
    required this.drafts,
    required this.onPosted,
    this.mentionName,
    this.onOpenImage,
  });

  final String issueKey;
  final JiraApiService service;
  final JiraCommentDraftStore drafts;

  /// Called after the comment was added to the issue.
  final VoidCallback onPosted;

  /// The display name of a mentioned username, when known (for the preview).
  final String? Function(String user)? mentionName;
  final ValueChanged<String>? onOpenImage;

  @override
  State<JiraCommentComposer> createState() => _JiraCommentComposerState();
}

class _JiraCommentComposerState extends State<JiraCommentComposer> {
  static const _saveDelay = Duration(milliseconds: 600);
  static const _searchDelay = Duration(milliseconds: 250);

  /// An `@query` that ends at the cursor (a mention being typed).
  static final _mentionAtCursor = RegExp(r'(?:^|[\s(])@([\w.@-]{0,40})$');

  final _text = TextEditingController();
  late final _focus = FocusNode(onKeyEvent: _onKey);

  bool _loaded = false;
  bool _consultantsOnly = false;
  bool _preview = false;
  bool _sending = false;
  String? _error;

  /// The text last seen, to tell typing from cursor moves.
  String _lastText = '';
  Timer? _saveTimer;
  bool _unsaved = false;
  DateTime? _savedAt;

  /// Where the `@` of the mention being typed is, and what follows it.
  int? _mentionStart;
  String? _mentionQuery;
  List<JiraUser> _suggestions = const [];
  int _highlighted = 0;
  Timer? _searchTimer;
  int _searchSeq = 0;

  /// Display names of the users picked here, for the preview.
  final _pickedNames = <String, String>{};

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _loadDraft();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _searchTimer?.cancel();
    // Keep what was typed since the last save.
    if (_unsaved) unawaited(_save());
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    final draft = await widget.drafts.read(widget.issueKey);
    final consultantsOnly =
        draft?.consultantsOnly ?? await widget.drafts.lastConsultantsOnly();
    if (!mounted) return;
    setState(() {
      _consultantsOnly = consultantsOnly;
      if (draft != null && _text.text.isEmpty) {
        _text.text = draft.body;
        _lastText = draft.body;
        _savedAt = draft.savedAt;
      }
      _loaded = true;
    });
  }

  void _changed() {
    if (!_loaded) return;
    if (_text.text != _lastText) {
      _lastText = _text.text;
      _error = null;
      _unsaved = true;
      _saveTimer?.cancel();
      _saveTimer = Timer(_saveDelay, _save);
    }
    _updateMention();
    setState(() {});
  }

  Future<void> _save() async {
    _saveTimer?.cancel();
    if (!_unsaved) return;
    _unsaved = false;
    final body = _text.text;
    final now = DateTime.now();
    await widget.drafts.write(
      widget.issueKey,
      JiraCommentDraft(
        body: body,
        consultantsOnly: _consultantsOnly,
        savedAt: now,
      ),
    );
    if (mounted) setState(() => _savedAt = body.trim().isEmpty ? null : now);
  }

  void _setConsultantsOnly(bool value) {
    if (value == _consultantsOnly) return;
    setState(() => _consultantsOnly = value);
    if (_text.text.trim().isEmpty) return;
    _unsaved = true;
    _save();
  }

  bool get _canSend => _loaded && !_sending && _text.text.trim().isNotEmpty;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.addComment(
        widget.issueKey,
        _text.text.trim(),
        visibleToRole: _consultantsOnly ? jiraConsultantsRole : null,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = userMessage(e);
        });
      }
      return;
    }
    _saveTimer?.cancel();
    _unsaved = false;
    await widget.drafts.write(widget.issueKey, null);
    await widget.drafts.rememberConsultantsOnly(_consultantsOnly);
    if (!mounted) return;
    _loaded = false; // Clearing isn't an edit to save.
    _text.clear();
    _lastText = '';
    setState(() {
      _loaded = true;
      _sending = false;
      _preview = false;
      _savedAt = null;
    });
    widget.onPosted();
  }

  Future<void> _discard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this comment?'),
        content: const Text('The draft is deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    _text.clear();
    await _save();
  }

  // Mentions.

  void _updateMention() {
    final selection = _text.selection;
    String? query;
    int? start;
    if (selection.isValid && selection.isCollapsed) {
      final before = _text.text.substring(0, selection.baseOffset);
      final match = _mentionAtCursor.firstMatch(before);
      if (match != null) {
        query = match.group(1)!;
        start = selection.baseOffset - query.length - 1;
      }
    }
    if (query == _mentionQuery && start == _mentionStart) return;
    _mentionStart = start;
    _mentionQuery = query;
    _searchTimer?.cancel();
    _searchSeq++;
    _suggestions = const [];
    if (query == null || query.isEmpty) return;
    _searchTimer = Timer(_searchDelay, () => _searchUsers(query!));
  }

  Future<void> _searchUsers(String query) async {
    final seq = _searchSeq;
    try {
      final users = await widget.service.searchMentionableUsers(
        widget.issueKey,
        query,
      );
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _suggestions = users;
        _highlighted = 0;
      });
    } catch (e) {
      debugPrint('Jira user search failed: $e');
    }
  }

  bool get _suggesting => _mentionQuery != null && _suggestions.isNotEmpty;

  void _pickUser(JiraUser user) {
    final start = _mentionStart;
    final end = _text.selection.baseOffset;
    if (start == null || end < start) return;
    final mention = '[~${user.name}] ';
    _pickedNames[user.name] = user.displayName;
    _text.value = TextEditingValue(
      text: _text.text.replaceRange(start, end, mention),
      selection: TextSelection.collapsed(offset: start + mention.length),
    );
    _focus.requestFocus();
  }

  void _closeSuggestions() => setState(() {
    _searchSeq++;
    _suggestions = const [];
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (HardwareKeyboard.instance.isMetaPressed) {
      if (key == LogicalKeyboardKey.enter) {
        _send();
      } else if (key == LogicalKeyboardKey.keyB) {
        _wrap('*');
      } else if (key == LogicalKeyboardKey.keyI) {
        _wrap('_');
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    }
    if (!_suggesting) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlighted = (_highlighted + 1) % _suggestions.length);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _highlighted =
            (_highlighted - 1 + _suggestions.length) % _suggestions.length,
      );
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.tab) {
      _pickUser(_suggestions[_highlighted]);
    } else if (key == LogicalKeyboardKey.escape) {
      _closeSuggestions();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // Formatting.

  void _edit(String text, TextSelection selection) {
    _text.value = TextEditingValue(text: text, selection: selection);
    _focus.requestFocus();
  }

  /// Puts [open] and [close] around the selection, or the cursor.
  void _wrap(String open, [String? close]) {
    close ??= open;
    final value = _text.value;
    final sel = value.selection;
    if (!sel.isValid) return;
    final selected = sel.textInside(value.text);
    final inner = sel.start + open.length;
    _edit(
      value.text.replaceRange(sel.start, sel.end, '$open$selected$close'),
      TextSelection(baseOffset: inner, extentOffset: inner + selected.length),
    );
  }

  /// Starts the selected lines with [prefix], or takes it off when they all
  /// have it.
  void _prefixLines(String prefix) {
    final value = _text.value;
    final sel = value.selection;
    if (!sel.isValid) return;
    final text = value.text;
    final start = sel.start == 0
        ? 0
        : text.lastIndexOf('\n', sel.start - 1) + 1;
    var end = text.indexOf('\n', sel.end);
    if (end < 0) end = text.length;
    final lines = text.substring(start, end).split('\n');
    final remove = lines.every((l) => l.startsWith(prefix));
    final changed = [
      for (final l in lines) remove ? l.substring(prefix.length) : '$prefix$l',
    ].join('\n');
    _edit(
      text.replaceRange(start, end, changed),
      lines.length == 1
          ? TextSelection.collapsed(offset: start + changed.length)
          : TextSelection(
              baseOffset: start,
              extentOffset: start + changed.length,
            ),
    );
  }

  void _link() {
    final value = _text.value;
    final sel = value.selection;
    if (!sel.isValid) return;
    final selected = sel.textInside(value.text);
    final label = selected.isEmpty ? 'link text' : selected;
    const url = 'https://';
    final text = value.text.replaceRange(sel.start, sel.end, '[$label|$url]');
    _edit(
      text,
      selected.isEmpty
          ? TextSelection(
              baseOffset: sel.start + 1,
              extentOffset: sel.start + 1 + label.length,
            )
          : TextSelection.collapsed(
              offset: sel.start + label.length + url.length + 2,
            ),
    );
  }

  void _startMention() {
    final value = _text.value;
    final sel = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final before = value.text.substring(0, sel.start);
    final at = before.isEmpty || before.endsWith(' ') || before.endsWith('\n')
        ? '@'
        : ' @';
    _edit(
      value.text.replaceRange(sel.start, sel.end, at),
      TextSelection.collapsed(offset: sel.start + at.length),
    );
  }

  // Building.

  Color get _tint => _consultantsOnly ? AppColors.claude : AppColors.accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _consultantsOnly
                  ? AppColors.claude.withValues(alpha: 0.6)
                  : AppColors.border,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              Divider(height: 1, color: AppColors.borderSubtle),
              if (_preview) _previewPane() else _editor(),
              if (!_preview && _suggesting) _suggestionList(),
              Divider(height: 1, color: AppColors.borderSubtle),
              _bottomBar(),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          IssueErrorBanner(message: _error!, fontSize: 12),
        ],
      ],
    );
  }

  /// Write/Preview, the formatting buttons, and who can see the comment.
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: [
          _Segment(
            label: 'Write',
            selected: !_preview,
            color: AppColors.textPrimary,
            onTap: () => setState(() => _preview = false),
          ),
          _Segment(
            label: 'Preview',
            selected: _preview,
            color: AppColors.textPrimary,
            onTap: () => setState(() {
              _preview = true;
              _suggestions = const [];
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _preview
                ? const SizedBox.shrink()
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _tool(
                          Icons.format_bold_rounded,
                          'Bold (⌘B)',
                          () => _wrap('*'),
                        ),
                        _tool(
                          Icons.format_italic_rounded,
                          'Italic (⌘I)',
                          () => _wrap('_'),
                        ),
                        _tool(
                          Icons.code_rounded,
                          'Monospace',
                          () => _wrap('{{', '}}'),
                        ),
                        _tool(
                          Icons.format_list_bulleted_rounded,
                          'Bulleted list',
                          () => _prefixLines('* '),
                        ),
                        _tool(
                          Icons.format_list_numbered_rounded,
                          'Numbered list',
                          () => _prefixLines('# '),
                        ),
                        _tool(Icons.link_rounded, 'Link', _link),
                        _tool(
                          Icons.alternate_email_rounded,
                          'Mention someone',
                          _startMention,
                        ),
                      ],
                    ),
                  ),
          ),
          _Segment(
            label: 'Everyone',
            icon: Icons.public_rounded,
            selected: !_consultantsOnly,
            color: AppColors.accent,
            onTap: () => _setConsultantsOnly(false),
          ),
          _Segment(
            label: 'Consultants only',
            icon: Icons.lock_outline_rounded,
            selected: _consultantsOnly,
            color: AppColors.claude,
            onTap: () => _setConsultantsOnly(true),
          ),
        ],
      ),
    );
  }

  Widget _tool(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      onPressed: _sending ? null : onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 17,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: AppColors.textSecondary),
    );
  }

  Widget _editor() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: TextField(
        controller: _text,
        focusNode: _focus,
        enabled: _loaded && !_sending,
        minLines: 4,
        maxLines: 14,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: 'Add a comment. Type @ to mention someone, ⌘↩ to send.',
          hintStyle: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _previewPane() {
    final body = _text.text.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: body.isEmpty
            ? Text(
                'Nothing to preview',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              )
            : JiraWikiText(
                body,
                fontSize: 13.5,
                onOpenImage: widget.onOpenImage,
                mentionName: (user) =>
                    _pickedNames[user] ?? widget.mentionName?.call(user),
              ),
      ),
    );
  }

  Widget _suggestionList() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, user) in _suggestions.indexed)
            InkWell(
              onTap: () => _pickUser(user),
              child: Container(
                color: i == _highlighted
                    ? AppColors.accent.withValues(alpha: 0.12)
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Draft status, Discard and Send.
  Widget _bottomBar() {
    final hasText = _text.text.trim().isNotEmpty;
    final savedAt = _savedAt;
    final status = !hasText
        ? null
        : _unsaved
        ? 'Saving draft…'
        : savedAt == null
        ? null
        : 'Draft saved ${formatRelativeTime(savedAt)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          if (status != null)
            Tooltip(
              message: 'Drafts are kept on this Mac until sent or discarded',
              child: Text(
                status,
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ),
          const Spacer(),
          if (hasText && !_sending)
            TextButton(
              onPressed: _discard,
              child: Text(
                'Discard',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: '⌘↩',
            child: Material(
              color: _canSend ? _tint : _tint.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(7),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _canSend ? _send : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_sending)
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.base,
                          ),
                        )
                      else
                        Icon(
                          _consultantsOnly
                              ? Icons.lock_outline_rounded
                              : Icons.send_rounded,
                          size: 14,
                          color: AppColors.base,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        _consultantsOnly ? 'Comment to consultants' : 'Comment',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.base,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One option of a small segmented choice.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? color : AppColors.textMuted;
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
