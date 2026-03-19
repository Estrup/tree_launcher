enum BuildStatus {
  notStarted,
  inProgress,
  completed,
  cancelling,
  postponed,
  notSet,
  none;

  static BuildStatus fromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'notstarted':
        return BuildStatus.notStarted;
      case 'inprogress':
        return BuildStatus.inProgress;
      case 'completed':
        return BuildStatus.completed;
      case 'cancelling':
        return BuildStatus.cancelling;
      case 'postponed':
        return BuildStatus.postponed;
      case 'notset':
        return BuildStatus.notSet;
      default:
        return BuildStatus.none;
    }
  }
}

enum BuildResultType {
  succeeded,
  partiallySucceeded,
  failed,
  canceled,
  none;

  static BuildResultType fromApi(String? value) {
    switch (value?.toLowerCase()) {
      case 'succeeded':
        return BuildResultType.succeeded;
      case 'partiallysucceeded':
        return BuildResultType.partiallySucceeded;
      case 'failed':
        return BuildResultType.failed;
      case 'canceled':
        return BuildResultType.canceled;
      default:
        return BuildResultType.none;
    }
  }
}

class BuildResult {
  final int id;
  final int definitionId;
  final String definitionName;
  final BuildStatus status;
  final BuildResultType result;
  final String? sourceBranch;
  final String? sourceVersion;
  final String? buildNumber;
  final DateTime? startTime;
  final DateTime? finishTime;
  final String? webUrl;

  BuildResult({
    required this.id,
    required this.definitionId,
    required this.definitionName,
    required this.status,
    required this.result,
    this.sourceBranch,
    this.sourceVersion,
    this.buildNumber,
    this.startTime,
    this.finishTime,
    this.webUrl,
  });

  factory BuildResult.fromApiJson(Map<String, dynamic> json) {
    final definition = json['definition'] as Map<String, dynamic>? ?? {};
    final links = json['_links'] as Map<String, dynamic>? ?? {};
    final webLink = links['web'] as Map<String, dynamic>? ?? {};

    return BuildResult(
      id: json['id'] as int,
      definitionId: definition['id'] as int? ?? 0,
      definitionName: definition['name'] as String? ?? '',
      status: BuildStatus.fromApi(json['status'] as String?),
      result: BuildResultType.fromApi(json['result'] as String?),
      sourceBranch: json['sourceBranch'] as String?,
      sourceVersion: json['sourceVersion'] as String?,
      buildNumber: json['buildNumber'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      finishTime: json['finishTime'] != null
          ? DateTime.tryParse(json['finishTime'] as String)
          : null,
      webUrl: webLink['href'] as String?,
    );
  }

  /// Branch name without the refs/heads/ prefix.
  String? get branchName {
    if (sourceBranch == null) return null;
    return sourceBranch!.replaceFirst('refs/heads/', '');
  }

  /// Abbreviated commit SHA (first 7 characters).
  String? get shortCommit {
    if (sourceVersion == null) return null;
    if (sourceVersion!.length > 7) return sourceVersion!.substring(0, 7);
    return sourceVersion;
  }

  /// Display label for the build's current state.
  String get statusLabel {
    if (status == BuildStatus.completed) {
      switch (result) {
        case BuildResultType.succeeded:
          return 'Succeeded';
        case BuildResultType.partiallySucceeded:
          return 'Partial';
        case BuildResultType.failed:
          return 'Failed';
        case BuildResultType.canceled:
          return 'Canceled';
        case BuildResultType.none:
          return 'Completed';
      }
    }
    switch (status) {
      case BuildStatus.inProgress:
        return 'Running';
      case BuildStatus.notStarted:
        return 'Queued';
      case BuildStatus.cancelling:
        return 'Cancelling';
      case BuildStatus.postponed:
        return 'Postponed';
      default:
        return 'Unknown';
    }
  }
}
