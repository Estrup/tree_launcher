import 'dart:math';

import 'package:tree_launcher/features/terminal/domain/claude_cli_command.dart';

/// What makes a [JiraTrigger] fire.
enum JiraTriggerEvent {
  /// An issue moves to [JiraTrigger.status].
  status('Moves to status'),

  /// An issue is created.
  created('Is created');

  const JiraTriggerEvent(this.label);

  /// Shown in the trigger editor.
  final String label;

  static JiraTriggerEvent? tryParse(String? name) {
    for (final event in values) {
      if (event.name == name) return event;
    }
    return null;
  }
}

/// A rule that starts a Claude session with a saved prompt when an issue in
/// a fixVersion moves to a status or is created. The app polls Jira for it
/// (there are no webhooks); only changes after [since] count.
class JiraTrigger {
  JiraTrigger({
    required this.id,
    required this.fixVersionId,
    required this.since,
    this.enabled = true,
    this.event = JiraTriggerEvent.status,
    this.status,
    this.assignedToMe = false,
    this.promptName,
    this.worktreePath,
    this.model = defaultClaudeModel,
    this.effort = defaultClaudeEffort,
  });

  /// A new, enabled rule that counts changes from now on.
  factory JiraTrigger.create({required String fixVersionId}) => JiraTrigger(
    id:
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${Random().nextInt(0x7fffffff)}',
    fixVersionId: fixVersionId,
    since: DateTime.now(),
  );

  final String id;
  final bool enabled;
  final String fixVersionId;
  final JiraTriggerEvent event;

  /// The status name a [JiraTriggerEvent.status] rule waits for.
  final String? status;

  /// Whether only issues assigned to the Jira user count.
  final bool assignedToMe;

  /// The saved prompt the session starts with; its kind makes it an agent.
  final String? promptName;

  /// The worktree the session runs in. Null runs it in the issue's own
  /// worktree, created from the fixVersion's branch when there is none.
  final String? worktreePath;

  /// The session's `--model` alias and `--effort` level.
  final String model;
  final String effort;

  /// Changes before this don't fire the rule. Reset when it is turned on.
  final DateTime since;

  /// Whether the rule has all it needs to run.
  bool get isComplete =>
      promptName != null &&
      (event != JiraTriggerEvent.status || (status?.trim() ?? '') != '');

  factory JiraTrigger.fromJson(Map<String, dynamic> json) => JiraTrigger(
    id: json['id'] as String,
    fixVersionId: json['fixVersionId'] as String,
    since: DateTime.tryParse(json['since'] as String? ?? '') ?? DateTime.now(),
    enabled: json['enabled'] as bool? ?? true,
    event:
        JiraTriggerEvent.tryParse(json['event'] as String?) ??
        JiraTriggerEvent.status,
    status: json['status'] as String?,
    assignedToMe: json['assignedToMe'] as bool? ?? false,
    promptName: json['promptName'] as String?,
    worktreePath: json['worktreePath'] as String?,
    model: _known(json['model'], claudeModelAliases) ?? defaultClaudeModel,
    effort: _known(json['effort'], claudeEffortLevels) ?? defaultClaudeEffort,
  );

  static String? _known(Object? value, List<String> allowed) =>
      allowed.contains(value) ? value as String : null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fixVersionId': fixVersionId,
    'since': since.toIso8601String(),
    'enabled': enabled,
    'event': event.name,
    if (status != null) 'status': status,
    'assignedToMe': assignedToMe,
    if (promptName != null) 'promptName': promptName,
    if (worktreePath != null) 'worktreePath': worktreePath,
    'model': model,
    'effort': effort,
  };

  JiraTrigger copyWith({
    bool? enabled,
    String? fixVersionId,
    JiraTriggerEvent? event,
    String? status,
    bool? assignedToMe,
    String? promptName,
    String? worktreePath,
    bool clearWorktreePath = false,
    String? model,
    String? effort,
    DateTime? since,
  }) => JiraTrigger(
    id: id,
    enabled: enabled ?? this.enabled,
    fixVersionId: fixVersionId ?? this.fixVersionId,
    event: event ?? this.event,
    status: status ?? this.status,
    assignedToMe: assignedToMe ?? this.assignedToMe,
    promptName: promptName ?? this.promptName,
    worktreePath: clearWorktreePath
        ? null
        : (worktreePath ?? this.worktreePath),
    model: model ?? this.model,
    effort: effort ?? this.effort,
    since: since ?? this.since,
  );

  /// JQL for the issues of [projectKey] the rule fires for: in its
  /// fixVersion, changed after [since] and, for a status rule, still in the
  /// status. An issue that leaves the status and comes back matches again.
  String jql(String projectKey) {
    String quote(String value) =>
        '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    final after = quote(jqlDateTime(since));
    return [
      'project = ${quote(projectKey)}',
      'fixVersion = $fixVersionId',
      if (event == JiraTriggerEvent.status) ...[
        'status = ${quote(status!.trim())}',
        'status CHANGED TO ${quote(status!.trim())} AFTER $after',
      ] else
        'created >= $after',
      if (assignedToMe) 'assignee = currentUser()',
      'issuetype not in subTaskIssueTypes() ORDER BY created ASC',
    ].join(' AND ');
  }
}

/// [time] as JQL writes a date and time (`yyyy/MM/dd HH:mm`, local time).
/// Jira reads it in the user's Jira time zone and ignores seconds, so the
/// minute is rounded down: a change in the same minute still counts.
String jqlDateTime(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}';
}
