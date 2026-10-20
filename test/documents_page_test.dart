import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/agents/data/agent_run_store.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/presentation/controllers/agents_controller.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agents_tab.dart';
import 'package:tree_launcher/features/documents/data/document_store.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_badges.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/documents_page.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/repo_pages.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(worktrees: const [], isBareLayout: false);

  @override
  Future<bool> isGitRepo(String path) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late WorkspaceController workspace;
  late SettingsController settings;
  late TerminalController terminal;
  late AgentsController agents;
  late DocumentsController documents;

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('documents_page_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => tempDir.path,
        );
    workspace = WorkspaceController(
      gitService: _FakeGitService(),
      repoConfigStore: FakeRepoConfigStore(),
      eventStore: WorktreeEventStore(testDatabase()),
      metadataStore: MemoryWorktreeMetadataStore(),
    );
    settings = SettingsController(store: FakeAppSettingsStore());
    terminal = TerminalController();
    agents = AgentsController(store: AgentRunStore(testDatabase()));
    documents = DocumentsController(
      store: DocumentStore(
        testDatabase(),
        directory: () async => '${tempDir.path}/documents',
      ),
    );
    await workspace.addRepo('/tmp/au2office');
  });

  tearDown(() async {
    await agents.flush();
    agents.dispose();
    documents.dispose();
    terminal.dispose();
    settings.dispose();
    workspace.dispose();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  String repoName() => workspace.selectedRepo!.name;

  Future<SessionDocument> save(
    String title, {
    String? agentId,
    AgentKind? kind,
    DocumentFormat format = DocumentFormat.markdown,
    List<String> issueKeys = const [],
    String? worktreePath,
  }) async => (await documents.save(
    DocumentDetails(
      repoName: repoName(),
      title: title,
      agentId: agentId,
      agentKind: kind,
      issueKeys: issueKeys,
      worktreePath: worktreePath,
    ),
    format,
    utf8.encode(format == DocumentFormat.pdf ? '%PDF-1.7' : '# $title'),
  )).document;

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
          ChangeNotifierProvider<SettingsController>.value(value: settings),
          ChangeNotifierProvider<TerminalController>.value(value: terminal),
          ChangeNotifierProvider<AgentsController>.value(value: agents),
          ChangeNotifierProvider<DocumentsController>.value(value: documents),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  test('a repo gets a Documents page once it has a document', () {
    final repo = workspace.selectedRepo;
    expect(
      repoPagesFor(repo, agents).map((p) => p.key),
      isNot(contains(documentsPageKey)),
    );
    expect(
      repoPagesFor(repo, agents, hasDocuments: true).map((p) => p.key),
      contains(documentsPageKey),
    );
  });

  testWidgets('the Documents page lists, filters and shows documents', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await save(
        'Refined AU2-1',
        kind: AgentKind.refine,
        agentId: 'ag_1',
        issueKeys: ['AU2-1'],
      );
      await save(
        'Build result',
        kind: AgentKind.build,
        agentId: 'ag_2',
        format: DocumentFormat.pdf,
      );
      await save('Plain notes', worktreePath: '/w/notes-wt');
    });
    await pump(tester, const DocumentsPage());

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Refined AU2-1'), findsOneWidget);
    expect(find.text('Build result'), findsWidgets);
    expect(find.text('PDF'), findsWidgets);
    // The newest is shown; no WebKit in tests.
    expect(
      find.text('The document viewer is not available here.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'au2-1');
    await tester.pump();
    expect(find.text('Refined AU2-1'), findsWidgets);
    expect(find.text('Plain notes'), findsNothing);

    await tester.enterText(find.byType(TextField), 'notes-wt');
    await tester.pump();
    expect(find.text('Plain notes'), findsWidgets);
    expect(find.text('Refined AU2-1'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('Refinement'));
    await tester.pump();
    expect(find.text('Refined AU2-1'), findsWidgets);
    expect(find.text('Plain notes'), findsNothing);
  });

  testWidgets('an agent card shows its run\'s documents and opens them', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final run = await agents.createForLaunch(
        kind: AgentKind.build,
        repoName: repoName(),
        title: 'Vipps callback',
        worktreePath: '/tmp/wt-vipps',
      );
      await save('Result: Vipps', agentId: run.id, kind: AgentKind.build);
      await save(
        'Report',
        agentId: run.id,
        kind: AgentKind.build,
        format: DocumentFormat.pdf,
      );
    });
    await pump(tester, const AgentsTab(kind: AgentKind.build));

    expect(find.text('Result: Vipps'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

    await tester.tap(find.text('Result: Vipps'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('From Build'), findsOneWidget);
  });

  testWidgets('a worktree badge counts its and its issue\'s documents', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await save('In the worktree', worktreePath: '/w/a');
      await save('About its issue', issueKeys: ['AU2-9']);
      await save('Elsewhere', worktreePath: '/w/b');
    });
    await pump(
      tester,
      const WorktreeDocumentsBadge(worktreePath: '/w/a', issueKey: 'AU2-9'),
    );
    expect(find.text('2'), findsOneWidget);

    await pump(tester, const WorktreeDocumentsBadge(worktreePath: '/w/none'));
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('issue and PR badges count their documents and list them', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await save('About AU2-9', issueKeys: ['AU2-9']);
      await save('Also AU2-9', issueKeys: ['AU2-9', 'AU2-10']);
      await save('Other', issueKeys: ['AU2-11']);
      await documents.save(
        DocumentDetails(repoName: repoName(), title: 'PR review', prNumber: 42),
        DocumentFormat.html,
        utf8.encode('<p>ok</p>'),
      );
    });

    await pump(tester, const IssueDocumentsBadge(issueKey: 'AU2-9'));
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.text('About AU2-9'), findsOneWidget);
    expect(find.text('Also AU2-9'), findsOneWidget);
    expect(find.text('Other'), findsNothing);

    // The PR's own document and its issue's.
    await pump(
      tester,
      PullRequestDocumentsBadge(
        repoName: repoName(),
        number: 42,
        issueKey: 'AU2-11',
      ),
    );
    expect(find.text('2'), findsOneWidget);
    await pump(
      tester,
      const PullRequestDocumentsBadge(repoName: 'elsewhere', number: 42),
    );
    expect(find.byType(DocumentsBadge), findsNothing);
  });
}
