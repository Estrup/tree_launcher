import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/data/jira_issue_cache.dart';
import 'package:tree_launcher/features/jira/domain/jira_issue.dart';
import 'package:tree_launcher/features/jira/domain/jira_transition.dart';
import 'package:tree_launcher/features/jira/domain/jira_user.dart';
import 'package:tree_launcher/features/jira/presentation/widgets/jira_issue_dialog.dart';

class _MemoryCache extends JiraIssueCache {
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
    if (rejectWith != null) throw Exception(rejectWith);
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

void main() {
  late _MemoryCache cache;

  setUp(() => cache = _MemoryCache());

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
}
