import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_attachment.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issue_dialog.dart';

import 'fake_config_stores.dart';
import 'test_database.dart';

class _MemoryCache extends JiraIssueCache {
  _MemoryCache() : super(testDatabase());

  final Map<String, CachedJiraIssue> entries = {};

  @override
  Future<CachedJiraIssue?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, JiraIssue issue, {DateTime? fetchedAt}) async {
    entries[key] = CachedJiraIssue(
      issue: issue,
      fetchedAt: fetchedAt ?? DateTime.now(),
    );
  }
}

class _FailingJiraService extends JiraApiService {
  @override
  Future<JiraIssue> fetchIssue(String key) async =>
      throw Exception('Jira is unreachable');

  @override
  Future<JiraUser> fetchMyself() async =>
      throw Exception('Jira is unreachable');
}

const _me = JiraUser(name: 'sen', displayName: 'Steffen Nielsen');

/// A workflow where the issue can start progress; the transition applies.
class _WorkflowJiraService extends JiraApiService {
  _WorkflowJiraService({this.rejectWith});

  final String? rejectWith;
  final applied = <String>[];
  final assignedTo = <String>[];
  String status = 'Authorized';
  String? assignee = 'Susanne Nielsen';

  @override
  Future<JiraIssue> fetchIssue(String key) async => JiraIssue(
    key: key,
    summary: _issue.summary,
    status: status,
    statusCategory: status == 'In Progress' ? 'indeterminate' : 'new',
    assignee: assignee,
  );

  @override
  Future<JiraUser> fetchMyself() async => _me;

  @override
  Future<void> assignIssue(String key, String userName) async {
    assignedTo.add(userName);
    assignee = _me.displayName;
  }

  @override
  Future<List<JiraTransition>> fetchTransitions(String key) async => const [
    JiraTransition(
      id: '21',
      name: 'Start Progress',
      toStatus: 'In Progress',
      toStatusCategory: 'indeterminate',
    ),
    JiraTransition(id: '31', name: 'Done', toStatus: 'Done'),
  ];

  @override
  Future<void> transitionIssue(String key, String transitionId) async {
    if (rejectWith != null) throw JiraApiException(400, rejectWith!);
    applied.add(transitionId);
    status = 'In Progress';
  }
}

final _issue = JiraIssue(
  key: 'AU2-5788',
  summary: 'Udlån sker til en Kontakt',
  status: 'Authorized',
  statusCategory: 'indeterminate',
  issueType: 'Story',
  assignee: 'Susanne Nielsen',
  priority: 'Medium',
  description: 'Hvad skal der ske i sådanne situationer?\n\n' * 20,
  updated: DateTime.now().subtract(const Duration(hours: 3)),
  comments: [
    JiraComment(
      author: 'Steffen Nielsen',
      body: 'Påbegynd ikke denne opgave endnu',
      created: DateTime.now().subtract(const Duration(days: 40)),
    ),
  ],
);

const _screenshot = JiraAttachment(
  id: '901',
  filename: 'image-2025-11-11-10-29-42-413.png',
  mimeType: 'image/png',
  size: 48 * 1024,
  contentUrl: 'https://jira.example/secure/attachment/901/image.png',
);

const _report = JiraAttachment(
  id: '902',
  filename: 'rapport.pdf',
  mimeType: 'application/pdf',
  size: 2 * 1024 * 1024,
  contentUrl: 'https://jira.example/secure/attachment/902/rapport.pdf',
);

/// Records comments, user searches and downloads.
class _CommentingJiraService extends _WorkflowJiraService {
  final added = <(String, String?)>[];
  final downloaded = <String>[];

  @override
  Future<void> addComment(
    String key,
    String body, {
    String? visibleToRole,
  }) async => added.add((body, visibleToRole));

  @override
  Future<List<JiraUser>> searchMentionableUsers(
    String key,
    String query, {
    int limit = 8,
  }) async => [
    const JiraUser(name: 'sun@cac.dk', displayName: 'Susanne Nielsen'),
  ].where((u) => u.name.startsWith(query)).toList();

  @override
  Future<JiraUser> fetchUser(String name) async =>
      JiraUser(name: name, displayName: 'Susanne Nielsen');

  @override
  Future<String> downloadAttachment(JiraAttachment attachment) async {
    downloaded.add(attachment.id);
    return '/tmp/${attachment.filename}';
  }
}

void main() {
  late _MemoryCache cache;
  late MemoryJiraCommentDraftStore drafts;
  late List<String> opened;

  setUp(() {
    cache = _MemoryCache();
    drafts = MemoryJiraCommentDraftStore();
    opened = [];
  });

  Future<void> open(
    WidgetTester tester, {
    JiraApiService? service,
    VoidCallback? onIssueChanged,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => JiraIssueDialog.show(
                context,
                issueKey: 'AU2-5788',
                service: service ?? _FailingJiraService(),
                onIssueChanged: onIssueChanged,
                cache: cache,
                drafts: drafts,
                open: opened.add,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a cached issue in a wide dialog', (tester) async {
    await cache.write('AU2-5788', _issue);

    await open(tester);

    expect(find.text('Udlån sker til en Kontakt'), findsOneWidget);
    expect(find.text('Authorized'), findsOneWidget);
    expect(find.text('Susanne Nielsen'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Updated 3h ago'), findsOneWidget);
    expect(find.text('Steffen Nielsen'), findsOneWidget);
    expect(find.text('SN'), findsOneWidget);
    final surface = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    expect(tester.getSize(surface).width, 860);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the error when nothing is cached and Jira fails', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Jira is unreachable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changes the status through a workflow transition', (
    tester,
  ) async {
    await cache.write('AU2-5788', _issue);
    final service = _WorkflowJiraService();
    await open(tester, service: service);

    await tester.tap(find.text('Authorized'));
    await tester.pumpAndSettle();
    // The transition's name shows after its status when they differ.
    expect(find.text('Start Progress'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();

    expect(service.applied, ['21']);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Authorized'), findsNothing);
    expect(cache.entries['AU2-5788']?.issue.status, 'In Progress');
  });

  testWidgets("shows Jira's reason when a transition is refused", (
    tester,
  ) async {
    await cache.write('AU2-5788', _issue);
    await open(
      tester,
      service: _WorkflowJiraService(
        rejectWith: 'Jira rejected the request: Resolution is required.',
      ),
    );

    await tester.tap(find.text('Authorized'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(
      find.text('Jira rejected the request: Resolution is required.'),
      findsOneWidget,
    );
    expect(find.text('Authorized'), findsOneWidget);
  });

  testWidgets('assigns the issue to the token user', (tester) async {
    await cache.write('AU2-5788', _issue);
    final service = _WorkflowJiraService();
    var changes = 0;
    await open(tester, service: service, onIssueChanged: () => changes++);

    await tester.tap(find.text('Assign to me'));
    await tester.pumpAndSettle();

    expect(service.assignedTo, ['sen']);
    expect(changes, 1);
    expect(find.text('Steffen Nielsen'), findsWidgets);
    expect(find.text('Susanne Nielsen'), findsNothing);
    expect(find.text('Assign to me'), findsNothing);
    expect(cache.entries['AU2-5788']?.issue.assignee, 'Steffen Nielsen');
  });

  testWidgets('offers no "Assign to me" on my own issue', (tester) async {
    await cache.write(
      'AU2-5788',
      JiraIssue(key: 'AU2-5788', summary: 'Mine', assignee: 'Steffen Nielsen'),
    );
    await open(tester, service: _WorkflowJiraService());

    expect(find.text('Assign to me'), findsNothing);
  });

  group('rendering', () {
    final issue = JiraIssue(
      key: 'AU2-5788',
      summary: 'Udlån',
      description:
          'h4. Baggrund\n'
          'Se skærmbilledet !image-2025-11-11-10-29-42-413.png!\n'
          '* punkt med *fed*\n'
          'Spørg [~sun@cac.dk]',
      attachments: const [_screenshot, _report],
      comments: [
        JiraComment(
          author: 'Steffen Nielsen',
          body: 'Kun til os',
          visibility: 'Consultants',
          created: DateTime.now(),
        ),
      ],
    );

    testWidgets('renders headings, lists and mention names', (tester) async {
      await cache.write('AU2-5788', issue);
      await open(tester, service: _CommentingJiraService());

      expect(find.text('Baggrund', findRichText: true), findsOneWidget);
      expect(find.text('•'), findsOneWidget);
      expect(
        find.textContaining('@Susanne Nielsen', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('h4.', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an image reference opens its attachment', (tester) async {
      await cache.write('AU2-5788', issue);
      final service = _CommentingJiraService();
      await open(tester, service: service);

      // Once in the description, once in the attachments.
      expect(find.text(_screenshot.filename), findsNWidgets(2));
      await tester.tap(find.text(_screenshot.filename).first);
      await tester.pumpAndSettle();

      expect(service.downloaded, ['901']);
      expect(opened, ['/tmp/${_screenshot.filename}']);
    });

    testWidgets('lists attachments, which open on a click', (tester) async {
      await cache.write('AU2-5788', issue);
      final service = _CommentingJiraService();
      await open(tester, service: service);

      expect(find.text('ATTACHMENTS'), findsOneWidget);
      expect(find.text('2.0 MB'), findsOneWidget);
      await tester.tap(find.text('rapport.pdf'));
      await tester.pumpAndSettle();

      expect(service.downloaded, ['902']);
      expect(opened, ['/tmp/rapport.pdf']);
    });

    testWidgets('marks consultant-only comments', (tester) async {
      await cache.write('AU2-5788', issue);
      await open(tester, service: _CommentingJiraService());

      expect(find.text('Consultants'), findsOneWidget);
    });
  });

  group('writing a comment', () {
    Finder editor() => find.byType(TextField);

    /// Taps [finder] after scrolling it into view below the description.
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
    }

    testWidgets('sends it to consultants only and clears the draft', (
      tester,
    ) async {
      await cache.write('AU2-5788', _issue);
      final service = _CommentingJiraService();
      await open(tester, service: service);

      await tester.enterText(editor(), 'Intern note');
      await tapVisible(tester, find.text('Consultants only'));
      await tester.pump(const Duration(seconds: 1));
      expect(drafts.drafts['AU2-5788']?.consultantsOnly, isTrue);

      await tapVisible(tester, find.text('Comment to consultants'));
      await tester.pumpAndSettle();

      expect(service.added, [('Intern note', 'Consultants')]);
      expect(drafts.drafts, isEmpty);
      expect(drafts.consultantsOnly, isTrue);
      expect(tester.widget<TextField>(editor()).controller!.text, isEmpty);
    });

    testWidgets('saves a draft while typing and brings it back', (
      tester,
    ) async {
      await cache.write('AU2-5788', _issue);
      await open(tester, service: _CommentingJiraService());

      await tester.enterText(editor(), 'Halvfærdig');
      await tester.pump(const Duration(seconds: 1));
      expect(drafts.drafts['AU2-5788']?.body, 'Halvfærdig');
      expect(find.textContaining('Draft saved'), findsOneWidget);

      Navigator.of(tester.element(editor())).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(editor()).controller!.text, 'Halvfærdig');
    });

    testWidgets('keeps what was typed when closed before the save', (
      tester,
    ) async {
      await cache.write('AU2-5788', _issue);
      await open(tester, service: _CommentingJiraService());

      await tester.enterText(editor(), 'Hurtigt lukket');
      Navigator.of(tester.element(editor())).pop();
      await tester.pumpAndSettle();

      expect(drafts.drafts['AU2-5788']?.body, 'Hurtigt lukket');
    });

    testWidgets('mentions a user picked from the suggestions', (tester) async {
      await cache.write('AU2-5788', _issue);
      await open(tester, service: _CommentingJiraService());

      await tester.enterText(editor(), 'Hej @sun');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('sun@cac.dk'), findsOneWidget);

      await tapVisible(tester, find.text('sun@cac.dk'));
      await tester.pump();

      expect(
        tester.widget<TextField>(editor()).controller!.text,
        'Hej [~sun@cac.dk] ',
      );
      expect(find.text('sun@cac.dk'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('bold wraps the selection', (tester) async {
      await cache.write('AU2-5788', _issue);
      await open(tester, service: _CommentingJiraService());

      await tester.enterText(editor(), 'gør det nu');
      final controller = tester.widget<TextField>(editor()).controller!;
      controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 7,
      );
      await tapVisible(tester, find.byTooltip('Bold (⌘B)'));
      await tester.pump();

      expect(controller.text, 'gør *det* nu');
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
