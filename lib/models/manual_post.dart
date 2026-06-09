import 'dart:math';

/// A manually logged unit of work that happened outside any worktree — "I spent
/// N hours on issue X today". Surfaced in the Activity timeline alongside
/// worktree-derived entries so the same view covers time logging end-to-end.
///
/// [description] is a snapshot taken from the picked predefined issue at creation
/// time, so later edits/deletions of the preset don't rewrite history.
class ManualPost {
  final String id;
  final DateTime timestamp;
  final String repoName;
  final String issueKey;
  final String description;
  final double? hours;

  ManualPost({
    required this.id,
    required this.timestamp,
    required this.repoName,
    required this.issueKey,
    this.description = '',
    this.hours,
  });

  /// Generates a collision-resistant id for a new post (single-user, local).
  static String newId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(0x7fffffff);
    return '$micros-$rand';
  }

  factory ManualPost.fromJson(Map<String, dynamic> json) {
    return ManualPost(
      id: json['id'] as String? ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      repoName: json['repoName'] as String? ?? '',
      issueKey: json['issueKey'] as String? ?? '',
      description: json['description'] as String? ?? '',
      hours: (json['hours'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'repoName': repoName,
    'issueKey': issueKey,
    'description': description,
    if (hours != null) 'hours': hours,
  };

  ManualPost copyWith({
    String? id,
    DateTime? timestamp,
    String? repoName,
    String? issueKey,
    String? description,
    double? hours,
  }) {
    return ManualPost(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      repoName: repoName ?? this.repoName,
      issueKey: issueKey ?? this.issueKey,
      description: description ?? this.description,
      hours: hours ?? this.hours,
    );
  }
}
