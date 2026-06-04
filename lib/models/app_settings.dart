enum TerminalApp { terminal, ghostty, custom }

enum CopilotButtonMode { inApp, external }

enum WorktreeViewMode { grid, list }

enum CopilotAttentionSound {
  basso('Basso'),
  blow('Blow'),
  bottle('Bottle'),
  frog('Frog'),
  funk('Funk'),
  glass('Glass'),
  hero('Hero'),
  morse('Morse'),
  ping('Ping'),
  pop('Pop'),
  purr('Purr'),
  sosumi('Sosumi'),
  submarine('Submarine'),
  tink('Tink');

  const CopilotAttentionSound(this.systemName);

  final String systemName;

  String get displayName => systemName;
}

class AppSettings {
  final TerminalApp terminalApp;
  final String? customTerminalCommand;
  final String? defaultBranchPrefix;
  final String themeName;
  final String? terminalFontFamily;
  final double? terminalFontSize;
  final CopilotButtonMode copilotButtonMode;
  final bool copilotAttentionSoundEnabled;
  final CopilotAttentionSound copilotAttentionSound;
  final String? copilotModel;
  final bool copilotAllowAll;
  final bool copilotAllowAllTools;
  final bool copilotAllowAllUrls;
  final bool copilotAllowAllPaths;
  final List<String> copilotAddDirs;
  final bool copilotAutopilot;
  final String? markdownDocumentsFolder;
  final List<String> markdownRecentFiles;
  final WorktreeViewMode worktreeViewMode;

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
    this.defaultBranchPrefix,
    this.themeName = 'muted',
    this.terminalFontFamily,
    this.terminalFontSize,
    this.copilotButtonMode = CopilotButtonMode.inApp,
    this.copilotAttentionSoundEnabled = false,
    this.copilotAttentionSound = CopilotAttentionSound.ping,
    this.copilotModel,
    this.copilotAllowAll = false,
    this.copilotAllowAllTools = false,
    this.copilotAllowAllUrls = false,
    this.copilotAllowAllPaths = false,
    this.copilotAddDirs = const [],
    this.copilotAutopilot = false,
    this.markdownDocumentsFolder,
    this.markdownRecentFiles = const [],
    this.worktreeViewMode = WorktreeViewMode.grid,
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
      copilotButtonMode: CopilotButtonMode.values.firstWhere(
        (e) => e.name == (json['copilotButtonMode'] as String?),
        orElse: () => CopilotButtonMode.inApp,
      ),
      copilotAttentionSoundEnabled:
          json['copilotAttentionSoundEnabled'] as bool? ?? false,
      copilotAttentionSound: CopilotAttentionSound.values.firstWhere(
        (e) => e.name == (json['copilotAttentionSound'] as String?),
        orElse: () => CopilotAttentionSound.ping,
      ),
      copilotModel: json['copilotModel'] as String?,
      copilotAllowAll: json['copilotAllowAll'] as bool? ?? false,
      copilotAllowAllTools: json['copilotAllowAllTools'] as bool? ?? false,
      copilotAllowAllUrls: json['copilotAllowAllUrls'] as bool? ?? false,
      copilotAllowAllPaths: json['copilotAllowAllPaths'] as bool? ?? false,
      copilotAddDirs:
          (json['copilotAddDirs'] as List<dynamic>?)?.cast<String>() ??
          const [],
      copilotAutopilot: json['copilotAutopilot'] as bool? ?? false,
      markdownDocumentsFolder: json['markdownDocumentsFolder'] as String?,
      markdownRecentFiles:
          (json['markdownRecentFiles'] as List<dynamic>?)?.cast<String>() ??
          const [],
      worktreeViewMode: WorktreeViewMode.values.firstWhere(
        (e) => e.name == (json['worktreeViewMode'] as String?),
        orElse: () => WorktreeViewMode.grid,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'terminalApp': terminalApp.name,
    'customTerminalCommand': customTerminalCommand,
    'defaultBranchPrefix': defaultBranchPrefix,
    'themeName': themeName,
    'terminalFontFamily': terminalFontFamily,
    'terminalFontSize': terminalFontSize,
    'copilotButtonMode': copilotButtonMode.name,
    'copilotAttentionSoundEnabled': copilotAttentionSoundEnabled,
    'copilotAttentionSound': copilotAttentionSound.name,
    'copilotModel': copilotModel,
    'copilotAllowAll': copilotAllowAll,
    'copilotAllowAllTools': copilotAllowAllTools,
    'copilotAllowAllUrls': copilotAllowAllUrls,
    'copilotAllowAllPaths': copilotAllowAllPaths,
    'copilotAddDirs': copilotAddDirs,
    'copilotAutopilot': copilotAutopilot,
    'markdownDocumentsFolder': markdownDocumentsFolder,
    'markdownRecentFiles': markdownRecentFiles,
    'worktreeViewMode': worktreeViewMode.name,
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
    CopilotButtonMode? copilotButtonMode,
    bool? copilotAttentionSoundEnabled,
    CopilotAttentionSound? copilotAttentionSound,
    String? copilotModel,
    bool clearCopilotModel = false,
    bool? copilotAllowAll,
    bool? copilotAllowAllTools,
    bool? copilotAllowAllUrls,
    bool? copilotAllowAllPaths,
    List<String>? copilotAddDirs,
    bool? copilotAutopilot,
    String? markdownDocumentsFolder,
    bool clearMarkdownDocumentsFolder = false,
    List<String>? markdownRecentFiles,
    WorktreeViewMode? worktreeViewMode,
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
      copilotButtonMode: copilotButtonMode ?? this.copilotButtonMode,
      copilotAttentionSoundEnabled:
          copilotAttentionSoundEnabled ?? this.copilotAttentionSoundEnabled,
      copilotAttentionSound:
          copilotAttentionSound ?? this.copilotAttentionSound,
      copilotModel: clearCopilotModel
          ? null
          : (copilotModel ?? this.copilotModel),
      copilotAllowAll: copilotAllowAll ?? this.copilotAllowAll,
      copilotAllowAllTools: copilotAllowAllTools ?? this.copilotAllowAllTools,
      copilotAllowAllUrls: copilotAllowAllUrls ?? this.copilotAllowAllUrls,
      copilotAllowAllPaths: copilotAllowAllPaths ?? this.copilotAllowAllPaths,
      copilotAddDirs: copilotAddDirs ?? this.copilotAddDirs,
      copilotAutopilot: copilotAutopilot ?? this.copilotAutopilot,
      markdownDocumentsFolder: clearMarkdownDocumentsFolder
          ? null
          : (markdownDocumentsFolder ?? this.markdownDocumentsFolder),
      markdownRecentFiles: markdownRecentFiles ?? this.markdownRecentFiles,
      worktreeViewMode: worktreeViewMode ?? this.worktreeViewMode,
    );
  }
}
