/// A link found in a terminal line: a URL, or text that may name a file.
sealed class TerminalLinkTarget {
  const TerminalLinkTarget();
}

/// An http(s) or file URL, as written.
class UrlLinkTarget extends TerminalLinkTarget {
  const UrlLinkTarget(this.url);

  final String url;

  @override
  bool operator ==(Object other) => other is UrlLinkTarget && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'UrlLinkTarget($url)';
}

/// Text that looks like a path, without its `:line:column` or `#L42`
/// suffix. Only a link when the path exists, which the caller checks.
class PathLinkTarget extends TerminalLinkTarget {
  const PathLinkTarget(this.path, {this.line, this.column});

  final String path;
  final int? line;
  final int? column;

  @override
  bool operator ==(Object other) =>
      other is PathLinkTarget &&
      other.path == path &&
      other.line == line &&
      other.column == column;

  @override
  int get hashCode => Object.hash(path, line, column);

  @override
  String toString() => 'PathLinkTarget($path, $line, $column)';
}

/// A link at [start] (inclusive) to [end] (exclusive) in a line's text.
class TerminalLinkMatch {
  const TerminalLinkMatch(this.start, this.end, this.target);

  final int start;
  final int end;
  final TerminalLinkTarget target;
}

final _url = RegExp(r'''(?:https?|file)://[^\s<>"'`←-➿]+''');

/// Characters a URL keeps inside it but not at its end, as in "see
/// https://example.com." or "(https://example.com)".
const _urlTrailing = '.,;:!?*\'"';

final _pathSuffix = RegExp(
  r'^(.+?)(?::(\d+)(?::(\d+))?(?:-\d+)?|#L(\d+)(?:-L?\d+)?)?$',
);

/// The link in [text] that the character at [index] belongs to, or null.
///
/// A URL wins over a path. A path is any run of characters between
/// whitespace, brackets, quotes, separators and the symbols TUIs draw (box
/// lines, arrows, bullets) that has a `/` or a `.` in it.
TerminalLinkMatch? findTerminalLink(String text, int index) {
  if (index < 0 || index >= text.length) return null;

  for (final match in _url.allMatches(text)) {
    if (match.start > index) break;
    final end = _trimUrlEnd(text, match.start, match.end);
    if (index < end) {
      return TerminalLinkMatch(
        match.start,
        end,
        UrlLinkTarget(text.substring(match.start, end)),
      );
    }
  }

  if (_isPathBreak(text.codeUnitAt(index))) return null;
  var start = index;
  while (start > 0 && !_isPathBreak(text.codeUnitAt(start - 1))) {
    start--;
  }
  var end = index + 1;
  while (end < text.length && !_isPathBreak(text.codeUnitAt(end))) {
    end++;
  }
  // Sentence punctuation after a path, as in "see lib/main.dart."
  while (end > start && '.:!?'.contains(text[end - 1])) {
    end--;
  }
  if (index >= end) return null;

  final token = text.substring(start, end);
  final parts = _pathSuffix.firstMatch(token);
  if (parts == null) return null;
  final path = parts.group(1)!;
  if (!path.contains('/') && !path.contains('.')) return null;
  if (path == '.' || path == '..' || !RegExp(r'[^./~]').hasMatch(path)) {
    return null;
  }
  final line = parts.group(2) ?? parts.group(4);
  final column = parts.group(3);
  return TerminalLinkMatch(
    start,
    end,
    PathLinkTarget(
      path,
      line: line == null ? null : int.parse(line),
      column: column == null ? null : int.parse(column),
    ),
  );
}

/// [end] moved back past trailing punctuation and a closing bracket that
/// has no opening one inside the URL.
int _trimUrlEnd(String text, int start, int end) {
  while (end > start) {
    final last = text[end - 1];
    if (_urlTrailing.contains(last)) {
      end--;
      continue;
    }
    final open = switch (last) {
      ')' => '(',
      ']' => '[',
      '}' => '{',
      _ => null,
    };
    if (open == null) break;
    final url = text.substring(start, end);
    if (open.allMatches(url).length >= last.allMatches(url).length) break;
    end--;
  }
  return end;
}

bool _isPathBreak(int c) {
  if (c <= 0x20) return true;
  // Box drawing, arrows, technical symbols (⏺ ⎿), geometric shapes, dingbats.
  if (c >= 0x2190 && c <= 0x27BF) return true;
  return switch (String.fromCharCode(c)) {
    '(' || ')' || '[' || ']' || '{' || '}' || '<' || '>' => true,
    '"' || "'" || '`' || '|' || ',' || ';' || ' ' || '•' || '·' => true,
    _ => false,
  };
}
