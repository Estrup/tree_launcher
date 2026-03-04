enum TerminalApp { terminal, ghostty, custom }
enum CopilotButtonMode { inApp, external }

class AppSettings {
  final TerminalApp terminalApp;
  final String? customTerminalCommand;
  final String? defaultBranchPrefix;
  final String themeName;
  final String? terminalFontFamily;
  final double? terminalFontSize;
  final CopilotButtonMode copilotButtonMode;

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
    this.defaultBranchPrefix,
    this.themeName = 'muted',
    this.terminalFontFamily,
    this.terminalFontSize,
    this.copilotButtonMode = CopilotButtonMode.inApp,
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
    );
  }
}
