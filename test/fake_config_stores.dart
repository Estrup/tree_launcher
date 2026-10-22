import 'package:tree_launcher/features/jira/data/jira_comment_draft_store.dart';
import 'package:tree_launcher/features/github_prs/data/github_token_store.dart';
import 'package:tree_launcher/features/settings/data/app_settings_store.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/data/worktree_metadata_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_metadata.dart';

/// The repos section of `config.json`, in memory. Widget tests use it
/// because real file I/O doesn't complete under their fake async.
class FakeRepoConfigStore implements RepoConfigStore {
  FakeRepoConfigStore([this.savedRepos = const []]);

  List<RepoConfig> savedRepos;
  String? lastSelectedRepoPath;

  @override
  Future<List<RepoConfig>> load() async => savedRepos;

  @override
  Future<void> save(List<RepoConfig> repos) async {
    savedRepos = List<RepoConfig>.from(repos);
  }

  @override
  Future<String?> loadLastSelectedRepoPath() async => lastSelectedRepoPath;

  @override
  Future<void> saveLastSelectedRepoPath(String? path) async {
    lastSelectedRepoPath = path;
  }
}

/// GitHub tokens in memory instead of the Keychain. Counts the calls, so
/// tests can check that unchanged tokens don't touch the store.
class MemoryGithubTokenStore implements GithubTokenStore {
  MemoryGithubTokenStore([Map<String, String>? tokens]) : tokens = tokens ?? {};

  final Map<String, String> tokens;
  int reads = 0;
  int writes = 0;
  int deletes = 0;

  /// When set, every call throws it, like a Keychain that can't be reached.
  Object? failWith;

  /// How long a write takes, like spawning `security`.
  Duration writeDelay = Duration.zero;

  @override
  Future<String?> read(String repoPath) async {
    reads++;
    if (failWith case final error?) throw error;
    return tokens[repoPath];
  }

  @override
  Future<void> write(String repoPath, String token) async {
    writes++;
    await Future<void>.delayed(writeDelay);
    if (failWith case final error?) throw error;
    tokens[repoPath] = token;
  }

  @override
  Future<void> delete(String repoPath) async {
    deletes++;
    if (failWith case final error?) throw error;
    tokens.remove(repoPath);
  }
}

/// The settings section of `config.json`, in memory.
class FakeAppSettingsStore implements AppSettingsStore {
  FakeAppSettingsStore([AppSettings? settings])
    : savedSettings = settings ?? AppSettings();

  AppSettings savedSettings;

  @override
  Future<AppSettings> load() async => savedSettings;

  @override
  Future<void> save(AppSettings settings) async {
    savedSettings = settings;
  }
}

/// Per-worktree metadata in memory, keyed by path. Widget tests use it
/// because database futures don't complete under their fake async.
class MemoryWorktreeMetadataStore implements WorktreeMetadataStore {
  MemoryWorktreeMetadataStore([Iterable<WorktreeMetadata> entries = const []])
    : saved = {for (final entry in entries) entry.path: entry};

  final Map<String, WorktreeMetadata> saved;

  @override
  Future<List<WorktreeMetadata>> loadAll() async => saved.values.toList();

  @override
  Future<void> saveAll(Iterable<WorktreeMetadata> entries) async {
    for (final entry in entries) {
      if (entry.isEmpty) {
        saved.remove(entry.path);
      } else {
        saved[entry.path] = entry;
      }
    }
  }

  @override
  Future<void> delete(Iterable<String> paths) async =>
      paths.forEach(saved.remove);

  @override
  Future<void> importLegacy(Iterable<WorktreeMetadata> entries) async {
    for (final entry in entries) {
      if (!entry.isEmpty) saved.putIfAbsent(entry.path, () => entry);
    }
  }
}

class MemoryJiraCommentDraftStore implements JiraCommentDraftStore {
  final drafts = <String, JiraCommentDraft>{};
  bool consultantsOnly = false;

  @override
  Future<JiraCommentDraft?> read(String issueKey) async => drafts[issueKey];

  @override
  Future<void> write(String issueKey, JiraCommentDraft? draft) async {
    if (draft == null || draft.body.trim().isEmpty) {
      drafts.remove(issueKey);
    } else {
      drafts[issueKey] = draft;
    }
  }

  @override
  Future<bool> lastConsultantsOnly() async => consultantsOnly;

  @override
  Future<void> rememberConsultantsOnly(bool value) async =>
      consultantsOnly = value;
}
