import 'package:tree_launcher/features/documents/domain/session_document.dart';

/// What in a text document won't show as it should in the viewer: the files
/// it refers to by relative path (the app stores the one file only) and what
/// it loads from the web (gone offline). One line per reference, in order,
/// without repeats.
///
/// Looks at `src`, `srcset`, stylesheet `href`s and `url(…)` in HTML (also
/// raw HTML in Markdown) and at Markdown image targets. A pattern search,
/// not a parser: it only has to catch what agent-written reports use.
List<String> documentReferenceWarnings(String text, DocumentFormat format) {
  if (!format.isText) return const [];
  final references = <String>[];
  for (final match in _src.allMatches(text)) {
    references.add(_attributeValue(match));
  }
  for (final match in _srcset.allMatches(text)) {
    for (final candidate in _attributeValue(match).split(',')) {
      final url = candidate.trim().split(RegExp(r'\s+')).first;
      if (url.isNotEmpty) references.add(url);
    }
  }
  for (final match in _linkTag.allMatches(text)) {
    final tag = match.group(0)!;
    if (!_stylesheet.hasMatch(tag)) continue;
    final href = _href.firstMatch(tag);
    if (href != null) references.add(_attributeValue(href));
  }
  for (final match in _cssUrl.allMatches(text)) {
    references.add(match.group(2)!.trim());
  }
  if (format == DocumentFormat.markdown) {
    for (final match in _markdownImage.allMatches(text)) {
      references.add(match.group(1)!);
    }
  }

  final warnings = <String>[];
  for (final reference in references) {
    final warning = _warningFor(reference.trim());
    if (warning != null && !warnings.contains(warning)) warnings.add(warning);
  }
  return warnings;
}

String? _warningFor(String reference) {
  if (reference.isEmpty || reference.startsWith('#')) return null;
  final lower = reference.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('//')) {
    return 'remote reference: $reference';
  }
  // data:, mailto:, javascript:, file: … have a scheme; only paths are
  // relative.
  if (RegExp(r'^[a-z][a-z0-9+.-]*:').hasMatch(lower)) return null;
  if (reference.startsWith('/')) {
    return "absolute path won't resolve: $reference";
  }
  return "relative reference won't resolve: $reference";
}

String _attributeValue(RegExpMatch match) =>
    match.group(2) ?? match.group(3) ?? '';

/// `="…"`, `='…'` or a bare value: the quoted value is group 2, a bare one
/// group 3.
const _value = r'''\s*=\s*(?:(["'])(.*?)\1|([^\s>"']+))''';
final _src = RegExp(r'''\bsrc''' + _value, caseSensitive: false);
final _srcset = RegExp(r'''\bsrcset''' + _value, caseSensitive: false);
final _href = RegExp(r'''\bhref''' + _value, caseSensitive: false);
final _linkTag = RegExp(r'<link\b[^>]*>', caseSensitive: false);
final _stylesheet = RegExp(
  r'''\brel\s*=\s*["']?[^"'>]*\bstylesheet\b''',
  caseSensitive: false,
);
final _cssUrl = RegExp(r'''url\(\s*(["']?)([^"')]+)\1\s*\)''');

/// `![alt](target "title")`; the target ends at whitespace or `)`.
final _markdownImage = RegExp(r'!\[[^\]]*\]\(\s*<?([^\s)>]+)>?');
