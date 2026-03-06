import 'dart:convert';
import 'dart:io';

import '../models/chatgpt_processing_result.dart';
import 'repo_action_tool_registry.dart';
import 'voice_logging.dart';

class ChatGptService {
  static const int _maxToolRounds = 3;

  Future<ChatGptProcessingResult> processAudioCommand({
    required String apiKey,
    required String audioPath,
    required String transcriptionModel,
    required String responseModel,
    required RepoActionToolRegistry toolRegistry,
  }) async {
    _log(
      'Processing audio command transcriptionModel=$transcriptionModel '
      'responseModel=$responseModel',
    );
    final transcript = await transcribeAudio(
      apiKey: apiKey,
      audioPath: audioPath,
      model: transcriptionModel,
    );
    return processTranscriptCommand(
      apiKey: apiKey,
      transcript: transcript,
      responseModel: responseModel,
      toolRegistry: toolRegistry,
    );
  }

  Future<ChatGptProcessingResult> processTranscriptCommand({
    required String apiKey,
    required String transcript,
    required String responseModel,
    required RepoActionToolRegistry toolRegistry,
  }) async {
    _log(
      'Processing transcript responseModel=$responseModel '
      'transcriptLength=${transcript.length}',
    );
    final chatResult = await _routeTranscript(
      apiKey: apiKey,
      transcript: transcript,
      model: responseModel,
      toolRegistry: toolRegistry,
    );

    return ChatGptProcessingResult(
      transcript: transcript,
      responseText: chatResult.responseText,
      toolSummaries: chatResult.toolSummaries,
    );
  }

  Future<String> transcribeAudio({
    required String apiKey,
    required String audioPath,
    required String model,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('Audio file was not found: $audioPath');
    }
    _log(
      'Starting transcription model=$model path=$audioPath '
      'size=${await file.length()} bytes',
    );

    final responseBody = await _postMultipart(
      apiKey: apiKey,
      path: '/v1/audio/transcriptions',
      fields: {'model': model},
      fileFieldName: 'file',
      file: file,
    );

    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final transcript = (decoded['text'] as String? ?? '').trim();
    if (transcript.isEmpty) {
      throw Exception('OpenAI transcription did not return any text.');
    }
    _log('Transcription completed textLength=${transcript.length}');

    return transcript;
  }

  Future<_ChatRoutingResult> _routeTranscript({
    required String apiKey,
    required String transcript,
    required String model,
    required RepoActionToolRegistry toolRegistry,
  }) async {
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _buildSystemPrompt(toolRegistry.describeContext()),
      },
      {'role': 'user', 'content': transcript},
    ];
    final toolSummaries = <String>[];
    final toolDefinitions = toolRegistry.buildToolDefinitions();
    _log(
      'Starting transcript routing model=$model tools=${toolDefinitions.length}',
    );

    for (var round = 0; round < _maxToolRounds; round++) {
      _log('Chat completion round ${round + 1} of $_maxToolRounds');
      final completion = await _createChatCompletion(
        apiKey: apiKey,
        model: model,
        messages: messages,
        tools: toolDefinitions,
      );
      messages.add(completion.requestMessage);

      if (completion.toolCalls.isEmpty) {
        _log(
          'Routing completed without tool calls responseLength=${completion.content.trim().length}',
        );
        return _ChatRoutingResult(
          responseText: completion.content.trim(),
          toolSummaries: toolSummaries,
        );
      }

      for (final toolCall in completion.toolCalls) {
        _log('Executing tool call name=${toolCall.name}');
        RepoActionToolResult toolResult;
        try {
          toolResult = await toolRegistry.executeTool(
            toolCall.name,
            toolCall.arguments,
          );
        } catch (error) {
          _log('Tool call failed name=${toolCall.name} error=$error');
          toolResult = RepoActionToolResult(
            payload: {'ok': false, 'error': error.toString()},
            summary: '${toolCall.name} failed: $error',
          );
        }

        _log('Tool call completed name=${toolCall.name} summary=${toolResult.summary}');
        toolSummaries.add(toolResult.summary);
        messages.add({
          'role': 'tool',
          'tool_call_id': toolCall.id,
          'content': jsonEncode(toolResult.payload),
        });
      }
    }

    throw Exception(
      'The OpenAI tool-routing flow exceeded $_maxToolRounds rounds.',
    );
  }

  String _buildSystemPrompt(Map<String, dynamic> context) {
    return '''
You are TreeLauncher's voice command router.

- The user's message came from a voice transcription.
- Use the provided repo/worktree tools whenever you need current repo data or need to perform a repo/worktree action.
- Only work within the tools you were given.
- Do not invent successful actions.
- If a tool fails, explain the failure plainly.
- Keep the final response concise and action-oriented.

Current app context:
${jsonEncode(context)}
''';
  }

  Future<_ChatCompletionResult> _createChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> messages,
    required List<Map<String, dynamic>> tools,
  }) async {
    final responseBody = await _postJson(
      apiKey: apiKey,
      path: '/v1/chat/completions',
      body: {
        'model': model,
        'messages': messages,
        'tools': tools,
        'tool_choice': 'auto',
      },
    );

    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('OpenAI did not return any chat completion choices.');
    }

    final message = Map<String, dynamic>.from(
      choices.first as Map<String, dynamic>,
    )['message'];
    if (message is! Map) {
      throw Exception('OpenAI returned an unexpected chat message payload.');
    }

    final typedMessage = Map<String, dynamic>.from(message);
    final rawToolCalls =
        (typedMessage['tool_calls'] as List<dynamic>? ?? const [])
            .map((call) => Map<String, dynamic>.from(call as Map))
            .toList();

    return _ChatCompletionResult(
      content: (typedMessage['content'] as String? ?? ''),
      toolCalls: rawToolCalls.map(_ChatToolCall.fromJson).toList(),
      requestMessage: {
        'role': 'assistant',
        'content': typedMessage['content'],
        if (rawToolCalls.isNotEmpty) 'tool_calls': rawToolCalls,
      },
    );
  }

  Future<String> _postJson({
    required String apiKey,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    _log('POST $path as JSON model=${body['model']}');
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.https('api.openai.com', path));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractApiError(responseBody));
      }

      return responseBody;
    } finally {
      client.close(force: true);
    }
  }

  Future<String> _postMultipart({
    required String apiKey,
    required String path,
    required Map<String, String> fields,
    required String fileFieldName,
    required File file,
  }) async {
    final client = HttpClient();
    final boundary = 'tree-launcher-${DateTime.now().microsecondsSinceEpoch}';
    final bytes = await file.readAsBytes();
    _log(
      'POST $path as multipart fields=${fields.keys.join(',')} '
      'file=${file.uri.pathSegments.last} size=${bytes.length}',
    );

    try {
      final request = await client.postUrl(Uri.https('api.openai.com', path));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      for (final entry in fields.entries) {
        request.write('--$boundary\r\n');
        request.write(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
        );
        request.write('${entry.value}\r\n');
      }

      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="$fileFieldName"; filename="${file.uri.pathSegments.last}"\r\n',
      );
      request.write('Content-Type: ${_contentTypeForFile(file.path)}\r\n\r\n');
      request.add(bytes);
      request.write('\r\n--$boundary--\r\n');

      final response = await request.close();
      final responseBody = await utf8.decodeStream(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(_extractApiError(responseBody));
      }

      return responseBody;
    } finally {
      client.close(force: true);
    }
  }

  String _contentTypeForFile(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/m4a';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _extractApiError(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      // Fall back to raw body below.
    }

    return responseBody.trim().isEmpty
        ? 'The OpenAI request failed.'
        : responseBody.trim();
  }

  void _log(String message) {
    logVoice('OpenAI', message);
  }
}

class _ChatRoutingResult {
  const _ChatRoutingResult({
    required this.responseText,
    required this.toolSummaries,
  });

  final String responseText;
  final List<String> toolSummaries;
}

class _ChatCompletionResult {
  const _ChatCompletionResult({
    required this.content,
    required this.toolCalls,
    required this.requestMessage,
  });

  final String content;
  final List<_ChatToolCall> toolCalls;
  final Map<String, dynamic> requestMessage;
}

class _ChatToolCall {
  const _ChatToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  factory _ChatToolCall.fromJson(Map<String, dynamic> json) {
    final function = Map<String, dynamic>.from(json['function'] as Map);
    final rawArguments = function['arguments'] as String? ?? '{}';

    return _ChatToolCall(
      id: json['id'] as String? ?? function['name'] as String? ?? 'tool_call',
      name: function['name'] as String? ?? 'unknown_tool',
      arguments: _decodeArguments(rawArguments),
    );
  }

  static Map<String, dynamic> _decodeArguments(String rawArguments) {
    try {
      final decoded = jsonDecode(rawArguments);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw const FormatException('Tool arguments were not a JSON object.');
    } on FormatException catch (error) {
      throw Exception('Failed to decode OpenAI tool arguments: $error');
    }
  }
}
