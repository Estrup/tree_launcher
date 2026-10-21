import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xterm/xterm.dart';
import 'package:tree_launcher/features/terminal/presentation/widgets/terminal_links.dart';
import 'package:tree_launcher/features/terminal/domain/terminal_link.dart';

/// The link at the first occurrence of [at] in [text].
TerminalLinkMatch? linkAt(String text, String at) =>
    findTerminalLink(text, text.indexOf(at));

String? linkText(String text, String at) {
  final match = linkAt(text, at);
  return match == null ? null : text.substring(match.start, match.end);
}

void main() {
  group('URLs', () {
    test('a URL anywhere in it', () {
      const text = 'Opened https://github.com/a/b/pull/12 for you';
      expect(
        linkAt(text, 'https')!.target,
        const UrlLinkTarget('https://github.com/a/b/pull/12'),
      );
      expect(
        linkAt(text, 'pull')!.target,
        const UrlLinkTarget('https://github.com/a/b/pull/12'),
      );
      expect(linkAt(text, 'Opened'), isNull);
      expect(linkAt(text, 'for'), isNull);
    });

    test('drops sentence punctuation and unmatched brackets', () {
      expect(
        linkText('see https://example.com/x.', 'https'),
        'https://example.com/x',
      );
      expect(
        linkText('(https://example.com/x)', 'https'),
        'https://example.com/x',
      );
      expect(
        linkText('https://en.wikipedia.org/wiki/A_(b)', 'https'),
        'https://en.wikipedia.org/wiki/A_(b)',
      );
      expect(
        linkText('"https://example.com/?q=1"', 'https'),
        'https://example.com/?q=1',
      );
    });

    test('ends at symbols a TUI draws', () {
      expect(
        linkText('│ https://example.com/a│', 'https'),
        'https://example.com/a',
      );
    });

    test('file URLs', () {
      expect(
        linkAt('file:///tmp/a.txt', 'file')!.target,
        const UrlLinkTarget('file:///tmp/a.txt'),
      );
    });
  });

  group('paths', () {
    test('relative and absolute', () {
      expect(
        linkAt('Edited lib/main.dart now', 'main')!.target,
        const PathLinkTarget('lib/main.dart'),
      );
      expect(
        linkAt('at /Users/me/x.txt', 'me')!.target,
        const PathLinkTarget('/Users/me/x.txt'),
      );
      expect(
        linkAt('~/notes/a.md', 'notes')!.target,
        const PathLinkTarget('~/notes/a.md'),
      );
      expect(
        linkAt('Update(pubspec.yaml)', 'pubspec')!.target,
        const PathLinkTarget('pubspec.yaml'),
      );
    });

    test('with a line and column', () {
      expect(
        linkAt('lib/a.dart:42', 'a.dart')!.target,
        const PathLinkTarget('lib/a.dart', line: 42),
      );
      expect(
        linkAt('lib/a.dart:42:7', '42')!.target,
        const PathLinkTarget('lib/a.dart', line: 42, column: 7),
      );
      expect(
        linkAt('lib/a.dart:10-20', 'lib')!.target,
        const PathLinkTarget('lib/a.dart', line: 10),
      );
      expect(
        linkAt('lib/a.dart#L12', 'lib')!.target,
        const PathLinkTarget('lib/a.dart', line: 12),
      );
    });

    test('in markdown and Claude output', () {
      expect(
        linkAt('[a.dart](lib/a.dart:3)', 'lib')!.target,
        const PathLinkTarget('lib/a.dart', line: 3),
      );
      expect(
        linkAt('  ⎿  Read lib/a.dart', 'lib')!.target,
        const PathLinkTarget('lib/a.dart'),
      );
      expect(linkText('see lib/a.dart.', 'lib'), 'lib/a.dart');
      expect(linkText('`lib/a.dart`', 'lib'), 'lib/a.dart');
    });

    test('not plain words or dots', () {
      expect(linkAt('hello world', 'world'), isNull);
      expect(linkAt('cd ..', '..'), isNull);
      expect(linkAt('x . y', '.'), isNull);
      expect(linkAt('a  b', ' '), isNull);
    });
  });

  group('in the terminal', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('terminal_link');
      File(p.join(dir.path, 'lib', 'a.dart')).createSync(recursive: true);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Terminal terminal(String output, {int width = 40}) => Terminal()
      ..resize(width, 10)
      ..write(output);

    test('an existing file, by its cells', () {
      final t = terminal('ok 界 lib/a.dart:3 and lib/b.dart');
      final link = terminalLinkAt(t.buffer, const CellOffset(9, 0), dir.path)!;
      expect(link.begin, const CellOffset(6, 0));
      expect(link.end, const CellOffset(18, 0));
      expect(
        link.target,
        PathLinkTarget(p.join(dir.path, 'lib', 'a.dart'), line: 3),
      );
      expect(link.isDirectory, isFalse);
      // Doesn't exist.
      expect(
        terminalLinkAt(t.buffer, const CellOffset(25, 0), dir.path),
        isNull,
      );
    });

    test('a folder', () {
      final t = terminal('cd lib');
      final link = terminalLinkAt(t.buffer, const CellOffset(4, 0), dir.path);
      expect(link, isNull, reason: 'no / or . in it');
      final t2 = terminal('cd ./lib');
      expect(
        terminalLinkAt(
          t2.buffer,
          const CellOffset(4, 0),
          dir.path,
        )!.isDirectory,
        isTrue,
      );
    });

    test('a URL wrapped onto the next row', () {
      final t = terminal('see https://example.com/abcdefghij', width: 20);
      final link = terminalLinkAt(t.buffer, const CellOffset(2, 1), dir.path)!;
      expect(
        link.target,
        const UrlLinkTarget('https://example.com/abcdefghij'),
      );
      expect(link.begin, const CellOffset(4, 0));
      expect(link.end, const CellOffset(14, 1));
    });
  });
}
