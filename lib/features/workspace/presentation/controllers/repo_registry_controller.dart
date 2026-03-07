import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/data/repo_config_store.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

class RepoRegistryController extends ChangeNotifier {
  RepoRegistryController({
    required RepoConfigStore store,
    required GitService gitService,
  }) : _store = store,
       _gitService = gitService;

  final RepoConfigStore _store;
  final GitService _gitService;

  List<RepoConfig> _repos = [];

  List<RepoConfig> get repos => List.unmodifiable(_repos);

  Future<void> loadRepos() async {
    _repos = await _store.load();
    notifyListeners();
  }

  Future<RepoConfig> addRepo(String path) async {
    final isValid = await _gitService.isGitRepo(path);
    if (!isValid) {
      throw Exception('Not a valid git repository: $path');
    }

    final repo = RepoConfig(name: p.basename(path), path: path);
    if (_repos.contains(repo)) {
      throw Exception('Repository already added');
    }

    _repos = [..._repos, repo];
    await _store.save(_repos);
    notifyListeners();
    return repo;
  }

  Future<void> replaceRepo(RepoConfig previous, RepoConfig updated) async {
    final index = _repos.indexOf(previous);
    if (index == -1) return;
    final next = [..._repos];
    next[index] = updated;
    _repos = next;
    await _store.save(_repos);
    notifyListeners();
  }

  Future<void> removeRepo(RepoConfig repo) async {
    _repos = _repos.where((item) => item != repo).toList();
    await _store.save(_repos);
    notifyListeners();
  }
}
