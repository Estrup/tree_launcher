// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AgentRunsTable extends AgentRuns
    with TableInfo<$AgentRunsTable, AgentRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoMeta = const VerificationMeta('repo');
  @override
  late final GeneratedColumn<String> repo = GeneratedColumn<String>(
    'repo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worktreePathMeta = const VerificationMeta(
    'worktreePath',
  );
  @override
  late final GeneratedColumn<String> worktreePath = GeneratedColumn<String>(
    'worktree_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prNumberMeta = const VerificationMeta(
    'prNumber',
  );
  @override
  late final GeneratedColumn<int> prNumber = GeneratedColumn<int>(
    'pr_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> startedAt =
      GeneratedColumn<String>(
        'started_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AgentRunsTable.$converterstartedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> updatedAt =
      GeneratedColumn<String>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AgentRunsTable.$converterupdatedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String> finishedAt =
      GeneratedColumn<String>(
        'finished_at',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($AgentRunsTable.$converterfinishedAtn);
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    repo,
    title,
    state,
    worktreePath,
    branch,
    prNumber,
    archived,
    startedAt,
    updatedAt,
    finishedAt,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('repo')) {
      context.handle(
        _repoMeta,
        repo.isAcceptableOrUnknown(data['repo']!, _repoMeta),
      );
    } else if (isInserting) {
      context.missing(_repoMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('worktree_path')) {
      context.handle(
        _worktreePathMeta,
        worktreePath.isAcceptableOrUnknown(
          data['worktree_path']!,
          _worktreePathMeta,
        ),
      );
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('pr_number')) {
      context.handle(
        _prNumberMeta,
        prNumber.isAcceptableOrUnknown(data['pr_number']!, _prNumberMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    } else if (isInserting) {
      context.missing(_detailMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      repo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      worktreePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worktree_path'],
      ),
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      ),
      prNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pr_number'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      startedAt: $AgentRunsTable.$converterstartedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}started_at'],
        )!,
      ),
      updatedAt: $AgentRunsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      finishedAt: $AgentRunsTable.$converterfinishedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}finished_at'],
        ),
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      )!,
    );
  }

  @override
  $AgentRunsTable createAlias(String alias) {
    return $AgentRunsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterstartedAt =
      const IsoDateTime();
  static TypeConverter<DateTime, String> $converterupdatedAt =
      const IsoDateTime();
  static TypeConverter<DateTime, String> $converterfinishedAt =
      const IsoDateTime();
  static TypeConverter<DateTime?, String?> $converterfinishedAtn =
      NullAwareTypeConverter.wrap($converterfinishedAt);
}

class AgentRunRow extends DataClass implements Insertable<AgentRunRow> {
  final String id;
  final String kind;
  final String repo;
  final String? title;
  final String state;
  final String? worktreePath;
  final String? branch;
  final int? prNumber;
  final bool archived;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;
  final String detail;
  const AgentRunRow({
    required this.id,
    required this.kind,
    required this.repo,
    this.title,
    required this.state,
    this.worktreePath,
    this.branch,
    this.prNumber,
    required this.archived,
    required this.startedAt,
    required this.updatedAt,
    this.finishedAt,
    required this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['repo'] = Variable<String>(repo);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || worktreePath != null) {
      map['worktree_path'] = Variable<String>(worktreePath);
    }
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || prNumber != null) {
      map['pr_number'] = Variable<int>(prNumber);
    }
    map['archived'] = Variable<bool>(archived);
    {
      map['started_at'] = Variable<String>(
        $AgentRunsTable.$converterstartedAt.toSql(startedAt),
      );
    }
    {
      map['updated_at'] = Variable<String>(
        $AgentRunsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<String>(
        $AgentRunsTable.$converterfinishedAtn.toSql(finishedAt),
      );
    }
    map['detail'] = Variable<String>(detail);
    return map;
  }

  AgentRunsCompanion toCompanion(bool nullToAbsent) {
    return AgentRunsCompanion(
      id: Value(id),
      kind: Value(kind),
      repo: Value(repo),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      state: Value(state),
      worktreePath: worktreePath == null && nullToAbsent
          ? const Value.absent()
          : Value(worktreePath),
      branch: branch == null && nullToAbsent
          ? const Value.absent()
          : Value(branch),
      prNumber: prNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(prNumber),
      archived: Value(archived),
      startedAt: Value(startedAt),
      updatedAt: Value(updatedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      detail: Value(detail),
    );
  }

  factory AgentRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentRunRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      repo: serializer.fromJson<String>(json['repo']),
      title: serializer.fromJson<String?>(json['title']),
      state: serializer.fromJson<String>(json['state']),
      worktreePath: serializer.fromJson<String?>(json['worktreePath']),
      branch: serializer.fromJson<String?>(json['branch']),
      prNumber: serializer.fromJson<int?>(json['prNumber']),
      archived: serializer.fromJson<bool>(json['archived']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      detail: serializer.fromJson<String>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'repo': serializer.toJson<String>(repo),
      'title': serializer.toJson<String?>(title),
      'state': serializer.toJson<String>(state),
      'worktreePath': serializer.toJson<String?>(worktreePath),
      'branch': serializer.toJson<String?>(branch),
      'prNumber': serializer.toJson<int?>(prNumber),
      'archived': serializer.toJson<bool>(archived),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'detail': serializer.toJson<String>(detail),
    };
  }

  AgentRunRow copyWith({
    String? id,
    String? kind,
    String? repo,
    Value<String?> title = const Value.absent(),
    String? state,
    Value<String?> worktreePath = const Value.absent(),
    Value<String?> branch = const Value.absent(),
    Value<int?> prNumber = const Value.absent(),
    bool? archived,
    DateTime? startedAt,
    DateTime? updatedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    String? detail,
  }) => AgentRunRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    repo: repo ?? this.repo,
    title: title.present ? title.value : this.title,
    state: state ?? this.state,
    worktreePath: worktreePath.present ? worktreePath.value : this.worktreePath,
    branch: branch.present ? branch.value : this.branch,
    prNumber: prNumber.present ? prNumber.value : this.prNumber,
    archived: archived ?? this.archived,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    detail: detail ?? this.detail,
  );
  AgentRunRow copyWithCompanion(AgentRunsCompanion data) {
    return AgentRunRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      repo: data.repo.present ? data.repo.value : this.repo,
      title: data.title.present ? data.title.value : this.title,
      state: data.state.present ? data.state.value : this.state,
      worktreePath: data.worktreePath.present
          ? data.worktreePath.value
          : this.worktreePath,
      branch: data.branch.present ? data.branch.value : this.branch,
      prNumber: data.prNumber.present ? data.prNumber.value : this.prNumber,
      archived: data.archived.present ? data.archived.value : this.archived,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('repo: $repo, ')
          ..write('title: $title, ')
          ..write('state: $state, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('branch: $branch, ')
          ..write('prNumber: $prNumber, ')
          ..write('archived: $archived, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    repo,
    title,
    state,
    worktreePath,
    branch,
    prNumber,
    archived,
    startedAt,
    updatedAt,
    finishedAt,
    detail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentRunRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.repo == this.repo &&
          other.title == this.title &&
          other.state == this.state &&
          other.worktreePath == this.worktreePath &&
          other.branch == this.branch &&
          other.prNumber == this.prNumber &&
          other.archived == this.archived &&
          other.startedAt == this.startedAt &&
          other.updatedAt == this.updatedAt &&
          other.finishedAt == this.finishedAt &&
          other.detail == this.detail);
}

class AgentRunsCompanion extends UpdateCompanion<AgentRunRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> repo;
  final Value<String?> title;
  final Value<String> state;
  final Value<String?> worktreePath;
  final Value<String?> branch;
  final Value<int?> prNumber;
  final Value<bool> archived;
  final Value<DateTime> startedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> finishedAt;
  final Value<String> detail;
  final Value<int> rowid;
  const AgentRunsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.repo = const Value.absent(),
    this.title = const Value.absent(),
    this.state = const Value.absent(),
    this.worktreePath = const Value.absent(),
    this.branch = const Value.absent(),
    this.prNumber = const Value.absent(),
    this.archived = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.detail = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentRunsCompanion.insert({
    required String id,
    required String kind,
    required String repo,
    this.title = const Value.absent(),
    required String state,
    this.worktreePath = const Value.absent(),
    this.branch = const Value.absent(),
    this.prNumber = const Value.absent(),
    this.archived = const Value.absent(),
    required DateTime startedAt,
    required DateTime updatedAt,
    this.finishedAt = const Value.absent(),
    required String detail,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       repo = Value(repo),
       state = Value(state),
       startedAt = Value(startedAt),
       updatedAt = Value(updatedAt),
       detail = Value(detail);
  static Insertable<AgentRunRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? repo,
    Expression<String>? title,
    Expression<String>? state,
    Expression<String>? worktreePath,
    Expression<String>? branch,
    Expression<int>? prNumber,
    Expression<bool>? archived,
    Expression<String>? startedAt,
    Expression<String>? updatedAt,
    Expression<String>? finishedAt,
    Expression<String>? detail,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (repo != null) 'repo': repo,
      if (title != null) 'title': title,
      if (state != null) 'state': state,
      if (worktreePath != null) 'worktree_path': worktreePath,
      if (branch != null) 'branch': branch,
      if (prNumber != null) 'pr_number': prNumber,
      if (archived != null) 'archived': archived,
      if (startedAt != null) 'started_at': startedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (detail != null) 'detail': detail,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? repo,
    Value<String?>? title,
    Value<String>? state,
    Value<String?>? worktreePath,
    Value<String?>? branch,
    Value<int?>? prNumber,
    Value<bool>? archived,
    Value<DateTime>? startedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? finishedAt,
    Value<String>? detail,
    Value<int>? rowid,
  }) {
    return AgentRunsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      repo: repo ?? this.repo,
      title: title ?? this.title,
      state: state ?? this.state,
      worktreePath: worktreePath ?? this.worktreePath,
      branch: branch ?? this.branch,
      prNumber: prNumber ?? this.prNumber,
      archived: archived ?? this.archived,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      detail: detail ?? this.detail,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (repo.present) {
      map['repo'] = Variable<String>(repo.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (worktreePath.present) {
      map['worktree_path'] = Variable<String>(worktreePath.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (prNumber.present) {
      map['pr_number'] = Variable<int>(prNumber.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(
        $AgentRunsTable.$converterstartedAt.toSql(startedAt.value),
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(
        $AgentRunsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<String>(
        $AgentRunsTable.$converterfinishedAtn.toSql(finishedAt.value),
      );
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('repo: $repo, ')
          ..write('title: $title, ')
          ..write('state: $state, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('branch: $branch, ')
          ..write('prNumber: $prNumber, ')
          ..write('archived: $archived, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('detail: $detail, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentRunIssuesTable extends AgentRunIssues
    with TableInfo<$AgentRunIssuesTable, AgentRunIssueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentRunIssuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _issueKeyMeta = const VerificationMeta(
    'issueKey',
  );
  @override
  late final GeneratedColumn<String> issueKey = GeneratedColumn<String>(
    'issue_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [runId, issueKey, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_run_issues';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentRunIssueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('issue_key')) {
      context.handle(
        _issueKeyMeta,
        issueKey.isAcceptableOrUnknown(data['issue_key']!, _issueKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_issueKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runId, issueKey};
  @override
  AgentRunIssueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentRunIssueRow(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      issueKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue_key'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $AgentRunIssuesTable createAlias(String alias) {
    return $AgentRunIssuesTable(attachedDatabase, alias);
  }
}

class AgentRunIssueRow extends DataClass
    implements Insertable<AgentRunIssueRow> {
  final String runId;
  final String issueKey;
  final int position;
  const AgentRunIssueRow({
    required this.runId,
    required this.issueKey,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<String>(runId);
    map['issue_key'] = Variable<String>(issueKey);
    map['position'] = Variable<int>(position);
    return map;
  }

  AgentRunIssuesCompanion toCompanion(bool nullToAbsent) {
    return AgentRunIssuesCompanion(
      runId: Value(runId),
      issueKey: Value(issueKey),
      position: Value(position),
    );
  }

  factory AgentRunIssueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentRunIssueRow(
      runId: serializer.fromJson<String>(json['runId']),
      issueKey: serializer.fromJson<String>(json['issueKey']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<String>(runId),
      'issueKey': serializer.toJson<String>(issueKey),
      'position': serializer.toJson<int>(position),
    };
  }

  AgentRunIssueRow copyWith({String? runId, String? issueKey, int? position}) =>
      AgentRunIssueRow(
        runId: runId ?? this.runId,
        issueKey: issueKey ?? this.issueKey,
        position: position ?? this.position,
      );
  AgentRunIssueRow copyWithCompanion(AgentRunIssuesCompanion data) {
    return AgentRunIssueRow(
      runId: data.runId.present ? data.runId.value : this.runId,
      issueKey: data.issueKey.present ? data.issueKey.value : this.issueKey,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunIssueRow(')
          ..write('runId: $runId, ')
          ..write('issueKey: $issueKey, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(runId, issueKey, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentRunIssueRow &&
          other.runId == this.runId &&
          other.issueKey == this.issueKey &&
          other.position == this.position);
}

class AgentRunIssuesCompanion extends UpdateCompanion<AgentRunIssueRow> {
  final Value<String> runId;
  final Value<String> issueKey;
  final Value<int> position;
  final Value<int> rowid;
  const AgentRunIssuesCompanion({
    this.runId = const Value.absent(),
    this.issueKey = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AgentRunIssuesCompanion.insert({
    required String runId,
    required String issueKey,
    required int position,
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       issueKey = Value(issueKey),
       position = Value(position);
  static Insertable<AgentRunIssueRow> custom({
    Expression<String>? runId,
    Expression<String>? issueKey,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (issueKey != null) 'issue_key': issueKey,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AgentRunIssuesCompanion copyWith({
    Value<String>? runId,
    Value<String>? issueKey,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return AgentRunIssuesCompanion(
      runId: runId ?? this.runId,
      issueKey: issueKey ?? this.issueKey,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (issueKey.present) {
      map['issue_key'] = Variable<String>(issueKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentRunIssuesCompanion(')
          ..write('runId: $runId, ')
          ..write('issueKey: $issueKey, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AgentEventsTable extends AgentEvents
    with TableInfo<$AgentEventsTable, AgentEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AgentEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<String> runId = GeneratedColumn<String>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES agent_runs (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> at =
      GeneratedColumn<String>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($AgentEventsTable.$converterat);
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, runId, at, stage, level, message];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'agent_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AgentEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AgentEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AgentEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_id'],
      )!,
      at: $AgentEventsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}at'],
        )!,
      ),
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
    );
  }

  @override
  $AgentEventsTable createAlias(String alias) {
    return $AgentEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterat = const IsoDateTime();
}

class AgentEventRow extends DataClass implements Insertable<AgentEventRow> {
  final int id;
  final String runId;
  final DateTime at;
  final String? stage;
  final String level;
  final String message;
  const AgentEventRow({
    required this.id,
    required this.runId,
    required this.at,
    this.stage,
    required this.level,
    required this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['run_id'] = Variable<String>(runId);
    {
      map['at'] = Variable<String>($AgentEventsTable.$converterat.toSql(at));
    }
    if (!nullToAbsent || stage != null) {
      map['stage'] = Variable<String>(stage);
    }
    map['level'] = Variable<String>(level);
    map['message'] = Variable<String>(message);
    return map;
  }

  AgentEventsCompanion toCompanion(bool nullToAbsent) {
    return AgentEventsCompanion(
      id: Value(id),
      runId: Value(runId),
      at: Value(at),
      stage: stage == null && nullToAbsent
          ? const Value.absent()
          : Value(stage),
      level: Value(level),
      message: Value(message),
    );
  }

  factory AgentEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AgentEventRow(
      id: serializer.fromJson<int>(json['id']),
      runId: serializer.fromJson<String>(json['runId']),
      at: serializer.fromJson<DateTime>(json['at']),
      stage: serializer.fromJson<String?>(json['stage']),
      level: serializer.fromJson<String>(json['level']),
      message: serializer.fromJson<String>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'runId': serializer.toJson<String>(runId),
      'at': serializer.toJson<DateTime>(at),
      'stage': serializer.toJson<String?>(stage),
      'level': serializer.toJson<String>(level),
      'message': serializer.toJson<String>(message),
    };
  }

  AgentEventRow copyWith({
    int? id,
    String? runId,
    DateTime? at,
    Value<String?> stage = const Value.absent(),
    String? level,
    String? message,
  }) => AgentEventRow(
    id: id ?? this.id,
    runId: runId ?? this.runId,
    at: at ?? this.at,
    stage: stage.present ? stage.value : this.stage,
    level: level ?? this.level,
    message: message ?? this.message,
  );
  AgentEventRow copyWithCompanion(AgentEventsCompanion data) {
    return AgentEventRow(
      id: data.id.present ? data.id.value : this.id,
      runId: data.runId.present ? data.runId.value : this.runId,
      at: data.at.present ? data.at.value : this.at,
      stage: data.stage.present ? data.stage.value : this.stage,
      level: data.level.present ? data.level.value : this.level,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AgentEventRow(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('at: $at, ')
          ..write('stage: $stage, ')
          ..write('level: $level, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, runId, at, stage, level, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AgentEventRow &&
          other.id == this.id &&
          other.runId == this.runId &&
          other.at == this.at &&
          other.stage == this.stage &&
          other.level == this.level &&
          other.message == this.message);
}

class AgentEventsCompanion extends UpdateCompanion<AgentEventRow> {
  final Value<int> id;
  final Value<String> runId;
  final Value<DateTime> at;
  final Value<String?> stage;
  final Value<String> level;
  final Value<String> message;
  const AgentEventsCompanion({
    this.id = const Value.absent(),
    this.runId = const Value.absent(),
    this.at = const Value.absent(),
    this.stage = const Value.absent(),
    this.level = const Value.absent(),
    this.message = const Value.absent(),
  });
  AgentEventsCompanion.insert({
    this.id = const Value.absent(),
    required String runId,
    required DateTime at,
    this.stage = const Value.absent(),
    required String level,
    required String message,
  }) : runId = Value(runId),
       at = Value(at),
       level = Value(level),
       message = Value(message);
  static Insertable<AgentEventRow> custom({
    Expression<int>? id,
    Expression<String>? runId,
    Expression<String>? at,
    Expression<String>? stage,
    Expression<String>? level,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (runId != null) 'run_id': runId,
      if (at != null) 'at': at,
      if (stage != null) 'stage': stage,
      if (level != null) 'level': level,
      if (message != null) 'message': message,
    });
  }

  AgentEventsCompanion copyWith({
    Value<int>? id,
    Value<String>? runId,
    Value<DateTime>? at,
    Value<String?>? stage,
    Value<String>? level,
    Value<String>? message,
  }) {
    return AgentEventsCompanion(
      id: id ?? this.id,
      runId: runId ?? this.runId,
      at: at ?? this.at,
      stage: stage ?? this.stage,
      level: level ?? this.level,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (runId.present) {
      map['run_id'] = Variable<String>(runId.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(
        $AgentEventsTable.$converterat.toSql(at.value),
      );
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AgentEventsCompanion(')
          ..write('id: $id, ')
          ..write('runId: $runId, ')
          ..write('at: $at, ')
          ..write('stage: $stage, ')
          ..write('level: $level, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

class $WorktreeEventsTable extends WorktreeEvents
    with TableInfo<$WorktreeEventsTable, WorktreeEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorktreeEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> at =
      GeneratedColumn<String>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($WorktreeEventsTable.$converterat);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoPathMeta = const VerificationMeta(
    'repoPath',
  );
  @override
  late final GeneratedColumn<String> repoPath = GeneratedColumn<String>(
    'repo_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoNameMeta = const VerificationMeta(
    'repoName',
  );
  @override
  late final GeneratedColumn<String> repoName = GeneratedColumn<String>(
    'repo_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worktreePathMeta = const VerificationMeta(
    'worktreePath',
  );
  @override
  late final GeneratedColumn<String> worktreePath = GeneratedColumn<String>(
    'worktree_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _worktreeNameMeta = const VerificationMeta(
    'worktreeName',
  );
  @override
  late final GeneratedColumn<String> worktreeName = GeneratedColumn<String>(
    'worktree_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _branchMeta = const VerificationMeta('branch');
  @override
  late final GeneratedColumn<String> branch = GeneratedColumn<String>(
    'branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jiraIssueMeta = const VerificationMeta(
    'jiraIssue',
  );
  @override
  late final GeneratedColumn<String> jiraIssue = GeneratedColumn<String>(
    'jira_issue',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    type,
    repoPath,
    repoName,
    worktreePath,
    worktreeName,
    branch,
    jiraIssue,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worktree_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorktreeEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('repo_path')) {
      context.handle(
        _repoPathMeta,
        repoPath.isAcceptableOrUnknown(data['repo_path']!, _repoPathMeta),
      );
    } else if (isInserting) {
      context.missing(_repoPathMeta);
    }
    if (data.containsKey('repo_name')) {
      context.handle(
        _repoNameMeta,
        repoName.isAcceptableOrUnknown(data['repo_name']!, _repoNameMeta),
      );
    } else if (isInserting) {
      context.missing(_repoNameMeta);
    }
    if (data.containsKey('worktree_path')) {
      context.handle(
        _worktreePathMeta,
        worktreePath.isAcceptableOrUnknown(
          data['worktree_path']!,
          _worktreePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_worktreePathMeta);
    }
    if (data.containsKey('worktree_name')) {
      context.handle(
        _worktreeNameMeta,
        worktreeName.isAcceptableOrUnknown(
          data['worktree_name']!,
          _worktreeNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_worktreeNameMeta);
    }
    if (data.containsKey('branch')) {
      context.handle(
        _branchMeta,
        branch.isAcceptableOrUnknown(data['branch']!, _branchMeta),
      );
    }
    if (data.containsKey('jira_issue')) {
      context.handle(
        _jiraIssueMeta,
        jiraIssue.isAcceptableOrUnknown(data['jira_issue']!, _jiraIssueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorktreeEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorktreeEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: $WorktreeEventsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}at'],
        )!,
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      repoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_path'],
      )!,
      repoName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_name'],
      )!,
      worktreePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worktree_path'],
      )!,
      worktreeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}worktree_name'],
      )!,
      branch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}branch'],
      ),
      jiraIssue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jira_issue'],
      ),
    );
  }

  @override
  $WorktreeEventsTable createAlias(String alias) {
    return $WorktreeEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterat = const IsoDateTime();
}

class WorktreeEventRow extends DataClass
    implements Insertable<WorktreeEventRow> {
  final int id;
  final DateTime at;
  final String type;
  final String repoPath;
  final String repoName;
  final String worktreePath;
  final String worktreeName;
  final String? branch;
  final String? jiraIssue;
  const WorktreeEventRow({
    required this.id,
    required this.at,
    required this.type,
    required this.repoPath,
    required this.repoName,
    required this.worktreePath,
    required this.worktreeName,
    this.branch,
    this.jiraIssue,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['at'] = Variable<String>($WorktreeEventsTable.$converterat.toSql(at));
    }
    map['type'] = Variable<String>(type);
    map['repo_path'] = Variable<String>(repoPath);
    map['repo_name'] = Variable<String>(repoName);
    map['worktree_path'] = Variable<String>(worktreePath);
    map['worktree_name'] = Variable<String>(worktreeName);
    if (!nullToAbsent || branch != null) {
      map['branch'] = Variable<String>(branch);
    }
    if (!nullToAbsent || jiraIssue != null) {
      map['jira_issue'] = Variable<String>(jiraIssue);
    }
    return map;
  }

  WorktreeEventsCompanion toCompanion(bool nullToAbsent) {
    return WorktreeEventsCompanion(
      id: Value(id),
      at: Value(at),
      type: Value(type),
      repoPath: Value(repoPath),
      repoName: Value(repoName),
      worktreePath: Value(worktreePath),
      worktreeName: Value(worktreeName),
      branch: branch == null && nullToAbsent
          ? const Value.absent()
          : Value(branch),
      jiraIssue: jiraIssue == null && nullToAbsent
          ? const Value.absent()
          : Value(jiraIssue),
    );
  }

  factory WorktreeEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorktreeEventRow(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      type: serializer.fromJson<String>(json['type']),
      repoPath: serializer.fromJson<String>(json['repoPath']),
      repoName: serializer.fromJson<String>(json['repoName']),
      worktreePath: serializer.fromJson<String>(json['worktreePath']),
      worktreeName: serializer.fromJson<String>(json['worktreeName']),
      branch: serializer.fromJson<String?>(json['branch']),
      jiraIssue: serializer.fromJson<String?>(json['jiraIssue']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'type': serializer.toJson<String>(type),
      'repoPath': serializer.toJson<String>(repoPath),
      'repoName': serializer.toJson<String>(repoName),
      'worktreePath': serializer.toJson<String>(worktreePath),
      'worktreeName': serializer.toJson<String>(worktreeName),
      'branch': serializer.toJson<String?>(branch),
      'jiraIssue': serializer.toJson<String?>(jiraIssue),
    };
  }

  WorktreeEventRow copyWith({
    int? id,
    DateTime? at,
    String? type,
    String? repoPath,
    String? repoName,
    String? worktreePath,
    String? worktreeName,
    Value<String?> branch = const Value.absent(),
    Value<String?> jiraIssue = const Value.absent(),
  }) => WorktreeEventRow(
    id: id ?? this.id,
    at: at ?? this.at,
    type: type ?? this.type,
    repoPath: repoPath ?? this.repoPath,
    repoName: repoName ?? this.repoName,
    worktreePath: worktreePath ?? this.worktreePath,
    worktreeName: worktreeName ?? this.worktreeName,
    branch: branch.present ? branch.value : this.branch,
    jiraIssue: jiraIssue.present ? jiraIssue.value : this.jiraIssue,
  );
  WorktreeEventRow copyWithCompanion(WorktreeEventsCompanion data) {
    return WorktreeEventRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      type: data.type.present ? data.type.value : this.type,
      repoPath: data.repoPath.present ? data.repoPath.value : this.repoPath,
      repoName: data.repoName.present ? data.repoName.value : this.repoName,
      worktreePath: data.worktreePath.present
          ? data.worktreePath.value
          : this.worktreePath,
      worktreeName: data.worktreeName.present
          ? data.worktreeName.value
          : this.worktreeName,
      branch: data.branch.present ? data.branch.value : this.branch,
      jiraIssue: data.jiraIssue.present ? data.jiraIssue.value : this.jiraIssue,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorktreeEventRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('type: $type, ')
          ..write('repoPath: $repoPath, ')
          ..write('repoName: $repoName, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('worktreeName: $worktreeName, ')
          ..write('branch: $branch, ')
          ..write('jiraIssue: $jiraIssue')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    at,
    type,
    repoPath,
    repoName,
    worktreePath,
    worktreeName,
    branch,
    jiraIssue,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorktreeEventRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.type == this.type &&
          other.repoPath == this.repoPath &&
          other.repoName == this.repoName &&
          other.worktreePath == this.worktreePath &&
          other.worktreeName == this.worktreeName &&
          other.branch == this.branch &&
          other.jiraIssue == this.jiraIssue);
}

class WorktreeEventsCompanion extends UpdateCompanion<WorktreeEventRow> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<String> type;
  final Value<String> repoPath;
  final Value<String> repoName;
  final Value<String> worktreePath;
  final Value<String> worktreeName;
  final Value<String?> branch;
  final Value<String?> jiraIssue;
  const WorktreeEventsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.type = const Value.absent(),
    this.repoPath = const Value.absent(),
    this.repoName = const Value.absent(),
    this.worktreePath = const Value.absent(),
    this.worktreeName = const Value.absent(),
    this.branch = const Value.absent(),
    this.jiraIssue = const Value.absent(),
  });
  WorktreeEventsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    required String type,
    required String repoPath,
    required String repoName,
    required String worktreePath,
    required String worktreeName,
    this.branch = const Value.absent(),
    this.jiraIssue = const Value.absent(),
  }) : at = Value(at),
       type = Value(type),
       repoPath = Value(repoPath),
       repoName = Value(repoName),
       worktreePath = Value(worktreePath),
       worktreeName = Value(worktreeName);
  static Insertable<WorktreeEventRow> custom({
    Expression<int>? id,
    Expression<String>? at,
    Expression<String>? type,
    Expression<String>? repoPath,
    Expression<String>? repoName,
    Expression<String>? worktreePath,
    Expression<String>? worktreeName,
    Expression<String>? branch,
    Expression<String>? jiraIssue,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (type != null) 'type': type,
      if (repoPath != null) 'repo_path': repoPath,
      if (repoName != null) 'repo_name': repoName,
      if (worktreePath != null) 'worktree_path': worktreePath,
      if (worktreeName != null) 'worktree_name': worktreeName,
      if (branch != null) 'branch': branch,
      if (jiraIssue != null) 'jira_issue': jiraIssue,
    });
  }

  WorktreeEventsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<String>? type,
    Value<String>? repoPath,
    Value<String>? repoName,
    Value<String>? worktreePath,
    Value<String>? worktreeName,
    Value<String?>? branch,
    Value<String?>? jiraIssue,
  }) {
    return WorktreeEventsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      type: type ?? this.type,
      repoPath: repoPath ?? this.repoPath,
      repoName: repoName ?? this.repoName,
      worktreePath: worktreePath ?? this.worktreePath,
      worktreeName: worktreeName ?? this.worktreeName,
      branch: branch ?? this.branch,
      jiraIssue: jiraIssue ?? this.jiraIssue,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(
        $WorktreeEventsTable.$converterat.toSql(at.value),
      );
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (repoPath.present) {
      map['repo_path'] = Variable<String>(repoPath.value);
    }
    if (repoName.present) {
      map['repo_name'] = Variable<String>(repoName.value);
    }
    if (worktreePath.present) {
      map['worktree_path'] = Variable<String>(worktreePath.value);
    }
    if (worktreeName.present) {
      map['worktree_name'] = Variable<String>(worktreeName.value);
    }
    if (branch.present) {
      map['branch'] = Variable<String>(branch.value);
    }
    if (jiraIssue.present) {
      map['jira_issue'] = Variable<String>(jiraIssue.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorktreeEventsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('type: $type, ')
          ..write('repoPath: $repoPath, ')
          ..write('repoName: $repoName, ')
          ..write('worktreePath: $worktreePath, ')
          ..write('worktreeName: $worktreeName, ')
          ..write('branch: $branch, ')
          ..write('jiraIssue: $jiraIssue')
          ..write(')'))
        .toString();
  }
}

class $ManualPostsTable extends ManualPosts
    with TableInfo<$ManualPostsTable, ManualPostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ManualPostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> at =
      GeneratedColumn<String>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ManualPostsTable.$converterat);
  static const VerificationMeta _repoNameMeta = const VerificationMeta(
    'repoName',
  );
  @override
  late final GeneratedColumn<String> repoName = GeneratedColumn<String>(
    'repo_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _issueKeyMeta = const VerificationMeta(
    'issueKey',
  );
  @override
  late final GeneratedColumn<String> issueKey = GeneratedColumn<String>(
    'issue_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hoursMeta = const VerificationMeta('hours');
  @override
  late final GeneratedColumn<double> hours = GeneratedColumn<double>(
    'hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    repoName,
    issueKey,
    description,
    hours,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'manual_posts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ManualPostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('repo_name')) {
      context.handle(
        _repoNameMeta,
        repoName.isAcceptableOrUnknown(data['repo_name']!, _repoNameMeta),
      );
    } else if (isInserting) {
      context.missing(_repoNameMeta);
    }
    if (data.containsKey('issue_key')) {
      context.handle(
        _issueKeyMeta,
        issueKey.isAcceptableOrUnknown(data['issue_key']!, _issueKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_issueKeyMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('hours')) {
      context.handle(
        _hoursMeta,
        hours.isAcceptableOrUnknown(data['hours']!, _hoursMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ManualPostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ManualPostRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      at: $ManualPostsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}at'],
        )!,
      ),
      repoName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_name'],
      )!,
      issueKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue_key'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      hours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hours'],
      ),
    );
  }

  @override
  $ManualPostsTable createAlias(String alias) {
    return $ManualPostsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterat = const IsoDateTime();
}

class ManualPostRow extends DataClass implements Insertable<ManualPostRow> {
  final String id;
  final DateTime at;
  final String repoName;
  final String issueKey;
  final String description;
  final double? hours;
  const ManualPostRow({
    required this.id,
    required this.at,
    required this.repoName,
    required this.issueKey,
    required this.description,
    this.hours,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['at'] = Variable<String>($ManualPostsTable.$converterat.toSql(at));
    }
    map['repo_name'] = Variable<String>(repoName);
    map['issue_key'] = Variable<String>(issueKey);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || hours != null) {
      map['hours'] = Variable<double>(hours);
    }
    return map;
  }

  ManualPostsCompanion toCompanion(bool nullToAbsent) {
    return ManualPostsCompanion(
      id: Value(id),
      at: Value(at),
      repoName: Value(repoName),
      issueKey: Value(issueKey),
      description: Value(description),
      hours: hours == null && nullToAbsent
          ? const Value.absent()
          : Value(hours),
    );
  }

  factory ManualPostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ManualPostRow(
      id: serializer.fromJson<String>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      repoName: serializer.fromJson<String>(json['repoName']),
      issueKey: serializer.fromJson<String>(json['issueKey']),
      description: serializer.fromJson<String>(json['description']),
      hours: serializer.fromJson<double?>(json['hours']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'at': serializer.toJson<DateTime>(at),
      'repoName': serializer.toJson<String>(repoName),
      'issueKey': serializer.toJson<String>(issueKey),
      'description': serializer.toJson<String>(description),
      'hours': serializer.toJson<double?>(hours),
    };
  }

  ManualPostRow copyWith({
    String? id,
    DateTime? at,
    String? repoName,
    String? issueKey,
    String? description,
    Value<double?> hours = const Value.absent(),
  }) => ManualPostRow(
    id: id ?? this.id,
    at: at ?? this.at,
    repoName: repoName ?? this.repoName,
    issueKey: issueKey ?? this.issueKey,
    description: description ?? this.description,
    hours: hours.present ? hours.value : this.hours,
  );
  ManualPostRow copyWithCompanion(ManualPostsCompanion data) {
    return ManualPostRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      repoName: data.repoName.present ? data.repoName.value : this.repoName,
      issueKey: data.issueKey.present ? data.issueKey.value : this.issueKey,
      description: data.description.present
          ? data.description.value
          : this.description,
      hours: data.hours.present ? data.hours.value : this.hours,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ManualPostRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('repoName: $repoName, ')
          ..write('issueKey: $issueKey, ')
          ..write('description: $description, ')
          ..write('hours: $hours')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, at, repoName, issueKey, description, hours);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ManualPostRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.repoName == this.repoName &&
          other.issueKey == this.issueKey &&
          other.description == this.description &&
          other.hours == this.hours);
}

class ManualPostsCompanion extends UpdateCompanion<ManualPostRow> {
  final Value<String> id;
  final Value<DateTime> at;
  final Value<String> repoName;
  final Value<String> issueKey;
  final Value<String> description;
  final Value<double?> hours;
  final Value<int> rowid;
  const ManualPostsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.repoName = const Value.absent(),
    this.issueKey = const Value.absent(),
    this.description = const Value.absent(),
    this.hours = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ManualPostsCompanion.insert({
    required String id,
    required DateTime at,
    required String repoName,
    required String issueKey,
    required String description,
    this.hours = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       at = Value(at),
       repoName = Value(repoName),
       issueKey = Value(issueKey),
       description = Value(description);
  static Insertable<ManualPostRow> custom({
    Expression<String>? id,
    Expression<String>? at,
    Expression<String>? repoName,
    Expression<String>? issueKey,
    Expression<String>? description,
    Expression<double>? hours,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (repoName != null) 'repo_name': repoName,
      if (issueKey != null) 'issue_key': issueKey,
      if (description != null) 'description': description,
      if (hours != null) 'hours': hours,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ManualPostsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? at,
    Value<String>? repoName,
    Value<String>? issueKey,
    Value<String>? description,
    Value<double?>? hours,
    Value<int>? rowid,
  }) {
    return ManualPostsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      repoName: repoName ?? this.repoName,
      issueKey: issueKey ?? this.issueKey,
      description: description ?? this.description,
      hours: hours ?? this.hours,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(
        $ManualPostsTable.$converterat.toSql(at.value),
      );
    }
    if (repoName.present) {
      map['repo_name'] = Variable<String>(repoName.value);
    }
    if (issueKey.present) {
      map['issue_key'] = Variable<String>(issueKey.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (hours.present) {
      map['hours'] = Variable<double>(hours.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ManualPostsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('repoName: $repoName, ')
          ..write('issueKey: $issueKey, ')
          ..write('description: $description, ')
          ..write('hours: $hours, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IssueCacheTable extends IssueCache
    with TableInfo<$IssueCacheTable, IssueCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IssueCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, String> fetchedAt =
      GeneratedColumn<String>(
        'fetched_at',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($IssueCacheTable.$converterfetchedAt);
  @override
  List<GeneratedColumn> get $columns => [source, key, payload, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'issue_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<IssueCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {source, key};
  @override
  IssueCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IssueCacheRow(
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: $IssueCacheTable.$converterfetchedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}fetched_at'],
        )!,
      ),
    );
  }

  @override
  $IssueCacheTable createAlias(String alias) {
    return $IssueCacheTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $converterfetchedAt =
      const IsoDateTime();
}

class IssueCacheRow extends DataClass implements Insertable<IssueCacheRow> {
  final String source;
  final String key;
  final String payload;
  final DateTime fetchedAt;
  const IssueCacheRow({
    required this.source,
    required this.key,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source'] = Variable<String>(source);
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    {
      map['fetched_at'] = Variable<String>(
        $IssueCacheTable.$converterfetchedAt.toSql(fetchedAt),
      );
    }
    return map;
  }

  IssueCacheCompanion toCompanion(bool nullToAbsent) {
    return IssueCacheCompanion(
      source: Value(source),
      key: Value(key),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory IssueCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IssueCacheRow(
      source: serializer.fromJson<String>(json['source']),
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'source': serializer.toJson<String>(source),
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  IssueCacheRow copyWith({
    String? source,
    String? key,
    String? payload,
    DateTime? fetchedAt,
  }) => IssueCacheRow(
    source: source ?? this.source,
    key: key ?? this.key,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  IssueCacheRow copyWithCompanion(IssueCacheCompanion data) {
    return IssueCacheRow(
      source: data.source.present ? data.source.value : this.source,
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IssueCacheRow(')
          ..write('source: $source, ')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(source, key, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IssueCacheRow &&
          other.source == this.source &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class IssueCacheCompanion extends UpdateCompanion<IssueCacheRow> {
  final Value<String> source;
  final Value<String> key;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const IssueCacheCompanion({
    this.source = const Value.absent(),
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IssueCacheCompanion.insert({
    required String source,
    required String key,
    required String payload,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : source = Value(source),
       key = Value(key),
       payload = Value(payload),
       fetchedAt = Value(fetchedAt);
  static Insertable<IssueCacheRow> custom({
    Expression<String>? source,
    Expression<String>? key,
    Expression<String>? payload,
    Expression<String>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (source != null) 'source': source,
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IssueCacheCompanion copyWith({
    Value<String>? source,
    Value<String>? key,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return IssueCacheCompanion(
      source: source ?? this.source,
      key: key ?? this.key,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<String>(
        $IssueCacheTable.$converterfetchedAt.toSql(fetchedAt.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IssueCacheCompanion(')
          ..write('source: $source, ')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaudeTranscriptsTable extends ClaudeTranscripts
    with TableInfo<$ClaudeTranscriptsTable, ClaudeTranscriptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaudeTranscriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectDirMeta = const VerificationMeta(
    'projectDir',
  );
  @override
  late final GeneratedColumn<String> projectDir = GeneratedColumn<String>(
    'project_dir',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMeta = const VerificationMeta('mtime');
  @override
  late final GeneratedColumn<int> mtime = GeneratedColumn<int>(
    'mtime',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedBytesMeta = const VerificationMeta(
    'scannedBytes',
  );
  @override
  late final GeneratedColumn<int> scannedBytes = GeneratedColumn<int>(
    'scanned_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activeDaysMeta = const VerificationMeta(
    'activeDays',
  );
  @override
  late final GeneratedColumn<String> activeDays = GeneratedColumn<String>(
    'active_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    projectDir,
    size,
    mtime,
    scannedBytes,
    activeDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claude_transcripts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClaudeTranscriptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('project_dir')) {
      context.handle(
        _projectDirMeta,
        projectDir.isAcceptableOrUnknown(data['project_dir']!, _projectDirMeta),
      );
    } else if (isInserting) {
      context.missing(_projectDirMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('mtime')) {
      context.handle(
        _mtimeMeta,
        mtime.isAcceptableOrUnknown(data['mtime']!, _mtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMeta);
    }
    if (data.containsKey('scanned_bytes')) {
      context.handle(
        _scannedBytesMeta,
        scannedBytes.isAcceptableOrUnknown(
          data['scanned_bytes']!,
          _scannedBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scannedBytesMeta);
    }
    if (data.containsKey('active_days')) {
      context.handle(
        _activeDaysMeta,
        activeDays.isAcceptableOrUnknown(data['active_days']!, _activeDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_activeDaysMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  ClaudeTranscriptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClaudeTranscriptRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      projectDir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_dir'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mtime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime'],
      )!,
      scannedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scanned_bytes'],
      )!,
      activeDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_days'],
      )!,
    );
  }

  @override
  $ClaudeTranscriptsTable createAlias(String alias) {
    return $ClaudeTranscriptsTable(attachedDatabase, alias);
  }
}

class ClaudeTranscriptRow extends DataClass
    implements Insertable<ClaudeTranscriptRow> {
  final String path;
  final String projectDir;
  final int size;

  /// Microseconds since the epoch.
  final int mtime;

  /// Where the last complete line read ends; the file is append-only, so a
  /// grown file is read from here.
  final int scannedBytes;

  /// JSON list of local calendar days (`2026-10-19`) with activity.
  final String activeDays;
  const ClaudeTranscriptRow({
    required this.path,
    required this.projectDir,
    required this.size,
    required this.mtime,
    required this.scannedBytes,
    required this.activeDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['project_dir'] = Variable<String>(projectDir);
    map['size'] = Variable<int>(size);
    map['mtime'] = Variable<int>(mtime);
    map['scanned_bytes'] = Variable<int>(scannedBytes);
    map['active_days'] = Variable<String>(activeDays);
    return map;
  }

  ClaudeTranscriptsCompanion toCompanion(bool nullToAbsent) {
    return ClaudeTranscriptsCompanion(
      path: Value(path),
      projectDir: Value(projectDir),
      size: Value(size),
      mtime: Value(mtime),
      scannedBytes: Value(scannedBytes),
      activeDays: Value(activeDays),
    );
  }

  factory ClaudeTranscriptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClaudeTranscriptRow(
      path: serializer.fromJson<String>(json['path']),
      projectDir: serializer.fromJson<String>(json['projectDir']),
      size: serializer.fromJson<int>(json['size']),
      mtime: serializer.fromJson<int>(json['mtime']),
      scannedBytes: serializer.fromJson<int>(json['scannedBytes']),
      activeDays: serializer.fromJson<String>(json['activeDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'projectDir': serializer.toJson<String>(projectDir),
      'size': serializer.toJson<int>(size),
      'mtime': serializer.toJson<int>(mtime),
      'scannedBytes': serializer.toJson<int>(scannedBytes),
      'activeDays': serializer.toJson<String>(activeDays),
    };
  }

  ClaudeTranscriptRow copyWith({
    String? path,
    String? projectDir,
    int? size,
    int? mtime,
    int? scannedBytes,
    String? activeDays,
  }) => ClaudeTranscriptRow(
    path: path ?? this.path,
    projectDir: projectDir ?? this.projectDir,
    size: size ?? this.size,
    mtime: mtime ?? this.mtime,
    scannedBytes: scannedBytes ?? this.scannedBytes,
    activeDays: activeDays ?? this.activeDays,
  );
  ClaudeTranscriptRow copyWithCompanion(ClaudeTranscriptsCompanion data) {
    return ClaudeTranscriptRow(
      path: data.path.present ? data.path.value : this.path,
      projectDir: data.projectDir.present
          ? data.projectDir.value
          : this.projectDir,
      size: data.size.present ? data.size.value : this.size,
      mtime: data.mtime.present ? data.mtime.value : this.mtime,
      scannedBytes: data.scannedBytes.present
          ? data.scannedBytes.value
          : this.scannedBytes,
      activeDays: data.activeDays.present
          ? data.activeDays.value
          : this.activeDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaudeTranscriptRow(')
          ..write('path: $path, ')
          ..write('projectDir: $projectDir, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('scannedBytes: $scannedBytes, ')
          ..write('activeDays: $activeDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(path, projectDir, size, mtime, scannedBytes, activeDays);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaudeTranscriptRow &&
          other.path == this.path &&
          other.projectDir == this.projectDir &&
          other.size == this.size &&
          other.mtime == this.mtime &&
          other.scannedBytes == this.scannedBytes &&
          other.activeDays == this.activeDays);
}

class ClaudeTranscriptsCompanion extends UpdateCompanion<ClaudeTranscriptRow> {
  final Value<String> path;
  final Value<String> projectDir;
  final Value<int> size;
  final Value<int> mtime;
  final Value<int> scannedBytes;
  final Value<String> activeDays;
  final Value<int> rowid;
  const ClaudeTranscriptsCompanion({
    this.path = const Value.absent(),
    this.projectDir = const Value.absent(),
    this.size = const Value.absent(),
    this.mtime = const Value.absent(),
    this.scannedBytes = const Value.absent(),
    this.activeDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaudeTranscriptsCompanion.insert({
    required String path,
    required String projectDir,
    required int size,
    required int mtime,
    required int scannedBytes,
    required String activeDays,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       projectDir = Value(projectDir),
       size = Value(size),
       mtime = Value(mtime),
       scannedBytes = Value(scannedBytes),
       activeDays = Value(activeDays);
  static Insertable<ClaudeTranscriptRow> custom({
    Expression<String>? path,
    Expression<String>? projectDir,
    Expression<int>? size,
    Expression<int>? mtime,
    Expression<int>? scannedBytes,
    Expression<String>? activeDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (projectDir != null) 'project_dir': projectDir,
      if (size != null) 'size': size,
      if (mtime != null) 'mtime': mtime,
      if (scannedBytes != null) 'scanned_bytes': scannedBytes,
      if (activeDays != null) 'active_days': activeDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaudeTranscriptsCompanion copyWith({
    Value<String>? path,
    Value<String>? projectDir,
    Value<int>? size,
    Value<int>? mtime,
    Value<int>? scannedBytes,
    Value<String>? activeDays,
    Value<int>? rowid,
  }) {
    return ClaudeTranscriptsCompanion(
      path: path ?? this.path,
      projectDir: projectDir ?? this.projectDir,
      size: size ?? this.size,
      mtime: mtime ?? this.mtime,
      scannedBytes: scannedBytes ?? this.scannedBytes,
      activeDays: activeDays ?? this.activeDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (projectDir.present) {
      map['project_dir'] = Variable<String>(projectDir.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtime.present) {
      map['mtime'] = Variable<int>(mtime.value);
    }
    if (scannedBytes.present) {
      map['scanned_bytes'] = Variable<int>(scannedBytes.value);
    }
    if (activeDays.present) {
      map['active_days'] = Variable<String>(activeDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClaudeTranscriptsCompanion(')
          ..write('path: $path, ')
          ..write('projectDir: $projectDir, ')
          ..write('size: $size, ')
          ..write('mtime: $mtime, ')
          ..write('scannedBytes: $scannedBytes, ')
          ..write('activeDays: $activeDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorktreeMetaTable extends WorktreeMeta
    with TableInfo<$WorktreeMetaTable, WorktreeMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorktreeMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repoPathMeta = const VerificationMeta(
    'repoPath',
  );
  @override
  late final GeneratedColumn<String> repoPath = GeneratedColumn<String>(
    'repo_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseBranchMeta = const VerificationMeta(
    'baseBranch',
  );
  @override
  late final GeneratedColumn<String> baseBranch = GeneratedColumn<String>(
    'base_branch',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _jiraIssueMeta = const VerificationMeta(
    'jiraIssue',
  );
  @override
  late final GeneratedColumn<String> jiraIssue = GeneratedColumn<String>(
    'jira_issue',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _githubIssueMeta = const VerificationMeta(
    'githubIssue',
  );
  @override
  late final GeneratedColumn<int> githubIssue = GeneratedColumn<int>(
    'github_issue',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prAuthorMeta = const VerificationMeta(
    'prAuthor',
  );
  @override
  late final GeneratedColumn<String> prAuthor = GeneratedColumn<String>(
    'pr_author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kickoffPromptPathMeta = const VerificationMeta(
    'kickoffPromptPath',
  );
  @override
  late final GeneratedColumn<String> kickoffPromptPath =
      GeneratedColumn<String>(
        'kickoff_prompt_path',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _snoozedMeta = const VerificationMeta(
    'snoozed',
  );
  @override
  late final GeneratedColumn<bool> snoozed = GeneratedColumn<bool>(
    'snoozed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("snoozed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hasSessionMeta = const VerificationMeta(
    'hasSession',
  );
  @override
  late final GeneratedColumn<bool> hasSession = GeneratedColumn<bool>(
    'has_session',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_session" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sessionPromptMeta = const VerificationMeta(
    'sessionPrompt',
  );
  @override
  late final GeneratedColumn<String> sessionPrompt = GeneratedColumn<String>(
    'session_prompt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, String>
  sessionStartedAt = GeneratedColumn<String>(
    'session_started_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($WorktreeMetaTable.$convertersessionStartedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    path,
    repoPath,
    baseBranch,
    jiraIssue,
    githubIssue,
    prAuthor,
    kickoffPromptPath,
    hidden,
    snoozed,
    hasSession,
    sessionPrompt,
    sessionStartedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'worktree_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorktreeMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('repo_path')) {
      context.handle(
        _repoPathMeta,
        repoPath.isAcceptableOrUnknown(data['repo_path']!, _repoPathMeta),
      );
    } else if (isInserting) {
      context.missing(_repoPathMeta);
    }
    if (data.containsKey('base_branch')) {
      context.handle(
        _baseBranchMeta,
        baseBranch.isAcceptableOrUnknown(data['base_branch']!, _baseBranchMeta),
      );
    }
    if (data.containsKey('jira_issue')) {
      context.handle(
        _jiraIssueMeta,
        jiraIssue.isAcceptableOrUnknown(data['jira_issue']!, _jiraIssueMeta),
      );
    }
    if (data.containsKey('github_issue')) {
      context.handle(
        _githubIssueMeta,
        githubIssue.isAcceptableOrUnknown(
          data['github_issue']!,
          _githubIssueMeta,
        ),
      );
    }
    if (data.containsKey('pr_author')) {
      context.handle(
        _prAuthorMeta,
        prAuthor.isAcceptableOrUnknown(data['pr_author']!, _prAuthorMeta),
      );
    }
    if (data.containsKey('kickoff_prompt_path')) {
      context.handle(
        _kickoffPromptPathMeta,
        kickoffPromptPath.isAcceptableOrUnknown(
          data['kickoff_prompt_path']!,
          _kickoffPromptPathMeta,
        ),
      );
    }
    if (data.containsKey('hidden')) {
      context.handle(
        _hiddenMeta,
        hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta),
      );
    }
    if (data.containsKey('snoozed')) {
      context.handle(
        _snoozedMeta,
        snoozed.isAcceptableOrUnknown(data['snoozed']!, _snoozedMeta),
      );
    }
    if (data.containsKey('has_session')) {
      context.handle(
        _hasSessionMeta,
        hasSession.isAcceptableOrUnknown(data['has_session']!, _hasSessionMeta),
      );
    }
    if (data.containsKey('session_prompt')) {
      context.handle(
        _sessionPromptMeta,
        sessionPrompt.isAcceptableOrUnknown(
          data['session_prompt']!,
          _sessionPromptMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  WorktreeMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorktreeMetaRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      repoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repo_path'],
      )!,
      baseBranch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_branch'],
      ),
      jiraIssue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}jira_issue'],
      ),
      githubIssue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}github_issue'],
      ),
      prAuthor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pr_author'],
      ),
      kickoffPromptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kickoff_prompt_path'],
      ),
      hidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hidden'],
      )!,
      snoozed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}snoozed'],
      )!,
      hasSession: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_session'],
      )!,
      sessionPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_prompt'],
      ),
      sessionStartedAt: $WorktreeMetaTable.$convertersessionStartedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}session_started_at'],
        ),
      ),
    );
  }

  @override
  $WorktreeMetaTable createAlias(String alias) {
    return $WorktreeMetaTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, String> $convertersessionStartedAt =
      const IsoDateTime();
  static TypeConverter<DateTime?, String?> $convertersessionStartedAtn =
      NullAwareTypeConverter.wrap($convertersessionStartedAt);
}

class WorktreeMetaRow extends DataClass implements Insertable<WorktreeMetaRow> {
  final String path;
  final String repoPath;
  final String? baseBranch;
  final String? jiraIssue;
  final int? githubIssue;
  final String? prAuthor;
  final String? kickoffPromptPath;
  final bool hidden;
  final bool snoozed;

  /// Whether a Claude session is remembered here.
  final bool hasSession;

  /// The prompt the session was started with: a saved prompt's name or a
  /// built-in prompt id.
  final String? sessionPrompt;

  /// When the session was first started; null for ones remembered before
  /// start times were kept.
  final DateTime? sessionStartedAt;
  const WorktreeMetaRow({
    required this.path,
    required this.repoPath,
    this.baseBranch,
    this.jiraIssue,
    this.githubIssue,
    this.prAuthor,
    this.kickoffPromptPath,
    required this.hidden,
    required this.snoozed,
    required this.hasSession,
    this.sessionPrompt,
    this.sessionStartedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['repo_path'] = Variable<String>(repoPath);
    if (!nullToAbsent || baseBranch != null) {
      map['base_branch'] = Variable<String>(baseBranch);
    }
    if (!nullToAbsent || jiraIssue != null) {
      map['jira_issue'] = Variable<String>(jiraIssue);
    }
    if (!nullToAbsent || githubIssue != null) {
      map['github_issue'] = Variable<int>(githubIssue);
    }
    if (!nullToAbsent || prAuthor != null) {
      map['pr_author'] = Variable<String>(prAuthor);
    }
    if (!nullToAbsent || kickoffPromptPath != null) {
      map['kickoff_prompt_path'] = Variable<String>(kickoffPromptPath);
    }
    map['hidden'] = Variable<bool>(hidden);
    map['snoozed'] = Variable<bool>(snoozed);
    map['has_session'] = Variable<bool>(hasSession);
    if (!nullToAbsent || sessionPrompt != null) {
      map['session_prompt'] = Variable<String>(sessionPrompt);
    }
    if (!nullToAbsent || sessionStartedAt != null) {
      map['session_started_at'] = Variable<String>(
        $WorktreeMetaTable.$convertersessionStartedAtn.toSql(sessionStartedAt),
      );
    }
    return map;
  }

  WorktreeMetaCompanion toCompanion(bool nullToAbsent) {
    return WorktreeMetaCompanion(
      path: Value(path),
      repoPath: Value(repoPath),
      baseBranch: baseBranch == null && nullToAbsent
          ? const Value.absent()
          : Value(baseBranch),
      jiraIssue: jiraIssue == null && nullToAbsent
          ? const Value.absent()
          : Value(jiraIssue),
      githubIssue: githubIssue == null && nullToAbsent
          ? const Value.absent()
          : Value(githubIssue),
      prAuthor: prAuthor == null && nullToAbsent
          ? const Value.absent()
          : Value(prAuthor),
      kickoffPromptPath: kickoffPromptPath == null && nullToAbsent
          ? const Value.absent()
          : Value(kickoffPromptPath),
      hidden: Value(hidden),
      snoozed: Value(snoozed),
      hasSession: Value(hasSession),
      sessionPrompt: sessionPrompt == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionPrompt),
      sessionStartedAt: sessionStartedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionStartedAt),
    );
  }

  factory WorktreeMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorktreeMetaRow(
      path: serializer.fromJson<String>(json['path']),
      repoPath: serializer.fromJson<String>(json['repoPath']),
      baseBranch: serializer.fromJson<String?>(json['baseBranch']),
      jiraIssue: serializer.fromJson<String?>(json['jiraIssue']),
      githubIssue: serializer.fromJson<int?>(json['githubIssue']),
      prAuthor: serializer.fromJson<String?>(json['prAuthor']),
      kickoffPromptPath: serializer.fromJson<String?>(
        json['kickoffPromptPath'],
      ),
      hidden: serializer.fromJson<bool>(json['hidden']),
      snoozed: serializer.fromJson<bool>(json['snoozed']),
      hasSession: serializer.fromJson<bool>(json['hasSession']),
      sessionPrompt: serializer.fromJson<String?>(json['sessionPrompt']),
      sessionStartedAt: serializer.fromJson<DateTime?>(
        json['sessionStartedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'repoPath': serializer.toJson<String>(repoPath),
      'baseBranch': serializer.toJson<String?>(baseBranch),
      'jiraIssue': serializer.toJson<String?>(jiraIssue),
      'githubIssue': serializer.toJson<int?>(githubIssue),
      'prAuthor': serializer.toJson<String?>(prAuthor),
      'kickoffPromptPath': serializer.toJson<String?>(kickoffPromptPath),
      'hidden': serializer.toJson<bool>(hidden),
      'snoozed': serializer.toJson<bool>(snoozed),
      'hasSession': serializer.toJson<bool>(hasSession),
      'sessionPrompt': serializer.toJson<String?>(sessionPrompt),
      'sessionStartedAt': serializer.toJson<DateTime?>(sessionStartedAt),
    };
  }

  WorktreeMetaRow copyWith({
    String? path,
    String? repoPath,
    Value<String?> baseBranch = const Value.absent(),
    Value<String?> jiraIssue = const Value.absent(),
    Value<int?> githubIssue = const Value.absent(),
    Value<String?> prAuthor = const Value.absent(),
    Value<String?> kickoffPromptPath = const Value.absent(),
    bool? hidden,
    bool? snoozed,
    bool? hasSession,
    Value<String?> sessionPrompt = const Value.absent(),
    Value<DateTime?> sessionStartedAt = const Value.absent(),
  }) => WorktreeMetaRow(
    path: path ?? this.path,
    repoPath: repoPath ?? this.repoPath,
    baseBranch: baseBranch.present ? baseBranch.value : this.baseBranch,
    jiraIssue: jiraIssue.present ? jiraIssue.value : this.jiraIssue,
    githubIssue: githubIssue.present ? githubIssue.value : this.githubIssue,
    prAuthor: prAuthor.present ? prAuthor.value : this.prAuthor,
    kickoffPromptPath: kickoffPromptPath.present
        ? kickoffPromptPath.value
        : this.kickoffPromptPath,
    hidden: hidden ?? this.hidden,
    snoozed: snoozed ?? this.snoozed,
    hasSession: hasSession ?? this.hasSession,
    sessionPrompt: sessionPrompt.present
        ? sessionPrompt.value
        : this.sessionPrompt,
    sessionStartedAt: sessionStartedAt.present
        ? sessionStartedAt.value
        : this.sessionStartedAt,
  );
  WorktreeMetaRow copyWithCompanion(WorktreeMetaCompanion data) {
    return WorktreeMetaRow(
      path: data.path.present ? data.path.value : this.path,
      repoPath: data.repoPath.present ? data.repoPath.value : this.repoPath,
      baseBranch: data.baseBranch.present
          ? data.baseBranch.value
          : this.baseBranch,
      jiraIssue: data.jiraIssue.present ? data.jiraIssue.value : this.jiraIssue,
      githubIssue: data.githubIssue.present
          ? data.githubIssue.value
          : this.githubIssue,
      prAuthor: data.prAuthor.present ? data.prAuthor.value : this.prAuthor,
      kickoffPromptPath: data.kickoffPromptPath.present
          ? data.kickoffPromptPath.value
          : this.kickoffPromptPath,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      snoozed: data.snoozed.present ? data.snoozed.value : this.snoozed,
      hasSession: data.hasSession.present
          ? data.hasSession.value
          : this.hasSession,
      sessionPrompt: data.sessionPrompt.present
          ? data.sessionPrompt.value
          : this.sessionPrompt,
      sessionStartedAt: data.sessionStartedAt.present
          ? data.sessionStartedAt.value
          : this.sessionStartedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorktreeMetaRow(')
          ..write('path: $path, ')
          ..write('repoPath: $repoPath, ')
          ..write('baseBranch: $baseBranch, ')
          ..write('jiraIssue: $jiraIssue, ')
          ..write('githubIssue: $githubIssue, ')
          ..write('prAuthor: $prAuthor, ')
          ..write('kickoffPromptPath: $kickoffPromptPath, ')
          ..write('hidden: $hidden, ')
          ..write('snoozed: $snoozed, ')
          ..write('hasSession: $hasSession, ')
          ..write('sessionPrompt: $sessionPrompt, ')
          ..write('sessionStartedAt: $sessionStartedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    repoPath,
    baseBranch,
    jiraIssue,
    githubIssue,
    prAuthor,
    kickoffPromptPath,
    hidden,
    snoozed,
    hasSession,
    sessionPrompt,
    sessionStartedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorktreeMetaRow &&
          other.path == this.path &&
          other.repoPath == this.repoPath &&
          other.baseBranch == this.baseBranch &&
          other.jiraIssue == this.jiraIssue &&
          other.githubIssue == this.githubIssue &&
          other.prAuthor == this.prAuthor &&
          other.kickoffPromptPath == this.kickoffPromptPath &&
          other.hidden == this.hidden &&
          other.snoozed == this.snoozed &&
          other.hasSession == this.hasSession &&
          other.sessionPrompt == this.sessionPrompt &&
          other.sessionStartedAt == this.sessionStartedAt);
}

class WorktreeMetaCompanion extends UpdateCompanion<WorktreeMetaRow> {
  final Value<String> path;
  final Value<String> repoPath;
  final Value<String?> baseBranch;
  final Value<String?> jiraIssue;
  final Value<int?> githubIssue;
  final Value<String?> prAuthor;
  final Value<String?> kickoffPromptPath;
  final Value<bool> hidden;
  final Value<bool> snoozed;
  final Value<bool> hasSession;
  final Value<String?> sessionPrompt;
  final Value<DateTime?> sessionStartedAt;
  final Value<int> rowid;
  const WorktreeMetaCompanion({
    this.path = const Value.absent(),
    this.repoPath = const Value.absent(),
    this.baseBranch = const Value.absent(),
    this.jiraIssue = const Value.absent(),
    this.githubIssue = const Value.absent(),
    this.prAuthor = const Value.absent(),
    this.kickoffPromptPath = const Value.absent(),
    this.hidden = const Value.absent(),
    this.snoozed = const Value.absent(),
    this.hasSession = const Value.absent(),
    this.sessionPrompt = const Value.absent(),
    this.sessionStartedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorktreeMetaCompanion.insert({
    required String path,
    required String repoPath,
    this.baseBranch = const Value.absent(),
    this.jiraIssue = const Value.absent(),
    this.githubIssue = const Value.absent(),
    this.prAuthor = const Value.absent(),
    this.kickoffPromptPath = const Value.absent(),
    this.hidden = const Value.absent(),
    this.snoozed = const Value.absent(),
    this.hasSession = const Value.absent(),
    this.sessionPrompt = const Value.absent(),
    this.sessionStartedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       repoPath = Value(repoPath);
  static Insertable<WorktreeMetaRow> custom({
    Expression<String>? path,
    Expression<String>? repoPath,
    Expression<String>? baseBranch,
    Expression<String>? jiraIssue,
    Expression<int>? githubIssue,
    Expression<String>? prAuthor,
    Expression<String>? kickoffPromptPath,
    Expression<bool>? hidden,
    Expression<bool>? snoozed,
    Expression<bool>? hasSession,
    Expression<String>? sessionPrompt,
    Expression<String>? sessionStartedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (repoPath != null) 'repo_path': repoPath,
      if (baseBranch != null) 'base_branch': baseBranch,
      if (jiraIssue != null) 'jira_issue': jiraIssue,
      if (githubIssue != null) 'github_issue': githubIssue,
      if (prAuthor != null) 'pr_author': prAuthor,
      if (kickoffPromptPath != null) 'kickoff_prompt_path': kickoffPromptPath,
      if (hidden != null) 'hidden': hidden,
      if (snoozed != null) 'snoozed': snoozed,
      if (hasSession != null) 'has_session': hasSession,
      if (sessionPrompt != null) 'session_prompt': sessionPrompt,
      if (sessionStartedAt != null) 'session_started_at': sessionStartedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorktreeMetaCompanion copyWith({
    Value<String>? path,
    Value<String>? repoPath,
    Value<String?>? baseBranch,
    Value<String?>? jiraIssue,
    Value<int?>? githubIssue,
    Value<String?>? prAuthor,
    Value<String?>? kickoffPromptPath,
    Value<bool>? hidden,
    Value<bool>? snoozed,
    Value<bool>? hasSession,
    Value<String?>? sessionPrompt,
    Value<DateTime?>? sessionStartedAt,
    Value<int>? rowid,
  }) {
    return WorktreeMetaCompanion(
      path: path ?? this.path,
      repoPath: repoPath ?? this.repoPath,
      baseBranch: baseBranch ?? this.baseBranch,
      jiraIssue: jiraIssue ?? this.jiraIssue,
      githubIssue: githubIssue ?? this.githubIssue,
      prAuthor: prAuthor ?? this.prAuthor,
      kickoffPromptPath: kickoffPromptPath ?? this.kickoffPromptPath,
      hidden: hidden ?? this.hidden,
      snoozed: snoozed ?? this.snoozed,
      hasSession: hasSession ?? this.hasSession,
      sessionPrompt: sessionPrompt ?? this.sessionPrompt,
      sessionStartedAt: sessionStartedAt ?? this.sessionStartedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (repoPath.present) {
      map['repo_path'] = Variable<String>(repoPath.value);
    }
    if (baseBranch.present) {
      map['base_branch'] = Variable<String>(baseBranch.value);
    }
    if (jiraIssue.present) {
      map['jira_issue'] = Variable<String>(jiraIssue.value);
    }
    if (githubIssue.present) {
      map['github_issue'] = Variable<int>(githubIssue.value);
    }
    if (prAuthor.present) {
      map['pr_author'] = Variable<String>(prAuthor.value);
    }
    if (kickoffPromptPath.present) {
      map['kickoff_prompt_path'] = Variable<String>(kickoffPromptPath.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (snoozed.present) {
      map['snoozed'] = Variable<bool>(snoozed.value);
    }
    if (hasSession.present) {
      map['has_session'] = Variable<bool>(hasSession.value);
    }
    if (sessionPrompt.present) {
      map['session_prompt'] = Variable<String>(sessionPrompt.value);
    }
    if (sessionStartedAt.present) {
      map['session_started_at'] = Variable<String>(
        $WorktreeMetaTable.$convertersessionStartedAtn.toSql(
          sessionStartedAt.value,
        ),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorktreeMetaCompanion(')
          ..write('path: $path, ')
          ..write('repoPath: $repoPath, ')
          ..write('baseBranch: $baseBranch, ')
          ..write('jiraIssue: $jiraIssue, ')
          ..write('githubIssue: $githubIssue, ')
          ..write('prAuthor: $prAuthor, ')
          ..write('kickoffPromptPath: $kickoffPromptPath, ')
          ..write('hidden: $hidden, ')
          ..write('snoozed: $snoozed, ')
          ..write('hasSession: $hasSession, ')
          ..write('sessionPrompt: $sessionPrompt, ')
          ..write('sessionStartedAt: $sessionStartedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JiraTagsTable extends JiraTags
    with TableInfo<$JiraTagsTable, JiraTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JiraTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jira_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<JiraTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  JiraTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JiraTagRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $JiraTagsTable createAlias(String alias) {
    return $JiraTagsTable(attachedDatabase, alias);
  }
}

class JiraTagRow extends DataClass implements Insertable<JiraTagRow> {
  final String id;
  final String name;
  final String color;
  final int position;
  const JiraTagRow({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['position'] = Variable<int>(position);
    return map;
  }

  JiraTagsCompanion toCompanion(bool nullToAbsent) {
    return JiraTagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      position: Value(position),
    );
  }

  factory JiraTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JiraTagRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'position': serializer.toJson<int>(position),
    };
  }

  JiraTagRow copyWith({
    String? id,
    String? name,
    String? color,
    int? position,
  }) => JiraTagRow(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    position: position ?? this.position,
  );
  JiraTagRow copyWithCompanion(JiraTagsCompanion data) {
    return JiraTagRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JiraTagRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JiraTagRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.position == this.position);
}

class JiraTagsCompanion extends UpdateCompanion<JiraTagRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<int> position;
  final Value<int> rowid;
  const JiraTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JiraTagsCompanion.insert({
    required String id,
    required String name,
    required String color,
    required int position,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color),
       position = Value(position);
  static Insertable<JiraTagRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JiraTagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return JiraTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JiraTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JiraIssueTagsTable extends JiraIssueTags
    with TableInfo<$JiraIssueTagsTable, JiraIssueTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JiraIssueTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _issueKeyMeta = const VerificationMeta(
    'issueKey',
  );
  @override
  late final GeneratedColumn<String> issueKey = GeneratedColumn<String>(
    'issue_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES jira_tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [issueKey, tagId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'jira_issue_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<JiraIssueTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('issue_key')) {
      context.handle(
        _issueKeyMeta,
        issueKey.isAcceptableOrUnknown(data['issue_key']!, _issueKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_issueKeyMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {issueKey, tagId};
  @override
  JiraIssueTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JiraIssueTagRow(
      issueKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}issue_key'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $JiraIssueTagsTable createAlias(String alias) {
    return $JiraIssueTagsTable(attachedDatabase, alias);
  }
}

class JiraIssueTagRow extends DataClass implements Insertable<JiraIssueTagRow> {
  final String issueKey;
  final String tagId;
  final int position;
  const JiraIssueTagRow({
    required this.issueKey,
    required this.tagId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['issue_key'] = Variable<String>(issueKey);
    map['tag_id'] = Variable<String>(tagId);
    map['position'] = Variable<int>(position);
    return map;
  }

  JiraIssueTagsCompanion toCompanion(bool nullToAbsent) {
    return JiraIssueTagsCompanion(
      issueKey: Value(issueKey),
      tagId: Value(tagId),
      position: Value(position),
    );
  }

  factory JiraIssueTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JiraIssueTagRow(
      issueKey: serializer.fromJson<String>(json['issueKey']),
      tagId: serializer.fromJson<String>(json['tagId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'issueKey': serializer.toJson<String>(issueKey),
      'tagId': serializer.toJson<String>(tagId),
      'position': serializer.toJson<int>(position),
    };
  }

  JiraIssueTagRow copyWith({String? issueKey, String? tagId, int? position}) =>
      JiraIssueTagRow(
        issueKey: issueKey ?? this.issueKey,
        tagId: tagId ?? this.tagId,
        position: position ?? this.position,
      );
  JiraIssueTagRow copyWithCompanion(JiraIssueTagsCompanion data) {
    return JiraIssueTagRow(
      issueKey: data.issueKey.present ? data.issueKey.value : this.issueKey,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JiraIssueTagRow(')
          ..write('issueKey: $issueKey, ')
          ..write('tagId: $tagId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(issueKey, tagId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JiraIssueTagRow &&
          other.issueKey == this.issueKey &&
          other.tagId == this.tagId &&
          other.position == this.position);
}

class JiraIssueTagsCompanion extends UpdateCompanion<JiraIssueTagRow> {
  final Value<String> issueKey;
  final Value<String> tagId;
  final Value<int> position;
  final Value<int> rowid;
  const JiraIssueTagsCompanion({
    this.issueKey = const Value.absent(),
    this.tagId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JiraIssueTagsCompanion.insert({
    required String issueKey,
    required String tagId,
    required int position,
    this.rowid = const Value.absent(),
  }) : issueKey = Value(issueKey),
       tagId = Value(tagId),
       position = Value(position);
  static Insertable<JiraIssueTagRow> custom({
    Expression<String>? issueKey,
    Expression<String>? tagId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (issueKey != null) 'issue_key': issueKey,
      if (tagId != null) 'tag_id': tagId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JiraIssueTagsCompanion copyWith({
    Value<String>? issueKey,
    Value<String>? tagId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return JiraIssueTagsCompanion(
      issueKey: issueKey ?? this.issueKey,
      tagId: tagId ?? this.tagId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (issueKey.present) {
      map['issue_key'] = Variable<String>(issueKey.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JiraIssueTagsCompanion(')
          ..write('issueKey: $issueKey, ')
          ..write('tagId: $tagId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UiStateTable extends UiState with TableInfo<$UiStateTable, UiStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UiStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ui_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<UiStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, key};
  @override
  UiStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UiStateRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $UiStateTable createAlias(String alias) {
    return $UiStateTable(attachedDatabase, alias);
  }
}

class UiStateRow extends DataClass implements Insertable<UiStateRow> {
  final String scope;
  final String key;
  final String value;
  const UiStateRow({
    required this.scope,
    required this.key,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  UiStateCompanion toCompanion(bool nullToAbsent) {
    return UiStateCompanion(
      scope: Value(scope),
      key: Value(key),
      value: Value(value),
    );
  }

  factory UiStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UiStateRow(
      scope: serializer.fromJson<String>(json['scope']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  UiStateRow copyWith({String? scope, String? key, String? value}) =>
      UiStateRow(
        scope: scope ?? this.scope,
        key: key ?? this.key,
        value: value ?? this.value,
      );
  UiStateRow copyWithCompanion(UiStateCompanion data) {
    return UiStateRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UiStateRow(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UiStateRow &&
          other.scope == this.scope &&
          other.key == this.key &&
          other.value == this.value);
}

class UiStateCompanion extends UpdateCompanion<UiStateRow> {
  final Value<String> scope;
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const UiStateCompanion({
    this.scope = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UiStateCompanion.insert({
    required String scope,
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       key = Value(key),
       value = Value(value);
  static Insertable<UiStateRow> custom({
    Expression<String>? scope,
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UiStateCompanion copyWith({
    Value<String>? scope,
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return UiStateCompanion(
      scope: scope ?? this.scope,
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UiStateCompanion(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AgentRunsTable agentRuns = $AgentRunsTable(this);
  late final $AgentRunIssuesTable agentRunIssues = $AgentRunIssuesTable(this);
  late final $AgentEventsTable agentEvents = $AgentEventsTable(this);
  late final $WorktreeEventsTable worktreeEvents = $WorktreeEventsTable(this);
  late final $ManualPostsTable manualPosts = $ManualPostsTable(this);
  late final $IssueCacheTable issueCache = $IssueCacheTable(this);
  late final $ClaudeTranscriptsTable claudeTranscripts =
      $ClaudeTranscriptsTable(this);
  late final $WorktreeMetaTable worktreeMeta = $WorktreeMetaTable(this);
  late final $JiraTagsTable jiraTags = $JiraTagsTable(this);
  late final $JiraIssueTagsTable jiraIssueTags = $JiraIssueTagsTable(this);
  late final $UiStateTable uiState = $UiStateTable(this);
  late final Index agentEventsRun = Index(
    'agent_events_run',
    'CREATE INDEX agent_events_run ON agent_events (run_id, id)',
  );
  late final Index worktreeEventsAt = Index(
    'worktree_events_at',
    'CREATE INDEX worktree_events_at ON worktree_events (at)',
  );
  late final Index claudeTranscriptsDir = Index(
    'claude_transcripts_dir',
    'CREATE INDEX claude_transcripts_dir ON claude_transcripts (project_dir)',
  );
  late final Index worktreeMetadataRepo = Index(
    'worktree_metadata_repo',
    'CREATE INDEX worktree_metadata_repo ON worktree_metadata (repo_path)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    agentRuns,
    agentRunIssues,
    agentEvents,
    worktreeEvents,
    manualPosts,
    issueCache,
    claudeTranscripts,
    worktreeMeta,
    jiraTags,
    jiraIssueTags,
    uiState,
    agentEventsRun,
    worktreeEventsAt,
    claudeTranscriptsDir,
    worktreeMetadataRepo,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'agent_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('agent_run_issues', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'agent_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('agent_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'jira_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('jira_issue_tags', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AgentRunsTableCreateCompanionBuilder =
    AgentRunsCompanion Function({
      required String id,
      required String kind,
      required String repo,
      Value<String?> title,
      required String state,
      Value<String?> worktreePath,
      Value<String?> branch,
      Value<int?> prNumber,
      Value<bool> archived,
      required DateTime startedAt,
      required DateTime updatedAt,
      Value<DateTime?> finishedAt,
      required String detail,
      Value<int> rowid,
    });
typedef $$AgentRunsTableUpdateCompanionBuilder =
    AgentRunsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> repo,
      Value<String?> title,
      Value<String> state,
      Value<String?> worktreePath,
      Value<String?> branch,
      Value<int?> prNumber,
      Value<bool> archived,
      Value<DateTime> startedAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> finishedAt,
      Value<String> detail,
      Value<int> rowid,
    });

final class $$AgentRunsTableReferences
    extends BaseReferences<_$AppDatabase, $AgentRunsTable, AgentRunRow> {
  $$AgentRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AgentRunIssuesTable, List<AgentRunIssueRow>>
  _agentRunIssuesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.agentRunIssues,
    aliasName: 'agent_runs__id__agent_run_issues__run_id',
  );

  $$AgentRunIssuesTableProcessedTableManager get agentRunIssuesRefs {
    final manager = $$AgentRunIssuesTableTableManager(
      $_db,
      $_db.agentRunIssues,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_agentRunIssuesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AgentEventsTable, List<AgentEventRow>>
  _agentEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.agentEvents,
    aliasName: 'agent_runs__id__agent_events__run_id',
  );

  $$AgentEventsTableProcessedTableManager get agentEventsRefs {
    final manager = $$AgentEventsTableTableManager(
      $_db,
      $_db.agentEvents,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_agentEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AgentRunsTableFilterComposer
    extends Composer<_$AppDatabase, $AgentRunsTable> {
  $$AgentRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repo => $composableBuilder(
    column: $table.repo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get prNumber => $composableBuilder(
    column: $table.prNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get startedAt =>
      $composableBuilder(
        column: $table.startedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String> get finishedAt =>
      $composableBuilder(
        column: $table.finishedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> agentRunIssuesRefs(
    Expression<bool> Function($$AgentRunIssuesTableFilterComposer f) f,
  ) {
    final $$AgentRunIssuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentRunIssues,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunIssuesTableFilterComposer(
            $db: $db,
            $table: $db.agentRunIssues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> agentEventsRefs(
    Expression<bool> Function($$AgentEventsTableFilterComposer f) f,
  ) {
    final $$AgentEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentEvents,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentEventsTableFilterComposer(
            $db: $db,
            $table: $db.agentEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AgentRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentRunsTable> {
  $$AgentRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repo => $composableBuilder(
    column: $table.repo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get prNumber => $composableBuilder(
    column: $table.prNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AgentRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentRunsTable> {
  $$AgentRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get repo =>
      $composableBuilder(column: $table.repo, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<int> get prNumber =>
      $composableBuilder(column: $table.prNumber, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, String> get finishedAt =>
      $composableBuilder(
        column: $table.finishedAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  Expression<T> agentRunIssuesRefs<T extends Object>(
    Expression<T> Function($$AgentRunIssuesTableAnnotationComposer a) f,
  ) {
    final $$AgentRunIssuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentRunIssues,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunIssuesTableAnnotationComposer(
            $db: $db,
            $table: $db.agentRunIssues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> agentEventsRefs<T extends Object>(
    Expression<T> Function($$AgentEventsTableAnnotationComposer a) f,
  ) {
    final $$AgentEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.agentEvents,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.agentEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AgentRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentRunsTable,
          AgentRunRow,
          $$AgentRunsTableFilterComposer,
          $$AgentRunsTableOrderingComposer,
          $$AgentRunsTableAnnotationComposer,
          $$AgentRunsTableCreateCompanionBuilder,
          $$AgentRunsTableUpdateCompanionBuilder,
          (AgentRunRow, $$AgentRunsTableReferences),
          AgentRunRow,
          PrefetchHooks Function({
            bool agentRunIssuesRefs,
            bool agentEventsRefs,
          })
        > {
  $$AgentRunsTableTableManager(_$AppDatabase db, $AgentRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> repo = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> worktreePath = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<int?> prNumber = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String> detail = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentRunsCompanion(
                id: id,
                kind: kind,
                repo: repo,
                title: title,
                state: state,
                worktreePath: worktreePath,
                branch: branch,
                prNumber: prNumber,
                archived: archived,
                startedAt: startedAt,
                updatedAt: updatedAt,
                finishedAt: finishedAt,
                detail: detail,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required String repo,
                Value<String?> title = const Value.absent(),
                required String state,
                Value<String?> worktreePath = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<int?> prNumber = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required DateTime startedAt,
                required DateTime updatedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                required String detail,
                Value<int> rowid = const Value.absent(),
              }) => AgentRunsCompanion.insert(
                id: id,
                kind: kind,
                repo: repo,
                title: title,
                state: state,
                worktreePath: worktreePath,
                branch: branch,
                prNumber: prNumber,
                archived: archived,
                startedAt: startedAt,
                updatedAt: updatedAt,
                finishedAt: finishedAt,
                detail: detail,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({agentRunIssuesRefs = false, agentEventsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (agentRunIssuesRefs) db.agentRunIssues,
                    if (agentEventsRefs) db.agentEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (agentRunIssuesRefs)
                        await $_getPrefetchedData<
                          AgentRunRow,
                          $AgentRunsTable,
                          AgentRunIssueRow
                        >(
                          currentTable: table,
                          referencedTable: $$AgentRunsTableReferences
                              ._agentRunIssuesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AgentRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentRunIssuesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (agentEventsRefs)
                        await $_getPrefetchedData<
                          AgentRunRow,
                          $AgentRunsTable,
                          AgentEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$AgentRunsTableReferences
                              ._agentEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AgentRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).agentEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AgentRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentRunsTable,
      AgentRunRow,
      $$AgentRunsTableFilterComposer,
      $$AgentRunsTableOrderingComposer,
      $$AgentRunsTableAnnotationComposer,
      $$AgentRunsTableCreateCompanionBuilder,
      $$AgentRunsTableUpdateCompanionBuilder,
      (AgentRunRow, $$AgentRunsTableReferences),
      AgentRunRow,
      PrefetchHooks Function({bool agentRunIssuesRefs, bool agentEventsRefs})
    >;
typedef $$AgentRunIssuesTableCreateCompanionBuilder =
    AgentRunIssuesCompanion Function({
      required String runId,
      required String issueKey,
      required int position,
      Value<int> rowid,
    });
typedef $$AgentRunIssuesTableUpdateCompanionBuilder =
    AgentRunIssuesCompanion Function({
      Value<String> runId,
      Value<String> issueKey,
      Value<int> position,
      Value<int> rowid,
    });

final class $$AgentRunIssuesTableReferences
    extends
        BaseReferences<_$AppDatabase, $AgentRunIssuesTable, AgentRunIssueRow> {
  $$AgentRunIssuesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AgentRunsTable _runIdTable(_$AppDatabase db) =>
      db.agentRuns.createAlias('agent_run_issues__run_id__agent_runs__id');

  $$AgentRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$AgentRunsTableTableManager(
      $_db,
      $_db.agentRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AgentRunIssuesTableFilterComposer
    extends Composer<_$AppDatabase, $AgentRunIssuesTable> {
  $$AgentRunIssuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get issueKey => $composableBuilder(
    column: $table.issueKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$AgentRunsTableFilterComposer get runId {
    final $$AgentRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableFilterComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentRunIssuesTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentRunIssuesTable> {
  $$AgentRunIssuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get issueKey => $composableBuilder(
    column: $table.issueKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$AgentRunsTableOrderingComposer get runId {
    final $$AgentRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableOrderingComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentRunIssuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentRunIssuesTable> {
  $$AgentRunIssuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get issueKey =>
      $composableBuilder(column: $table.issueKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$AgentRunsTableAnnotationComposer get runId {
    final $$AgentRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentRunIssuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentRunIssuesTable,
          AgentRunIssueRow,
          $$AgentRunIssuesTableFilterComposer,
          $$AgentRunIssuesTableOrderingComposer,
          $$AgentRunIssuesTableAnnotationComposer,
          $$AgentRunIssuesTableCreateCompanionBuilder,
          $$AgentRunIssuesTableUpdateCompanionBuilder,
          (AgentRunIssueRow, $$AgentRunIssuesTableReferences),
          AgentRunIssueRow,
          PrefetchHooks Function({bool runId})
        > {
  $$AgentRunIssuesTableTableManager(
    _$AppDatabase db,
    $AgentRunIssuesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentRunIssuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentRunIssuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentRunIssuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> runId = const Value.absent(),
                Value<String> issueKey = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AgentRunIssuesCompanion(
                runId: runId,
                issueKey: issueKey,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String runId,
                required String issueKey,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => AgentRunIssuesCompanion.insert(
                runId: runId,
                issueKey: issueKey,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentRunIssuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable: $$AgentRunIssuesTableReferences
                                    ._runIdTable(db),
                                referencedColumn:
                                    $$AgentRunIssuesTableReferences
                                        ._runIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AgentRunIssuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentRunIssuesTable,
      AgentRunIssueRow,
      $$AgentRunIssuesTableFilterComposer,
      $$AgentRunIssuesTableOrderingComposer,
      $$AgentRunIssuesTableAnnotationComposer,
      $$AgentRunIssuesTableCreateCompanionBuilder,
      $$AgentRunIssuesTableUpdateCompanionBuilder,
      (AgentRunIssueRow, $$AgentRunIssuesTableReferences),
      AgentRunIssueRow,
      PrefetchHooks Function({bool runId})
    >;
typedef $$AgentEventsTableCreateCompanionBuilder =
    AgentEventsCompanion Function({
      Value<int> id,
      required String runId,
      required DateTime at,
      Value<String?> stage,
      required String level,
      required String message,
    });
typedef $$AgentEventsTableUpdateCompanionBuilder =
    AgentEventsCompanion Function({
      Value<int> id,
      Value<String> runId,
      Value<DateTime> at,
      Value<String?> stage,
      Value<String> level,
      Value<String> message,
    });

final class $$AgentEventsTableReferences
    extends BaseReferences<_$AppDatabase, $AgentEventsTable, AgentEventRow> {
  $$AgentEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AgentRunsTable _runIdTable(_$AppDatabase db) =>
      db.agentRuns.createAlias('agent_events__run_id__agent_runs__id');

  $$AgentRunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<String>('run_id')!;

    final manager = $$AgentRunsTableTableManager(
      $_db,
      $_db.agentRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AgentEventsTableFilterComposer
    extends Composer<_$AppDatabase, $AgentEventsTable> {
  $$AgentEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  $$AgentRunsTableFilterComposer get runId {
    final $$AgentRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableFilterComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $AgentEventsTable> {
  $$AgentEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  $$AgentRunsTableOrderingComposer get runId {
    final $$AgentRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableOrderingComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AgentEventsTable> {
  $$AgentEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  $$AgentRunsTableAnnotationComposer get runId {
    final $$AgentRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.agentRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AgentRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.agentRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AgentEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AgentEventsTable,
          AgentEventRow,
          $$AgentEventsTableFilterComposer,
          $$AgentEventsTableOrderingComposer,
          $$AgentEventsTableAnnotationComposer,
          $$AgentEventsTableCreateCompanionBuilder,
          $$AgentEventsTableUpdateCompanionBuilder,
          (AgentEventRow, $$AgentEventsTableReferences),
          AgentEventRow,
          PrefetchHooks Function({bool runId})
        > {
  $$AgentEventsTableTableManager(_$AppDatabase db, $AgentEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AgentEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AgentEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AgentEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> runId = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String?> stage = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> message = const Value.absent(),
              }) => AgentEventsCompanion(
                id: id,
                runId: runId,
                at: at,
                stage: stage,
                level: level,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String runId,
                required DateTime at,
                Value<String?> stage = const Value.absent(),
                required String level,
                required String message,
              }) => AgentEventsCompanion.insert(
                id: id,
                runId: runId,
                at: at,
                stage: stage,
                level: level,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AgentEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable: $$AgentEventsTableReferences
                                    ._runIdTable(db),
                                referencedColumn: $$AgentEventsTableReferences
                                    ._runIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AgentEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AgentEventsTable,
      AgentEventRow,
      $$AgentEventsTableFilterComposer,
      $$AgentEventsTableOrderingComposer,
      $$AgentEventsTableAnnotationComposer,
      $$AgentEventsTableCreateCompanionBuilder,
      $$AgentEventsTableUpdateCompanionBuilder,
      (AgentEventRow, $$AgentEventsTableReferences),
      AgentEventRow,
      PrefetchHooks Function({bool runId})
    >;
typedef $$WorktreeEventsTableCreateCompanionBuilder =
    WorktreeEventsCompanion Function({
      Value<int> id,
      required DateTime at,
      required String type,
      required String repoPath,
      required String repoName,
      required String worktreePath,
      required String worktreeName,
      Value<String?> branch,
      Value<String?> jiraIssue,
    });
typedef $$WorktreeEventsTableUpdateCompanionBuilder =
    WorktreeEventsCompanion Function({
      Value<int> id,
      Value<DateTime> at,
      Value<String> type,
      Value<String> repoPath,
      Value<String> repoName,
      Value<String> worktreePath,
      Value<String> worktreeName,
      Value<String?> branch,
      Value<String?> jiraIssue,
    });

class $$WorktreeEventsTableFilterComposer
    extends Composer<_$AppDatabase, $WorktreeEventsTable> {
  $$WorktreeEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoPath => $composableBuilder(
    column: $table.repoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoName => $composableBuilder(
    column: $table.repoName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get worktreeName => $composableBuilder(
    column: $table.worktreeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jiraIssue => $composableBuilder(
    column: $table.jiraIssue,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorktreeEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorktreeEventsTable> {
  $$WorktreeEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoPath => $composableBuilder(
    column: $table.repoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoName => $composableBuilder(
    column: $table.repoName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get worktreeName => $composableBuilder(
    column: $table.worktreeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get branch => $composableBuilder(
    column: $table.branch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jiraIssue => $composableBuilder(
    column: $table.jiraIssue,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorktreeEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorktreeEventsTable> {
  $$WorktreeEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get repoPath =>
      $composableBuilder(column: $table.repoPath, builder: (column) => column);

  GeneratedColumn<String> get repoName =>
      $composableBuilder(column: $table.repoName, builder: (column) => column);

  GeneratedColumn<String> get worktreePath => $composableBuilder(
    column: $table.worktreePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get worktreeName => $composableBuilder(
    column: $table.worktreeName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get branch =>
      $composableBuilder(column: $table.branch, builder: (column) => column);

  GeneratedColumn<String> get jiraIssue =>
      $composableBuilder(column: $table.jiraIssue, builder: (column) => column);
}

class $$WorktreeEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorktreeEventsTable,
          WorktreeEventRow,
          $$WorktreeEventsTableFilterComposer,
          $$WorktreeEventsTableOrderingComposer,
          $$WorktreeEventsTableAnnotationComposer,
          $$WorktreeEventsTableCreateCompanionBuilder,
          $$WorktreeEventsTableUpdateCompanionBuilder,
          (
            WorktreeEventRow,
            BaseReferences<
              _$AppDatabase,
              $WorktreeEventsTable,
              WorktreeEventRow
            >,
          ),
          WorktreeEventRow,
          PrefetchHooks Function()
        > {
  $$WorktreeEventsTableTableManager(
    _$AppDatabase db,
    $WorktreeEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorktreeEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorktreeEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorktreeEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> repoPath = const Value.absent(),
                Value<String> repoName = const Value.absent(),
                Value<String> worktreePath = const Value.absent(),
                Value<String> worktreeName = const Value.absent(),
                Value<String?> branch = const Value.absent(),
                Value<String?> jiraIssue = const Value.absent(),
              }) => WorktreeEventsCompanion(
                id: id,
                at: at,
                type: type,
                repoPath: repoPath,
                repoName: repoName,
                worktreePath: worktreePath,
                worktreeName: worktreeName,
                branch: branch,
                jiraIssue: jiraIssue,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime at,
                required String type,
                required String repoPath,
                required String repoName,
                required String worktreePath,
                required String worktreeName,
                Value<String?> branch = const Value.absent(),
                Value<String?> jiraIssue = const Value.absent(),
              }) => WorktreeEventsCompanion.insert(
                id: id,
                at: at,
                type: type,
                repoPath: repoPath,
                repoName: repoName,
                worktreePath: worktreePath,
                worktreeName: worktreeName,
                branch: branch,
                jiraIssue: jiraIssue,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorktreeEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorktreeEventsTable,
      WorktreeEventRow,
      $$WorktreeEventsTableFilterComposer,
      $$WorktreeEventsTableOrderingComposer,
      $$WorktreeEventsTableAnnotationComposer,
      $$WorktreeEventsTableCreateCompanionBuilder,
      $$WorktreeEventsTableUpdateCompanionBuilder,
      (
        WorktreeEventRow,
        BaseReferences<_$AppDatabase, $WorktreeEventsTable, WorktreeEventRow>,
      ),
      WorktreeEventRow,
      PrefetchHooks Function()
    >;
typedef $$ManualPostsTableCreateCompanionBuilder =
    ManualPostsCompanion Function({
      required String id,
      required DateTime at,
      required String repoName,
      required String issueKey,
      required String description,
      Value<double?> hours,
      Value<int> rowid,
    });
typedef $$ManualPostsTableUpdateCompanionBuilder =
    ManualPostsCompanion Function({
      Value<String> id,
      Value<DateTime> at,
      Value<String> repoName,
      Value<String> issueKey,
      Value<String> description,
      Value<double?> hours,
      Value<int> rowid,
    });

class $$ManualPostsTableFilterComposer
    extends Composer<_$AppDatabase, $ManualPostsTable> {
  $$ManualPostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get repoName => $composableBuilder(
    column: $table.repoName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get issueKey => $composableBuilder(
    column: $table.issueKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hours => $composableBuilder(
    column: $table.hours,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ManualPostsTableOrderingComposer
    extends Composer<_$AppDatabase, $ManualPostsTable> {
  $$ManualPostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoName => $composableBuilder(
    column: $table.repoName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get issueKey => $composableBuilder(
    column: $table.issueKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hours => $composableBuilder(
    column: $table.hours,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ManualPostsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ManualPostsTable> {
  $$ManualPostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get repoName =>
      $composableBuilder(column: $table.repoName, builder: (column) => column);

  GeneratedColumn<String> get issueKey =>
      $composableBuilder(column: $table.issueKey, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hours =>
      $composableBuilder(column: $table.hours, builder: (column) => column);
}

class $$ManualPostsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ManualPostsTable,
          ManualPostRow,
          $$ManualPostsTableFilterComposer,
          $$ManualPostsTableOrderingComposer,
          $$ManualPostsTableAnnotationComposer,
          $$ManualPostsTableCreateCompanionBuilder,
          $$ManualPostsTableUpdateCompanionBuilder,
          (
            ManualPostRow,
            BaseReferences<_$AppDatabase, $ManualPostsTable, ManualPostRow>,
          ),
          ManualPostRow,
          PrefetchHooks Function()
        > {
  $$ManualPostsTableTableManager(_$AppDatabase db, $ManualPostsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ManualPostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ManualPostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ManualPostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> repoName = const Value.absent(),
                Value<String> issueKey = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<double?> hours = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ManualPostsCompanion(
                id: id,
                at: at,
                repoName: repoName,
                issueKey: issueKey,
                description: description,
                hours: hours,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime at,
                required String repoName,
                required String issueKey,
                required String description,
                Value<double?> hours = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ManualPostsCompanion.insert(
                id: id,
                at: at,
                repoName: repoName,
                issueKey: issueKey,
                description: description,
                hours: hours,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ManualPostsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ManualPostsTable,
      ManualPostRow,
      $$ManualPostsTableFilterComposer,
      $$ManualPostsTableOrderingComposer,
      $$ManualPostsTableAnnotationComposer,
      $$ManualPostsTableCreateCompanionBuilder,
      $$ManualPostsTableUpdateCompanionBuilder,
      (
        ManualPostRow,
        BaseReferences<_$AppDatabase, $ManualPostsTable, ManualPostRow>,
      ),
      ManualPostRow,
      PrefetchHooks Function()
    >;
typedef $$IssueCacheTableCreateCompanionBuilder =
    IssueCacheCompanion Function({
      required String source,
      required String key,
      required String payload,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$IssueCacheTableUpdateCompanionBuilder =
    IssueCacheCompanion Function({
      Value<String> source,
      Value<String> key,
      Value<String> payload,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$IssueCacheTableFilterComposer
    extends Composer<_$AppDatabase, $IssueCacheTable> {
  $$IssueCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, String> get fetchedAt =>
      $composableBuilder(
        column: $table.fetchedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );
}

class $$IssueCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $IssueCacheTable> {
  $$IssueCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IssueCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $IssueCacheTable> {
  $$IssueCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, String> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$IssueCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IssueCacheTable,
          IssueCacheRow,
          $$IssueCacheTableFilterComposer,
          $$IssueCacheTableOrderingComposer,
          $$IssueCacheTableAnnotationComposer,
          $$IssueCacheTableCreateCompanionBuilder,
          $$IssueCacheTableUpdateCompanionBuilder,
          (
            IssueCacheRow,
            BaseReferences<_$AppDatabase, $IssueCacheTable, IssueCacheRow>,
          ),
          IssueCacheRow,
          PrefetchHooks Function()
        > {
  $$IssueCacheTableTableManager(_$AppDatabase db, $IssueCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IssueCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IssueCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IssueCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> source = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IssueCacheCompanion(
                source: source,
                key: key,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String source,
                required String key,
                required String payload,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => IssueCacheCompanion.insert(
                source: source,
                key: key,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IssueCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IssueCacheTable,
      IssueCacheRow,
      $$IssueCacheTableFilterComposer,
      $$IssueCacheTableOrderingComposer,
      $$IssueCacheTableAnnotationComposer,
      $$IssueCacheTableCreateCompanionBuilder,
      $$IssueCacheTableUpdateCompanionBuilder,
      (
        IssueCacheRow,
        BaseReferences<_$AppDatabase, $IssueCacheTable, IssueCacheRow>,
      ),
      IssueCacheRow,
      PrefetchHooks Function()
    >;
typedef $$ClaudeTranscriptsTableCreateCompanionBuilder =
    ClaudeTranscriptsCompanion Function({
      required String path,
      required String projectDir,
      required int size,
      required int mtime,
      required int scannedBytes,
      required String activeDays,
      Value<int> rowid,
    });
typedef $$ClaudeTranscriptsTableUpdateCompanionBuilder =
    ClaudeTranscriptsCompanion Function({
      Value<String> path,
      Value<String> projectDir,
      Value<int> size,
      Value<int> mtime,
      Value<int> scannedBytes,
      Value<String> activeDays,
      Value<int> rowid,
    });

class $$ClaudeTranscriptsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaudeTranscriptsTable> {
  $$ClaudeTranscriptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectDir => $composableBuilder(
    column: $table.projectDir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scannedBytes => $composableBuilder(
    column: $table.scannedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeDays => $composableBuilder(
    column: $table.activeDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClaudeTranscriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaudeTranscriptsTable> {
  $$ClaudeTranscriptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectDir => $composableBuilder(
    column: $table.projectDir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtime => $composableBuilder(
    column: $table.mtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scannedBytes => $composableBuilder(
    column: $table.scannedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeDays => $composableBuilder(
    column: $table.activeDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClaudeTranscriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaudeTranscriptsTable> {
  $$ClaudeTranscriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get projectDir => $composableBuilder(
    column: $table.projectDir,
    builder: (column) => column,
  );

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtime =>
      $composableBuilder(column: $table.mtime, builder: (column) => column);

  GeneratedColumn<int> get scannedBytes => $composableBuilder(
    column: $table.scannedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activeDays => $composableBuilder(
    column: $table.activeDays,
    builder: (column) => column,
  );
}

class $$ClaudeTranscriptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaudeTranscriptsTable,
          ClaudeTranscriptRow,
          $$ClaudeTranscriptsTableFilterComposer,
          $$ClaudeTranscriptsTableOrderingComposer,
          $$ClaudeTranscriptsTableAnnotationComposer,
          $$ClaudeTranscriptsTableCreateCompanionBuilder,
          $$ClaudeTranscriptsTableUpdateCompanionBuilder,
          (
            ClaudeTranscriptRow,
            BaseReferences<
              _$AppDatabase,
              $ClaudeTranscriptsTable,
              ClaudeTranscriptRow
            >,
          ),
          ClaudeTranscriptRow,
          PrefetchHooks Function()
        > {
  $$ClaudeTranscriptsTableTableManager(
    _$AppDatabase db,
    $ClaudeTranscriptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaudeTranscriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaudeTranscriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaudeTranscriptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> projectDir = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtime = const Value.absent(),
                Value<int> scannedBytes = const Value.absent(),
                Value<String> activeDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaudeTranscriptsCompanion(
                path: path,
                projectDir: projectDir,
                size: size,
                mtime: mtime,
                scannedBytes: scannedBytes,
                activeDays: activeDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String projectDir,
                required int size,
                required int mtime,
                required int scannedBytes,
                required String activeDays,
                Value<int> rowid = const Value.absent(),
              }) => ClaudeTranscriptsCompanion.insert(
                path: path,
                projectDir: projectDir,
                size: size,
                mtime: mtime,
                scannedBytes: scannedBytes,
                activeDays: activeDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClaudeTranscriptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaudeTranscriptsTable,
      ClaudeTranscriptRow,
      $$ClaudeTranscriptsTableFilterComposer,
      $$ClaudeTranscriptsTableOrderingComposer,
      $$ClaudeTranscriptsTableAnnotationComposer,
      $$ClaudeTranscriptsTableCreateCompanionBuilder,
      $$ClaudeTranscriptsTableUpdateCompanionBuilder,
      (
        ClaudeTranscriptRow,
        BaseReferences<
          _$AppDatabase,
          $ClaudeTranscriptsTable,
          ClaudeTranscriptRow
        >,
      ),
      ClaudeTranscriptRow,
      PrefetchHooks Function()
    >;
typedef $$WorktreeMetaTableCreateCompanionBuilder =
    WorktreeMetaCompanion Function({
      required String path,
      required String repoPath,
      Value<String?> baseBranch,
      Value<String?> jiraIssue,
      Value<int?> githubIssue,
      Value<String?> prAuthor,
      Value<String?> kickoffPromptPath,
      Value<bool> hidden,
      Value<bool> snoozed,
      Value<bool> hasSession,
      Value<String?> sessionPrompt,
      Value<DateTime?> sessionStartedAt,
      Value<int> rowid,
    });
typedef $$WorktreeMetaTableUpdateCompanionBuilder =
    WorktreeMetaCompanion Function({
      Value<String> path,
      Value<String> repoPath,
      Value<String?> baseBranch,
      Value<String?> jiraIssue,
      Value<int?> githubIssue,
      Value<String?> prAuthor,
      Value<String?> kickoffPromptPath,
      Value<bool> hidden,
      Value<bool> snoozed,
      Value<bool> hasSession,
      Value<String?> sessionPrompt,
      Value<DateTime?> sessionStartedAt,
      Value<int> rowid,
    });

class $$WorktreeMetaTableFilterComposer
    extends Composer<_$AppDatabase, $WorktreeMetaTable> {
  $$WorktreeMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repoPath => $composableBuilder(
    column: $table.repoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jiraIssue => $composableBuilder(
    column: $table.jiraIssue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get githubIssue => $composableBuilder(
    column: $table.githubIssue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prAuthor => $composableBuilder(
    column: $table.prAuthor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kickoffPromptPath => $composableBuilder(
    column: $table.kickoffPromptPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get snoozed => $composableBuilder(
    column: $table.snoozed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasSession => $composableBuilder(
    column: $table.hasSession,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionPrompt => $composableBuilder(
    column: $table.sessionPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, String>
  get sessionStartedAt => $composableBuilder(
    column: $table.sessionStartedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );
}

class $$WorktreeMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $WorktreeMetaTable> {
  $$WorktreeMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repoPath => $composableBuilder(
    column: $table.repoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jiraIssue => $composableBuilder(
    column: $table.jiraIssue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get githubIssue => $composableBuilder(
    column: $table.githubIssue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prAuthor => $composableBuilder(
    column: $table.prAuthor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kickoffPromptPath => $composableBuilder(
    column: $table.kickoffPromptPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hidden => $composableBuilder(
    column: $table.hidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get snoozed => $composableBuilder(
    column: $table.snoozed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasSession => $composableBuilder(
    column: $table.hasSession,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionPrompt => $composableBuilder(
    column: $table.sessionPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionStartedAt => $composableBuilder(
    column: $table.sessionStartedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorktreeMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorktreeMetaTable> {
  $$WorktreeMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get repoPath =>
      $composableBuilder(column: $table.repoPath, builder: (column) => column);

  GeneratedColumn<String> get baseBranch => $composableBuilder(
    column: $table.baseBranch,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jiraIssue =>
      $composableBuilder(column: $table.jiraIssue, builder: (column) => column);

  GeneratedColumn<int> get githubIssue => $composableBuilder(
    column: $table.githubIssue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get prAuthor =>
      $composableBuilder(column: $table.prAuthor, builder: (column) => column);

  GeneratedColumn<String> get kickoffPromptPath => $composableBuilder(
    column: $table.kickoffPromptPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<bool> get snoozed =>
      $composableBuilder(column: $table.snoozed, builder: (column) => column);

  GeneratedColumn<bool> get hasSession => $composableBuilder(
    column: $table.hasSession,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionPrompt => $composableBuilder(
    column: $table.sessionPrompt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, String> get sessionStartedAt =>
      $composableBuilder(
        column: $table.sessionStartedAt,
        builder: (column) => column,
      );
}

class $$WorktreeMetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorktreeMetaTable,
          WorktreeMetaRow,
          $$WorktreeMetaTableFilterComposer,
          $$WorktreeMetaTableOrderingComposer,
          $$WorktreeMetaTableAnnotationComposer,
          $$WorktreeMetaTableCreateCompanionBuilder,
          $$WorktreeMetaTableUpdateCompanionBuilder,
          (
            WorktreeMetaRow,
            BaseReferences<_$AppDatabase, $WorktreeMetaTable, WorktreeMetaRow>,
          ),
          WorktreeMetaRow,
          PrefetchHooks Function()
        > {
  $$WorktreeMetaTableTableManager(_$AppDatabase db, $WorktreeMetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorktreeMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorktreeMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorktreeMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> repoPath = const Value.absent(),
                Value<String?> baseBranch = const Value.absent(),
                Value<String?> jiraIssue = const Value.absent(),
                Value<int?> githubIssue = const Value.absent(),
                Value<String?> prAuthor = const Value.absent(),
                Value<String?> kickoffPromptPath = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> snoozed = const Value.absent(),
                Value<bool> hasSession = const Value.absent(),
                Value<String?> sessionPrompt = const Value.absent(),
                Value<DateTime?> sessionStartedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorktreeMetaCompanion(
                path: path,
                repoPath: repoPath,
                baseBranch: baseBranch,
                jiraIssue: jiraIssue,
                githubIssue: githubIssue,
                prAuthor: prAuthor,
                kickoffPromptPath: kickoffPromptPath,
                hidden: hidden,
                snoozed: snoozed,
                hasSession: hasSession,
                sessionPrompt: sessionPrompt,
                sessionStartedAt: sessionStartedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String repoPath,
                Value<String?> baseBranch = const Value.absent(),
                Value<String?> jiraIssue = const Value.absent(),
                Value<int?> githubIssue = const Value.absent(),
                Value<String?> prAuthor = const Value.absent(),
                Value<String?> kickoffPromptPath = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<bool> snoozed = const Value.absent(),
                Value<bool> hasSession = const Value.absent(),
                Value<String?> sessionPrompt = const Value.absent(),
                Value<DateTime?> sessionStartedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorktreeMetaCompanion.insert(
                path: path,
                repoPath: repoPath,
                baseBranch: baseBranch,
                jiraIssue: jiraIssue,
                githubIssue: githubIssue,
                prAuthor: prAuthor,
                kickoffPromptPath: kickoffPromptPath,
                hidden: hidden,
                snoozed: snoozed,
                hasSession: hasSession,
                sessionPrompt: sessionPrompt,
                sessionStartedAt: sessionStartedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorktreeMetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorktreeMetaTable,
      WorktreeMetaRow,
      $$WorktreeMetaTableFilterComposer,
      $$WorktreeMetaTableOrderingComposer,
      $$WorktreeMetaTableAnnotationComposer,
      $$WorktreeMetaTableCreateCompanionBuilder,
      $$WorktreeMetaTableUpdateCompanionBuilder,
      (
        WorktreeMetaRow,
        BaseReferences<_$AppDatabase, $WorktreeMetaTable, WorktreeMetaRow>,
      ),
      WorktreeMetaRow,
      PrefetchHooks Function()
    >;
typedef $$JiraTagsTableCreateCompanionBuilder =
    JiraTagsCompanion Function({
      required String id,
      required String name,
      required String color,
      required int position,
      Value<int> rowid,
    });
typedef $$JiraTagsTableUpdateCompanionBuilder =
    JiraTagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<int> position,
      Value<int> rowid,
    });

final class $$JiraTagsTableReferences
    extends BaseReferences<_$AppDatabase, $JiraTagsTable, JiraTagRow> {
  $$JiraTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$JiraIssueTagsTable, List<JiraIssueTagRow>>
  _jiraIssueTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.jiraIssueTags,
    aliasName: 'jira_tags__id__jira_issue_tags__tag_id',
  );

  $$JiraIssueTagsTableProcessedTableManager get jiraIssueTagsRefs {
    final manager = $$JiraIssueTagsTableTableManager(
      $_db,
      $_db.jiraIssueTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_jiraIssueTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$JiraTagsTableFilterComposer
    extends Composer<_$AppDatabase, $JiraTagsTable> {
  $$JiraTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> jiraIssueTagsRefs(
    Expression<bool> Function($$JiraIssueTagsTableFilterComposer f) f,
  ) {
    final $$JiraIssueTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.jiraIssueTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JiraIssueTagsTableFilterComposer(
            $db: $db,
            $table: $db.jiraIssueTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$JiraTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $JiraTagsTable> {
  $$JiraTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$JiraTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JiraTagsTable> {
  $$JiraTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  Expression<T> jiraIssueTagsRefs<T extends Object>(
    Expression<T> Function($$JiraIssueTagsTableAnnotationComposer a) f,
  ) {
    final $$JiraIssueTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.jiraIssueTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JiraIssueTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.jiraIssueTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$JiraTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JiraTagsTable,
          JiraTagRow,
          $$JiraTagsTableFilterComposer,
          $$JiraTagsTableOrderingComposer,
          $$JiraTagsTableAnnotationComposer,
          $$JiraTagsTableCreateCompanionBuilder,
          $$JiraTagsTableUpdateCompanionBuilder,
          (JiraTagRow, $$JiraTagsTableReferences),
          JiraTagRow,
          PrefetchHooks Function({bool jiraIssueTagsRefs})
        > {
  $$JiraTagsTableTableManager(_$AppDatabase db, $JiraTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JiraTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JiraTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JiraTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JiraTagsCompanion(
                id: id,
                name: name,
                color: color,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String color,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => JiraTagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$JiraTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({jiraIssueTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (jiraIssueTagsRefs) db.jiraIssueTags,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (jiraIssueTagsRefs)
                    await $_getPrefetchedData<
                      JiraTagRow,
                      $JiraTagsTable,
                      JiraIssueTagRow
                    >(
                      currentTable: table,
                      referencedTable: $$JiraTagsTableReferences
                          ._jiraIssueTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $$JiraTagsTableReferences(
                        db,
                        table,
                        p0,
                      ).jiraIssueTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$JiraTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JiraTagsTable,
      JiraTagRow,
      $$JiraTagsTableFilterComposer,
      $$JiraTagsTableOrderingComposer,
      $$JiraTagsTableAnnotationComposer,
      $$JiraTagsTableCreateCompanionBuilder,
      $$JiraTagsTableUpdateCompanionBuilder,
      (JiraTagRow, $$JiraTagsTableReferences),
      JiraTagRow,
      PrefetchHooks Function({bool jiraIssueTagsRefs})
    >;
typedef $$JiraIssueTagsTableCreateCompanionBuilder =
    JiraIssueTagsCompanion Function({
      required String issueKey,
      required String tagId,
      required int position,
      Value<int> rowid,
    });
typedef $$JiraIssueTagsTableUpdateCompanionBuilder =
    JiraIssueTagsCompanion Function({
      Value<String> issueKey,
      Value<String> tagId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$JiraIssueTagsTableReferences
    extends
        BaseReferences<_$AppDatabase, $JiraIssueTagsTable, JiraIssueTagRow> {
  $$JiraIssueTagsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $JiraTagsTable _tagIdTable(_$AppDatabase db) =>
      db.jiraTags.createAlias('jira_issue_tags__tag_id__jira_tags__id');

  $$JiraTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$JiraTagsTableTableManager(
      $_db,
      $_db.jiraTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$JiraIssueTagsTableFilterComposer
    extends Composer<_$AppDatabase, $JiraIssueTagsTable> {
  $$JiraIssueTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get issueKey => $composableBuilder(
    column: $table.issueKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$JiraTagsTableFilterComposer get tagId {
    final $$JiraTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.jiraTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JiraTagsTableFilterComposer(
            $db: $db,
            $table: $db.jiraTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JiraIssueTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $JiraIssueTagsTable> {
  $$JiraIssueTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get issueKey => $composableBuilder(
    column: $table.issueKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$JiraTagsTableOrderingComposer get tagId {
    final $$JiraTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.jiraTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JiraTagsTableOrderingComposer(
            $db: $db,
            $table: $db.jiraTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JiraIssueTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $JiraIssueTagsTable> {
  $$JiraIssueTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get issueKey =>
      $composableBuilder(column: $table.issueKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$JiraTagsTableAnnotationComposer get tagId {
    final $$JiraTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.jiraTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JiraTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.jiraTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JiraIssueTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $JiraIssueTagsTable,
          JiraIssueTagRow,
          $$JiraIssueTagsTableFilterComposer,
          $$JiraIssueTagsTableOrderingComposer,
          $$JiraIssueTagsTableAnnotationComposer,
          $$JiraIssueTagsTableCreateCompanionBuilder,
          $$JiraIssueTagsTableUpdateCompanionBuilder,
          (JiraIssueTagRow, $$JiraIssueTagsTableReferences),
          JiraIssueTagRow,
          PrefetchHooks Function({bool tagId})
        > {
  $$JiraIssueTagsTableTableManager(_$AppDatabase db, $JiraIssueTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JiraIssueTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JiraIssueTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JiraIssueTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> issueKey = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JiraIssueTagsCompanion(
                issueKey: issueKey,
                tagId: tagId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String issueKey,
                required String tagId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => JiraIssueTagsCompanion.insert(
                issueKey: issueKey,
                tagId: tagId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$JiraIssueTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$JiraIssueTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$JiraIssueTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$JiraIssueTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $JiraIssueTagsTable,
      JiraIssueTagRow,
      $$JiraIssueTagsTableFilterComposer,
      $$JiraIssueTagsTableOrderingComposer,
      $$JiraIssueTagsTableAnnotationComposer,
      $$JiraIssueTagsTableCreateCompanionBuilder,
      $$JiraIssueTagsTableUpdateCompanionBuilder,
      (JiraIssueTagRow, $$JiraIssueTagsTableReferences),
      JiraIssueTagRow,
      PrefetchHooks Function({bool tagId})
    >;
typedef $$UiStateTableCreateCompanionBuilder =
    UiStateCompanion Function({
      required String scope,
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$UiStateTableUpdateCompanionBuilder =
    UiStateCompanion Function({
      Value<String> scope,
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$UiStateTableFilterComposer
    extends Composer<_$AppDatabase, $UiStateTable> {
  $$UiStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UiStateTableOrderingComposer
    extends Composer<_$AppDatabase, $UiStateTable> {
  $$UiStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UiStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $UiStateTable> {
  $$UiStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$UiStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UiStateTable,
          UiStateRow,
          $$UiStateTableFilterComposer,
          $$UiStateTableOrderingComposer,
          $$UiStateTableAnnotationComposer,
          $$UiStateTableCreateCompanionBuilder,
          $$UiStateTableUpdateCompanionBuilder,
          (
            UiStateRow,
            BaseReferences<_$AppDatabase, $UiStateTable, UiStateRow>,
          ),
          UiStateRow,
          PrefetchHooks Function()
        > {
  $$UiStateTableTableManager(_$AppDatabase db, $UiStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UiStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UiStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UiStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UiStateCompanion(
                scope: scope,
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => UiStateCompanion.insert(
                scope: scope,
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UiStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UiStateTable,
      UiStateRow,
      $$UiStateTableFilterComposer,
      $$UiStateTableOrderingComposer,
      $$UiStateTableAnnotationComposer,
      $$UiStateTableCreateCompanionBuilder,
      $$UiStateTableUpdateCompanionBuilder,
      (UiStateRow, BaseReferences<_$AppDatabase, $UiStateTable, UiStateRow>),
      UiStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AgentRunsTableTableManager get agentRuns =>
      $$AgentRunsTableTableManager(_db, _db.agentRuns);
  $$AgentRunIssuesTableTableManager get agentRunIssues =>
      $$AgentRunIssuesTableTableManager(_db, _db.agentRunIssues);
  $$AgentEventsTableTableManager get agentEvents =>
      $$AgentEventsTableTableManager(_db, _db.agentEvents);
  $$WorktreeEventsTableTableManager get worktreeEvents =>
      $$WorktreeEventsTableTableManager(_db, _db.worktreeEvents);
  $$ManualPostsTableTableManager get manualPosts =>
      $$ManualPostsTableTableManager(_db, _db.manualPosts);
  $$IssueCacheTableTableManager get issueCache =>
      $$IssueCacheTableTableManager(_db, _db.issueCache);
  $$ClaudeTranscriptsTableTableManager get claudeTranscripts =>
      $$ClaudeTranscriptsTableTableManager(_db, _db.claudeTranscripts);
  $$WorktreeMetaTableTableManager get worktreeMeta =>
      $$WorktreeMetaTableTableManager(_db, _db.worktreeMeta);
  $$JiraTagsTableTableManager get jiraTags =>
      $$JiraTagsTableTableManager(_db, _db.jiraTags);
  $$JiraIssueTagsTableTableManager get jiraIssueTags =>
      $$JiraIssueTagsTableTableManager(_db, _db.jiraIssueTags);
  $$UiStateTableTableManager get uiState =>
      $$UiStateTableTableManager(_db, _db.uiState);
}
