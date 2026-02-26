enum TerminalApp { terminal, ghostty, custom }

class AppSettings {
  final TerminalApp terminalApp;
  final String? customTerminalCommand;
  final String? defaultBranchPrefix;

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
    this.defaultBranchPrefix,
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
    );
  }

  Map<String, dynamic> toJson() => {
    'terminalApp': terminalApp.name,
    'customTerminalCommand': customTerminalCommand,
    'defaultBranchPrefix': defaultBranchPrefix,
  };

  AppSettings copyWith({
    TerminalApp? terminalApp,
    String? customTerminalCommand,
    String? defaultBranchPrefix,
  }) {
    return AppSettings(
      terminalApp: terminalApp ?? this.terminalApp,
      customTerminalCommand:
          customTerminalCommand ?? this.customTerminalCommand,
      defaultBranchPrefix: defaultBranchPrefix ?? this.defaultBranchPrefix,
    );
  }
}
