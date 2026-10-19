import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/workspace/domain/repo_config.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// State of a repo settings section that edits its own copy of the selected
/// repo's settings: [loadFrom] fills the copy when the section opens and when
/// another repo gets selected, and [saveLater] saves it after a pause, so
/// typing doesn't save on every key.
mixin RepoSettingsSectionState<T extends StatefulWidget> on State<T> {
  String? _repoPath;
  Timer? _saveTimer;

  /// Fills the section's copy from [repo]; null when no repo is selected.
  void loadFrom(RepoConfig? repo);

  @override
  void initState() {
    super.initState();
    final repo = context.read<WorkspaceController>().selectedRepo;
    _repoPath = repo?.path;
    loadFrom(repo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = context.read<WorkspaceController>().selectedRepo;
    if (repo != null && repo.path != _repoPath) {
      _repoPath = repo.path;
      loadFrom(repo);
    }
  }

  /// Runs [save] with the selected repo after [delay], unless this is called
  /// again (or [cancelSave]) first.
  void saveLater(
    void Function(WorkspaceController workspace, RepoConfig repo) save, {
    Duration delay = const Duration(milliseconds: 300),
  }) {
    _saveTimer?.cancel();
    _saveTimer = Timer(delay, () {
      final workspace = context.read<WorkspaceController>();
      final repo = workspace.selectedRepo;
      if (repo != null) save(workspace, repo);
    });
  }

  /// Drops a save [saveLater] has pending.
  void cancelSave() => _saveTimer?.cancel();

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
