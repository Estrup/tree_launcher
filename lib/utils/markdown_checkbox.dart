import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class CheckmarkSyntax extends md.InlineSyntax {
  CheckmarkSyntax() : super(r'\[([xX ]+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    if (match.group(1)?.toLowerCase() == 'x') {
      parser.addNode(md.Element.text('checkmark', 'x'));
    } else {
      parser.addNode(md.Element.text('checkmark', ' '));
    }
    return true;
  }
}

class CustomCheckbox extends StatelessWidget {
  final bool isChecked;
  final TextStyle? preferredStyle;

  const CustomCheckbox({
    super.key,
    required this.isChecked,
    this.preferredStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Icon(
        isChecked ? Icons.check_box : Icons.check_box_outline_blank,
        size: 16,
        color: isChecked
            ? Colors.green
            : preferredStyle?.color?.withValues(alpha: 0.6) ?? Colors.grey,
      ),
    );
  }
}

class CheckmarkBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final isChecked = element.textContent == 'x';
    return CustomCheckbox(isChecked: isChecked, preferredStyle: preferredStyle);
  }
}
