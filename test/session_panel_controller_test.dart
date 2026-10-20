import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/features/session_panel/presentation/controllers/session_panel_controller.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_status.dart';

import 'test_database.dart';

class _FakeGitService extends GitService {
  int calls = 0;
  Object? error;

  @override
  Future<WorktreeStatus> worktreeStatus(
    String worktreePath, {
    String? baseBranch,
  }) async {
    calls++;
    await Future<void>.delayed(Duration.zero);
    if (error != null) throw error!;
    return WorktreeStatus(branch: 'feature', base: baseBranch);
  }
}

void main() {
  const wt = '/repos/app-au2-1';
  const a = '/repos/app-au2-1/lib/a.dart';
  const b = '/repos/app-au2-1/lib/b.dart';
  const c = '/repos/app-au2-1/.factory/spec.md';

  late _FakeGitService git;
  late SessionPanelController controller;

  setUp(() {
    git = _FakeGitService();
    controller = SessionPanelController(git: git);
  });

  tearDown(() => controller.dispose());

  test('starts on Info with Info and Files', () {
    expect(controller.tabsFor(wt), [
      SessionPanelTab.info,
      SessionPanelTab.files,
    ]);
    expect(controller.selectedFor(wt), SessionPanelTab.info);
  });

  test('opening a file adds a tab once and selects it', () {
    controller.openFile(wt, a);
    controller.openFile(wt, b);
    controller.select(wt, SessionPanelTab.files);
    controller.openFile(wt, a);

    expect(controller.tabsFor(wt), [
      SessionPanelTab.info,
      SessionPanelTab.files,
      const SessionPanelTab.file(a),
      const SessionPanelTab.file(b),
    ]);
    expect(controller.selectedFor(wt), const SessionPanelTab.file(a));
    expect(const SessionPanelTab.file(c).title, 'spec.md');
  });

  test('closing the selected tab selects the next, then the one before', () {
    controller
      ..openFile(wt, a)
      ..openFile(wt, b)
      ..openFile(wt, c)
      ..select(wt, const SessionPanelTab.file(b));

    controller.closeTab(wt, const SessionPanelTab.file(b));
    expect(controller.selectedFor(wt), const SessionPanelTab.file(c));

    controller.closeTab(wt, const SessionPanelTab.file(c));
    expect(controller.selectedFor(wt), const SessionPanelTab.file(a));

    controller.closeTab(wt, const SessionPanelTab.file(a));
    expect(controller.selectedFor(wt), SessionPanelTab.files);
  });

  test('closing another tab keeps the selection', () {
    controller
      ..openFile(wt, a)
      ..openFile(wt, b);

    controller.closeTab(wt, const SessionPanelTab.file(a));

    expect(controller.selectedFor(wt), const SessionPanelTab.file(b));
  });

  test('keeps each worktree its own tabs', () {
    controller.openFile(wt, a);

    expect(controller.tabsFor('/repos/other'), hasLength(2));
    expect(controller.selectedFor('/repos/other'), SessionPanelTab.info);
    expect(controller.selectedFor(wt), const SessionPanelTab.file(a));
  });

  test('does not select a file tab that is not open', () {
    controller.select(wt, const SessionPanelTab.file(a));

    expect(controller.selectedFor(wt), SessionPanelTab.info);
  });

  test('fit keeps the panel within its limits', () {
    // Plenty of room: the chosen width.
    expect(SessionPanelController.fit(380, 1400), 380);
    // Never under the minimum.
    expect(SessionPanelController.fit(100, 1400), 260);
    // At most 60% of the view.
    expect(SessionPanelController.fit(1200, 1400), 840);
    // The terminal keeps its minimum.
    expect(SessionPanelController.fit(500, 800), 380);
    // No room: no panel.
    expect(SessionPanelController.fit(380, 600), 0);
  });

  test('a status read joins the one under way and keeps its error', () async {
    final first = controller.refreshStatus(wt, baseBranch: 'develop');
    final second = controller.refreshStatus(wt, baseBranch: 'develop');
    expect(controller.isLoadingStatus(wt), isTrue);
    await Future.wait([first, second]);

    expect(git.calls, 1);
    expect(controller.isLoadingStatus(wt), isFalse);
    expect(controller.statusFor(wt)?.branch, 'feature');
    expect(controller.statusFor(wt)?.base, 'develop');

    git.error = Exception('not a git repository');
    await controller.refreshStatus(wt);

    expect(controller.statusErrorFor(wt), 'not a git repository');
    // The last status read is kept.
    expect(controller.statusFor(wt)?.branch, 'feature');
  });

  test('remembers the width and whether it shows', () async {
    final store = UiStateStore(testDatabase());
    final first = SessionPanelController(git: git, uiState: store);
    first.setWidth(150);
    expect(first.width, SessionPanelController.minWidth);
    first.setWidth(450);
    first.toggle();
    expect(first.isOpen, isFalse);
    // Let the writes land.
    await pumpEventQueue();
    first.dispose();

    final second = SessionPanelController(git: git, uiState: store);
    await second.load();

    expect(second.width, 450);
    expect(second.isOpen, isFalse);
    second.dispose();
  });
}
