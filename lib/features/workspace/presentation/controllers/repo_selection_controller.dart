import 'package:flutter/foundation.dart';

import 'package:tree_launcher/models/repo_config.dart';

class RepoSelectionController extends ChangeNotifier {
  RepoConfig? _selectedRepo;
  bool _showSettings = false;
  String _pageKey = 'worktrees';

  RepoConfig? get selectedRepo => _selectedRepo;
  bool get showSettings => _showSettings;

  /// Key of the repo page shown (see `RepoPage`), kept when switching repos.
  String get pageKey => _pageKey;

  void showPage(String key) {
    if (_pageKey == key) return;
    _pageKey = key;
    notifyListeners();
  }

  void selectRepo(RepoConfig? repo) {
    if (_selectedRepo == repo) return;
    _selectedRepo = repo;
    notifyListeners();
  }

  void replaceSelectedRepo(RepoConfig previous, RepoConfig updated) {
    if (_selectedRepo != previous) return;
    _selectedRepo = updated;
    notifyListeners();
  }

  void toggleSettings() {
    _showSettings = !_showSettings;
    notifyListeners();
  }

  void closeSettings() {
    if (!_showSettings) return;
    _showSettings = false;
    notifyListeners();
  }
}
