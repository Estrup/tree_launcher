import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/activity/data/claude_session_activity.dart';
import 'package:tree_launcher/features/activity/data/manual_post_store.dart';
import 'package:tree_launcher/features/activity/data/worktree_event_store.dart';
import 'package:tree_launcher/features/activity/domain/activity_entry.dart';
import 'package:tree_launcher/features/activity/domain/activity_filter.dart';
import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/workspace/domain/worktree.dart';
import 'package:tree_launcher/models/manual_post.dart';

// Re-exported so existing imports of `ActivityEntry` via this controller keep
// working now that the model lives in the domain layer.
export 'package:tree_launcher/features/activity/domain/activity_entry.dart';

class ActivityController extends ChangeNotifier {
  ActivityController({
    WorktreeEventStore? eventStore,
    ClaudeSessionActivity? claudeActivity,
    ManualPostStore? manualPostStore,
    ActivityService? service,
  }) : _manualPostStore = manualPostStore ?? ManualPostStore(),
       _service =
           service ??
           ActivityService(
             eventStore: eventStore,
             claudeActivity: claudeActivity,
             manualPostStore: manualPostStore,
           );

  final ActivityService _service;
  final ManualPostStore _manualPostStore;

  /// Live worktrees from the last [load], reused when a manual post is
  /// added/removed so the reload keeps the same worktree context.
  List<Worktree> _lastWorktrees = const [];

  bool _loading = false;
  bool get loading => _loading;

  List<ActivityEntry> _entries = [];
  List<ActivityEntry> get entries => List.unmodifiable(_entries);

  ActivityFilter _filter = ActivityFilter.all;
  ActivityFilter get filter => _filter;

  void setFilter(ActivityFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  /// Entries narrowed to the active [filter]. Evaluated against the current
  /// wall clock so "Today"/"This week" stay correct without a reload.
  List<ActivityEntry> get filteredEntries {
    final range = _filter.range(DateTime.now());
    if (range == null) return List.unmodifiable(_entries);
    return _entries.where((e) => e.matchesRange(range)).toList();
  }

  /// Loads the timeline. [currentWorktrees] are the live worktrees of the
  /// selected repo — they're folded in so worktrees that predate the event log
  /// (or were never created through this app) still appear, populated from
  /// their Claude session history.
  Future<void> load({List<Worktree> currentWorktrees = const []}) async {
    _lastWorktrees = currentWorktrees;
    _loading = true;
    notifyListeners();

    try {
      _entries = await _service.loadEntries(currentWorktrees: currentWorktrees);
    } catch (e) {
      debugPrint('ActivityController.load failed: $e');
      _entries = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Logs a manual activity post (work done outside any worktree), stamped at
  /// the current time, then reloads the timeline.
  Future<void> addManualPost({
    required String repoName,
    required String issueKey,
    String description = '',
    double? hours,
  }) async {
    await _manualPostStore.add(
      ManualPost(
        id: ManualPost.newId(),
        timestamp: DateTime.now(),
        repoName: repoName,
        issueKey: issueKey,
        description: description,
        hours: hours,
      ),
    );
    await load(currentWorktrees: _lastWorktrees);
  }

  /// Removes a previously logged manual post by id, then reloads.
  Future<void> deleteManualPost(String id) async {
    await _manualPostStore.delete(id);
    await load(currentWorktrees: _lastWorktrees);
  }
}
