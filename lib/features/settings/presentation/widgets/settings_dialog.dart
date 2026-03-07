import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/providers/settings_provider.dart';
import 'package:tree_launcher/services/config_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SettingsProvider>(),
        child: const SettingsDialog(),
      ),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final SoundService _soundService = SoundService();
  late final TextEditingController _customTerminalController;
  late final TextEditingController _branchPrefixController;
  late final TextEditingController _openAiApiKeyController;
  late final TextEditingController _openAiTranscriptionModelController;
  late final TextEditingController _openAiResponseModelController;
  late final TextEditingController _remotePortController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _customTerminalController = TextEditingController(
      text: settings.customTerminalCommand ?? '',
    );
    _branchPrefixController = TextEditingController(
      text: settings.defaultBranchPrefix ?? '',
    );
    _openAiApiKeyController = TextEditingController(
      text: context.read<SettingsProvider>().openAiApiKey,
    );
    _openAiTranscriptionModelController = TextEditingController(
      text: settings.openAiTranscriptionModel,
    );
    _openAiResponseModelController = TextEditingController(
      text: settings.openAiResponseModel,
    );
    _remotePortController = TextEditingController(
      text: settings.remoteControlPort.toString(),
    );
  }

  @override
  void dispose() {
    _customTerminalController.dispose();
    _branchPrefixController.dispose();
    _openAiApiKeyController.dispose();
    _openAiTranscriptionModelController.dispose();
    _openAiResponseModelController.dispose();
    _remotePortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return AlertDialog(
      backgroundColor: AppColors.surface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border),
      ),
      title: Text(
        'Settings',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Theme ──
              Text(
                'THEME',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildThemePicker(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Terminal application ──
              Text(
                'TERMINAL APPLICATION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildTerminalOptions(settings, settingsProvider),
              if (settings.terminalApp == TerminalApp.custom) ...[
                const SizedBox(height: 16),
                TextField(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    labelText: 'Command path',
                    labelStyle: TextStyle(color: AppColors.textMuted),
                    hintText:
                        'shortcuts run "My Shortcut" --input-path "{path}"',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                    filled: true,
                    fillColor: AppColors.surface0,
                  ),
                  controller: _customTerminalController,
                  onChanged: (value) {
                    settingsProvider.updateCustomTerminalCommand(
                      value.isEmpty ? null : value,
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),

              // ── Built-in terminal ──
              Text(
                'BUILT-IN TERMINAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildTerminalFontSettings(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Copilot button ──
              Text(
                'COPILOT BUTTON',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildCopilotButtonOptions(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Copilot attention ──
              Text(
                'COPILOT ATTENTION',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildCopilotAttentionSoundSettings(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Branch prefix ──
              Text(
                'DEFAULT BRANCH PREFIX',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  labelText: 'Branch prefix',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  hintText: 'e.g. feature, fix, username',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                  filled: true,
                  fillColor: AppColors.surface0,
                ),
                controller: _branchPrefixController,
                onChanged: (value) {
                  settingsProvider.updateDefaultBranchPrefix(
                    value.isEmpty ? null : value,
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                'New branches will be auto-filled as prefix/worktree-name',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              // ── OpenAI ──
              Text(
                'OPENAI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildOpenAiSettings(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Remote control ──
              Text(
                'REMOTE CONTROL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildRemoteControlSettings(settings, settingsProvider),
              const SizedBox(height: 24),

              // ── Config file link ──
              _buildConfigFileLink(),
            ],
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Done',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.base,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemePicker(AppSettings settings, SettingsProvider provider) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: palettes.entries.map((entry) {
        final name = entry.key;
        final palette = entry.value;
        final isSelected = settings.themeName == name;
        return _ThemeCard(
          label: paletteDisplayNames[name] ?? name,
          palette: palette,
          isSelected: isSelected,
          onTap: () => provider.updateTheme(name),
        );
      }).toList(),
    );
  }

  Widget _buildTerminalOptions(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    return Row(
      children: [
        _OptionCard(
          label: 'Terminal',
          icon: Icons.terminal_rounded,
          isSelected: settings.terminalApp == TerminalApp.terminal,
          onTap: () => provider.updateTerminalApp(TerminalApp.terminal),
        ),
        const SizedBox(width: 8),
        _OptionCard(
          label: 'Ghostty',
          icon: Icons.terminal_rounded,
          isSelected: settings.terminalApp == TerminalApp.ghostty,
          onTap: () => provider.updateTerminalApp(TerminalApp.ghostty),
        ),
        const SizedBox(width: 8),
        _OptionCard(
          label: 'Custom',
          icon: Icons.tune_rounded,
          isSelected: settings.terminalApp == TerminalApp.custom,
          onTap: () => provider.updateTerminalApp(TerminalApp.custom),
        ),
      ],
    );
  }

  Widget _buildTerminalFontSettings(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    const fonts = [
      'SF Mono',
      'Menlo',
      'Monaco',
      'JetBrains Mono',
      'Fira Code',
      'monospace',
    ];
    const sizes = [11.0, 12.0, 13.0, 14.0, 15.0, 16.0];

    final currentFont = settings.terminalFontFamily ?? 'SF Mono';
    final currentSize = settings.terminalFontSize ?? 13.0;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _DropdownField<String>(
            label: 'Font',
            value: currentFont,
            items: fonts
                .map(
                  (f) => DropdownMenuItem(
                    value: f,
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        fontFamily: f,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => provider.updateTerminalFontFamily(v),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _DropdownField<double>(
            label: 'Size',
            value: currentSize,
            items: sizes
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      '${s.toInt()} px',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => provider.updateTerminalFontSize(v),
          ),
        ),
      ],
    );
  }

  Widget _buildCopilotButtonOptions(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    return Row(
      children: [
        _OptionCard(
          label: 'In-App',
          icon: Icons.auto_awesome_rounded,
          isSelected: settings.copilotButtonMode == CopilotButtonMode.inApp,
          onTap: () =>
              provider.updateCopilotButtonMode(CopilotButtonMode.inApp),
        ),
        const SizedBox(width: 8),
        _OptionCard(
          label: 'External',
          icon: Icons.open_in_new_rounded,
          isSelected: settings.copilotButtonMode == CopilotButtonMode.external,
          onTap: () =>
              provider.updateCopilotButtonMode(CopilotButtonMode.external),
        ),
      ],
    );
  }

  Widget _buildOpenAiSettings(AppSettings settings, SettingsProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _openAiApiKeyController,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            labelText: 'API key',
            labelStyle: TextStyle(color: AppColors.textMuted),
            hintText: 'sk-...',
            hintStyle: TextStyle(
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent),
            ),
            filled: true,
            fillColor: AppColors.surface0,
          ),
          onChanged: (value) {
            provider.updateOpenAiApiKey(value);
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Stored directly in the app config file.',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _openAiTranscriptionModelController,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            labelText: 'Transcription model',
            labelStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent),
            ),
            filled: true,
            fillColor: AppColors.surface0,
          ),
          onChanged: (value) {
            if (value.trim().isEmpty) {
              return;
            }
            provider.updateOpenAiTranscriptionModel(value.trim());
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _openAiResponseModelController,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          decoration: InputDecoration(
            labelText: 'Response model',
            labelStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.accent),
            ),
            filled: true,
            fillColor: AppColors.surface0,
          ),
          onChanged: (value) {
            if (value.trim().isEmpty) {
              return;
            }
            provider.updateOpenAiResponseModel(value.trim());
          },
        ),
      ],
    );
  }

  Widget _buildRemoteControlSettings(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    final isEnabled = settings.remoteControlEnabled;
    final bindAddress = settings.remoteControlBindAddress;
    final port = settings.remoteControlPort;
    final url = 'http://$bindAddress:$port';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Serve Copilot terminals via web browser',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Switch(
              value: isEnabled,
              activeTrackColor: AppColors.accent,
              onChanged: (v) => provider.updateRemoteControlEnabled(v),
            ),
          ],
        ),
        if (isEnabled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _DropdownField<String>(
                  label: 'Bind address',
                  value: bindAddress,
                  items: const [
                    DropdownMenuItem(
                      value: '127.0.0.1',
                      child: Text('localhost', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: '0.0.0.0',
                      child: Text(
                        'All interfaces',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) provider.updateRemoteControlBindAddress(v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Port',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _remotePortController,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.accent),
                          ),
                          filled: true,
                          fillColor: AppColors.surface0,
                        ),
                        onChanged: (value) {
                          final parsed = int.tryParse(value);
                          if (parsed != null && parsed > 0 && parsed < 65536) {
                            provider.updateRemoteControlPort(parsed);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            url,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.accent,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCopilotAttentionSoundSettings(
    AppSettings settings,
    SettingsProvider provider,
  ) {
    if (!Platform.isMacOS) {
      return Text(
        'Copilot attention sounds are currently available on macOS only.',
        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Play a system sound when Copilot needs your attention',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            Switch(
              value: settings.copilotAttentionSoundEnabled,
              activeTrackColor: AppColors.accent,
              onChanged: (value) =>
                  provider.updateCopilotAttentionSoundEnabled(value),
            ),
          ],
        ),
        if (settings.copilotAttentionSoundEnabled) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _DropdownField<CopilotAttentionSound>(
                  label: 'Sound',
                  value: settings.copilotAttentionSound,
                  items: _soundService.supportedCopilotAttentionSounds
                      .map(
                        (sound) => DropdownMenuItem(
                          value: sound,
                          child: Text(
                            sound.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      provider.updateCopilotAttentionSound(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 36,
                child: TextButton.icon(
                  onPressed: () => _previewCopilotAttentionSound(settings),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surface0,
                    foregroundColor: AppColors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text(
                    'Preview',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildConfigFileLink() {
    return FutureBuilder<String>(
      future: ConfigService().getConfigPath(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final path = snapshot.data!;
        return GestureDetector(
          onTap: () => Process.run('open', [path]),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              path,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.accent,
                fontFamily: 'monospace',
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _previewCopilotAttentionSound(AppSettings settings) async {
    try {
      await _soundService.playSystemSound(settings.copilotAttentionSound);
    } on MissingPluginException catch (error) {
      _showPreviewError(error.message ?? error.toString());
    } on PlatformException catch (error) {
      _showPreviewError(error.message ?? error.toString());
    } on UnsupportedError catch (error) {
      _showPreviewError(error.message ?? error.toString());
    }
  }

  void _showPreviewError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ThemeCard extends StatefulWidget {
  final String label;
  final AppColorPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.label,
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 90,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppColors.accentMuted
                : _hovered
                ? AppColors.surface2
                : AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.accent.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              // Mini preview swatch
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: p.base,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: p.border, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(p.accent),
                    _dot(p.terminal),
                    _dot(p.copilot),
                    _dot(p.vscode),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable option card (terminal app picker)
// ---------------------------------------------------------------------------

class _OptionCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? AppColors.accentMuted
                  : _hovered
                  ? AppColors.surface2
                  : AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.accent.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.isSelected
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown field helper
// ---------------------------------------------------------------------------

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.surface1,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              icon: Icon(
                Icons.expand_more,
                size: 16,
                color: AppColors.textMuted,
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
