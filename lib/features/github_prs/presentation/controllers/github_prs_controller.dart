import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/github_prs/data/github_api_service.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

/// A pending notification that the current user has been asked to review a PR.
class PrReviewNotification {
  final GithubPullRequest pr;

  /// True when the user had previously been requested on this PR (e.g. they
  /// reviewed and the author re-requested), as opposed to a first-time request.
  final bool reRequested;

  PrReviewNotification({required this.pr, required this.reRequested});
}

class GithubPrsController extends ChangeNotifier {
  GithubPrsController({GithubApiService? service})
    : _service = service ?? GithubApiService();

  final GithubApiService _service;

  List<GithubPullRequest> _pullRequests = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefreshed;
  Timer? _pollTimer;
  GithubConfig? _activeConfig;

  /// Path of the repo whose config we last synced to, so app-level repo
  /// switches don't trigger redundant reloads.
  String? _lastSyncedRepoPath;

  /// Login of the user the active token authenticates as. Fetched once per
  /// active config; used to detect PRs that request the current user.
  String? _currentUserLogin;

  /// PR numbers that requested the current user as a reviewer on the previous
  /// successful fetch. Used to detect the absent→present transition that marks
  /// a new request (new PR, added as reviewer, or re-request).
  Set<int> _prsRequestingMe = {};

  /// PR numbers that have requested the current user at any earlier point this
  /// session. Lets us label a fresh request as a re-request when the user was
  /// previously requested and then removed (e.g. after reviewing).
  final Set<int> _everRequestedMe = {};

  bool _hasLoadedOnce = false;

  /// Invoked when the current user is freshly requested as a reviewer on a PR
  /// (new PR, added as reviewer, or re-request). Wired up at the app level to
  /// auto-create a worktree. Only called when the active config opts in.
  void Function(GithubPullRequest pr)? onReviewRequested;

  /// Invoked on every transition into "requested as a reviewer" for a PR,
  /// regardless of the auto-create setting. Wired at the app level to clear a
  /// worktree's snooze so it reappears once the PR is again assigned to me.
  void Function(GithubPullRequest pr)? onRequestedMeTransition;

  /// Queue of review requests that haven't yet been surfaced as a toast.
  final List<PrReviewNotification> _pendingReviewToasts = [];

  List<GithubPullRequest> get pullRequests => _pullRequests;

  /// GitHub login of the authenticated user, or null if unknown.
  String? get currentUserLogin => _currentUserLogin;

  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshed => _lastRefreshed;
  bool get hasPendingReviewToast => _pendingReviewToasts.isNotEmpty;

  /// Removes and returns the next pending review-request notification, or null.
  PrReviewNotification? consumeReviewToast() {
    if (_pendingReviewToasts.isEmpty) return null;
    return _pendingReviewToasts.removeAt(0);
  }

  /// Drives loading off the app-level selected repo so polling and toast
  /// detection run regardless of which tab is active.
  void syncToRepo(RepoConfig? repo) {
    if (repo?.path == _lastSyncedRepoPath) return;
    _lastSyncedRepoPath = repo?.path;

    final config = repo?.githubConfig;
    // Deferred so we never notifyListeners() synchronously during the
    // provider's build (syncToRepo is called from ProxyProvider.update).
    Future.microtask(() {
      if (config == null || !config.isConfigured) {
        clear();
      } else {
        loadPrs(config);
      }
    });
  }

  Future<void> loadPrs(GithubConfig config) async {
    if (!config.isConfigured) return;

    final prev = _activeConfig;
    final isDifferentRepo = prev == null ||
        prev.owner != config.owner ||
        prev.repo != config.repo;
    final shouldFetchUser =
        _currentUserLogin == null || prev?.token != config.token;

    // A different repo gets a fresh seed so we don't toast its pre-existing
    // review requests on the first load.
    if (isDifferentRepo) {
      _prsRequestingMe = {};
      _everRequestedMe.clear();
      _hasLoadedOnce = false;
      _pendingReviewToasts.clear();
    }

    _activeConfig = config;
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (shouldFetchUser) {
      _currentUserLogin = await _service.fetchAuthenticatedUserLogin(config);
    }

    try {
      final prs = await _service.fetchOpenPullRequests(config);
      _detectReviewRequests(prs);
      _pullRequests = prs;
      _lastRefreshed = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _startPolling();
  }

  /// Queues a toast for each PR where the current user transitions from not
  /// being a requested reviewer to being one. That single transition covers a
  /// newly created PR, being added to an existing PR, and a re-request after a
  /// prior review. A request is flagged as a re-request when the user was
  /// requested on this PR earlier in the session and then removed.
  ///
  /// The first successful load only seeds the tracking sets so existing
  /// requests don't spam toasts on startup.
  void _detectReviewRequests(List<GithubPullRequest> prs) {
    final me = _currentUserLogin;
    final currentRequestingMe = <int>{};

    for (final pr in prs) {
      final requestsMe = me != null && pr.requestedReviewers.contains(me);
      if (!requestsMe) continue;

      currentRequestingMe.add(pr.number);

      final wasRequestedLastFetch = _prsRequestingMe.contains(pr.number);
      if (_hasLoadedOnce && !wasRequestedLastFetch) {
        _pendingReviewToasts.add(
          PrReviewNotification(
            pr: pr,
            reRequested: _everRequestedMe.contains(pr.number),
          ),
        );
        onRequestedMeTransition?.call(pr);
        if (_activeConfig?.autoCreateWorktreeOnReviewRequest ?? false) {
          onReviewRequested?.call(pr);
        }
      }
      _everRequestedMe.add(pr.number);
    }

    _prsRequestingMe = currentRequestingMe;
    _hasLoadedOnce = true;
  }

  Future<void> refresh() async {
    if (_activeConfig == null) return;
    await loadPrs(_activeConfig!);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final minutes = (_activeConfig?.prRefreshIntervalMinutes ?? 5).clamp(1, 1440);
    _pollTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      if (_activeConfig != null) {
        loadPrs(_activeConfig!);
      }
    });
  }

  void clear() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pullRequests = [];
    _activeConfig = null;
    _error = null;
    _lastRefreshed = null;
    _currentUserLogin = null;
    _prsRequestingMe = {};
    _everRequestedMe.clear();
    _hasLoadedOnce = false;
    _pendingReviewToasts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
