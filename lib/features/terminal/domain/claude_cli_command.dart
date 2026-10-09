/// Builds the shell command that starts the Claude CLI in a terminal.
///
/// [extraArgs] (the user's Settings value) is inserted verbatim so it can hold
/// several flags. A non-empty [prompt] becomes the session's first message,
/// shell-quoted and placed after `--` so a variadic flag in [extraArgs] (such
/// as `--channels`) can't swallow it. [resume] continues the most recent
/// conversation in the working directory instead, and ignores [prompt].
String buildClaudeCliCommand({
  String extraArgs = '',
  String? prompt,
  bool resume = false,
}) {
  final parts = ['claude'];
  final args = extraArgs.trim();
  if (args.isNotEmpty) parts.add(args);
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
