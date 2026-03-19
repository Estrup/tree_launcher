import 'package:path/path.dart' as p;

class MarkdownDocument {
  final String path;
  final String content;
  final String savedContent;
  final int cursorOffset;

  const MarkdownDocument({
    required this.path,
    this.content = '',
    this.savedContent = '',
    this.cursorOffset = 0,
  });

  String get fileName => p.basename(path);
  bool get isModified => content != savedContent;

  MarkdownDocument copyWith({
    String? path,
    String? content,
    String? savedContent,
    int? cursorOffset,
  }) {
    return MarkdownDocument(
      path: path ?? this.path,
      content: content ?? this.content,
      savedContent: savedContent ?? this.savedContent,
      cursorOffset: cursorOffset ?? this.cursorOffset,
    );
  }
}
