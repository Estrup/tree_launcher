import 'package:drift/drift.dart';

/// Stores a [DateTime] as ISO-8601 text, the same way the JSON files did, so
/// values round-trip unchanged (local stays local, microseconds are kept).
class IsoDateTime extends TypeConverter<DateTime, String> {
  const IsoDateTime();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb);

  @override
  String toSql(DateTime value) => value.toIso8601String();
}

/// Agent runs. What is filtered or sorted on is a column; the rest of a run
/// (prompt, stages, currentStage, summary, result, links, model, effort,
/// claudeSessionId) is display detail, kept as JSON in [detail].
@DataClassName('AgentRunRow')
class AgentRuns extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get repo => text()();
  TextColumn get title => text().nullable()();
  TextColumn get state => text()();
  TextColumn get worktreePath => text().nullable()();
  TextColumn get branch => text().nullable()();
  IntColumn get prNumber => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get startedAt => text().map(const IsoDateTime())();
  TextColumn get updatedAt => text().map(const IsoDateTime())();
  TextColumn get finishedAt => text().nullable().map(const IsoDateTime())();
  TextColumn get detail => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The Jira issues an agent run works on, in the run's order.
@DataClassName('AgentRunIssueRow')
class AgentRunIssues extends Table {
  TextColumn get runId =>
      text().references(AgentRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get issueKey => text()();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {runId, issueKey};
}

/// Agent run timelines. Deleting a run deletes its events.
@DataClassName('AgentEventRow')
@TableIndex(name: 'agent_events_run', columns: {#runId, #id})
class AgentEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get runId =>
      text().references(AgentRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get at => text().map(const IsoDateTime())();
  TextColumn get stage => text().nullable()();
  TextColumn get level => text()();
  TextColumn get message => text()();
}

/// Worktree created/closed log. Keyed by path, not a foreign key: the history
/// outlives the worktree.
@DataClassName('WorktreeEventRow')
@TableIndex(name: 'worktree_events_at', columns: {#at})
class WorktreeEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get at => text().map(const IsoDateTime())();
  TextColumn get type => text()();
  TextColumn get repoPath => text()();
  TextColumn get repoName => text()();
  TextColumn get worktreePath => text()();
  TextColumn get worktreeName => text()();
  TextColumn get branch => text().nullable()();
  TextColumn get jiraIssue => text().nullable()();
}

/// Manually logged activity posts.
@DataClassName('ManualPostRow')
class ManualPosts extends Table {
  TextColumn get id => text()();
  TextColumn get at => text().map(const IsoDateTime())();
  TextColumn get repoName => text()();
  TextColumn get issueKey => text()();
  TextColumn get description => text()();
  RealColumn get hours => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Issues fetched from Jira (`source` 'jira', key `AU2-1234`) and GitHub
/// (`source` 'github', key `owner/repo#12`), as the issue's JSON.
@DataClassName('IssueCacheRow')
class IssueCache extends Table {
  TextColumn get source => text()();
  TextColumn get key => text()();
  TextColumn get payload => text()();
  TextColumn get fetchedAt => text().map(const IsoDateTime())();

  @override
  Set<Column> get primaryKey => {source, key};
}

/// What has been read from each Claude transcript in `~/.claude/projects`, so
/// a transcript is only read again once its size or mtime changes.
@DataClassName('ClaudeTranscriptRow')
@TableIndex(name: 'claude_transcripts_dir', columns: {#projectDir})
class ClaudeTranscripts extends Table {
  TextColumn get path => text()();
  TextColumn get projectDir => text()();
  IntColumn get size => integer()();

  /// Microseconds since the epoch.
  IntColumn get mtime => integer()();

  /// Where the last complete line read ends; the file is append-only, so a
  /// grown file is read from here.
  IntColumn get scannedBytes => integer()();

  /// JSON list of local calendar days (`2026-10-19`) with activity.
  TextColumn get activeDays => text()();

  @override
  Set<Column> get primaryKey => {path};
}

/// What the app knows about a worktree beyond what git says, one row per
/// worktree path: the issue and PR it was made for, the branch it was made
/// from, the kickoff prompt an agent left in it, whether it is hidden or
/// snoozed, and the Claude session remembered there (a sidebar shortcut).
///
/// Which worktrees exist is git's to say; a row whose worktree is gone is
/// removed when its repo's worktrees are listed again.
@DataClassName('WorktreeMetaRow')
@TableIndex(name: 'worktree_metadata_repo', columns: {#repoPath})
class WorktreeMeta extends Table {
  @override
  String get tableName => 'worktree_metadata';

  TextColumn get path => text()();
  TextColumn get repoPath => text()();
  TextColumn get baseBranch => text().nullable()();
  TextColumn get jiraIssue => text().nullable()();
  IntColumn get githubIssue => integer().nullable()();
  TextColumn get prAuthor => text().nullable()();
  TextColumn get kickoffPromptPath => text().nullable()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get snoozed => boolean().withDefault(const Constant(false))();

  /// Whether a Claude session is remembered here.
  BoolColumn get hasSession => boolean().withDefault(const Constant(false))();

  /// The prompt the session was started with: a saved prompt's name or a
  /// built-in prompt id.
  TextColumn get sessionPrompt => text().nullable()();

  /// When the session was first started; null for ones remembered before
  /// start times were kept.
  TextColumn get sessionStartedAt =>
      text().nullable().map(const IsoDateTime())();

  @override
  Set<Column> get primaryKey => {path};
}
