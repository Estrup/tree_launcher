import 'package:markdown/markdown.dart' as md;

/// The colours a rendered Markdown page uses, as CSS colours; taken from the
/// app's palette, so a document reads like the rest of the app.
class DocumentPageStyle {
  const DocumentPageStyle({
    required this.dark,
    required this.background,
    required this.text,
    required this.mutedText,
    required this.link,
    required this.border,
    required this.codeBackground,
  });

  final bool dark;
  final String background;
  final String text;
  final String mutedText;
  final String link;
  final String border;
  final String codeBackground;
}

/// [markdown] as a whole HTML page titled [title], in [style].
///
/// GitHub-flavoured: tables, task lists, fenced code, strikethrough,
/// autolinks. Raw HTML passes through, as on GitHub.
String markdownPage(
  String markdown, {
  required String title,
  required DocumentPageStyle style,
}) {
  final body = md.markdownToHtml(
    markdown,
    extensionSet: md.ExtensionSet.gitHubWeb,
  );
  return '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="${style.dark ? 'dark' : 'light'}">
<title>${_escape(title)}</title>
<style>${_css(style)}</style>
</head>
<body>
<main>
$body
</main>
</body>
</html>
''';
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _css(DocumentPageStyle s) =>
    '''
:root { color-scheme: ${s.dark ? 'dark' : 'light'}; }
html { background: ${s.background}; }
body {
  margin: 0;
  color: ${s.text};
  background: ${s.background};
  font: 14px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
}
main { max-width: 860px; margin: 0 auto; padding: 24px 32px 48px; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 0.6em; }
h1 { font-size: 1.9em; padding-bottom: 0.3em; border-bottom: 1px solid ${s.border}; }
h2 { font-size: 1.45em; padding-bottom: 0.25em; border-bottom: 1px solid ${s.border}; }
h3 { font-size: 1.2em; }
main > :first-child { margin-top: 0; }
a { color: ${s.link}; text-decoration: none; }
a:hover { text-decoration: underline; }
p, ul, ol, table, pre, blockquote { margin: 0 0 1em; }
ul, ol { padding-left: 1.8em; }
li + li { margin-top: 0.2em; }
ul.contains-task-list { list-style: none; padding-left: 1.4em; }
.task-list-item > input { margin: 0 0.5em 0 -1.4em; }
blockquote { margin-left: 0; padding: 0 1em; color: ${s.mutedText}; border-left: 3px solid ${s.border}; }
code, pre { font: 12.5px/1.5 ui-monospace, "SF Mono", Menlo, monospace; }
code { background: ${s.codeBackground}; padding: 0.15em 0.35em; border-radius: 4px; }
pre { background: ${s.codeBackground}; padding: 12px 14px; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid ${s.border}; padding: 6px 12px; text-align: left; }
th { background: ${s.codeBackground}; }
hr { border: 0; border-top: 1px solid ${s.border}; margin: 1.5em 0; }
img { max-width: 100%; }
''';
