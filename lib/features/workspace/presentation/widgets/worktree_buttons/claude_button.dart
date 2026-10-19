import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/launcher_service.dart';
import 'package:tree_launcher/features/agents/domain/claude_prompt.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_buttons/action_buttons.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/worktree_actions.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_prompts.dart';

class ClaudeButton extends StatefulWidget {
  final Worktree wt;
  final LauncherService launcherService;
  final bool compact;

  const ClaudeButton({
    super.key,
    required this.wt,
    required this.launcherService,
    this.compact = false,
  });

  @override
  State<ClaudeButton> createState() => _ClaudeButtonState();
}

class _ClaudeButtonState extends State<ClaudeButton> {
  bool _mainHovered = false;
  bool _dropHovered = false;

  /// Launches Claude with the auto-generated context prompt (today's behavior).
  void _openWithContext() {
    widget.launcherService.openClaude(
      widget.wt.path,
      prompt: claudeContextPrompt(widget.wt),
    );
  }

  void _showDropdown(BuildContext context, List<ClaudePrompt> prompts) {
    final repoName = context.read<WorkspaceController>().selectedRepo?.name;
    final prNumber = openPrNumberForBranch(context, widget.wt.branch);
    final claudeIcon = SvgPicture.asset(
      'assets/icons/claude.svg',
      width: 13,
      height: 13,
      colorFilter: ColorFilter.mode(AppColors.claude, BlendMode.srcIn),
    );
    final hasKickoff = widget.wt.kickoffPromptPath != null;
    showMenuBelow<int>(
      context,
      minWidth: 220,
      items: [
        PopupMenuItem<int>(
          value: -1,
          height: 36,
          child: Text(
            'None',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ),
        if (hasKickoff)
          PopupMenuItem<int>(
            value: -2,
            height: 36,
            child: Row(
              children: [
                claudeIcon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kickoff prompt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        for (var i = 0; i < prompts.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 36,
            child: Row(
              children: [
                claudeIcon,
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prompts[i].name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == -1) {
        _openWithContext();
        return;
      }
      if (value == -2) {
        widget.launcherService.openClaude(
          widget.wt.path,
          prompt: kickoffPromptLaunchPrompt(widget.wt),
        );
        return;
      }
      widget.launcherService.openClaude(
        widget.wt.path,
        prompt: resolveWorktreePrompt(
          prompts[value],
          widget.wt,
          repoName: repoName,
          prNumber: prNumber,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<WorkspaceController>().selectedRepo;
    final prompts = repo?.claudePrompts ?? const <ClaudePrompt>[];
    final hasKickoff = widget.wt.kickoffPromptPath != null;
    // The dropdown is worth showing when there are configured prompts or this
    // worktree has an API-supplied kickoff prompt to launch.
    final hasPrompts = prompts.isNotEmpty || hasKickoff;

    if (widget.compact) {
      final claudeIcon = SvgPicture.asset(
        'assets/icons/claude.svg',
        width: 14,
        height: 14,
        colorFilter: ColorFilter.mode(AppColors.claude, BlendMode.srcIn),
      );
      return CompactActionButton(
        color: AppColors.claude,
        bgColor: AppColors.claudeBg,
        tooltip: 'Claude',
        icon: claudeIcon,
        onPrimary: _openWithContext,
        onDropdown: hasPrompts ? () => _showDropdown(context, prompts) : null,
      );
    }

    if (!hasPrompts) {
      return Tooltip(
        message: 'Claude',
        child: ActionButton(
          svgAsset: 'assets/icons/claude.svg',
          color: AppColors.claude,
          bgColor: AppColors.claudeBg,
          onPressed: _openWithContext,
        ),
      );
    }

    return SizedBox(
      width: 60,
      height: 36,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: AppColors.claudeBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (_mainHovered || _dropHovered)
                ? AppColors.claude.withValues(alpha: 0.4)
                : AppColors.claude.withValues(alpha: 0.15),
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
                    onTap: _openWithContext,
                    child: Tooltip(
                      message: 'Claude',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        color: _mainHovered
                            ? AppColors.claude.withValues(alpha: 0.2)
                            : Colors.transparent,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/claude.svg',
                            width: 15,
                            height: 15,
                            colorFilter: ColorFilter.mode(
                              AppColors.claude,
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
                color: AppColors.claude.withValues(alpha: 0.15),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _dropHovered = true),
                onExit: (_) => setState(() => _dropHovered = false),
                child: GestureDetector(
                  onTap: () => _showDropdown(context, prompts),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 28,
                    color: _dropHovered
                        ? AppColors.claude.withValues(alpha: 0.2)
                        : Colors.transparent,
                    child: Center(
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: AppColors.claude,
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
