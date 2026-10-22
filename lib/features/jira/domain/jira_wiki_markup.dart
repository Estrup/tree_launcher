/// A parser for the Jira Server wiki markup that descriptions and comments are
/// written in, into blocks of styled inline pieces the issue dialog renders.
///
/// Covers what issues actually use: headings (`h4.`), lists (`*`, `#`, `-`),
/// `{code}`/`{noformat}`, `{quote}`/`bq.`/`{panel}`, tables, `----`, and
/// inline `*bold*`, `_italic_`, `-strike-`, `+underline+`, `{{mono}}`, links
/// (`[text|url]`, bare URLs), mentions (`[~user]`) and image references
/// (`!image.png!`). Anything else shows as written.
library;

sealed class WikiBlock {
  const WikiBlock();
}

class WikiHeading extends WikiBlock {
  const WikiHeading(this.level, this.content);

  /// 1 to 6.
  final int level;
  final List<WikiInline> content;
}

class WikiParagraph extends WikiBlock {
  const WikiParagraph(this.content);
  final List<WikiInline> content;
}

/// One list item. [markers] are its list markers, e.g. `*`, `**` or `*#`: the
/// length is the depth, and the last one says whether it is numbered.
class WikiListItem extends WikiBlock {
  const WikiListItem(this.markers, this.content);
  final String markers;
  final List<WikiInline> content;

  int get depth => markers.length;
  bool get ordered => markers.endsWith('#');
}

/// A `{code}` or `{noformat}` block, shown as written.
class WikiCode extends WikiBlock {
  const WikiCode(this.text);
  final String text;
}

/// A `{quote}`, `bq.` or `{panel}`, with an optional panel [title].
class WikiQuote extends WikiBlock {
  const WikiQuote(this.children, {this.title});
  final List<WikiBlock> children;
  final String? title;
}

class WikiRule extends WikiBlock {
  const WikiRule();
}

class WikiTable extends WikiBlock {
  const WikiTable(this.rows);
  final List<List<WikiCell>> rows;
}

class WikiCell {
  const WikiCell(this.content, {this.header = false});
  final List<WikiInline> content;
  final bool header;
}

/// The inline styles a piece of text can have.
class WikiStyle {
  const WikiStyle({
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.underline = false,
    this.mono = false,
  });

  final bool bold;
  final bool italic;
  final bool strike;
  final bool underline;
  final bool mono;

  static const plain = WikiStyle();

  WikiStyle copyWith({
    bool? bold,
    bool? italic,
    bool? strike,
    bool? underline,
    bool? mono,
  }) => WikiStyle(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    strike: strike ?? this.strike,
    underline: underline ?? this.underline,
    mono: mono ?? this.mono,
  );

  @override
  bool operator ==(Object other) =>
      other is WikiStyle &&
      other.bold == bold &&
      other.italic == italic &&
      other.strike == strike &&
      other.underline == underline &&
      other.mono == mono;

  @override
  int get hashCode => Object.hash(bold, italic, strike, underline, mono);

  @override
  String toString() => [
    if (bold) 'bold',
    if (italic) 'italic',
    if (strike) 'strike',
    if (underline) 'underline',
    if (mono) 'mono',
  ].join('+');
}

sealed class WikiInline {
  const WikiInline();
}

class WikiText extends WikiInline {
  const WikiText(this.text, [this.style = WikiStyle.plain]);
  final String text;
  final WikiStyle style;
}

class WikiLink extends WikiInline {
  const WikiLink(this.text, this.url, [this.style = WikiStyle.plain]);
  final String text;
  final String url;
  final WikiStyle style;
}

/// `[~user]`: [user] is the Jira username.
class WikiMention extends WikiInline {
  const WikiMention(this.user);
  final String user;
}

/// `!source!`: [source] is an attachment's file name or a URL.
class WikiImage extends WikiInline {
  const WikiImage(this.source);
  final String source;
}

/// Parses [markup] into blocks.
List<WikiBlock> parseJiraWiki(String markup) =>
    _BlockParser(markup.replaceAll('\r\n', '\n').split('\n')).parse();

/// The usernames [markup] mentions (`[~user]`), in order, without repeats.
List<String> jiraWikiMentions(String markup) => {
  for (final m in RegExp(r'\[~([^\]\s]+)\]').allMatches(markup)) m.group(1)!,
}.toList();

class _BlockParser {
  _BlockParser(this._lines);

  final List<String> _lines;
  int _i = 0;

  static final _heading = RegExp(r'^\s*h([1-6])\.\s*(.*)$');
  static final _listItem = RegExp(r'^\s*([*#]+|-)\s+(.*)$');
  static final _rule = RegExp(r'^\s*-{4,}\s*$');
  static final _quoteLine = RegExp(r'^\s*bq\.\s*(.*)$');
  static final _openTag = RegExp(
    r'^\s*\{(code|noformat|quote|panel)(?::([^}]*))?\}(.*)$',
  );

  List<WikiBlock> parse() {
    final blocks = <WikiBlock>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(WikiParagraph(parseJiraInline(paragraph.join('\n'))));
      paragraph.clear();
    }

    while (_i < _lines.length) {
      final line = _lines[_i];

      final tag = _openTag.firstMatch(line);
      if (tag != null) {
        flushParagraph();
        final name = tag.group(1)!;
        _i++;
        final body = _until('{$name}', tag.group(3)!);
        if (name == 'code' || name == 'noformat') {
          blocks.add(WikiCode(_trimBlankLines(body)));
        } else {
          blocks.add(
            WikiQuote(
              _BlockParser(body.split('\n')).parse(),
              title: name == 'panel' ? _panelTitle(tag.group(2)) : null,
            ),
          );
        }
        continue;
      }

      _i++;
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }

      final heading = _heading.firstMatch(line);
      if (heading != null) {
        flushParagraph();
        blocks.add(
          WikiHeading(
            int.parse(heading.group(1)!),
            parseJiraInline(heading.group(2)!.trim()),
          ),
        );
        continue;
      }

      if (_rule.hasMatch(line)) {
        flushParagraph();
        blocks.add(const WikiRule());
        continue;
      }

      final item = _listItem.firstMatch(line);
      if (item != null) {
        flushParagraph();
        final markers = item.group(1)!;
        blocks.add(
          WikiListItem(
            markers == '-' ? '*' : markers,
            parseJiraInline(item.group(2)!.trim()),
          ),
        );
        continue;
      }

      final quote = _quoteLine.firstMatch(line);
      if (quote != null) {
        flushParagraph();
        blocks.add(
          WikiQuote([WikiParagraph(parseJiraInline(quote.group(1)!.trim()))]),
        );
        continue;
      }

      if (line.trimLeft().startsWith('|')) {
        flushParagraph();
        final rows = [_tableRow(line)];
        while (_i < _lines.length && _lines[_i].trimLeft().startsWith('|')) {
          rows.add(_tableRow(_lines[_i++]));
        }
        blocks.add(WikiTable(rows));
        continue;
      }

      paragraph.add(line);
    }
    flushParagraph();
    return blocks;
  }

  /// The text up to the closing [tag], starting with [rest] of the opening
  /// line; leaves [_i] after the line it closes on. Text after the closing
  /// tag on that line is parsed as a line of its own.
  String _until(String tag, String rest) {
    final close = rest.indexOf(tag);
    if (close >= 0) {
      _reparse(rest.substring(close + tag.length));
      return rest.substring(0, close);
    }
    final body = [if (rest.isNotEmpty) rest];
    while (_i < _lines.length) {
      final line = _lines[_i++];
      final at = line.indexOf(tag);
      if (at >= 0) {
        body.add(line.substring(0, at));
        _reparse(line.substring(at + tag.length));
        break;
      }
      body.add(line);
    }
    return body.join('\n');
  }

  void _reparse(String rest) {
    if (rest.trim().isNotEmpty) _lines.insert(_i, rest);
  }

  static String? _panelTitle(String? params) {
    if (params == null) return null;
    for (final param in params.split('|')) {
      final eq = param.indexOf('=');
      if (eq > 0 && param.substring(0, eq).trim() == 'title') {
        return param.substring(eq + 1).trim();
      }
    }
    return null;
  }

  static String _trimBlankLines(String text) =>
      text.replaceAll(RegExp(r'^\s*\n|\n\s*$'), '');

  /// Splits a table line into cells: `||` starts a header cell, `|` a plain
  /// one. A `|` inside `[...]` (a link) doesn't split.
  static List<WikiCell> _tableRow(String line) {
    final text = line.trim();
    final cells = <WikiCell>[];
    var header = false;
    var start = -1;
    var depth = 0;
    void close(int end) {
      if (start >= 0) {
        final content = text.substring(start, end).trim();
        cells.add(WikiCell(parseJiraInline(content), header: header));
      }
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (c == '[') depth++;
      if (c == ']' && depth > 0) depth--;
      if (c != '|' || depth > 0) continue;
      close(i);
      header = i + 1 < text.length && text[i + 1] == '|';
      if (header) i++;
      start = i + 1;
    }
    // A row ends with its closing `|`; text after the last one is a cell.
    if (start >= 0 && start < text.length) close(text.length);
    return cells;
  }
}

/// Parses inline markup (one block's text) into styled pieces.
List<WikiInline> parseJiraInline(String text) =>
    _InlineParser(text).parse(WikiStyle.plain);

class _InlineParser {
  _InlineParser(this._s);

  final String _s;

  static const _emphasis = {
    '*': 'bold',
    '_': 'italic',
    '-': 'strike',
    '+': 'underline',
  };
  static final _url = RegExp(r'''(?:https?://|mailto:)[^\s<>"'\]|]+''');
  static final _word = RegExp(r'[\p{L}\p{N}]', unicode: true);
  static final _color = RegExp(r'\{color(?::[^}]*)?\}');

  List<WikiInline> parse(WikiStyle style) {
    final out = <WikiInline>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      _addText(out, buffer.toString(), style);
      buffer.clear();
    }

    var i = 0;
    while (i < _s.length) {
      final c = _s[i];

      // Escapes: `\\` is a line break, `\x` a literal x.
      if (c == '\\' && i + 1 < _s.length) {
        buffer.write(_s[i + 1] == '\\' ? '\n' : _s[i + 1]);
        i += 2;
        continue;
      }

      if (_s.startsWith('{{', i)) {
        final end = _s.indexOf('}}', i + 2);
        if (end > i + 2) {
          flush();
          _addText(out, _s.substring(i + 2, end), style.copyWith(mono: true));
          i = end + 2;
          continue;
        }
      }

      final color = _color.matchAsPrefix(_s, i);
      if (color != null) {
        i = color.end;
        continue;
      }

      if (c == '[') {
        final end = _s.indexOf(']', i + 1);
        if (end > i + 1) {
          final link = _link(_s.substring(i + 1, end), style);
          if (link != null) {
            flush();
            out.add(link);
            i = end + 1;
            continue;
          }
        }
      }

      if (c == '!') {
        final image = RegExp(
          r'!([^!\s|][^!\n|]*)(?:\|[^!\n]*)?!',
        ).matchAsPrefix(_s, i);
        final source = image?.group(1)!.trim();
        if (image != null &&
            (source!.contains('.') || source.startsWith('http'))) {
          flush();
          out.add(WikiImage(source));
          i = image.end;
          continue;
        }
      }

      if (_emphasis.containsKey(c) && _opens(i)) {
        final end = _closing(c, i);
        if (end != null) {
          flush();
          final inner = _InlineParser(
            _s.substring(i + 1, end),
          ).parse(_with(style, _emphasis[c]!));
          out.addAll(inner);
          i = end + 1;
          continue;
        }
      }

      if ((c == 'h' || c == 'm') && (i == 0 || !_isWord(_s[i - 1]))) {
        final url = _url.matchAsPrefix(_s, i);
        if (url != null) {
          // Sentence punctuation after a URL isn't part of it.
          var link = url.group(0)!;
          final trimmed = link.replaceFirst(RegExp(r'[.,;:!?)]+$'), '');
          link = trimmed.isEmpty ? link : trimmed;
          flush();
          out.add(WikiLink(link, link, style));
          i += link.length;
          continue;
        }
      }

      buffer.write(c);
      i++;
    }
    flush();
    return out;
  }

  /// Joins [text] onto the last piece when it has the same style.
  static void _addText(List<WikiInline> out, String text, WikiStyle style) {
    final last = out.isEmpty ? null : out.last;
    if (last is WikiText && last.style == style) {
      out[out.length - 1] = WikiText(last.text + text, style);
    } else {
      out.add(WikiText(text, style));
    }
  }

  static WikiStyle _with(WikiStyle style, String name) => switch (name) {
    'bold' => style.copyWith(bold: true),
    'italic' => style.copyWith(italic: true),
    'strike' => style.copyWith(strike: true),
    _ => style.copyWith(underline: true),
  };

  /// `[~user]`, `[text|url]`, `[url]`; null for brackets that aren't a link.
  static WikiInline? _link(String inner, WikiStyle style) {
    if (inner.startsWith('~') && !inner.contains(' ')) {
      return WikiMention(inner.substring(1));
    }
    final bar = inner.lastIndexOf('|');
    final text = bar >= 0 ? inner.substring(0, bar).trim() : inner.trim();
    final url = bar >= 0 ? inner.substring(bar + 1).trim() : inner.trim();
    if (!RegExp(r'^(https?://|mailto:|file:)').hasMatch(url)) return null;
    return WikiLink(text.isEmpty ? url : text, url, style);
  }

  static bool _isWord(String c) => _word.hasMatch(c);

  /// Whether the marker at [i] can open emphasis: not inside a word, and
  /// followed by text rather than a space or another marker.
  bool _opens(int i) {
    if (i > 0 && _isWord(_s[i - 1])) return false;
    if (i + 1 >= _s.length) return false;
    final next = _s[i + 1];
    return next.trim().isNotEmpty && next != _s[i];
  }

  /// The index of the marker closing the one at [open], on the same line.
  int? _closing(String marker, int open) {
    final lineEnd = _s.indexOf('\n', open);
    final end = lineEnd < 0 ? _s.length : lineEnd;
    for (var j = open + 2; j < end; j++) {
      if (_s[j] != marker) continue;
      if (_s[j - 1].trim().isEmpty) continue;
      if (j + 1 < _s.length && _isWord(_s[j + 1])) continue;
      return j;
    }
    return null;
  }
}
