import 'package:tree_launcher/features/terminal/domain/terminal_session.dart';

final _ansiEscapePattern = RegExp(
  r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~]|\][^\x07\x1B]*(?:\x07|\x1B\\))',
);

String readCopilotTerminalOutput(
  TerminalSession terminalSession, {
  int lineCount = 50,
}) {
  if (lineCount <= 0) {
    return '';
  }

  final buffer = terminalSession.terminal.buffer;
  final totalLines = buffer.lines.length;
  final startLine = totalLines > lineCount ? totalLines - lineCount : 0;

  final textBuffer = StringBuffer();
  for (var i = startLine; i < totalLines; i++) {
    final line = buffer.lines[i];
    if (i > startLine && !line.isWrapped) {
      textBuffer.write('\n');
    }
    textBuffer.write(line.getText());
  }

  final text = textBuffer.toString().replaceAll(_ansiEscapePattern, '');
  final lines = text.split('\n');
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}
