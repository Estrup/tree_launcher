class ChatGptProcessingResult {
  const ChatGptProcessingResult({
    required this.transcript,
    required this.responseText,
    this.toolSummaries = const [],
  });

  final String transcript;
  final String responseText;
  final List<String> toolSummaries;

  String get summary {
    final message = responseText.trim();
    if (message.isNotEmpty) {
      return message;
    }

    if (toolSummaries.isNotEmpty) {
      return toolSummaries.join(' ');
    }

    return transcript.trim();
  }
}
