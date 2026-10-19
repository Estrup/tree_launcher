import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/use_cases/agent_api_control.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/settings_small_button.dart';

class AgentApiSettingsSection extends StatefulWidget {
  const AgentApiSettingsSection({super.key});

  @override
  State<AgentApiSettingsSection> createState() => _AgentApiSectionState();
}

class _AgentApiSectionState extends State<AgentApiSettingsSection> {
  late final TextEditingController _portController;
  final FocusNode _portFocus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    // A debug override (--dart-define=AGENT_API_PORT) wins over the saved
    // config and must never be written back, so the field shows it read-only.
    _portController = TextEditingController(
      text: context.read<AgentApiControl>().configuredPort.toString(),
    );
    // Commit when the field loses focus, mirroring onSubmitted.
    _portFocus.addListener(() {
      if (!_portFocus.hasFocus) _commitPort();
    });
  }

  @override
  void dispose() {
    _portController.dispose();
    _portFocus.dispose();
    super.dispose();
  }

  Future<void> _commitPort() async {
    final api = context.read<AgentApiControl>();
    // Never persist while a debug override is active.
    if (api.portOverride != null) return;
    final port = int.tryParse(_portController.text.trim());

    if (port == null || port < 1024 || port > 65535) {
      setState(() => _error = 'Enter a port between 1024 and 65535');
      return;
    }
    setState(() => _error = null);
    await api.changePort(port);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final api = context.watch<AgentApiControl>();
    final running = api.isRunning;
    final activePort = api.port;
    final overridden = api.portOverride != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agent API',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Local HTTP API for AI agents, bound to 127.0.0.1',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'PORT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 160,
            child: TextField(
              style: appFormFieldTextStyle(context, monospace: true),
              decoration: InputDecoration(
                hintText: '8765',
                hintStyle: appFormFieldHintStyle(context, monospace: true),
              ),
              controller: _portController,
              focusNode: _portFocus,
              enabled: !overridden,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _commitPort(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            overridden
                ? 'Debug override from --dart-define=AGENT_API_PORT. The saved '
                      'config port (${settings.agentApiPort}) is unchanged and '
                      'will be used on a normal launch.'
                : _error ??
                      'Changing the port restarts the service immediately. '
                          'Takes effect on next launch too.',
            style: TextStyle(
              fontSize: 10,
              color: _error != null && !overridden
                  ? AppColors.error
                  : AppColors.textMuted.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              SettingsSmallButton(
                label: api.restarting ? 'Restarting…' : 'Restart service',
                icon: Icons.refresh_rounded,
                onTap: api.restart,
              ),
              const SizedBox(width: 12),
              Icon(
                running ? Icons.circle : Icons.circle_outlined,
                size: 9,
                color: running ? AppColors.success : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                running
                    ? 'Running on http://127.0.0.1:$activePort'
                    : 'Not running',
                style: TextStyle(
                  fontSize: 12,
                  color: running
                      ? AppColors.textSecondary
                      : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
