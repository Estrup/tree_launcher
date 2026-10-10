/// A tag of the user's own for Jira issues (e.g. "Blocked", "Demo"), kept in
/// the app settings and never sent to Jira. An issue can have several.
class JiraTag {
  /// Stable id that issues refer to, so renaming keeps their tags.
  final String id;
  final String name;

  /// One of [jiraTagColors].
  final String color;

  const JiraTag({required this.id, required this.name, required this.color});

  factory JiraTag.fromJson(Map<String, dynamic> json) => JiraTag(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String? ?? jiraTagColors.first,
  );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  JiraTag copyWith({String? name, String? color}) =>
      JiraTag(id: id, name: name ?? this.name, color: color ?? this.color);
}

/// Colors a [JiraTag] can have, in the order new tags take them.
const jiraTagColors = [
  'blue',
  'green',
  'yellow',
  'orange',
  'red',
  'purple',
  'pink',
  'gray',
];
