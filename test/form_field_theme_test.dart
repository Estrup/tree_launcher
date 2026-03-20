import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/copilot/data/sound_service.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/terminal/presentation/controllers/terminal_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/features/workspace/presentation/widgets/add_worktree_dialog.dart';
import 'package:tree_launcher/models/worktree.dart';

void main() {

  testWidgets(
    'text fields and themed dropdowns share the same baseline height',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: const ValueKey('text-field-box'),
                      child: const TextField(
                        decoration: InputDecoration(hintText: 'Worktree name'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      key: const ValueKey('dropdown-box'),
                      child: AppDropdownField<String>(
                        initialValue: 'main',
                        items: const [
                          DropdownMenuItem(value: 'main', child: Text('main')),
                          DropdownMenuItem(
                            value: 'develop',
                            child: Text('develop'),
                          ),
                        ],
                        onChanged: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textHeight = tester
          .getSize(find.byKey(const ValueKey('text-field-box')))
          .height;
      final dropdownHeight = tester
          .getSize(find.byKey(const ValueKey('dropdown-box')))
          .height;

      expect((textHeight - dropdownHeight).abs(), lessThanOrEqualTo(1.0));
    },
  );

  testWidgets(
    'add worktree error fields keep themed shape and padding while turning red',
    (WidgetTester tester) async {
      await tester.pumpWidget(_buildHarness(child: const AddWorktreeDialog()));
      await tester.pumpAndSettle();

      final fieldsBefore = find.byType(TextField);
      final nameHeightBefore = tester.getSize(fieldsBefore.at(0)).height;
      final jiraHeightBefore = tester.getSize(fieldsBefore.at(1)).height;

      await tester.enterText(fieldsBefore.at(0), 'bad!');
      await tester.pump();

      final fieldsAfter = find.byType(TextField);
      final nameField = tester.widget<TextField>(fieldsAfter.at(0));
      final jiraField = tester.widget<TextField>(fieldsAfter.at(1));
      final errorBorder =
          nameField.decoration!.enabledBorder! as OutlineInputBorder;
      final defaultBorder =
          AppTheme.dark.inputDecorationTheme.enabledBorder!
              as OutlineInputBorder;

      expect(errorBorder.borderSide.color, AppColors.error);
      expect(errorBorder.borderRadius, defaultBorder.borderRadius);
      expect(nameField.decoration!.contentPadding, isNull);
      expect(jiraField.decoration!.contentPadding, isNull);
      expect(tester.getSize(fieldsAfter.at(0)).height, nameHeightBefore);
      expect(tester.getSize(fieldsAfter.at(1)).height, jiraHeightBefore);
    },
  );
}

Widget _buildHarness({required Widget child}) {
  final workspace = WorkspaceController(gitService: _FakeGitService());
  final settings = SettingsController();
  final terminal = TerminalController();
  final copilot = CopilotController.create(
    workspaceController: workspace,
    settingsController: settings,
    soundService: SoundService(),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkspaceController>.value(value: workspace),
      ChangeNotifierProvider<SettingsController>.value(value: settings),
      ChangeNotifierProvider<TerminalController>.value(value: terminal),
      ChangeNotifierProvider<CopilotController>.value(value: copilot),
    ],
    child: _DisposableTestApp(
      disposers: [
        copilot.dispose,
        terminal.dispose,
        settings.dispose,
        workspace.dispose,
      ],
      child: child,
    ),
  );
}

class _DisposableTestApp extends StatefulWidget {
  final List<VoidCallback> disposers;
  final Widget child;

  const _DisposableTestApp({required this.disposers, required this.child});

  @override
  State<_DisposableTestApp> createState() => _DisposableTestAppState();
}

class _DisposableTestAppState extends State<_DisposableTestApp> {
  @override
  void dispose() {
    for (final disposer in widget.disposers.reversed) {
      disposer();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Center(child: widget.child)),
    );
  }
}

class _FakeGitService extends GitService {
  @override
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    return WorktreeListResult(worktrees: const [], isBareLayout: false);
  }

  @override
  Future<List<String>> listBranches(String repoPath) async {
    return const ['main', 'develop'];
  }

  @override
  Future<String> addWorktree(
    String repoPath,
    String name, {
    String? baseBranch,
    String? newBranch,
  }) async {
    return '/tmp/${math.max(name.length, 1)}';
  }
}
