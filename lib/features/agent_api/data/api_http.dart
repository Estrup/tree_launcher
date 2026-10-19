import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';

import 'package:tree_launcher/core/errors/user_message.dart';

/// Request and response helpers shared by the agent API's routes.

/// A JSON response with [status].
Response jsonResponse(Object data, {int status = 200}) => Response(
  status,
  body: jsonEncode(data),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// The request's JSON object body, or the 400 response to send.
Future<({Map<String, dynamic>? body, Response? error})> readJsonObject(
  Request request,
) async {
  try {
    final raw = await request.readAsString();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return (
        body: null,
        error: jsonResponse({
          'error': 'request body must be a JSON object',
        }, status: 400),
      );
    }
    return (body: decoded, error: null);
  } catch (e) {
    return (
      body: null,
      error: jsonResponse({'error': 'invalid JSON body: $e'}, status: 400),
    );
  }
}

/// [body]'s [key] as a trimmed string; null when it is missing or blank.
String? stringField(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

/// The 500 for an unexpected failure while doing [what] (e.g. "load
/// activity"), logged with the error.
Response serverError(String what, Object error) {
  debugPrint('AgentApiServer: $what failed: $error');
  return jsonResponse({
    'error': 'failed to $what: ${userMessage(error)}',
  }, status: 500);
}

/// The query parameter [name] as a bool: null when absent, else `true` or
/// `false`; anything else is the 400 to send.
({bool? value, Response? error}) boolQuery(
  Map<String, String> query,
  String name,
) => switch (query[name]?.trim()) {
  null || '' => (value: null, error: null),
  'true' => (value: true, error: null),
  'false' => (value: false, error: null),
  _ => (
    value: null,
    error: jsonResponse({'error': '$name must be true or false'}, status: 400),
  ),
};

/// The 400 for missing required fields.
Response missingFields(List<String> fields) => jsonResponse({
  'error': 'missing required field(s): ${fields.join(', ')}',
}, status: 400);

/// The 400 for fields a route doesn't take, listing the ones it does.
Response unsupportedFields(Iterable<String> fields, Set<String> allowed) =>
    jsonResponse({
      'error': 'unsupported field(s): ${fields.join(', ')}',
      'fields': allowed.toList(),
    }, status: 400);

/// Names from a JSON list of strings or a comma-separated string, trimmed and
/// without blanks; null when [value] is null. Throws [FormatException] naming
/// [field] for anything else.
List<String>? nameList(Object? value, String field) {
  if (value == null) return null;
  final Iterable<String> raw;
  if (value is String) {
    raw = value.split(',');
  } else if (value is List && value.every((v) => v is String)) {
    raw = value.cast<String>();
  } else {
    throw FormatException('$field must be a list of strings');
  }
  return [
    for (final name in raw)
      if (name.trim().isNotEmpty) name.trim(),
  ];
}
