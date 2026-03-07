import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

class RepoSelectionController extends ChangeNotifier {
  RepoConfig? _selectedRepo;
  bool _showSettings = false;

  RepoConfig? get selectedRepo => _selectedRepo;
  bool get showSettings => _showSettings;

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
