import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

class HelpSettingsSection extends StatelessWidget {
  const HelpSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    const shortcuts = [
      (
        keys: ['⌘', '`'],
        description: 'Toggle terminal visibility',
      ),
      (
        keys: ['⇧', 'Enter'],
        description: 'Multi-line input in terminal',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Keyboard Shortcuts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Available shortcuts in Tree Launcher.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          ...shortcuts.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ShortcutRow(keys: s.keys, description: s.description),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final List<String> keys;
  final String description;

  const _ShortcutRow({required this.keys, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: keys
                .map(
                  (k) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        k,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
