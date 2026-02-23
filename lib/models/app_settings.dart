enum TerminalApp { terminal, iterm2, custom }

class AppSettings {
  final TerminalApp terminalApp;
  final String? customTerminalCommand;

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      terminalApp: TerminalApp.values.firstWhere(
        (e) => e.name == json['terminalApp'],
        orElse: () => TerminalApp.terminal,
      ),
      customTerminalCommand: json['customTerminalCommand'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'terminalApp': terminalApp.name,
        'customTerminalCommand': customTerminalCommand,
      };

  AppSettings copyWith({
    TerminalApp? terminalApp,
    String? customTerminalCommand,
  }) {
    return AppSettings(
      terminalApp: terminalApp ?? this.terminalApp,
      customTerminalCommand:
          customTerminalCommand ?? this.customTerminalCommand,
    );
  }
}
