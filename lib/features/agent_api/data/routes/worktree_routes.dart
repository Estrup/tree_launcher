import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `POST /v1/worktrees`: creates a worktree in the running app.
class WorktreeRoutes {
  WorktreeRoutes({
    required AppSettingsSource settings,
    required WorktreeCreator creator,
  }) : _settings = settings,
       _creator = creator;

  final AppSettingsSource _settings;
  final WorktreeCreator _creator;

  void mount(Router router) => router..post('/v1/worktrees', _create);

  static const _fields = {
    'repo',
    'baseBranch',
    'branch',
    'worktreeName',
    'issueKey',
    'kickoffPrompt',
  };

  /// `POST /v1/worktrees`
  ///
  /// JSON body:
  /// - `repo` (required) — repo name, as in `GET /v1/activity?repo=`.
  /// - `baseBranch` (required) — branch the worktree is created from.
  /// - `branch` (required) — the new-branch suffix; the full branch becomes
  ///   `<defaultBranchPrefix>/<branch>` when a prefix is configured.
  /// - `worktreeName` (required) — the worktree directory name.
  /// - `issueKey` (optional) — Jira key stored as worktree metadata.
  /// - `kickoffPrompt` (optional) — prompt text (e.g. a full implementation
  ///   plan) written to `<worktree>/.tree-launcher/kickoff-prompt.md`; the
  ///   response returns its `kickoffPromptPath`, and the worktree's Claude
  ///   dropdown gains a "Kickoff prompt" option that launches Claude pointed
  ///   at the file.
  ///
  /// `worktreeName` and `branch` are normalized (lowercased, spaces→dashes) and
  /// validated against the app's naming rules.
  Future<Response> _create(Request request) async {
    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;
    final unknown = body.keys.where((k) => !_fields.contains(k));
    if (unknown.isNotEmpty) return unsupportedFields(unknown, _fields);

    final repo = stringField(body, 'repo');
    final baseBranch = stringField(body, 'baseBranch');
    final branchInput = stringField(body, 'branch');
    final worktreeInput = stringField(body, 'worktreeName');
    final issueKey = stringField(body, 'issueKey');
    final kickoffPrompt = stringField(body, 'kickoffPrompt');

    final missing = [
      if (repo == null) 'repo',
      if (baseBranch == null) 'baseBranch',
      if (branchInput == null) 'branch',
      if (worktreeInput == null) 'worktreeName',
    ];
    if (missing.isNotEmpty) return missingFields(missing);

    final worktreeName = normalizeWorktreeName(worktreeInput!);
    final branchSuffix = normalizeWorktreeName(branchInput!);

    final worktreeError = validateWorktreeName(worktreeName);
    if (worktreeError != null) {
      return jsonResponse({
        'error': 'worktreeName: $worktreeError',
      }, status: 400);
    }
    final branchError = validateWorktreeName(branchSuffix);
    if (branchError != null) {
      return jsonResponse({'error': 'branch: $branchError'}, status: 400);
    }
    if (issueKey != null) {
      final jiraError = validateJiraKey(issueKey);
      if (jiraError != null) {
        return jsonResponse({'error': 'issueKey: $jiraError'}, status: 400);
      }
    }

    try {
      final newBranch = buildBranchName(
        branchSuffix,
        _settings.settings.defaultBranchPrefix,
      );

      final created = await _creator.createWorktree(
        repoName: repo!,
        worktreeName: worktreeName,
        baseBranch: baseBranch!,
        newBranch: newBranch,
        jiraIssue: issueKey,
        kickoffPrompt: kickoffPrompt,
      );

      return jsonResponse({
        'repo': repo,
        'worktreeName': worktreeName,
        'worktreePath': created.worktreePath,
        'branch': created.branch,
        'issueKey': issueKey,
        'kickoffPromptPath': created.kickoffPromptPath,
      }, status: 201);
    } on RepoNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } on WorktreeConflictException catch (e) {
      return jsonResponse({'error': e.message}, status: 409);
    } catch (e) {
      return serverError('create worktree', e);
    }
  }
}
