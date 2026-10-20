import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/core/database/ui_state_store.dart';
import 'package:tree_launcher/core/errors/user_message.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_status.dart';

enum SessionPanelTabKind { info, files, file }

/// One tab of the session panel: Info, Files, or an open file.
class SessionPanelTab {
  const SessionPanelTab._(this.kind, [this.path]);

  static const info = SessionPanelTab._(SessionPanelTabKind.info);
  static const files = SessionPanelTab._(SessionPanelTabKind.files);

  /// The tab of the file at [path].
  const SessionPanelTab.file(String path)
    : this._(SessionPanelTabKind.file, path);

  final SessionPanelTabKind kind;

  /// The open file's absolute path; null for Info and Files.
  final String? path;

  String get title => switch (kind) {
    SessionPanelTabKind.info => 'Info',
    SessionPanelTabKind.files => 'Files',
    SessionPanelTabKind.file => p.basename(path!),
  };

  @override
  bool operator ==(Object other) =>
      other is SessionPanelTab && other.kind == kind && other.path == path;

  @override
  int get hashCode => Object.hash(kind, path);
}

/// What the panel shows for one worktree.
class _WorktreePanel {
  final List<SessionPanelTab> files = [];
  SessionPanelTab selected = SessionPanelTab.info;
  WorktreeStatus? status;
  String? statusError;
  Future<void>? statusLoad;
}

/// The panel beside a Claude session in the built-in terminal: whether it
/// shows, its width (both remembered), and per worktree its open file tabs,
/// selected tab and git status. Kept per worktree so switching sessions
/// switches the panel, and coming back finds it as it was.
class SessionPanelController extends ChangeNotifier {
  SessionPanelController({required GitService git, UiStateStore? uiState})
    : _git = git,
      _uiState = uiState;

  final GitService _git;

  /// Where the width and shown state are remembered; null keeps them in
  /// memory only.
  final UiStateStore? _uiState;

  static const minWidth = 260.0;
  static const defaultWidth = 380.0;

  /// The terminal keeps at least this much beside the panel.
  static const minTerminalWidth = 420.0;

  /// The panel takes at most this share of the view.
  static const maxShare = 0.6;

  static const _widthKey = 'sessionPanelWidth';
  static const _openKey = 'sessionPanelOpen';

  double _width = defaultWidth;
  bool _open = true;
  final Map<String, _WorktreePanel> _panels = {};
  bool _disposed = false;

  /// The width the user chose; see [fit] for the one laid out.
  double get width => _width;

  /// Whether the panel shows beside Claude sessions.
  bool get isOpen => _open;

  /// Reads the remembered width and shown state. Never throws.
  Future<void> load() async {
    final store = _uiState;
    if (store == null) return;
    try {
      final saved = await store.read(UiStateStore.appScope);
      final width = saved[_widthKey];
      if (width is num) _width = math.max(minWidth, width.toDouble());
      final open = saved[_openKey];
      if (open is bool) _open = open;
      _notify();
    } catch (e) {
      debugPrint('Loading the session panel state failed: $e');
    }
  }

  /// The width to lay the panel out at in a view [available] wide: [width]
  /// within [minWidth] and [maxShare] of the view, leaving the terminal
  /// [minTerminalWidth]. Zero when there isn't room for even [minWidth].
  static double fit(double width, double available) {
    final max = math.min(available * maxShare, available - minTerminalWidth);
    if (max < minWidth) return 0;
    return width.clamp(minWidth, max);
  }

  void toggle() {
    _open = !_open;
    _notify();
    _save({_openKey: _open});
  }

  /// Sets the chosen width (at least [minWidth]) and remembers it.
  void setWidth(double width) {
    final next = math.max(minWidth, width);
    if (next == _width) return;
    _width = next;
    _notify();
    _save({_widthKey: _width});
  }

  _WorktreePanel _panel(String worktree) =>
      _panels.putIfAbsent(worktree, _WorktreePanel.new);

  /// Info, Files, then the files open in [worktree], in the order opened.
  List<SessionPanelTab> tabsFor(String worktree) => [
    SessionPanelTab.info,
    SessionPanelTab.files,
    ...?_panels[worktree]?.files,
  ];

  SessionPanelTab selectedFor(String worktree) =>
      _panels[worktree]?.selected ?? SessionPanelTab.info;

  void select(String worktree, SessionPanelTab tab) {
    final panel = _panel(worktree);
    if (tab.kind == SessionPanelTabKind.file && !panel.files.contains(tab)) {
      return;
    }
    if (panel.selected == tab) return;
    panel.selected = tab;
    _notify();
  }

  /// Opens the file at [path] in a tab of [worktree]'s panel and selects
  /// it; selects its tab when it is already open.
  void openFile(String worktree, String path) {
    final panel = _panel(worktree);
    final tab = SessionPanelTab.file(path);
    if (!panel.files.contains(tab)) panel.files.add(tab);
    panel.selected = tab;
    _notify();
  }

  /// Closes a file [tab] of [worktree]'s panel. When it was selected, the
  /// tab after it is selected, else the one before (Files after the last).
  void closeTab(String worktree, SessionPanelTab tab) {
    final panel = _panels[worktree];
    if (panel == null) return;
    final index = panel.files.indexOf(tab);
    if (index == -1) return;
    panel.files.removeAt(index);
    if (panel.selected == tab) {
      panel.selected = panel.files.isEmpty
          ? SessionPanelTab.files
          : panel.files[math.min(index, panel.files.length - 1)];
    }
    _notify();
  }

  /// The git status last read for [worktree]; null before the first read.
  WorktreeStatus? statusFor(String worktree) => _panels[worktree]?.status;

  /// Why the last status read for [worktree] failed; null when it worked.
  String? statusErrorFor(String worktree) => _panels[worktree]?.statusError;

  /// Whether a status read for [worktree] is under way.
  bool isLoadingStatus(String worktree) =>
      _panels[worktree]?.statusLoad != null;

  /// Reads [worktree]'s git status again, comparing it to [baseBranch]. A
  /// call while one is under way joins it. Never throws.
  Future<void> refreshStatus(String worktree, {String? baseBranch}) {
    final panel = _panel(worktree);
    final running = panel.statusLoad;
    if (running != null) return running;
    _notify();
    return panel.statusLoad = () async {
      try {
        panel.status = await _git.worktreeStatus(
          worktree,
          baseBranch: baseBranch,
        );
        panel.statusError = null;
      } catch (e) {
        panel.statusError = userMessage(e);
      } finally {
        panel.statusLoad = null;
        _notify();
      }
    }();
  }

  void _save(Map<String, Object?> values) {
    final store = _uiState;
    if (store == null) return;
    unawaited(
      store
          .write(UiStateStore.appScope, values)
          .catchError(
            (Object e) => debugPrint('Saving the session panel failed: $e'),
          ),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
