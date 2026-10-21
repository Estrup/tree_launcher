import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/domain/issue_base_branches.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `POST /v1/worktrees`: creates a worktree in the running app.
class WorktreeRoutes {
  WorktreeRoutes({
    required AppSettingsSource settings,
    required WorktreeCreator creator,
    IssueBaseBranches? baseBranches,
  }) : _settings = settings,
       _creator = creator,
       _baseBranches = baseBranches;

  final AppSettingsSource _settings;
  final WorktreeCreator _creator;

  /// Fills in a missing `baseBranch` from the issue's fixVersion.
  final IssueBaseBranches? _baseBranches;

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
  /// - `baseBranch` — branch the worktree is created from. Optional with an
  ///   `issueKey` whose fixVersion the repo maps to a branch.
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
    final branchInput = stringField(body, 'branch');
    final worktreeInput = stringField(body, 'worktreeName');
    final issueKey = stringField(body, 'issueKey');
    final kickoffPrompt = stringField(body, 'kickoffPrompt');
    final baseBranch =
        stringField(body, 'baseBranch') ??
        await mappedBaseBranch(_baseBranches, repo, issueKey);

    final missing = [
      if (repo == null) 'repo',
      if (baseBranch == null) 'baseBranch',
      if (branchInput == null) 'branch',
      if (worktreeInput == null) 'worktreeName',
    ];
    if (missing.isNotEmpty) return missingFields(missing);

    final names = normalizedWorktreeNames(worktreeInput!, branchInput!);
    if (names.error != null) return names.error!;
    final worktreeName = names.worktreeName;
    final branchSuffix = names.branch;
    final keyError = issueKeyError(issueKey);
    if (keyError != null) return keyError;

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

/// The branch [repo] maps to [issueKey]'s fixVersion, when both are given
/// and the key is valid; else null.
Future<String?> mappedBaseBranch(
  IssueBaseBranches? baseBranches,
  String? repo,
  String? issueKey,
) async {
  if (baseBranches == null || repo == null || issueKey == null) return null;
  if (issueKeyError(issueKey) != null) return null;
  return baseBranches.baseBranchFor(repo, issueKey);
}

/// [worktreeInput] and [branchInput] normalised (lowercased, spaces to
/// dashes) and validated by the app's naming rules; [branch] is still
/// without the prefix. When either is invalid, [error] is the 400 to send.
({String worktreeName, String branch, Response? error}) normalizedWorktreeNames(
  String worktreeInput,
  String branchInput,
) {
  final worktreeName = normalizeWorktreeName(worktreeInput);
  final branch = normalizeWorktreeName(branchInput);
  Response? error;
  if (validateWorktreeName(worktreeName) case final message?) {
    error = jsonResponse({'error': 'worktreeName: $message'}, status: 400);
  } else if (validateWorktreeName(branch) case final message?) {
    error = jsonResponse({'error': 'branch: $message'}, status: 400);
  }
  return (worktreeName: worktreeName, branch: branch, error: error);
}

/// The 400 for an [issueKey] that isn't a Jira key; null when it is one or
/// there is none.
Response? issueKeyError(String? issueKey) {
  if (issueKey == null) return null;
  final error = validateJiraKey(issueKey);
  return error == null
      ? null
      : jsonResponse({'error': 'issueKey: $error'}, status: 400);
}
