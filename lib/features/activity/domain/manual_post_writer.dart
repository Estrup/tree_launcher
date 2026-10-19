import 'package:tree_launcher/features/activity/domain/manual_post.dart';

/// Logs manual activity posts in the running app, for the agent HTTP API.
///
/// Implemented by the live `ActivityController`, so a post logged by an agent
/// shows in the Activity tab at once.
abstract interface class ManualPostWriter {
  /// Logs a post stamped at the current time and returns it.
  Future<ManualPost> addManualPost({
    required String repoName,
    required String issueKey,
    String description = '',
    double? hours,
  });
}
