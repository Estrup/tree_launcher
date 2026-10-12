import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';

/// Where an agent run is, as the agent reports it. `waiting` means it needs a
/// human (a gate or an interruption).
enum AgentState {
  starting,
  running,
  waiting,
  done,
  failed,
  stopped;

  bool get isFinished =>
      this == AgentState.done ||
      this == AgentState.failed ||
      this == AgentState.stopped;

  static AgentState? tryParse(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final state in values) {
      if (state.name == lower) return state;
    }
    return null;
  }
}

enum AgentStageState {
  pending,
  running,
  waiting,
  done,
  failed,
  skipped;

  bool get isActive =>
      this == AgentStageState.running || this == AgentStageState.waiting;

  static AgentStageState? tryParse(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final state in values) {
      if (state.name == lower) return state;
    }
    return null;
  }
}

/// One step of an agent's flow. The agent declares its stages (the factory's
/// `spec, plan, implement, …`), so the app knows no skill's flow.
class AgentStage {
  const AgentStage({
    required this.name,
    this.state = AgentStageState.pending,
    this.progressDone,
    this.progressTotal,
  });

  final String name;
  final AgentStageState state;

  /// Progress within the stage, such as plan step 4 of 7.
  final int? progressDone;
  final int? progressTotal;

  AgentStage copyWith({
    AgentStageState? state,
    int? progressDone,
    int? progressTotal,
  }) => AgentStage(
    name: name,
    state: state ?? this.state,
    progressDone: progressDone ?? this.progressDone,
    progressTotal: progressTotal ?? this.progressTotal,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'state': state.name,
    if (progressDone != null || progressTotal != null)
      'progress': {'done': progressDone, 'total': progressTotal},
  };

  static AgentStage fromJson(Map<String, dynamic> json) {
    final progress = json['progress'];
    return AgentStage(
      name: json['name'] as String,
      state:
          AgentStageState.tryParse(json['state'] as String?) ??
          AgentStageState.pending,
      progressDone: progress is Map ? progress['done'] as int? : null,
      progressTotal: progress is Map ? progress['total'] as int? : null,
    );
  }
}

/// A labelled link on an agent run: a URL, or a file path (relative paths
/// are resolved against the run's worktree).
class AgentLink {
  const AgentLink({required this.label, required this.target});

  final String label;
  final String target;

  bool get isUrl =>
      target.startsWith('http://') || target.startsWith('https://');

  Map<String, dynamic> toJson() => {'label': label, 'target': target};

  static AgentLink fromJson(Map<String, dynamic> json) => AgentLink(
    label: json['label'] as String,
    target: json['target'] as String,
  );
}

/// What an agent (or the app, when it launches one) says about itself when
/// it registers. Null fields leave a run's value as it is.
class AgentRegistration {
  const AgentRegistration({
    this.kind,
    this.repoName,
    this.promptName,
    this.title,
    this.issueKeys,
    this.worktreePath,
    this.branch,
    this.prNumber,
    this.stages,
    this.model,
    this.effort,
  });

  final AgentKind? kind;
  final String? repoName;
  final String? promptName;
  final String? title;
  final List<String>? issueKeys;
  final String? worktreePath;
  final String? branch;
  final int? prNumber;
  final List<String>? stages;
  final String? model;
  final String? effort;
}

/// One status report from an agent. Every field is optional.
class AgentReport {
  const AgentReport({
    this.state,
    this.stage,
    this.stageState,
    this.progressDone,
    this.progressTotal,
    this.stages,
    this.message,
    this.level,
    this.links = const [],
    this.result,
  });

  final AgentState? state;

  /// The stage this report is about; added to the run if it isn't declared.
  final String? stage;
  final AgentStageState? stageState;
  final int? progressDone;
  final int? progressTotal;

  /// Re-declares the run's stages, keeping the state of those that remain.
  final List<String>? stages;
  final String? message;
  final AgentEventLevel? level;

  /// Added to the run's links, replacing any with the same label.
  final List<AgentLink> links;

  /// The outcome in a few words, such as "PR #7123" or "verificeret".
  final String? result;
}

/// One launch of an agent: a Claude session doing a kind of work (build,
/// verify, review, docs), and what it has reported about its progress.
class AgentRun {
  const AgentRun({
    required this.id,
    required this.kind,
    required this.repoName,
    required this.startedAt,
    required this.updatedAt,
    this.promptName,
    this.title,
    this.issueKeys = const [],
    this.worktreePath,
    this.branch,
    this.prNumber,
    this.stages = const [],
    this.currentStage,
    this.state = AgentState.starting,
    this.summary,
    this.result,
    this.links = const [],
    this.model,
    this.effort,
    this.claudeSessionId,
    this.finishedAt,
    this.archived = false,
  });

  final String id;
  final AgentKind kind;
  final String repoName;

  /// The saved prompt it was started with: its subtype.
  final String? promptName;
  final String? title;

  /// The Jira issues it works on (a docs run can cover several).
  final List<String> issueKeys;

  /// Its working directory: the issue's worktree, or a shared checkout.
  final String? worktreePath;
  final String? branch;
  final int? prNumber;
  final List<AgentStage> stages;
  final String? currentStage;
  final AgentState state;

  /// The latest message, shown on its card.
  final String? summary;
  final String? result;
  final List<AgentLink> links;

  /// The model and effort it was launched with, to resume it the same way.
  final String? model;
  final String? effort;

  /// The Claude CLI session id, seen while it runs in the built-in terminal,
  /// so it can be resumed exactly (`claude --resume <id>`) even when other
  /// sessions share its working directory.
  final String? claudeSessionId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;
  final bool archived;

  /// Its first issue key, if any.
  String? get issueKey => issueKeys.isEmpty ? null : issueKeys.first;

  AgentStage? get activeStage {
    final name = currentStage;
    if (name == null) return null;
    for (final stage in stages) {
      if (stage.name == name) return stage;
    }
    return null;
  }

  AgentRun copyWith({
    AgentKind? kind,
    String? repoName,
    String? promptName,
    String? title,
    List<String>? issueKeys,
    String? worktreePath,
    String? branch,
    int? prNumber,
    List<AgentStage>? stages,
    String? currentStage,
    bool clearCurrentStage = false,
    AgentState? state,
    String? summary,
    String? result,
    List<AgentLink>? links,
    String? model,
    String? effort,
    String? claudeSessionId,
    DateTime? updatedAt,
    DateTime? finishedAt,
    bool clearFinishedAt = false,
    bool? archived,
  }) => AgentRun(
    id: id,
    kind: kind ?? this.kind,
    repoName: repoName ?? this.repoName,
    promptName: promptName ?? this.promptName,
    title: title ?? this.title,
    issueKeys: issueKeys ?? this.issueKeys,
    worktreePath: worktreePath ?? this.worktreePath,
    branch: branch ?? this.branch,
    prNumber: prNumber ?? this.prNumber,
    stages: stages ?? this.stages,
    currentStage: clearCurrentStage
        ? null
        : (currentStage ?? this.currentStage),
    state: state ?? this.state,
    summary: summary ?? this.summary,
    result: result ?? this.result,
    links: links ?? this.links,
    model: model ?? this.model,
    effort: effort ?? this.effort,
    claudeSessionId: claudeSessionId ?? this.claudeSessionId,
    startedAt: startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    archived: archived ?? this.archived,
  );

  /// This run with [registration]'s non-null fields applied. Declared
  /// [AgentRegistration.stages] replace the stages, keeping the state of
  /// those that remain.
  AgentRun registered(AgentRegistration registration, DateTime now) {
    final declared = registration.stages;
    final stages = declared == null ? null : _redeclare(declared);
    return copyWith(
      kind: registration.kind,
      repoName: registration.repoName,
      promptName: registration.promptName,
      title: registration.title,
      issueKeys: registration.issueKeys,
      worktreePath: registration.worktreePath,
      branch: registration.branch,
      prNumber: registration.prNumber,
      stages: stages,
      clearCurrentStage:
          stages != null && !stages.any((s) => s.name == currentStage),
      model: registration.model,
      effort: registration.effort,
      updatedAt: now,
    );
  }

  /// This run after [report], and the timeline event it adds (null when the
  /// report changed nothing worth a line).
  ///
  /// A stage that becomes active becomes the current stage and completes the
  /// active stages before it. A stage report without a stage state follows
  /// the run's state (running, unless the report waits, fails or finishes).
  /// A report without a stage applies the run's new state to the current
  /// stage. The first report moves a run out of `starting`; a running stage
  /// moves it out of `waiting` or a finished state.
  ({AgentRun run, AgentEvent? event}) reported(
    AgentReport report,
    DateTime now,
  ) {
    final stages = report.stages == null
        ? [...this.stages]
        : _redeclare(report.stages!);
    var current = stages.any((s) => s.name == currentStage)
        ? currentStage
        : null;

    var newState =
        report.state ??
        (state == AgentState.starting ? AgentState.running : state);

    final stageName = report.stage?.trim();
    String? stageChange;
    if (stageName != null && stageName.isNotEmpty) {
      var index = stages.indexWhere((s) => s.name == stageName);
      if (index == -1) {
        stages.add(AgentStage(name: stageName));
        index = stages.length - 1;
      }
      final stageState =
          report.stageState ??
          _stageStateFor(report.state ?? AgentState.running);
      if (report.state == null && stageState == AgentStageState.running) {
        newState = AgentState.running;
      }
      final before = stages[index];
      stages[index] = before.copyWith(
        state: stageState,
        progressDone: report.progressDone,
        progressTotal: report.progressTotal,
      );
      if (stageState.isActive) {
        current = stageName;
        for (var i = 0; i < index; i++) {
          if (stages[i].state.isActive) {
            stages[i] = stages[i].copyWith(state: AgentStageState.done);
          }
        }
      }
      if (before.state != stageState) {
        stageChange = '$stageName ${_stageVerb(stageState)}';
      }
    } else if (current != null) {
      final index = stages.indexWhere((s) => s.name == current);
      final stage = stages[index];
      final next = switch (newState) {
        AgentState.waiting when stage.state == AgentStageState.running =>
          AgentStageState.waiting,
        AgentState.running when stage.state == AgentStageState.waiting =>
          AgentStageState.running,
        AgentState.done when stage.state.isActive => AgentStageState.done,
        AgentState.failed when stage.state.isActive => AgentStageState.failed,
        _ => stage.state,
      };
      stages[index] = stage.copyWith(state: next);
    }

    if (newState == AgentState.done || newState == AgentState.failed) {
      final settled = newState == AgentState.done
          ? AgentStageState.done
          : AgentStageState.failed;
      for (var i = 0; i < stages.length; i++) {
        if (stages[i].state.isActive) {
          stages[i] = stages[i].copyWith(state: settled);
        }
      }
    }

    final links = [...this.links];
    for (final link in report.links) {
      links.removeWhere((l) => l.label == link.label);
      links.add(link);
    }

    final message = report.message?.trim();
    final hasMessage = message != null && message.isNotEmpty;
    final stateChanged = newState != state && state != AgentState.starting;
    final run = AgentRun(
      id: id,
      kind: kind,
      repoName: repoName,
      promptName: promptName,
      title: title,
      issueKeys: issueKeys,
      worktreePath: worktreePath,
      branch: branch,
      prNumber: prNumber,
      stages: stages,
      currentStage: current,
      state: newState,
      summary: hasMessage ? message : summary,
      result: report.result ?? result,
      links: links,
      model: model,
      effort: effort,
      claudeSessionId: claudeSessionId,
      startedAt: startedAt,
      updatedAt: now,
      finishedAt: newState.isFinished ? (finishedAt ?? now) : null,
      archived: archived,
    );

    String? text = hasMessage ? message : null;
    if (text == null) {
      final parts = [
        ?stageChange,
        if (stateChanged || (newState != state && stageChange == null))
          _stateText(newState),
      ];
      if (parts.isNotEmpty) text = parts.join(' · ');
    }
    if (text == null) return (run: run, event: null);
    return (
      run: run,
      event: AgentEvent(
        agentId: id,
        at: now,
        message: text,
        stage: stageName != null && stageName.isNotEmpty ? stageName : current,
        level: report.level ?? _levelFor(report.state),
      ),
    );
  }

  List<AgentStage> _redeclare(List<String> names) => [
    for (final name in names)
      stages.where((s) => s.name == name).firstOrNull ?? AgentStage(name: name),
  ];

  static AgentStageState _stageStateFor(AgentState state) => switch (state) {
    AgentState.waiting => AgentStageState.waiting,
    AgentState.done => AgentStageState.done,
    AgentState.failed => AgentStageState.failed,
    _ => AgentStageState.running,
  };

  static String _stageVerb(AgentStageState state) => switch (state) {
    AgentStageState.pending => 'pending',
    AgentStageState.running => 'started',
    AgentStageState.waiting => 'waiting',
    AgentStageState.done => 'done',
    AgentStageState.failed => 'failed',
    AgentStageState.skipped => 'skipped',
  };

  static String _stateText(AgentState state) => switch (state) {
    AgentState.starting => 'Starting',
    AgentState.running => 'Running',
    AgentState.waiting => 'Waiting for you',
    AgentState.done => 'Done',
    AgentState.failed => 'Failed',
    AgentState.stopped => 'Stopped',
  };

  static AgentEventLevel _levelFor(AgentState? state) => switch (state) {
    AgentState.waiting => AgentEventLevel.action,
    AgentState.done => AgentEventLevel.success,
    AgentState.failed => AgentEventLevel.error,
    _ => AgentEventLevel.info,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'repo': repoName,
    'prompt': promptName,
    'title': title,
    'issueKeys': issueKeys,
    'worktreePath': worktreePath,
    'branch': branch,
    'prNumber': prNumber,
    'stages': [for (final stage in stages) stage.toJson()],
    'currentStage': currentStage,
    'state': state.name,
    'summary': summary,
    'result': result,
    'links': [for (final link in links) link.toJson()],
    'model': model,
    'effort': effort,
    'claudeSessionId': claudeSessionId,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'archived': archived,
  };

  static AgentRun fromJson(Map<String, dynamic> json) {
    final startedAt = DateTime.parse(json['startedAt'] as String);
    return AgentRun(
      id: json['id'] as String,
      kind: AgentKind.tryParse(json['kind'] as String?) ?? AgentKind.build,
      repoName: json['repo'] as String? ?? '',
      promptName: json['prompt'] as String?,
      title: json['title'] as String?,
      issueKeys:
          (json['issueKeys'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      worktreePath: json['worktreePath'] as String?,
      branch: json['branch'] as String?,
      prNumber: json['prNumber'] as int?,
      stages: [
        for (final stage
            in (json['stages'] as List<dynamic>?)
                    ?.whereType<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[])
          AgentStage.fromJson(stage),
      ],
      currentStage: json['currentStage'] as String?,
      state:
          AgentState.tryParse(json['state'] as String?) ?? AgentState.running,
      summary: json['summary'] as String?,
      result: json['result'] as String?,
      links: [
        for (final link
            in (json['links'] as List<dynamic>?)
                    ?.whereType<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[])
          AgentLink.fromJson(link),
      ],
      model: json['model'] as String?,
      effort: json['effort'] as String?,
      claudeSessionId: json['claudeSessionId'] as String?,
      startedAt: startedAt,
      updatedAt: json['updatedAt'] == null
          ? startedAt
          : DateTime.parse(json['updatedAt'] as String),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt'] as String),
      archived: json['archived'] as bool? ?? false,
    );
  }
}
