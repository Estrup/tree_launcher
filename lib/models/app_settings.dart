enum TerminalApp { terminal, ghostty, custom }

enum CopilotButtonMode { inApp, external }

enum TtsVoice {
  alloy('alloy'),
  echo('echo'),
  fable('fable'),
  onyx('onyx'),
  nova('nova'),
  shimmer('shimmer');

  const TtsVoice(this.apiName);

  final String apiName;

  String get displayName =>
      '${apiName[0].toUpperCase()}${apiName.substring(1)}';
}

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
  final String? openAiApiKey;
  final String openAiTranscriptionModel;
  final String openAiResponseModel;
  final String? terminalFontFamily;
  final double? terminalFontSize;
  final CopilotButtonMode copilotButtonMode;
  final bool copilotAttentionSoundEnabled;
  final CopilotAttentionSound copilotAttentionSound;
  final String openAiTtsModel;
  final TtsVoice openAiTtsVoice;
  final bool remoteControlEnabled;
  final int remoteControlPort;
  final String remoteControlBindAddress;

  AppSettings({
    this.terminalApp = TerminalApp.terminal,
    this.customTerminalCommand,
    this.defaultBranchPrefix,
    this.themeName = 'muted',
    this.openAiApiKey,
    this.openAiTranscriptionModel = 'gpt-4o-transcribe',
    this.openAiResponseModel = 'gpt-5',
    this.terminalFontFamily,
    this.terminalFontSize,
    this.copilotButtonMode = CopilotButtonMode.inApp,
    this.copilotAttentionSoundEnabled = false,
    this.copilotAttentionSound = CopilotAttentionSound.ping,
    this.openAiTtsModel = 'tts-1',
    this.openAiTtsVoice = TtsVoice.nova,
    this.remoteControlEnabled = false,
    this.remoteControlPort = 8422,
    this.remoteControlBindAddress = '127.0.0.1',
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
      openAiApiKey: json['openAiApiKey'] as String?,
      openAiTranscriptionModel:
          json['openAiTranscriptionModel'] as String? ?? 'gpt-4o-transcribe',
      openAiResponseModel: json['openAiResponseModel'] as String? ?? 'gpt-5',
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
      openAiTtsModel: json['openAiTtsModel'] as String? ?? 'tts-1',
      openAiTtsVoice: TtsVoice.values.firstWhere(
        (e) => e.name == (json['openAiTtsVoice'] as String?),
        orElse: () => TtsVoice.nova,
      ),
      remoteControlEnabled: json['remoteControlEnabled'] as bool? ?? false,
      remoteControlPort: json['remoteControlPort'] as int? ?? 8422,
      remoteControlBindAddress:
          json['remoteControlBindAddress'] as String? ?? '127.0.0.1',
    );
  }

  Map<String, dynamic> toJson() => {
    'terminalApp': terminalApp.name,
    'customTerminalCommand': customTerminalCommand,
    'defaultBranchPrefix': defaultBranchPrefix,
    'themeName': themeName,
    'openAiApiKey': openAiApiKey,
    'openAiTranscriptionModel': openAiTranscriptionModel,
    'openAiResponseModel': openAiResponseModel,
    'terminalFontFamily': terminalFontFamily,
    'terminalFontSize': terminalFontSize,
    'copilotButtonMode': copilotButtonMode.name,
    'copilotAttentionSoundEnabled': copilotAttentionSoundEnabled,
    'copilotAttentionSound': copilotAttentionSound.name,
    'openAiTtsModel': openAiTtsModel,
    'openAiTtsVoice': openAiTtsVoice.name,
    'remoteControlEnabled': remoteControlEnabled,
    'remoteControlPort': remoteControlPort,
    'remoteControlBindAddress': remoteControlBindAddress,
  };

  AppSettings copyWith({
    TerminalApp? terminalApp,
    String? customTerminalCommand,
    String? defaultBranchPrefix,
    String? themeName,
    String? openAiApiKey,
    String? openAiTranscriptionModel,
    String? openAiResponseModel,
    String? terminalFontFamily,
    double? terminalFontSize,
    bool clearOpenAiApiKey = false,
    bool clearTerminalFontFamily = false,
    bool clearTerminalFontSize = false,
    CopilotButtonMode? copilotButtonMode,
    bool? copilotAttentionSoundEnabled,
    CopilotAttentionSound? copilotAttentionSound,
    String? openAiTtsModel,
    TtsVoice? openAiTtsVoice,
    bool? remoteControlEnabled,
    int? remoteControlPort,
    String? remoteControlBindAddress,
  }) {
    return AppSettings(
      terminalApp: terminalApp ?? this.terminalApp,
      customTerminalCommand:
          customTerminalCommand ?? this.customTerminalCommand,
      defaultBranchPrefix: defaultBranchPrefix ?? this.defaultBranchPrefix,
      themeName: themeName ?? this.themeName,
      openAiApiKey: clearOpenAiApiKey
          ? null
          : (openAiApiKey ?? this.openAiApiKey),
      openAiTranscriptionModel:
          openAiTranscriptionModel ?? this.openAiTranscriptionModel,
      openAiResponseModel: openAiResponseModel ?? this.openAiResponseModel,
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
      openAiTtsModel: openAiTtsModel ?? this.openAiTtsModel,
      openAiTtsVoice: openAiTtsVoice ?? this.openAiTtsVoice,
      remoteControlEnabled: remoteControlEnabled ?? this.remoteControlEnabled,
      remoteControlPort: remoteControlPort ?? this.remoteControlPort,
      remoteControlBindAddress:
          remoteControlBindAddress ?? this.remoteControlBindAddress,
    );
  }
}
