import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

/// A custom [TextEditingController] that applies inline markdown styling
/// to render a live preview within a single [TextField].
///
/// Implements Obsidian-style syntax hiding: markdown markers are hidden
/// on non-active lines and revealed when the cursor enters the line.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  /// Style that makes marker characters near-invisible (collapsed).
  TextStyle _hiddenStyle(TextStyle base) => base.copyWith(
        fontSize: 0.01,
        color: Colors.transparent,
      );

  /// Compute which line (0-indexed) the cursor is on.
  int _cursorLineIndex() {
    final offset = selection.baseOffset.clamp(0, text.length);
    int line = 0;
    for (int i = 0; i < offset; i++) {
      if (text.codeUnitAt(i) == 10) line++; // '\n'
    }
    return line;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final cursorLine = _cursorLineIndex();
    final spans = _buildSpans(text, baseStyle, cursorLine);
    return TextSpan(children: spans, style: baseStyle);
  }

  List<InlineSpan> _buildSpans(
      String text, TextStyle baseStyle, int cursorLine) {
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    bool inCodeBlock = false;

    final codeBlockStyle = baseStyle.copyWith(
      fontFamily: 'Menlo',
      fontSize: (baseStyle.fontSize ?? 14) * 0.9,
      color: AppColors.textSecondary,
      backgroundColor: AppColors.surface1,
    );
    final codeFenceStyle = baseStyle.copyWith(
      color: AppColors.textMuted.withValues(alpha: 0.6),
      fontFamily: 'Menlo',
      fontSize: (baseStyle.fontSize ?? 14) * 0.9,
      backgroundColor: AppColors.surface1,
    );

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[i];
      final isActive = i == cursorLine;

      if (line.startsWith('```')) {
        spans.add(TextSpan(text: line, style: codeFenceStyle));
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (inCodeBlock) {
        spans.add(TextSpan(text: line, style: codeBlockStyle));
      } else {
        _parseLine(line, baseStyle, spans, isActive);
      }
    }

    return spans;
  }

  void _parseLine(String line, TextStyle baseStyle, List<InlineSpan> spans,
      bool isActive) {
    // Heading detection
    final headingMatch = RegExp(r'^(#{1,6})\s').firstMatch(line);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      final hashPart = line.substring(0, headingMatch.end);
      final content = line.substring(headingMatch.end);
      final headingSize = _headingSize(level, baseStyle.fontSize ?? 14);
      if (isActive) {
        spans.add(TextSpan(
          text: hashPart,
          style: baseStyle.copyWith(
            color: AppColors.textMuted.withValues(alpha: 0.5),
            fontSize: headingSize,
            fontWeight: FontWeight.w700,
          ),
        ));
      } else {
        // Hide the # markers
        spans.add(TextSpan(text: hashPart, style: _hiddenStyle(baseStyle)));
      }
      _parseInline(
          content,
          baseStyle.copyWith(
            fontSize: headingSize,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          spans,
          isActive);
      return;
    }

    // Horizontal rule
    if (RegExp(r'^(\*{3,}|-{3,}|_{3,})\s*$').hasMatch(line)) {
      spans.add(TextSpan(
        text: line,
        style: baseStyle.copyWith(
          color: AppColors.textMuted.withValues(alpha: 0.4),
          decoration: TextDecoration.lineThrough,
        ),
      ));
      return;
    }

    // Blockquote — always visible (structural)
    if (line.startsWith('> ')) {
      spans.add(TextSpan(
        text: '> ',
        style: baseStyle.copyWith(
          color: AppColors.accent.withValues(alpha: 0.5),
          fontWeight: FontWeight.w700,
        ),
      ));
      _parseInline(
          line.substring(2),
          baseStyle.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
          spans,
          isActive);
      return;
    }

    // Unordered list — always visible (structural)
    final ulMatch = RegExp(r'^(\s*)([-*+])\s').firstMatch(line);
    if (ulMatch != null) {
      spans.add(TextSpan(
        text: line.substring(0, ulMatch.end),
        style: baseStyle.copyWith(color: AppColors.accent),
      ));
      _parseInline(line.substring(ulMatch.end), baseStyle, spans, isActive);
      return;
    }

    // Ordered list — always visible (structural)
    final olMatch = RegExp(r'^(\s*)(\d+\.)\s').firstMatch(line);
    if (olMatch != null) {
      spans.add(TextSpan(
        text: line.substring(0, olMatch.end),
        style: baseStyle.copyWith(color: AppColors.accent),
      ));
      _parseInline(line.substring(olMatch.end), baseStyle, spans, isActive);
      return;
    }

    // Checkbox — always visible (structural)
    final cbMatch = RegExp(r'^(\s*[-*+]\s)\[([ xX])\]\s').firstMatch(line);
    if (cbMatch != null) {
      spans.add(TextSpan(
        text: line.substring(0, cbMatch.end),
        style: baseStyle.copyWith(color: AppColors.accent),
      ));
      _parseInline(line.substring(cbMatch.end), baseStyle, spans, isActive);
      return;
    }

    // Normal line — parse inline formatting
    _parseInline(line, baseStyle, spans, isActive);
  }

  void _parseInline(String text, TextStyle baseStyle, List<InlineSpan> spans,
      bool isActive) {
    if (text.isEmpty) return;

    final pattern = RegExp(
      r'(\*\*\*|___)(.*?)\1' // bold+italic
      r'|(\*\*|__)(.*?)\3' // bold
      r'|(\*|_)(.*?)\5' // italic
      r'|(~~)(.*?)\7' // strikethrough
      r'|(`)(.*?)\9' // inline code
      r'|(!\[)(.*?)(\]\()(.*?)(\))' // image
      r'|(\[)(.*?)(\]\()(.*?)(\))', // link
    );

    final markerVisible = baseStyle.copyWith(
      color: AppColors.textMuted.withValues(alpha: 0.4),
    );
    final markerHidden = _hiddenStyle(baseStyle);

    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final full = match.group(0)!;
      final mStyle = isActive ? markerVisible : markerHidden;

      if (match.group(1) != null) {
        // Bold + italic
        final marker = match.group(1)!;
        final content = match.group(2)!;
        spans.add(TextSpan(text: marker, style: mStyle));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
          ),
        ));
        spans.add(TextSpan(text: marker, style: mStyle));
      } else if (match.group(3) != null) {
        // Bold
        final marker = match.group(3)!;
        final content = match.group(4)!;
        spans.add(TextSpan(text: marker, style: mStyle));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
        spans.add(TextSpan(text: marker, style: mStyle));
      } else if (match.group(5) != null) {
        // Italic
        final marker = match.group(5)!;
        final content = match.group(6)!;
        spans.add(TextSpan(text: marker, style: mStyle));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
        spans.add(TextSpan(text: marker, style: mStyle));
      } else if (match.group(7) != null) {
        // Strikethrough
        final content = match.group(8)!;
        spans.add(TextSpan(text: '~~', style: mStyle));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
            color: AppColors.textMuted,
          ),
        ));
        spans.add(TextSpan(text: '~~', style: mStyle));
      } else if (match.group(9) != null) {
        // Inline code
        final content = match.group(10)!;
        spans.add(TextSpan(text: '`', style: mStyle));
        spans.add(TextSpan(
          text: content,
          style: baseStyle.copyWith(
            fontFamily: 'Menlo',
            fontSize: (baseStyle.fontSize ?? 14) * 0.9,
            backgroundColor: AppColors.surface1,
            color: AppColors.accent,
          ),
        ));
        spans.add(TextSpan(text: '`', style: mStyle));
      } else if (match.group(11) != null) {
        // Image ![alt](url)
        if (isActive) {
          spans.add(TextSpan(
            text: full,
            style: baseStyle.copyWith(
              color: AppColors.accent.withValues(alpha: 0.7),
              fontFamily: 'Menlo',
              fontSize: (baseStyle.fontSize ?? 14) * 0.9,
            ),
          ));
        } else {
          final altText = match.group(12)!;
          // Hide syntax, show alt text as styled label
          spans.add(TextSpan(text: '![', style: markerHidden));
          spans.add(TextSpan(
            text: altText,
            style: baseStyle.copyWith(
              color: AppColors.accent.withValues(alpha: 0.7),
            ),
          ));
          spans.add(TextSpan(text: '](', style: markerHidden));
          spans.add(TextSpan(text: match.group(14)!, style: markerHidden));
          spans.add(TextSpan(text: ')', style: markerHidden));
        }
      } else if (match.group(16) != null) {
        // Link [text](url)
        final linkText = match.group(17)!;
        final url = match.group(19)!;
        if (isActive) {
          spans.add(TextSpan(text: '[', style: markerVisible));
          spans.add(TextSpan(
            text: linkText,
            style: baseStyle.copyWith(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent.withValues(alpha: 0.4),
            ),
          ));
          spans.add(TextSpan(text: '](', style: markerVisible));
          spans.add(TextSpan(
            text: url,
            style: baseStyle.copyWith(
              color: AppColors.textMuted.withValues(alpha: 0.5),
              fontFamily: 'Menlo',
              fontSize: (baseStyle.fontSize ?? 14) * 0.85,
            ),
          ));
          spans.add(TextSpan(text: ')', style: markerVisible));
        } else {
          // Hide all syntax, show only styled link text
          spans.add(TextSpan(text: '[', style: markerHidden));
          spans.add(TextSpan(
            text: linkText,
            style: baseStyle.copyWith(
              color: AppColors.accent,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.accent.withValues(alpha: 0.4),
            ),
          ));
          spans.add(TextSpan(text: '](', style: markerHidden));
          spans.add(TextSpan(text: url, style: markerHidden));
          spans.add(TextSpan(text: ')', style: markerHidden));
        }
      } else {
        spans.add(TextSpan(text: full, style: baseStyle));
      }

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }
  }

  double _headingSize(int level, double baseFontSize) {
    switch (level) {
      case 1:
        return baseFontSize * 1.8;
      case 2:
        return baseFontSize * 1.5;
      case 3:
        return baseFontSize * 1.3;
      case 4:
        return baseFontSize * 1.15;
      case 5:
        return baseFontSize * 1.05;
      case 6:
        return baseFontSize * 1.0;
      default:
        return baseFontSize;
    }
  }
}

/// The main markdown text field widget with live preview.
class MarkdownTextField extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  const MarkdownTextField({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.focusNode,
  });

  @override
  State<MarkdownTextField> createState() => _MarkdownTextFieldState();
}

class _MarkdownTextFieldState extends State<MarkdownTextField> {
  late final MarkdownEditingController _controller;
  late final ScrollController _scrollController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = MarkdownEditingController(text: widget.initialContent);
    _scrollController = ScrollController();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(MarkdownTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialContent != oldWidget.initialContent &&
        widget.initialContent != _controller.text) {
      _controller.removeListener(_onTextChanged);
      _controller.text = widget.initialContent;
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    widget.onChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFileDrop(DropDoneDetails details) {
    for (final file in details.files) {
      final path = file.path;
      final offset = _controller.selection.baseOffset.clamp(0, _controller.text.length);
      final before = _controller.text.substring(0, offset);
      final after = _controller.text.substring(offset);
      final newText = '$before$path$after';
      _controller.removeListener(_onTextChanged);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: offset + path.length);
      _controller.addListener(_onTextChanged);
      widget.onChanged(_controller.text);
    }
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: _onFileDrop,
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Container(
        color: AppColors.base,
        padding: const EdgeInsets.only(top: 8),
        child: Stack(
          children: [
            TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              scrollController: _scrollController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                fontSize: 14,
                height: 1.7,
                color: AppColors.textPrimary,
                fontFamily: '.AppleSystemUIFont',
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(32, 24, 32, 24),
                isCollapsed: true,
              ),
              scrollPadding: const EdgeInsets.all(24),
              cursorColor: AppColors.accent,
              cursorWidth: 1.5,
            ),
            if (_isDragging)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.7),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
