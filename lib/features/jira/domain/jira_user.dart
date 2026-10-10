/// A Jira Server/Data Center user.
class JiraUser {
  /// Username, which identifies the user in API calls (e.g. assigning).
  final String name;
  final String displayName;

  const JiraUser({required this.name, required this.displayName});

  /// Parses a user from the REST API (e.g. `GET /rest/api/2/myself`).
  factory JiraUser.fromApiJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return JiraUser(
      name: name,
      displayName: json['displayName'] as String? ?? name,
    );
  }
}
