import 'package:tree_launcher/features/agents/domain/agent_kind.dart';

/// Recorded for a Claude session started with the issue-context first
/// message; [prContextPromptId], [githubIssueContextPromptId] and
/// [kickoffPromptId] likewise. A session started with a saved prompt records
/// the prompt's name instead.
const issueContextPromptId = ':issue-context';
const prContextPromptId = ':pr-context';
const githubIssueContextPromptId = ':github-issue-context';
const kickoffPromptId = ':kickoff';

/// Remembered when a Claude session was last started without a prompt.
const noClaudePromptId = ':none';

/// A reusable, named prompt template for launching Claude in a worktree.
/// Placeholders ({issue}, {github_issue}, {pr}, {base_branch}, {worktree},
/// {path}, {repo}) are filled from the worktree before launch; {issue} is its
/// Jira key, {github_issue} its GitHub issue number and {pr} the number of its
/// open pull request.
class ClaudePrompt {
  final String name;
  final String prompt;

  /// The kind of agent this prompt starts, making it one of that kind's
  /// subtypes in its repo tab; null for an ordinary prompt.
  final AgentKind? kind;

  ClaudePrompt({required this.name, required this.prompt, this.kind});

  factory ClaudePrompt.fromJson(Map<String, dynamic> json) {
    return ClaudePrompt(
      name: json['name'] as String,
      prompt: json['prompt'] as String,
      kind: AgentKind.tryParse(json['kind'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'prompt': prompt,
    if (kind != null) 'kind': kind!.id,
  };

  ClaudePrompt copyWith({
    String? name,
    String? prompt,
    AgentKind? kind,
    bool clearKind = false,
  }) {
    return ClaudePrompt(
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
      kind: clearKind ? null : (kind ?? this.kind),
    );
  }
}
