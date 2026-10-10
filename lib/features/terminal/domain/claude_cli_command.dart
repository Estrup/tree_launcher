/// Model aliases offered when starting a Claude session (`--model`); each
/// resolves to the latest model of that family.
const claudeModelAliases = ['fable', 'opus', 'sonnet'];

/// Model picked when there is no remembered choice.
const defaultClaudeModel = 'opus';

/// Effort levels accepted by `--effort`.
const claudeEffortLevels = ['low', 'medium', 'high', 'xhigh', 'max'];

/// Effort picked when there is no remembered choice.
const defaultClaudeEffort = 'high';

/// Builds the shell command that starts the Claude CLI in a terminal.
///
/// [extraArgs] (the user's Settings value) is inserted verbatim so it can hold
/// several flags. [model] and [effort] add `--model` / `--effort` after it, so
/// they win over the same flags in [extraArgs]; null leaves the CLI's default.
/// A non-empty [prompt] becomes the session's first message,
/// shell-quoted and placed after `--` so a variadic flag in [extraArgs] (such
/// as `--channels`) can't swallow it. [resume] continues the most recent
/// conversation in the working directory instead, and ignores [prompt].
String buildClaudeCliCommand({
  String extraArgs = '',
  String? prompt,
  String? model,
  String? effort,
  bool resume = false,
}) {
  final parts = ['claude'];
  final args = extraArgs.trim();
  if (args.isNotEmpty) parts.add(args);
  if (model != null && model.isNotEmpty) parts.addAll(['--model', model]);
  if (effort != null && effort.isNotEmpty) parts.addAll(['--effort', effort]);
  if (resume) {
    parts.add('--continue');
  } else {
    final text = prompt?.trim() ?? '';
    if (text.isNotEmpty) parts.addAll(['--', shellQuote(text)]);
  }
  return parts.join(' ');
}

/// Single-quotes [value] for a POSIX shell.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";
