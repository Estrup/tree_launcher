/// [error] as a message to show the user: what an `Exception('...')` says,
/// without Dart's "Exception: " prefix, or any other error's own text.
String userMessage(Object error) =>
    error.toString().replaceFirst(RegExp(r'^Exception: '), '');
