import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/app/use_cases/agent_launcher.dart';
import 'package:tree_launcher/app/use_cases/start_claude_in_worktree.dart';
import 'package:tree_launcher/app/use_cases/start_claude_session.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/agents/domain/claude_session_starter.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

class _Repos implements RepoCatalog {
  _Repos(this.repos);

  @override
  final List<RepoConfig> repos;

  @override
  Future<void> get whenLoaded => Future.value();
}

/// Records what it creates; fails as git would when [conflict] is set.
class _Creator implements WorktreeCreator {
  final created = <Map<String, Object?>>[];
  String? conflict;

  /// Whether writing the kickoff file works.
  bool writesKickoff = true;

  @override
  Future<CreatedWorktree> createWorktree({
    required String repoName,
    required String worktreeName,
    required String baseBranch,
    required String newBranch,
    String? jiraIssue,
    String? kickoffPrompt,
  }) async {
    if (conflict != null) throw WorktreeConflictException(conflict!);
    created.add({
      'repo': repoName,
      'name': worktreeName,
      'base': baseBranch,
      'branch': newBranch,
      'issue': jiraIssue,
      'kickoff': kickoffPrompt,
    });
    final path = '/repos/$worktreeName';
    return CreatedWorktree(
      worktreePath: path,
      branch: newBranch,
      kickoffPromptPath: kickoffPrompt != null && writesKickoff
          ? '$path/.tree-launcher/kickoff-prompt.md'
          : null,
    );
  }
}

/// The au2 repo's worktrees.
class _Git extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async =>
      WorktreeListResult(
        worktrees: [
          Worktree(
            path: '/repos/develop',
            branch: 'develop',
            name: 'develop',
            isMain: true,
            commitHash: 'abc',
          ),
          Worktree(
            path: '/repos/au2-9-fix',
            branch: 'sen/au2-9-fix',
            name: 'au2-9-fix',
            isMain: false,
            commitHash: 'def',
          ),
        ],
        isBareLayout: true,
      );
}

/// Records [launch]; fails the test if [call] (which remembers the
/// choices) is used.
class _Start implements StartClaudeSession {
  Map<String, Object?>? launched;
  Exception? failWith;

  @override
  Future<void> call({
    required RepoConfig repo,
    required String worktreePath,
    String? branch,
    String? prompt,
    String? promptId,
    ClaudePrompt? savedPrompt,
    String? model,
    String? effort,
    bool? useExistingWorktree,
    String? issueKey,
    String? title,
    int? prNumber,
  }) async => fail('remembered the choices');

  @override
  Future<({String title, AgentRun? agent})> launch({
    required RepoConfig repo,
    required String worktreePath,
    String? branch,
    String? prompt,
    String? promptId,
    ClaudePrompt? savedPrompt,
    String? model,
    String? effort,
    String? issueKey,
    String? title,
    int? prNumber,
    bool show = false,
  }) async {
    if (failWith != null) throw failWith!;
    launched = {
      'repo': repo.name,
      'path': worktreePath,
      'branch': branch,
      'prompt': prompt,
      'promptId': promptId,
      'saved': savedPrompt?.name,
      'model': model,
      'effort': effort,
      'issue': issueKey,
      'title': title,
      'pr': prNumber,
      'show': show,
    };
    final kind = savedPrompt?.kind;
    if (kind == null) return (title: 'Claude: x', agent: null);
    final now = DateTime(2026, 10, 20);
    final run = AgentRun(
      id: 'ag_12345678',
      kind: kind,
      repoName: repo.name,
      issueKeys: [?issueKey],
      startedAt: now,
      updatedAt: now,
    );
    return (
      title: AgentLauncher.titleFor(run, agentTypeIn(defaultAgentTypes, kind)),
      agent: run,
    );
  }
}

void main() {
  late _Creator creator;
  late _Start start;
  late StartClaudeInWorktree useCase;

  final repo = RepoConfig(
    name: 'au2office',
    path: '/repos/au2',
    claudePrompts: [
      ClaudePrompt(
        name: 'Factory: Refine',
        prompt: 'kør /refine-factory {issue}',
        kind: AgentKind.refine,
      ),
      ClaudePrompt(name: 'Fix issue', prompt: 'Fix {issue} from {base_branch}'),
      ClaudePrompt(name: 'Review PR', prompt: 'Review PR {pr} in {worktree}'),
    ],
  );
  final metadata = {
    '/repos/au2-9-fix': const WorktreeMetadata(
      path: '/repos/au2-9-fix',
      repoPath: '/repos/au2',
      jiraIssue: 'AU2-9',
      baseBranch: 'develop',
      kickoffPromptPath: '/repos/au2-9-fix/.tree-launcher/kickoff-prompt.md',
    ),
  };

  setUp(() {
    creator = _Creator();
    start = _Start();
    useCase = StartClaudeInWorktree(
      repos: _Repos([repo]),
      creator: creator,
      git: _Git(),
      metadataFor: (path) => metadata[path],
      start: start,
    );
  });

  ClaudeSessionRequest inNewWorktree({
    String? prompt,
    String? promptText,
    String? issueKey = 'AU2-5407',
    String? kickoffPrompt,
    int? prNumber,
  }) => ClaudeSessionRequest(
    repoName: 'au2office',
    newWorktree: NewWorktreeRequest(
      worktreeName: 'vipps-au2-5407',
      baseBranch: 'develop',
      newBranch: 'sen/vipps-au2-5407',
      kickoffPrompt: kickoffPrompt,
    ),
    issueKey: issueKey,
    prompt: prompt,
    promptText: promptText,
    prNumber: prNumber,
    title: 'Vipps Mobilepay callback http 500',
    model: 'opus',
    effort: 'medium',
  );

  test('a prompt with a kind starts an agent in a new worktree', () async {
    final started = await useCase.start(
      inNewWorktree(prompt: 'factory: refine'),
    );

    expect(creator.created.single, {
      'repo': 'au2office',
      'name': 'vipps-au2-5407',
      'base': 'develop',
      'branch': 'sen/vipps-au2-5407',
      'issue': 'AU2-5407',
      'kickoff': null,
    });
    expect(start.launched, {
      'repo': 'au2office',
      'path': '/repos/vipps-au2-5407',
      'branch': 'sen/vipps-au2-5407',
      'prompt': 'kør /refine-factory AU2-5407',
      'promptId': 'Factory: Refine',
      'saved': 'Factory: Refine',
      'model': 'opus',
      'effort': 'medium',
      'issue': 'AU2-5407',
      'title': 'Vipps Mobilepay callback http 500',
      'pr': null,
      'show': false,
    });
    expect(started.agent!.kind, AgentKind.refine);
    expect(started.title, 'Refinement: AU2-5407');
    expect(started.prompt, 'kør /refine-factory AU2-5407');
    expect(started.worktree.created, isTrue);
    expect(started.worktree.baseBranch, 'develop');
  });

  test('a prompt without a kind starts a plain session', () async {
    final started = await useCase.start(inNewWorktree(prompt: 'Fix issue'));

    expect(start.launched!['prompt'], 'Fix AU2-5407 from develop');
    expect(start.launched!['saved'], 'Fix issue');
    expect(started.agent, isNull);
  });

  test('the built-in prompts resolve as in the dialog', () async {
    await useCase.start(inNewWorktree(prompt: issueContextPromptId));
    expect(
      start.launched!['prompt'],
      'Context: Working on issue AU2-5407 where the base branch is develop.',
    );
    expect(start.launched!['promptId'], issueContextPromptId);

    await useCase.start(
      inNewWorktree(prompt: kickoffPromptId, kickoffPrompt: '# Plan'),
    );
    expect(creator.created.last['kickoff'], '# Plan');
    expect(
      start.launched!['prompt'],
      'Read and follow the implementation plan in '
      '.tree-launcher/kickoff-prompt.md.',
    );
    expect(start.launched!['promptId'], kickoffPromptId);
  });

  test('promptText and no prompt', () async {
    await useCase.start(inNewWorktree(promptText: 'Look at {issue}'));
    expect(start.launched!['prompt'], 'Look at AU2-5407');
    expect(start.launched!['promptId'], isNull);

    await useCase.start(inNewWorktree());
    expect(start.launched!['prompt'], isNull);
    expect(start.launched!['promptId'], isNull);
  });

  group('fails before creating a worktree', () {
    Future<void> expectPromptError(
      ClaudeSessionRequest request,
      Matcher message,
    ) async {
      await expectLater(
        useCase.start(request),
        throwsA(
          isA<ClaudePromptException>().having(
            (e) => e.message,
            'message',
            message,
          ),
        ),
      );
      expect(creator.created, isEmpty);
      expect(start.launched, isNull);
    }

    test('for an unknown prompt, listing the known ones', () async {
      await expectLater(
        useCase.start(inNewWorktree(prompt: 'Nope')),
        throwsA(
          isA<ClaudePromptException>()
              .having((e) => e.details['prompts'], 'prompts', [
                'Factory: Refine',
                'Fix issue',
                'Review PR',
                issueContextPromptId,
                kickoffPromptId,
              ]),
        ),
      );
      expect(creator.created, isEmpty);
    });

    test('for {issue} without an issue key', () async {
      await expectPromptError(
        inNewWorktree(prompt: 'Fix issue', issueKey: null),
        contains('{issue}'),
      );
    });

    test('for {pr} without a PR number', () async {
      await expectPromptError(
        inNewWorktree(prompt: 'Review PR'),
        contains('{pr}'),
      );
    });

    test('for :kickoff without a kickoff prompt', () async {
      await expectPromptError(
        inNewWorktree(prompt: kickoffPromptId),
        contains('kickoffPrompt'),
      );
    });

    test('for an unknown repo', () async {
      await expectLater(
        useCase.start(
          const ClaudeSessionRequest(
            repoName: 'nope',
            existingWorktree: 'develop',
          ),
        ),
        throwsA(isA<RepoNotFoundException>()),
      );
    });
  });

  test('a conflict creates nothing and starts nothing', () async {
    creator.conflict = 'branch already exists';
    await expectLater(
      useCase.start(inNewWorktree()),
      throwsA(isA<WorktreeConflictException>()),
    );
    expect(start.launched, isNull);
  });

  test('a failed start after creating says which worktree exists', () async {
    start.failWith = Exception('no terminal');
    await expectLater(
      useCase.start(inNewWorktree(prompt: 'Fix issue')),
      throwsA(
        isA<ClaudeStartFailedException>()
            .having((e) => e.worktree.path, 'path', '/repos/vipps-au2-5407')
            .having((e) => e.worktree.created, 'created', isTrue),
      ),
    );
    expect(creator.created, hasLength(1));
  });

  test('an unwritten kickoff file fails after creating', () async {
    creator.writesKickoff = false;
    await expectLater(
      useCase.start(
        inNewWorktree(prompt: kickoffPromptId, kickoffPrompt: '# Plan'),
      ),
      throwsA(isA<ClaudeStartFailedException>()),
    );
    expect(start.launched, isNull);
  });

  group('an existing worktree', () {
    ClaudeSessionRequest inExisting(
      String worktree, {
      String? prompt,
      String? issueKey,
      int? prNumber,
    }) => ClaudeSessionRequest(
      repoName: 'au2office',
      existingWorktree: worktree,
      prompt: prompt,
      issueKey: issueKey,
      prNumber: prNumber,
      show: true,
    );

    test('found by name uses its recorded issue and base branch', () async {
      final started = await useCase.start(
        inExisting('au2-9-fix', prompt: 'Fix issue'),
      );

      expect(creator.created, isEmpty);
      expect(start.launched!['path'], '/repos/au2-9-fix');
      expect(start.launched!['branch'], 'sen/au2-9-fix');
      expect(start.launched!['prompt'], 'Fix AU2-9 from develop');
      expect(start.launched!['issue'], 'AU2-9');
      expect(start.launched!['show'], isTrue);
      expect(started.worktree.created, isFalse);
      expect(started.worktree.issueKey, 'AU2-9');
    });

    test('found by path, with an issue of the request', () async {
      await useCase.start(
        inExisting('/repos/develop/', prompt: 'Fix issue', issueKey: 'AU2-1'),
      );

      expect(start.launched!['path'], '/repos/develop');
      // The shared checkout has no recorded base branch.
      expect(start.launched!['prompt'], 'Fix AU2-1 from');
    });

    test('its staged kickoff prompt', () async {
      await useCase.start(inExisting('au2-9-fix', prompt: kickoffPromptId));
      expect(start.launched!['prompt'], contains('kickoff-prompt.md'));

      await expectLater(
        useCase.start(inExisting('develop', prompt: kickoffPromptId)),
        throwsA(isA<ClaudePromptException>()),
      );
    });

    test('{pr} and {worktree} from the request and the worktree', () async {
      await useCase.start(
        inExisting('au2-9-fix', prompt: 'Review PR', prNumber: 7),
      );
      expect(start.launched!['prompt'], 'Review PR 7 in au2-9-fix');
      expect(start.launched!['pr'], 7);
    });

    test('an unknown one', () async {
      await expectLater(
        useCase.start(inExisting('gone')),
        throwsA(isA<WorktreeNotFoundException>()),
      );
      expect(start.launched, isNull);
    });
  });
}
