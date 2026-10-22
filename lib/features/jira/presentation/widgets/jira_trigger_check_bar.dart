import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/app/use_cases/jira_trigger_watcher.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/jira/domain/jira_trigger_schedule.dart';

/// When Jira was last and is next checked for triggers, with a button to
/// check now. Shows nothing where the app's watcher isn't provided.
class JiraTriggerCheckBar extends StatelessWidget {
  const JiraTriggerCheckBar({super.key});

  @override
  Widget build(BuildContext context) {
    final watcher = Provider.of<JiraTriggerWatcher?>(context);
    if (watcher == null) return const SizedBox.shrink();
    final last = watcher.lastCheck;
    final next = watcher.nextTick;
    final schedule = watcher.schedule;
    String time(DateTime t) => formatTimeOfDay(t.hour * 60 + t.minute);
    final parts = [
      if (watcher.isChecking)
        'Checking…'
      else if (last == null)
        'Not checked yet'
      else
        'Last checked ${time(last.at)}: ${last.triggers} '
            'trigger${last.triggers == 1 ? '' : 's'}, ${last.started} started'
            '${last.failed > 0 ? ', ${last.failed} failed' : ''}',
      if (schedule != null && !schedule.enabled)
        'checks are off'
      else if (next != null)
        schedule != null && !schedule.isActiveAt(next)
            ? 'next at ${time(next)} is outside the hours'
            : 'next at ${time(next)}',
    ];
    return Row(
      children: [
        Flexible(
          child: Text(
            parts.join(' · '),
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: watcher.isChecking ? null : watcher.checkNow,
          icon: watcher.isChecking
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Check now'),
        ),
      ],
    );
  }
}
