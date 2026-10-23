import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger_schedule.dart';

enum TerminalApp { terminal, ghostty, custom }

/// Default extra arguments for the Claude CLI sessions started from the Jira
/// tab: subscribes the session to the Discord channel plugin.
const defaultClaudeCliArgs =
    '--channels plugin:discord@claude-plugins-official';

class AppSettings {
  final TerminalApp terminalApp;
  final String? customTerminalCommand;
  final String? defaultBranchPrefix;
  final String themeName;
  final String? terminalFontFamily;
  final double? terminalFontSize;
  final bool showHiddenWorktrees;

  /// Whether the worktree list spreads each row over two lines: the name and
  /// actions, then the branch, issue, its title and PR.
  final bool twoLineWorktreeRows;

  /// Repo paths the user has hidden from the sidebar.
  final List<String> hiddenRepos;

  /// Loopback port the agent API HTTP server listens on. Default mirrors
  /// `AgentApiServer.defaultPort` (kept as a literal here to avoid the model
  /// depending on the feature layer).
  final int agentApiPort;

  /// Extra arguments appended to `claude` when starting (or resuming) a Claude
  /// CLI session in the built-in terminal. Inserted into the shell command
  /// verbatim; empty means none.
  final String claudeCliArgs;

  /// Model alias (`--model`) last picked when starting a Claude session from
  /// the Jira or PR tab; null uses the CLI's default.
  final String? claudeModel;

  /// Effort level (`--effort`) last picked alongside [claudeModel]; null uses
  /// the CLI's default.
  final String? claudeEffort;

  /// The prompt last picked when starting a Claude session from the Jira or
  /// PR tab: a saved prompt's name or a built-in prompt id (see
  /// `issueContextPromptId`, `noClaudePromptId`); null when none was yet.
  final String? claudePrompt;

  /// Whether "Existing worktree" was last picked there instead of creating
  /// one (for an issue that had no worktree of its own).
  final bool claudeUseExistingWorktree;

  /// The user's own tags for Jira issues, in display order.
  final List<JiraTag> jiraTags;

  /// Issue key -> ids of the [jiraTags] it has.
  final Map<String, List<String>> jiraTagsByIssue;

  /// When Jira is checked for the repos' triggers.
  final JiraTriggerSchedule jiraTriggerSchedule;

  /// The catalog of agent types, in tab order. Each repo switches off the
  /// ones it doesn't use (`RepoConfig.disabledAgentTypes`).
  final List<AgentType> agentTypes;

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
    this.defaultBranchPrefix,
    this.themeName = 'muted',
    this.terminalFontFamily,
    this.terminalFontSize,
    this.showHiddenWorktrees = false,
    this.twoLineWorktreeRows = false,
    this.hiddenRepos = const [],
    this.agentApiPort = 8765,
    this.claudeCliArgs = defaultClaudeCliArgs,
    this.claudeModel,
    this.claudeEffort,
    this.claudePrompt,
    this.claudeUseExistingWorktree = false,
    this.jiraTags = const [],
    this.jiraTagsByIssue = const {},
    this.jiraTriggerSchedule = const JiraTriggerSchedule(),
    this.agentTypes = defaultAgentTypes,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final terminalAppRaw = json['terminalApp'] as String?;
    final terminalAppName = terminalAppRaw == 'iterm2'
        ? 'ghostty'
        : terminalAppRaw;
    return AppSettings(
      terminalApp: TerminalApp.values.firstWhere(
        (e) => e.name == terminalAppName,
        orElse: () => TerminalApp.terminal,
      ),
      customTerminalCommand: json['customTerminalCommand'] as String?,
      defaultBranchPrefix: json['defaultBranchPrefix'] as String?,
      themeName: json['themeName'] as String? ?? 'muted',
      terminalFontFamily: json['terminalFontFamily'] as String?,
      terminalFontSize: (json['terminalFontSize'] as num?)?.toDouble(),
      showHiddenWorktrees: json['showHiddenWorktrees'] as bool? ?? false,
      twoLineWorktreeRows: json['twoLineWorktreeRows'] as bool? ?? false,
      hiddenRepos:
          (json['hiddenRepos'] as List<dynamic>?)?.cast<String>() ?? const [],
      agentApiPort: json['agentApiPort'] as int? ?? 8765,
      claudeCliArgs: json['claudeCliArgs'] as String? ?? defaultClaudeCliArgs,
      claudeModel: json['claudeModel'] as String?,
      claudeEffort: json['claudeEffort'] as String?,
      claudePrompt: json['claudePrompt'] as String?,
      claudeUseExistingWorktree:
          json['claudeUseExistingWorktree'] as bool? ?? false,
      jiraTags:
          (json['jiraTags'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(JiraTag.fromJson)
              .toList() ??
          const [],
      jiraTagsByIssue: {
        for (final MapEntry(:key, :value)
            in (json['jiraTagsByIssue'] as Map<String, dynamic>? ?? {}).entries)
          if (value is List) key: value.whereType<String>().toList(),
      },
      jiraTriggerSchedule: json['jiraTriggerSchedule'] is Map<String, dynamic>
          ? JiraTriggerSchedule.fromJson(
              json['jiraTriggerSchedule'] as Map<String, dynamic>,
            )
          : const JiraTriggerSchedule(),
      agentTypes:
          (json['agentTypes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(AgentType.fromJson)
              .toList() ??
          defaultAgentTypes,
    );
  }

  Map<String, dynamic> toJson() => {
    'terminalApp': terminalApp.name,
    'customTerminalCommand': customTerminalCommand,
    'defaultBranchPrefix': defaultBranchPrefix,
    'themeName': themeName,
    'terminalFontFamily': terminalFontFamily,
    'terminalFontSize': terminalFontSize,
    'showHiddenWorktrees': showHiddenWorktrees,
    'twoLineWorktreeRows': twoLineWorktreeRows,
    'hiddenRepos': hiddenRepos,
    'agentApiPort': agentApiPort,
    'claudeCliArgs': claudeCliArgs,
    'claudeModel': claudeModel,
    'claudeEffort': claudeEffort,
    'claudePrompt': claudePrompt,
    'claudeUseExistingWorktree': claudeUseExistingWorktree,
    'jiraTags': [for (final tag in jiraTags) tag.toJson()],
    'jiraTagsByIssue': jiraTagsByIssue,
    'jiraTriggerSchedule': jiraTriggerSchedule.toJson(),
    'agentTypes': [for (final type in agentTypes) type.toJson()],
  };

  /// The catalog's type for [kind], or a stand-in when it has none.
  AgentType agentType(AgentKind kind) => agentTypeIn(agentTypes, kind);

  /// The tags [issueKey] has, in [jiraTags] order.
  List<JiraTag> tagsFor(String issueKey) {
    final ids = jiraTagsByIssue[issueKey];
    if (ids == null || ids.isEmpty) return const [];
    return jiraTags.where((tag) => ids.contains(tag.id)).toList();
  }

  AppSettings copyWith({
    TerminalApp? terminalApp,
    String? customTerminalCommand,
    String? defaultBranchPrefix,
    String? themeName,
    String? terminalFontFamily,
    double? terminalFontSize,
    bool clearTerminalFontFamily = false,
    bool clearTerminalFontSize = false,
    bool? showHiddenWorktrees,
    bool? twoLineWorktreeRows,
    List<String>? hiddenRepos,
    int? agentApiPort,
    String? claudeCliArgs,
    String? claudeModel,
    String? claudeEffort,
    bool clearClaudeModel = false,
    bool clearClaudeEffort = false,
    String? claudePrompt,
    bool? claudeUseExistingWorktree,
    List<JiraTag>? jiraTags,
    Map<String, List<String>>? jiraTagsByIssue,
    JiraTriggerSchedule? jiraTriggerSchedule,
    List<AgentType>? agentTypes,
  }) {
    return AppSettings(
      terminalApp: terminalApp ?? this.terminalApp,
      customTerminalCommand:
          customTerminalCommand ?? this.customTerminalCommand,
      defaultBranchPrefix: defaultBranchPrefix ?? this.defaultBranchPrefix,
      themeName: themeName ?? this.themeName,
      terminalFontFamily: clearTerminalFontFamily
          ? null
          : (terminalFontFamily ?? this.terminalFontFamily),
      terminalFontSize: clearTerminalFontSize
          ? null
          : (terminalFontSize ?? this.terminalFontSize),
      showHiddenWorktrees: showHiddenWorktrees ?? this.showHiddenWorktrees,
      twoLineWorktreeRows: twoLineWorktreeRows ?? this.twoLineWorktreeRows,
      hiddenRepos: hiddenRepos ?? this.hiddenRepos,
      agentApiPort: agentApiPort ?? this.agentApiPort,
      claudeCliArgs: claudeCliArgs ?? this.claudeCliArgs,
      claudeModel: clearClaudeModel ? null : (claudeModel ?? this.claudeModel),
      claudeEffort: clearClaudeEffort
          ? null
          : (claudeEffort ?? this.claudeEffort),
      claudePrompt: claudePrompt ?? this.claudePrompt,
      claudeUseExistingWorktree:
          claudeUseExistingWorktree ?? this.claudeUseExistingWorktree,
      jiraTags: jiraTags ?? this.jiraTags,
      jiraTagsByIssue: jiraTagsByIssue ?? this.jiraTagsByIssue,
      jiraTriggerSchedule: jiraTriggerSchedule ?? this.jiraTriggerSchedule,
      agentTypes: agentTypes ?? this.agentTypes,
    );
  }
}
