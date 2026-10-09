enum TerminalApp { terminal, ghostty, custom }

/// Default extra arguments for the Claude CLI sessions started from the Jira
/// tab: subscribes the session to the Discord channel plugin.
const defaultClaudeCliArgs = '--channels plugin:discord@claude-plugins-official';

class AppSettings {
  final TerminalApp terminalApp;
  final String? customTerminalCommand;
  final String? defaultBranchPrefix;
  final String themeName;
  final String? terminalFontFamily;
  final double? terminalFontSize;
  final bool showHiddenWorktrees;

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

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
    this.defaultBranchPrefix,
    this.themeName = 'muted',
    this.terminalFontFamily,
    this.terminalFontSize,
    this.showHiddenWorktrees = false,
    this.hiddenRepos = const [],
    this.agentApiPort = 8765,
    this.claudeCliArgs = defaultClaudeCliArgs,
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
      hiddenRepos:
          (json['hiddenRepos'] as List<dynamic>?)?.cast<String>() ?? const [],
      agentApiPort: json['agentApiPort'] as int? ?? 8765,
      claudeCliArgs: json['claudeCliArgs'] as String? ?? defaultClaudeCliArgs,
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
    'hiddenRepos': hiddenRepos,
    'agentApiPort': agentApiPort,
    'claudeCliArgs': claudeCliArgs,
  };

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
    List<String>? hiddenRepos,
    int? agentApiPort,
    String? claudeCliArgs,
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
      hiddenRepos: hiddenRepos ?? this.hiddenRepos,
      agentApiPort: agentApiPort ?? this.agentApiPort,
      claudeCliArgs: claudeCliArgs ?? this.claudeCliArgs,
    );
  }
}
