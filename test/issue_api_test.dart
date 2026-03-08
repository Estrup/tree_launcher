import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/models/comment.dart';
import 'package:tree_launcher/models/issue_status.dart';
import 'package:tree_launcher/models/project.dart';
import 'package:tree_launcher/services/comment_repository.dart';
import 'package:tree_launcher/services/database_service.dart';
import 'package:tree_launcher/services/issue_api_controller.dart';
import 'package:tree_launcher/services/issue_api_service.dart';
import 'package:tree_launcher/services/issue_repository.dart';
import 'package:tree_launcher/services/project_repository.dart';

void main() {
  group('IssueApiService', () {
    late _IssueApiHarness harness;

    setUp(() {
      harness = _IssueApiHarness();
    });

    tearDown(() {
      harness.dispose();
    });

    test('creates, updates, archives, and comments on issues', () {
      final project = harness.createProject(
        repoPath: '/repos/kanban',
        name: 'Platform',
        key: 'PLT',
      );

      final created = harness.service.createIssue(
        project.repoPath,
        project.key,
        'Expose local API',
        description: 'Initial scope',
      );
      expect(created.issue.displayId, 'PLT-001');

      final updated = harness.service.updateIssue(
        created.issue.displayId,
        title: 'Expose issue API',
        description: null,
        tags: const ['agent', 'api'],
        status: IssueStatus.inProgress,
      );

      expect(updated.issue.title, 'Expose issue API');
      expect(updated.issue.description, isNull);
      expect(updated.issue.tags, ['agent', 'api']);
      expect(updated.issue.status, IssueStatus.inProgress);

      final comment = harness.service.addComment(
        updated.issue.displayId,
        content: 'Started implementation',
        authorName: 'Codex',
      );
      expect(comment.comment.authorType, CommentAuthorType.agent);

      final comments = harness.service.listComments(updated.issue.displayId);
      expect(comments.comments, hasLength(1));
      expect(comments.comments.first.content, 'Started implementation');

      final archived = harness.service.archiveIssue(updated.issue.displayId);
      expect(archived.issue.isArchived, isTrue);
    });

    test('fails on ambiguous display ids across repositories', () {
      final projectOne = harness.createProject(
        repoPath: '/repos/one',
        name: 'Platform',
        key: 'PLT',
      );
      final projectTwo = harness.createProject(
        repoPath: '/repos/two',
        name: 'Platform',
        key: 'PLT',
      );
      harness.issueRepository.createIssue(projectOne.id, 'PLT', 'A');
      harness.issueRepository.createIssue(projectTwo.id, 'PLT', 'B');

      expect(
        () => harness.service.getIssue('PLT-001'),
        throwsA(
          isA<IssueApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            409,
          ),
        ),
      );
    });

    test('scopes issue lookup and preserves orphan diagnostics', () {
      final project = harness.createProject(
        repoPath: '/repos/kanban',
        name: 'Platform',
        key: 'PLT',
      );
      final valid = harness.service.createIssue(
        project.repoPath,
        project.key,
        'Real issue',
      );
      harness.issueRepository.createIssue(
        'missing-project',
        'PLT',
        'Orphaned copy',
      );

      final resolved = harness.service.getIssue(
        valid.issue.displayId,
        repoPath: project.repoPath,
      );

      expect(resolved.issue.id, valid.issue.id);
      expect(
        resolved.diagnostics['orphanedMatches'],
        isA<List<dynamic>>().having((matches) => matches.length, 'length', 1),
      );
    });
  });

  group('IssueApiController', () {
    late _IssueApiHarness harness;
    late List<String> mutatedRepoPaths;
    late IssueApiController controller;

    setUp(() {
      harness = _IssueApiHarness();
      mutatedRepoPaths = [];
      controller = IssueApiController(
        issueService: harness.service,
        onRepoMutated: (repoPath) async {
          mutatedRepoPaths.add(repoPath);
        },
      );
    });

    tearDown(() {
      harness.dispose();
    });

    test('returns validation errors for missing create parameters', () async {
      final response = await controller.handle(
        const IssueApiRequest(
          method: 'POST',
          pathSegments: ['api', 'issues'],
          queryParameters: {},
          body: {'repoPath': '/repos/kanban'},
        ),
      );

      expect(response.statusCode, 400);
      expect(response.ok, isFalse);
      expect(response.summary, 'project is required.');
    });

    test('returns not found for unknown issues', () async {
      final response = await controller.handle(
        const IssueApiRequest(
          method: 'GET',
          pathSegments: ['api', 'issues', 'PLT-001'],
          queryParameters: {},
        ),
      );

      expect(response.statusCode, 404);
      expect(response.ok, isFalse);
    });

    test('rejects invalid status values on patch', () async {
      final project = harness.createProject(
        repoPath: '/repos/kanban',
        name: 'Platform',
        key: 'PLT',
      );
      final issue = harness.service.createIssue(
        project.repoPath,
        project.key,
        'Expose local API',
      );

      final response = await controller.handle(
        IssueApiRequest(
          method: 'PATCH',
          pathSegments: ['api', 'issues', issue.issue.displayId],
          queryParameters: const {},
          body: const {'status': 'blocked'},
        ),
      );

      expect(response.statusCode, 400);
      expect(
        response.summary,
        'status must be one of todo, inProgress, inReview, done.',
      );
    });

    test('creates issue and reports mutation callback', () async {
      final project = harness.createProject(
        repoPath: '/repos/kanban',
        name: 'Platform',
        key: 'PLT',
      );

      final response = await controller.handle(
        IssueApiRequest(
          method: 'POST',
          pathSegments: const ['api', 'issues'],
          queryParameters: const {},
          body: {
            'repoPath': project.repoPath,
            'project': project.key,
            'title': 'Expose local API',
          },
        ),
      );

      expect(response.statusCode, 201);
      expect(response.ok, isTrue);
      expect(response.data['issue']['displayId'], 'PLT-001');
      expect(mutatedRepoPaths, [project.repoPath]);
    });

    test('creates issue with initial status', () async {
      final project = harness.createProject(
        repoPath: '/repos/kanban',
        name: 'Platform',
        key: 'PLT',
      );

      final response = await controller.handle(
        IssueApiRequest(
          method: 'POST',
          pathSegments: const ['api', 'issues'],
          queryParameters: const {},
          body: {
            'repoPath': project.repoPath,
            'project': project.key,
            'title': 'Expose local API',
            'status': 'inReview',
          },
        ),
      );

      expect(response.statusCode, 201);
      expect(response.data['issue']['status'], 'inReview');
    });

    test('scopes issue lookups by repo path', () async {
      final projectOne = harness.createProject(
        repoPath: '/repos/one',
        name: 'Platform',
        key: 'PLT',
      );
      final projectTwo = harness.createProject(
        repoPath: '/repos/two',
        name: 'Platform',
        key: 'PLT',
      );
      harness.issueRepository.createIssue(projectOne.id, 'PLT', 'A');
      harness.issueRepository.createIssue(projectTwo.id, 'PLT', 'B');

      final response = await controller.handle(
        const IssueApiRequest(
          method: 'GET',
          pathSegments: ['api', 'issues', 'PLT-001'],
          queryParameters: {'repoPath': '/repos/two'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.data['issue']['repoPath'], '/repos/two');
      expect(response.data['issue']['title'], 'B');
    });

    test('syncs issues in bulk by title', () async {
      final project = harness.createProject(
        repoPath: '/repos/kanban',
        name: 'Platform',
        key: 'PLT',
      );
      harness.service.createIssue(
        project.repoPath,
        project.key,
        'Existing issue',
      );

      final response = await controller.handle(
        IssueApiRequest(
          method: 'POST',
          pathSegments: const ['api', 'issues', 'sync'],
          queryParameters: const {},
          body: {
            'repoPath': project.repoPath,
            'project': project.key,
            'issues': [
              {
                'title': 'Existing issue',
                'description': 'Updated',
                'status': 'done',
                'tags': ['synced'],
              },
              {
                'title': 'New issue',
                'description': 'Created',
                'status': 'inProgress',
              },
            ],
          },
        ),
      );

      expect(response.statusCode, 200);
      expect(response.data['operations'], hasLength(2));
      expect(response.data['operations'][0]['action'], 'updated');
      expect(response.data['operations'][0]['issue']['status'], 'done');
      expect(response.data['operations'][1]['action'], 'created');
      expect(response.data['operations'][1]['issue']['displayId'], 'PLT-002');
    });

    test('lists diagnostics for orphaned and duplicate issues', () async {
      final projectOne = harness.createProject(
        repoPath: '/repos/one',
        name: 'Platform',
        key: 'PLT',
      );
      final projectTwo = harness.createProject(
        repoPath: '/repos/two',
        name: 'Platform',
        key: 'PLT',
      );
      harness.issueRepository.createIssue(projectOne.id, 'PLT', 'A');
      harness.issueRepository.createIssue(projectTwo.id, 'PLT', 'B');
      harness.issueRepository.createIssue('missing-project', 'PLT', 'Orphan');

      final response = await controller.handle(
        const IssueApiRequest(
          method: 'GET',
          pathSegments: ['api', 'issues', 'diagnostics'],
          queryParameters: {'displayId': 'PLT-001'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.data['orphanedIssues'], hasLength(1));
      expect(response.data['duplicateDisplayIds'], hasLength(1));
    });
  });
}

class _IssueApiHarness {
  _IssueApiHarness() {
    DatabaseService.instance.initializeForTesting();
    final db = DatabaseService.instance.db;
    projectRepository = ProjectRepository.withDb(db);
    issueRepository = IssueRepository.withDb(db);
    commentRepository = CommentRepository.withDb(db);
    service = IssueApiService(
      projectRepository: projectRepository,
      issueRepository: issueRepository,
      commentRepository: commentRepository,
    );
  }

  late final ProjectRepository projectRepository;
  late final IssueRepository issueRepository;
  late final CommentRepository commentRepository;
  late final IssueApiService service;

  Project createProject({
    required String repoPath,
    required String name,
    required String key,
  }) {
    return projectRepository.createProject(repoPath, name, key);
  }

  void dispose() {
    DatabaseService.instance.close();
  }
}
