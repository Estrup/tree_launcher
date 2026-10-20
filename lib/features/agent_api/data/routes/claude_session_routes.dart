import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/agent_api/data/routes/worktree_routes.dart';
import 'package:tree_launcher/features/agents/domain/claude_session_starter.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

/// `POST /v1/claude/sessions`: starts Claude in a new or an existing
/// worktree in one go, as the Start Claude Session dialog does.
class ClaudeSessionRoutes {
  ClaudeSessionRoutes({
    required AppSettingsSource settings,
    required ClaudeSessionStarter starter,
  }) : _settings = settings,
       _starter = starter;

  final AppSettingsSource _settings;
  final ClaudeSessionStarter _starter;

  void mount(Router router) => router..post('/v1/claude/sessions', _start);

  static const _fields = {
    'repo',
    'existingWorktree',
    'worktreeName',
    'baseBranch',
    'branch',
    'kickoffPrompt',
    'issueKey',
    'prompt',
    'promptText',
    'prNumber',
    'title',
    'model',
    'effort',
    'show',
  };

  /// The fields that only apply to a new worktree.
  static const _newWorktreeFields = [
    'worktreeName',
    'baseBranch',
    'branch',
    'kickoffPrompt',
  ];

  /// `POST /v1/claude/sessions`
  ///
  /// Checks the request's shape here; the starter checks the repo, the
  /// prompt and the worktree, then creates and starts. See
  /// `docs/agent-api.md` for the fields.
  Future<Response> _start(Request request) async {
    final parsed = await readJsonObject(request);
    if (parsed.error != null) return parsed.error!;
    final body = parsed.body!;
    final unknown = body.keys.where((k) => !_fields.contains(k));
    if (unknown.isNotEmpty) return unsupportedFields(unknown, _fields);

    final repo = stringField(body, 'repo');
    final existingWorktree = stringField(body, 'existingWorktree');
    final issueKey = stringField(body, 'issueKey');
    final title = stringField(body, 'title');
    final prompt = stringField(body, 'prompt');
    final promptText = stringField(body, 'promptText');
    final model = stringField(body, 'model')?.toLowerCase();
    final effort = stringField(body, 'effort')?.toLowerCase();

    if (existingWorktree != null) {
      final misplaced = [
        for (final field in _newWorktreeFields)
          if (stringField(body, field) != null) field,
      ];
      if (misplaced.isNotEmpty) {
        return jsonResponse({
          'error':
              '${misplaced.join(', ')} only apply to a new worktree, '
              'not with existingWorktree',
        }, status: 400);
      }
    }
    if (prompt != null && promptText != null) {
      return jsonResponse({
        'error': 'give prompt or promptText, not both',
      }, status: 400);
    }

    // A new worktree's name defaults to the one the Jira button suggests.
    final worktreeInput =
        stringField(body, 'worktreeName') ??
        (issueKey != null && title != null
            ? worktreeNameForJiraIssue(issueKey, title)
            : null);
    final baseBranch = stringField(body, 'baseBranch');
    final missing = [
      if (repo == null) 'repo',
      if (existingWorktree == null && worktreeInput == null) 'worktreeName',
      if (existingWorktree == null && baseBranch == null) 'baseBranch',
    ];
    if (missing.isNotEmpty) return missingFields(missing);

    final keyError = issueKeyError(issueKey);
    if (keyError != null) return keyError;
    final pr = intField(body, 'prNumber');
    if (pr.error != null) return pr.error!;
    if (model != null && !claudeModelAliases.contains(model)) {
      return jsonResponse({
        'error': 'unknown model "$model"',
        'models': claudeModelAliases,
      }, status: 400);
    }
    if (effort != null && !claudeEffortLevels.contains(effort)) {
      return jsonResponse({
        'error': 'unknown effort "$effort"',
        'efforts': claudeEffortLevels,
      }, status: 400);
    }
    final show = body['show'] ?? false;
    if (show is! bool) {
      return jsonResponse({'error': 'show must be true or false'}, status: 400);
    }

    NewWorktreeRequest? newWorktree;
    if (existingWorktree == null) {
      final names = normalizedWorktreeNames(
        worktreeInput!,
        stringField(body, 'branch') ?? worktreeInput,
      );
      if (names.error != null) return names.error!;
      newWorktree = NewWorktreeRequest(
        worktreeName: names.worktreeName,
        baseBranch: baseBranch!,
        newBranch: buildBranchName(
          names.branch,
          _settings.settings.defaultBranchPrefix,
        ),
        kickoffPrompt: stringField(body, 'kickoffPrompt'),
      );
    }

    try {
      final started = await _starter.start(
        ClaudeSessionRequest(
          repoName: repo!,
          existingWorktree: existingWorktree,
          newWorktree: newWorktree,
          issueKey: issueKey,
          prompt: prompt,
          promptText: promptText,
          prNumber: pr.value,
          title: title,
          model: model,
          effort: effort,
          show: show,
        ),
      );
      return jsonResponse({
        'repo': started.repoName,
        'worktree': started.worktree.toJson(),
        'session': {
          'title': started.title,
          'promptId': started.promptId,
          'prompt': started.prompt,
          'model': started.model,
          'effort': started.effort,
        },
        'agent': started.agent?.toJson(),
      }, status: 201);
    } on RepoNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } on WorktreeNotFoundException catch (e) {
      return jsonResponse({'error': e.toString()}, status: 404);
    } on WorktreeConflictException catch (e) {
      return jsonResponse({'error': e.message}, status: 409);
    } on ClaudePromptException catch (e) {
      return jsonResponse({'error': e.message, ...e.details}, status: 400);
    } on ClaudeStartFailedException catch (e) {
      return jsonResponse({
        'error':
            'created worktree ${e.worktree.name}, but failed to start '
            'Claude: ${e.message}',
        'worktree': e.worktree.toJson(),
      }, status: 500);
    } catch (e) {
      return serverError('start Claude session', e);
    }
  }
}
