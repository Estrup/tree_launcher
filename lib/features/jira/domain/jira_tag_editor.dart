import 'package:tree_launcher/features/jira/domain/jira_tag.dart';

/// The user's local Jira tags in the running app, for the agent HTTP API.
///
/// Implemented by the live `SettingsController`, so changes go through its
/// in-memory → save → notify pipeline: the running app never reloads settings
/// from disk, so a direct config write would be clobbered by its next save.
abstract class JiraTagEditor {
  /// Every tag, in display order.
  List<JiraTag> get jiraTags;

  /// The tags [issueKey] has, in display order.
  List<JiraTag> jiraTagsFor(String issueKey);

  /// Replaces [issueKey]'s tags with the tags [tagIds]; empty removes all.
  Future<void> setJiraTagsFor(String issueKey, List<String> tagIds);
}
