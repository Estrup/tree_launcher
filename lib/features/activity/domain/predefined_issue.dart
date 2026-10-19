/// A reusable issue key + description configured per repo, used as the picker
/// source when logging a manual activity post.
class PredefinedIssue {
  final String key;
  final String description;

  PredefinedIssue({required this.key, required this.description});

  factory PredefinedIssue.fromJson(Map<String, dynamic> json) {
    return PredefinedIssue(
      key: json['key'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'description': description};

  PredefinedIssue copyWith({String? key, String? description}) {
    return PredefinedIssue(
      key: key ?? this.key,
      description: description ?? this.description,
    );
  }
}
