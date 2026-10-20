import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tree_launcher/core/database/app_database.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/documents/data/document_store.dart';
import 'package:tree_launcher/features/documents/domain/document_references.dart';
import 'package:tree_launcher/features/documents/domain/markdown_html.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';

import 'test_database.dart';

const _style = DocumentPageStyle(
  dark: true,
  background: '#111111',
  text: '#eeeeee',
  mutedText: '#999999',
  link: '#88aaff',
  border: '#333333',
  codeBackground: '#222222',
);

void main() {
  group('documentReferenceWarnings', () {
    test('reports relative and remote references in HTML', () {
      const html = '''
<link rel="stylesheet" href="style.css">
<link rel="icon" href="favicon.png">
<img src="shots/a.png" srcset="shots/a@2x.png 2x, https://cdn.example.com/b.png 3x">
<script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
<div style="background: url('bg.png')"></div>
<img src="data:image/png;base64,AAAA">
<a href="#top">top</a>
<img src=/abs/c.png>
''';
      expect(documentReferenceWarnings(html, DocumentFormat.html), [
        "relative reference won't resolve: shots/a.png",
        'remote reference: https://cdn.jsdelivr.net/npm/chart.js',
        "absolute path won't resolve: /abs/c.png",
        "relative reference won't resolve: shots/a@2x.png",
        'remote reference: https://cdn.example.com/b.png',
        "relative reference won't resolve: style.css",
        "relative reference won't resolve: bg.png",
      ]);
    });

    test('reports Markdown images, once each', () {
      const markdown = '''
![before](shots/before.png "Before") and ![again](shots/before.png)
![inline](data:image/png;base64,AAAA)
[a link](other.md) is not an image.
''';
      expect(documentReferenceWarnings(markdown, DocumentFormat.markdown), [
        "relative reference won't resolve: shots/before.png",
      ]);
    });

    test('checks nothing in a PDF', () {
      expect(
        documentReferenceWarnings('<img src="a.png">', DocumentFormat.pdf),
        isEmpty,
      );
    });
  });

  group('markdownPage', () {
    test('renders GitHub-flavoured Markdown in the given style', () {
      final html = markdownPage(
        '# Result\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n'
        '- [x] done\n\n```dart\nvoid main() {}\n```\n\n<kbd>raw</kbd>\n',
        title: 'R&D <notes>',
        style: _style,
      );
      expect(html, contains('<h1 id="result">Result</h1>'));
      expect(html, contains('<table>'));
      expect(html, contains('type="checkbox"'));
      expect(html, contains('<pre><code class="language-dart">'));
      expect(html, contains('<kbd>raw</kbd>'));
      expect(html, contains('<title>R&amp;D &lt;notes&gt;</title>'));
      expect(html, contains('background: #111111'));
      expect(html, contains('color-scheme: dark'));
    });
  });

  group('DocumentStore and DocumentsController', () {
    late AppDatabase db;
    late Directory dir;
    late DocumentStore store;
    late DocumentsController controller;
    var now = DateTime(2026, 10, 20, 14);

    setUp(() async {
      db = testDatabase();
      dir = await Directory.systemTemp.createTemp('documents_test');
      store = DocumentStore(db, directory: () async => dir.path);
      controller = DocumentsController(store: store, clock: () => now);
    });

    tearDown(() async {
      controller.dispose();
      await dir.delete(recursive: true);
    });

    DocumentDetails details({
      String? name,
      String? agentId,
      List<String> issueKeys = const ['AU2-5407'],
    }) => DocumentDetails(
      repoName: 'au2office',
      title: 'Result',
      name: name,
      agentId: agentId,
      agentKind: agentId == null ? null : AgentKind.build,
      worktreePath: '/w/vipps-au2-5407',
      issueKeys: issueKeys,
    );

    test('saves the file and its details, and loads them again', () async {
      final saved = await controller.save(
        details(agentId: 'ag_1', issueKeys: ['AU2-5407', 'AU2-5408']),
        DocumentFormat.markdown,
        utf8.encode('# Result'),
      );
      final document = saved.document;
      expect(saved.replaced, isFalse);
      expect(document.id, startsWith('doc_'));
      expect(document.filePath, p.join(dir.path, '${document.id}.md'));
      expect(await File(document.filePath).readAsString(), '# Result');
      expect(await controller.readText(document.id), '# Result');

      final reloaded = DocumentsController(
        store: DocumentStore(db, directory: () async => dir.path),
      );
      addTearDown(reloaded.dispose);
      await reloaded.load();
      final loaded = reloaded.documentById(document.id)!;
      expect(loaded.issueKeys, ['AU2-5407', 'AU2-5408']);
      expect(loaded.agentKind, AgentKind.build);
      expect(loaded.sizeBytes, 8);
      expect(loaded.filePath, document.filePath);
    });

    test('replaces a run\'s document of the same name', () async {
      final first = await controller.save(
        details(agentId: 'ag_1', name: 'result'),
        DocumentFormat.markdown,
        utf8.encode('# v1'),
      );
      now = now.add(const Duration(minutes: 5));
      final second = await controller.save(
        details(agentId: 'ag_1', name: 'result'),
        DocumentFormat.pdf,
        utf8.encode('%PDF-1.7'),
      );

      expect(second.replaced, isTrue);
      expect(second.document.id, first.document.id);
      expect(second.document.createdAt, first.document.createdAt);
      expect(second.document.updatedAt, now);
      expect(await File(first.document.filePath).exists(), isFalse);
      expect(await File(second.document.filePath).exists(), isTrue);
      expect(controller.documents, hasLength(1));

      // Another run, or no name, adds a document.
      await controller.save(
        details(agentId: 'ag_2', name: 'result'),
        DocumentFormat.markdown,
        utf8.encode('x'),
      );
      await controller.save(
        details(),
        DocumentFormat.markdown,
        utf8.encode('x'),
      );
      expect(controller.documents, hasLength(3));
    });

    test('deletes the row, the issues, the file and the cache', () async {
      final document = (await controller.save(
        details(),
        DocumentFormat.html,
        utf8.encode('<p>hi</p>'),
      )).document;
      final cache = File(await controller.renderedPathFor(document.id));
      await cache.create(recursive: true);

      await controller.delete(document.id);

      expect(controller.documentById(document.id), isNull);
      expect(await File(document.filePath).exists(), isFalse);
      expect(await cache.exists(), isFalse);
      expect(await db.select(db.documentIssues).get(), isEmpty);
    });

    test('filters by repo, run, issue, worktree, kind and format', () async {
      await controller.save(
        details(agentId: 'ag_1'),
        DocumentFormat.markdown,
        utf8.encode('a'),
      );
      await controller.save(
        DocumentDetails(repoName: 'other', title: 'B'),
        DocumentFormat.pdf,
        utf8.encode('%PDF-'),
      );

      expect(controller.documentsFor(repoName: 'au2office'), hasLength(1));
      expect(controller.documentsFor(agentId: 'ag_1'), hasLength(1));
      expect(controller.documentsFor(issueKey: 'AU2-5407'), hasLength(1));
      expect(controller.documentsFor(worktree: 'vipps-au2-5407'), hasLength(1));
      expect(
        controller.documentsFor(worktree: '/w/vipps-au2-5407/'),
        hasLength(1),
      );
      expect(controller.documentsFor(kind: AgentKind.build), hasLength(1));
      expect(controller.documentsFor(format: DocumentFormat.pdf), hasLength(1));
      expect(controller.documentsFor(kind: AgentKind.verify), isEmpty);
      expect(controller.hasDocumentsFor('other'), isTrue);
      expect(
        controller.documentsForWorktree('/elsewhere', issueKey: 'AU2-5407'),
        hasLength(1),
      );
    });
  });
}
