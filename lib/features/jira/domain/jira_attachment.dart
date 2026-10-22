/// A file attached to a Jira issue. Its [contentUrl] needs the Jira token to
/// download.
class JiraAttachment {
  final String id;
  final String filename;
  final int size;
  final String? mimeType;
  final String contentUrl;
  final String? author;
  final DateTime? created;

  const JiraAttachment({
    required this.id,
    required this.filename,
    required this.contentUrl,
    this.size = 0,
    this.mimeType,
    this.author,
    this.created,
  });

  bool get isImage => mimeType?.startsWith('image/') ?? false;

  /// Parses an entry of the REST API's `fields.attachment`.
  factory JiraAttachment.fromApiJson(Map<String, dynamic> json) {
    final author = json['author'];
    return JiraAttachment(
      id: json['id']?.toString() ?? '',
      filename: json['filename'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      mimeType: json['mimeType'] as String?,
      contentUrl: json['content'] as String? ?? '',
      author: author is Map<String, dynamic>
          ? author['displayName'] as String?
          : null,
      created: DateTime.tryParse(json['created'] as String? ?? ''),
    );
  }

  /// Parses the flat shape written by [toJson] (used by the on-disk cache).
  factory JiraAttachment.fromJson(Map<String, dynamic> json) => JiraAttachment(
    id: json['id'] as String? ?? '',
    filename: json['filename'] as String? ?? '',
    size: json['size'] as int? ?? 0,
    mimeType: json['mimeType'] as String?,
    contentUrl: json['contentUrl'] as String? ?? '',
    author: json['author'] as String?,
    created: DateTime.tryParse(json['created'] as String? ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'size': size,
    if (mimeType != null) 'mimeType': mimeType,
    'contentUrl': contentUrl,
    if (author != null) 'author': author,
    if (created != null) 'created': created!.toIso8601String(),
  };
}

/// [bytes] as a short size, e.g. `840 B`, `12 KB`, `3.4 MB`.
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
