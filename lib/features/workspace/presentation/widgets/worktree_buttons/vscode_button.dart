import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/features/workspace/domain/vscode_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/action_buttons.dart';

class VscodeButton extends StatefulWidget {
  final String worktreePath;
  final LauncherService launcherService;
  final bool compact;

  /// Folders offered in the dropdown; null uses the selected repo's.
  final List<VscodeConfig>? configs;

  const VscodeButton({
    super.key,
    required this.worktreePath,
    required this.launcherService,
    this.compact = false,
    this.configs,
  });

  @override
  State<VscodeButton> createState() => _VscodeButtonState();
}

class _VscodeButtonState extends State<VscodeButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  void _showDropdown(BuildContext context, List<dynamic> configs) {
    showMenuBelow<String>(
      context,
      minWidth: 280,
      items: [
        PopupMenuItem<String>(
          value: '.',
          height: 36,
          child: Row(
            children: [
              SvgPicture.asset(
                'assets/icons/vscode.svg',
                width: 13,
                height: 13,
                colorFilter: ColorFilter.mode(
                  AppColors.vscode,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Open at root',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        ...configs.map((config) {
          return PopupMenuItem<String>(
            value: config.path as String,
            height: 36,
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/vscode.svg',
                  width: 13,
                  height: 13,
                  colorFilter: ColorFilter.mode(
                    AppColors.vscode,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  config.name as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.path as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ).then((selectedPath) {
      if (selectedPath == null) return;
      final resolved = selectedPath == '.'
          ? widget.worktreePath
          : p.join(widget.worktreePath, selectedPath);
      widget.launcherService.openVSCode(resolved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final configs =
        widget.configs ??
        context.watch<WorkspaceController>().selectedRepo?.vscodeConfigs ??
        [];
    final hasConfigs = configs.isNotEmpty;

    if (widget.compact) {
      final vscodeIcon = SvgPicture.asset(
        'assets/icons/vscode.svg',
        width: 14,
        height: 14,
        colorFilter: ColorFilter.mode(AppColors.vscode, BlendMode.srcIn),
      );
      return CompactActionButton(
        color: AppColors.vscode,
        bgColor: AppColors.vscodeBg,
        tooltip: 'VS Code',
        icon: vscodeIcon,
        onPrimary: () => widget.launcherService.openVSCode(widget.worktreePath),
        onDropdown: hasConfigs ? () => _showDropdown(context, configs) : null,
      );
    }

    if (!hasConfigs) {
      return Tooltip(
        message: 'VS Code',
        child: ActionButton(
          svgAsset: 'assets/icons/vscode.svg',
          color: AppColors.vscode,
          bgColor: AppColors.vscodeBg,
          onPressed: () =>
              widget.launcherService.openVSCode(widget.worktreePath),
        ),
      );
    }

    return SizedBox(
      width: 60,
      height: 36,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: AppColors.vscodeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (_mainHovered || _dropHovered)
                ? AppColors.vscode.withValues(alpha: 0.4)
                : AppColors.vscode.withValues(alpha: 0.15),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Row(
            children: [
              Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _mainHovered = true),
                  onExit: (_) => setState(() => _mainHovered = false),
                  child: GestureDetector(
                    onTap: () =>
                        widget.launcherService.openVSCode(widget.worktreePath),
                    child: Tooltip(
                      message: 'VS Code',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        color: _mainHovered
                            ? AppColors.vscode.withValues(alpha: 0.2)
                            : Colors.transparent,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/vscode.svg',
                            width: 15,
                            height: 15,
                            colorFilter: ColorFilter.mode(
                              AppColors.vscode,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                color: AppColors.vscode.withValues(alpha: 0.15),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _dropHovered = true),
                onExit: (_) => setState(() => _dropHovered = false),
                child: GestureDetector(
                  onTap: () => _showDropdown(context, configs),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 28,
                    color: _dropHovered
                        ? AppColors.vscode.withValues(alpha: 0.2)
                        : Colors.transparent,
                    child: Center(
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.vscode,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Claude button
// ---------------------------------------------------------------------------
