import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/settings_controls.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/repo_settings/repo_settings_section_state.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

class RepoVscodeConfigsSection extends StatefulWidget {
  const RepoVscodeConfigsSection({super.key});

  @override
  State<RepoVscodeConfigsSection> createState() => _VscodeConfigsSectionState();
}

class _VscodeConfigsSectionState extends State<RepoVscodeConfigsSection>
    with RepoSettingsSectionState {
  late List<VscodeConfig> _configs;

  @override
  void loadFrom(RepoConfig? repo) {
    _configs = List.from(repo?.vscodeConfigs ?? []);
  }

  void _save() {
    saveLater((provider, repo) {
      final cleaned = _configs
          .where((c) => c.name.trim().isNotEmpty || c.path.trim().isNotEmpty)
          .map((c) => VscodeConfig(name: c.name.trim(), path: c.path.trim()))
          .toList();
      provider.updateRepoVscodeConfigs(repo, cleaned);
    });
  }

  void _addConfig() {
    setState(() {
      _configs.add(VscodeConfig(name: '', path: ''));
    });
  }

  void _removeConfig(int index) {
    setState(() {
      _configs.removeAt(index);
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VS Code Configs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configure VS Code workspace paths relative to the worktree directory',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SettingsAddButton(
                label: 'Add Config',
                color: AppColors.vscode,
                bgColor: AppColors.vscodeBg,
                onTap: _addConfig,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_configs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.code_rounded,
                    size: 32,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No VS Code configs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The VS Code button will open the worktree root by default.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_configs.length, (index) {
              return _VscodeConfigCard(
                key: ValueKey('vsc_$index'),
                config: _configs[index],
                onChanged: (config) {
                  setState(() => _configs[index] = config);
                  _save();
                },
                onRemove: () => _removeConfig(index),
              );
            }),
        ],
      ),
    );
  }
}

class _VscodeConfigCard extends StatefulWidget {
  final VscodeConfig config;
  final ValueChanged<VscodeConfig> onChanged;
  final VoidCallback onRemove;

  const _VscodeConfigCard({
    super.key,
    required this.config,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_VscodeConfigCard> createState() => _VscodeConfigCardState();
}

class _VscodeConfigCardState extends State<_VscodeConfigCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.config.name);
    _pathController = TextEditingController(text: widget.config.path);
  }

  @override
  void didUpdateWidget(_VscodeConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Cards are keyed by index, so removing one reuses State for a different
    // config. Re-sync controllers when the underlying config differs.
    if (widget.config.name != _nameController.text) {
      _nameController.text = widget.config.name;
    }
    if (widget.config.path != _pathController.text) {
      _pathController.text = widget.config.path;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name field
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NAME',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  style: appFormFieldTextStyle(context),
                  decoration: const InputDecoration(hintText: 'e.g. Frontend'),
                  controller: _nameController,
                  onChanged: (v) => widget.onChanged(
                    VscodeConfig(name: v, path: widget.config.path),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Path field
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PATH',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  style: appFormFieldTextStyle(context, monospace: true),
                  decoration: InputDecoration(
                    hintText: 'Relative path (e.g. frontend/)',
                    hintStyle: appFormFieldHintStyle(context, monospace: true),
                  ),
                  controller: _pathController,
                  onChanged: (v) => widget.onChanged(
                    VscodeConfig(name: widget.config.name, path: v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Remove button
          Padding(
            padding: const EdgeInsets.only(top: 22),
            child: SettingsRemoveButton(onTap: widget.onRemove),
          ),
        ],
      ),
    );
  }
}
