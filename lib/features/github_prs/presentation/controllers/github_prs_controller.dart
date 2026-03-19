import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/github_prs/data/github_api_service.dart';
import 'package:tree_launcher/features/github_prs/domain/github_config.dart';
import 'package:tree_launcher/features/github_prs/domain/pull_request.dart';

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

  List<GithubPullRequest> get pullRequests => _pullRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshed => _lastRefreshed;

  static const _pollInterval = Duration(minutes: 5);

  Future<void> loadPrs(GithubConfig config) async {
    if (!config.isConfigured) return;

    _activeConfig = config;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pullRequests = await _service.fetchOpenPullRequests(config);
      _lastRefreshed = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    _startPolling();
  }

  Future<void> refresh() async {
    if (_activeConfig == null) return;
    await loadPrs(_activeConfig!);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
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
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
