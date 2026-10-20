import 'package:path/path.dart' as p;

/// How a file opens in the panel's viewer.
enum FileViewKind {
  /// Rendered in the web view, with its source a toggle away.
  markdown,
  html,
  pdf,
  image,

  /// Plain text with line numbers.
  text;

  /// The kind for the file at [path], by its extension.
  static FileViewKind forPath(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.md' || '.markdown' => FileViewKind.markdown,
        '.html' || '.htm' => FileViewKind.html,
        '.pdf' => FileViewKind.pdf,
        '.png' ||
        '.jpg' ||
        '.jpeg' ||
        '.gif' ||
        '.webp' ||
        '.bmp' => FileViewKind.image,
        _ => FileViewKind.text,
      };

  /// Whether it is shown rendered and has text source to show instead.
  bool get hasSource => this == markdown || this == html;
}

/// What reading a file as text found.
sealed class FileContent {
  const FileContent();
}

/// The file's text, read as UTF-8 (malformed bytes replaced).
class TextFileContent extends FileContent {
  const TextFileContent(this.text);

  final String text;

  /// Its lines, without the line breaks; a final line break doesn't add an
  /// empty line.
  List<String> get lines {
    final lines = text.split(RegExp(r'\r?\n'));
    if (lines.length > 1 && lines.last.isEmpty) lines.removeLast();
    return lines;
  }
}

/// A file too large to show as text.
class TooLargeFileContent extends FileContent {
  const TooLargeFileContent(this.sizeBytes);

  final int sizeBytes;
}

/// A file that isn't text: it has a NUL byte near its start.
class BinaryFileContent extends FileContent {
  const BinaryFileContent();
}
