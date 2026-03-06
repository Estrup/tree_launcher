import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void logVoice(
  String scope,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  final prefix = '[Voice/$scope]';
  developer.log(
    message,
    name: 'tree_launcher.voice.$scope',
    error: error,
    stackTrace: stackTrace,
  );
  debugPrint('$prefix $message');
}
