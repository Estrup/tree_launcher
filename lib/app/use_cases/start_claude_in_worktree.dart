import 'package:path/path.dart' as p;

import 'package:tree_launcher/app/use_cases/start_claude_session.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/agents/domain/claude_session_starter.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_prompts.dart';

/// A request's prompt, the saved one if it is one, and what the session is
/// recorded with.
typedef _PickedPrompt = ({
  ClaudePromptChoice choice,
  ClaudePrompt? saved,
  String? promptId,
});

/// The agent API's Start Claude Session: creates the worktree (or finds the
/// existing one), then starts Claude there through [StartClaudeSession], as
/// the dialog does, without remembering any choices.
///
/// Everything that can be checked before creating the worktree is, so a
/// request that would fail at the prompt never leaves a worktree behind.
class StartClaudeInWorktree implements ClaudeSessionStarter {
  StartClaudeInWorktree({
    required RepoCatalog repos,
    required WorktreeCreator creator,
    required GitService git,
    required WorktreeMetadata? Function(String worktreePath) metadataFor,
    required StartClaudeSession start,
  }) : _repos = repos,
       _creator = creator,
       _git = git,
       _metadataFor = metadataFor,
       _start = start;

  final RepoCatalog _repos;
  final WorktreeCreator _creator;
  final GitService _git;

  /// A worktree's recorded issues, base branch and kickoff file.
  final WorktreeMetadata? Function(String worktreePath) _metadataFor;

  final StartClaudeSession _start;

  @override
  Future<StartedClaudeSession> start(ClaudeSessionRequest request) async {
    final repo = (await _repos.loadedRepos())
        .where((r) => r.name == request.repoName)
        .firstOrNull;
    if (repo == null) throw RepoNotFoundException(request.repoName);
    final prompt = _promptFor(repo, request);

    if (request.existingWorktree case final wanted?) {
      final found = await _findWorktree(repo, wanted);
      final metadata = _metadataFor(found.path);
      final worktree = StartedWorktree(
        name: found.name,
        path: found.path,
        branch: found.branch,
        baseBranch: metadata?.baseBranch,
        issueKey: request.issueKey ?? metadata?.jiraIssue,
        created: false,
        kickoffPromptPath: metadata?.kickoffPromptPath,
      );
      _check(
        prompt.choice,
        issue: worktree.issueKey,
        githubIssue: metadata?.githubIssue,
        prNumber: request.prNumber,
        kickoffMissing: worktree.kickoffPromptPath == null
            ? 'worktree ${found.name} has no kickoff prompt staged'
            : null,
      );
      return _launch(
        repo,
        worktree,
        request,
        prompt,
        githubIssue: metadata?.githubIssue,
      );
    }

    final wanted = request.newWorktree!;
    _check(
      prompt.choice,
      issue: request.issueKey,
      prNumber: request.prNumber,
      kickoffMissing: wanted.kickoffPrompt == null
          ? 'the prompt $kickoffPromptId needs a kickoffPrompt'
          : null,
    );
    final created = await _creator.createWorktree(
      repoName: repo.name,
      worktreeName: wanted.worktreeName,
      baseBranch: wanted.baseBranch,
      newBranch: wanted.newBranch,
      jiraIssue: request.issueKey,
      kickoffPrompt: wanted.kickoffPrompt,
    );
    final worktree = StartedWorktree(
      name: wanted.worktreeName,
      path: created.worktreePath,
      branch: created.branch,
      baseBranch: wanted.baseBranch,
      issueKey: request.issueKey,
      created: true,
      kickoffPromptPath: created.kickoffPromptPath,
    );
    if (prompt.choice is KickoffClaudePrompt &&
        worktree.kickoffPromptPath == null) {
      throw ClaudeStartFailedException(
        "the kickoff prompt couldn't be written",
        worktree,
      );
    }
    try {
      return await _launch(repo, worktree, request, prompt);
    } catch (e) {
      throw ClaudeStartFailedException(userMessage(e), worktree);
    }
  }

  /// The prompt [request] picks in [repo]. Throws [ClaudePromptException] for an unknown prompt.
  _PickedPrompt _promptFor(RepoConfig repo, ClaudeSessionRequest request) {
    if (request.promptText case final text?) {
      return (choice: TextClaudePrompt(text), saved: null, promptId: null);
    }
    final name = request.prompt;
    if (name == null) {
      return (choice: const NoClaudePrompt(), saved: null, promptId: null);
    }
    if (name == issueContextPromptId) {
      return (
        choice: const ContextClaudePrompt(),
        saved: null,
        promptId: issueContextPromptId,
      );
    }
    if (name == kickoffPromptId) {
      return (
        choice: const KickoffClaudePrompt(),
        saved: null,
        promptId: kickoffPromptId,
      );
    }
    final saved = repo.claudePrompts
        .where((p) => p.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (saved == null) {
      throw ClaudePromptException(
        'unknown prompt "$name" in repo ${repo.name}',
        details: {
          'prompts': [
            for (final p in repo.claudePrompts) p.name,
            issueContextPromptId,
            kickoffPromptId,
          ],
        },
      );
    }
    if (saved.kind case final kind? when !repo.usesAgentType(kind)) {
      throw ClaudePromptException(
        'prompt "${saved.name}" starts a "${kind.id}" agent, and that agent '
        'type is switched off for repo ${repo.name}',
      );
    }
    return (
      choice: SavedClaudePrompt(saved),
      saved: saved,
      promptId: saved.name,
    );
  }

  /// Throws [ClaudePromptException] when [choice] can't make its message:
  /// a kickoff prompt without a file ([kickoffMissing] says why), or a
  /// placeholder without a value.
  void _check(
    ClaudePromptChoice choice, {
    String? issue,
    int? githubIssue,
    int? prNumber,
    String? kickoffMissing,
  }) {
    final template = switch (choice) {
      SavedClaudePrompt(:final prompt) => prompt.prompt,
      TextClaudePrompt(:final text) => text,
      _ => null,
    };
    final error = switch (choice) {
      KickoffClaudePrompt() => kickoffMissing,
      _ when template != null => missingPlaceholderValue(
        template,
        issue: issue,
        githubIssue: githubIssue,
        prNumber: prNumber,
      ),
      _ => null,
    };
    if (error != null) throw ClaudePromptException(error);
  }

  /// [repo]'s worktree whose folder name or path is [wanted]. Throws
  /// [WorktreeNotFoundException] when there is none.
  Future<Worktree> _findWorktree(RepoConfig repo, String wanted) async {
    final worktrees = (await _git.getWorktrees(repo.path)).worktrees;
    final path = p.normalize(wanted);
    return worktrees
            .where((w) => p.normalize(w.path) == path || w.name == wanted)
            .firstOrNull ??
        (throw WorktreeNotFoundException(repo.name, wanted));
  }

  Future<StartedClaudeSession> _launch(
    RepoConfig repo,
    StartedWorktree worktree,
    ClaudeSessionRequest request,
    _PickedPrompt prompt, {
    int? githubIssue,
  }) async {
    final message = firstClaudeMessage(
      prompt.choice,
      issue: worktree.issueKey,
      githubIssue: githubIssue,
      baseBranch: worktree.baseBranch,
      worktreeName: p.basename(worktree.path),
      worktreePath: worktree.path,
      repoName: repo.name,
      prNumber: request.prNumber,
      kickoffPromptPath: worktree.kickoffPromptPath,
    );
    final started = await _start.launch(
      repo: repo,
      worktreePath: worktree.path,
      branch: worktree.branch,
      prompt: message,
      promptId: prompt.promptId,
      savedPrompt: prompt.saved,
      model: request.model,
      effort: request.effort,
      issueKey: worktree.issueKey,
      title: request.title,
      prNumber: request.prNumber,
      show: request.show,
    );
    return StartedClaudeSession(
      repoName: repo.name,
      worktree: worktree,
      title: started.title,
      promptId: prompt.promptId,
      prompt: message,
      model: request.model,
      effort: request.effort,
      agent: started.agent,
    );
  }
}
