import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/jira/domain/jira_wiki_markup.dart';

/// Renders Jira wiki markup (a description or comment) as selectable text:
/// headings, lists, code, quotes, tables, emphasis, links and mentions.
/// Image references (`!image.png!`) show as chips that call [onOpenImage].
class JiraWikiText extends StatefulWidget {
  const JiraWikiText(
    this.markup, {
    super.key,
    this.fontSize = 14,
    this.onOpenImage,
    this.busyImages = const {},
    this.mentionName,
    this.openUrl = openExternal,
  });

  final String markup;
  final double fontSize;

  /// Opens an image reference's attachment (a file name) or URL.
  final ValueChanged<String>? onOpenImage;

  /// Image references being opened, which show a spinner.
  final Set<String> busyImages;

  /// The display name of a mentioned username, when known.
  final String? Function(String user)? mentionName;

  final UrlOpener openUrl;

  @override
  State<JiraWikiText> createState() => _JiraWikiTextState();
}

class _JiraWikiTextState extends State<JiraWikiText> {
  late List<WikiBlock> _blocks = parseJiraWiki(widget.markup);

  /// The link taps of the last build, disposed on the next.
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void didUpdateWidget(JiraWikiText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markup != widget.markup) {
      _blocks = parseJiraWiki(widget.markup);
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TextStyle get _base => TextStyle(
    fontSize: widget.fontSize,
    height: 1.55,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    return SelectionArea(child: _blockColumn(_blocks));
  }

  Widget _blockColumn(List<WikiBlock> blocks) {
    final children = <Widget>[];
    // Numbering per list depth, reset by anything that isn't a list item.
    final numbers = <int>[];
    for (final (i, block) in blocks.indexed) {
      if (block is WikiListItem) {
        while (numbers.length > block.depth) {
          numbers.removeLast();
        }
        while (numbers.length < block.depth) {
          numbers.add(0);
        }
        numbers[block.depth - 1]++;
      } else {
        numbers.clear();
      }
      final previous = i == 0 ? null : blocks[i - 1];
      final gap = previous == null
          ? 0.0
          : previous is WikiListItem && block is WikiListItem
          ? 2.0
          : block is WikiHeading
          ? 12.0
          : 8.0;
      children.add(
        Padding(
          padding: EdgeInsets.only(top: gap),
          child: _block(block, block is WikiListItem ? numbers.last : 0),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _block(WikiBlock block, int number) {
    switch (block) {
      case WikiHeading(:final level, :final content):
        final size =
            widget.fontSize +
            switch (level) {
              1 => 3.0,
              2 => 2.0,
              3 => 1.0,
              _ => 0.0,
            };
        return _rich(
          content,
          _base.copyWith(
            fontSize: size,
            height: 1.35,
            fontWeight: level <= 3 ? FontWeight.w700 : FontWeight.w600,
            color: level >= 6 ? AppColors.textSecondary : null,
          ),
        );
      case WikiParagraph(:final content):
        return _rich(content, _base);
      case WikiListItem(:final depth, :final ordered, :final content):
        return Padding(
          padding: EdgeInsets.only(left: 4 + (depth - 1) * 18.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  ordered ? '$number.' : (depth == 1 ? '•' : '◦'),
                  style: _base.copyWith(color: AppColors.textMuted),
                ),
              ),
              Expanded(child: _rich(content, _base)),
            ],
          ),
        );
      case WikiCode(:final text):
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.base,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              text,
              style: _base.copyWith(
                fontFamily: 'monospace',
                fontSize: widget.fontSize - 1.5,
                height: 1.45,
              ),
            ),
          ),
        );
      case WikiQuote(:final children, :final title):
        return Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.border, width: 3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null && title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    title,
                    style: _base.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              DefaultTextStyle.merge(
                style: TextStyle(color: AppColors.textSecondary),
                child: _blockColumn(children),
              ),
            ],
          ),
        );
      case WikiRule():
        return Divider(height: 12, color: AppColors.border);
      case WikiTable(:final rows):
        return _table(rows);
    }
  }

  Widget _table(List<List<WikiCell>> rows) {
    final columns = rows.fold(0, (n, row) => row.length > n ? row.length : n);
    if (columns == 0) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: AppColors.border),
        children: [
          for (final row in rows)
            TableRow(
              children: [
                for (var c = 0; c < columns; c++)
                  _cell(c < row.length ? row[c] : null),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(WikiCell? cell) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      color: cell?.header == true ? AppColors.surface2 : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: cell == null
          ? const SizedBox.shrink()
          : _rich(
              cell.content,
              _base.copyWith(
                fontSize: widget.fontSize - 1,
                fontWeight: cell.header ? FontWeight.w600 : null,
              ),
            ),
    );
  }

  Widget _rich(List<WikiInline> content, TextStyle style) => Text.rich(
    TextSpan(style: style, children: [for (final p in content) _span(p)]),
  );

  InlineSpan _span(WikiInline piece) {
    switch (piece) {
      case WikiText(:final text, :final style):
        return TextSpan(text: text, style: _style(style));
      case WikiLink(:final text, :final url, :final style):
        final tap = TapGestureRecognizer()..onTap = () => widget.openUrl(url);
        _recognizers.add(tap);
        return TextSpan(
          text: text,
          recognizer: tap,
          mouseCursor: SystemMouseCursors.click,
          style: _style(style).copyWith(
            color: AppColors.accent,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.accent.withValues(alpha: 0.5),
          ),
        );
      case WikiMention(:final user):
        final name = widget.mentionName?.call(user) ?? user;
        return TextSpan(
          text: '@$name',
          style: TextStyle(
            color: AppColors.accent,
            fontWeight: FontWeight.w600,
            backgroundColor: AppColors.accent.withValues(alpha: 0.12),
          ),
        );
      case WikiImage(:final source):
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: JiraFileChip(
            name: source.split('/').last,
            icon: Icons.image_outlined,
            busy: widget.busyImages.contains(source),
            onTap: widget.onOpenImage == null
                ? null
                : () => widget.onOpenImage!(source),
          ),
        );
    }
  }

  TextStyle _style(WikiStyle style) => TextStyle(
    fontWeight: style.bold ? FontWeight.w700 : null,
    fontStyle: style.italic ? FontStyle.italic : null,
    fontFamily: style.mono ? 'monospace' : null,
    backgroundColor: style.mono ? AppColors.surface2 : null,
    decoration: TextDecoration.combine([
      if (style.strike) TextDecoration.lineThrough,
      if (style.underline) TextDecoration.underline,
    ]),
  );
}

/// A small clickable file: an image reference in text, or an attachment.
class JiraFileChip extends StatelessWidget {
  const JiraFileChip({
    super.key,
    required this.name,
    required this.icon,
    this.detail,
    this.busy = false,
    this.onTap,
  });

  final String name;
  final IconData icon;

  /// Shown muted after the name, e.g. the size.
  final String? detail;

  /// Shows a spinner in place of the icon (while downloading).
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          hoverColor: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: busy
                      ? Padding(
                          padding: const EdgeInsets.all(2),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: color,
                          ),
                        )
                      : Icon(icon, size: 14, color: color),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
