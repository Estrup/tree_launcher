import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/custom_command.dart';
import '../models/repo_config.dart';
import '../models/vscode_config.dart';
import '../models/worktree.dart';
import '../services/git_service.dart';
import '../services/config_service.dart';

class RepoProvider extends ChangeNotifier {
  final GitService _gitService;
  final ConfigService _configService;

  List<RepoConfig> _repos = [];
  RepoConfig? _selectedRepo;
  List<Worktree> _worktrees = [];
  bool _loading = false;
  String? _error;
  bool _showSettings = false;
  bool _isBareLayout = false;

  RepoProvider({
    required GitService gitService,
    required ConfigService configService,
  })  : _gitService = gitService,
        _configService = configService;

  List<RepoConfig> get repos => _repos;
  RepoConfig? get selectedRepo => _selectedRepo;
  List<Worktree> get worktrees => _worktrees;
  bool get loading => _loading;
  String? get error => _error;
  bool get showSettings => _showSettings;
  bool get isBareLayout => _isBareLayout;

  void toggleSettings() {
    _showSettings = !_showSettings;
    notifyListeners();
  }

  void closeSettings() {
    _showSettings = false;
    notifyListeners();
  }

  Future<void> loadRepos() async {
    _repos = await _configService.loadRepos();
    if (_repos.isNotEmpty && _selectedRepo == null) {
      _selectedRepo = _repos.first;
      await refreshWorktrees();
    }
    notifyListeners();
  }

  Future<void> addRepo(String path) async {
    final isValid = await _gitService.isGitRepo(path);
    if (!isValid) {
      throw Exception('Not a valid git repository: $path');
    }

    final name = p.basename(path);
    final repo = RepoConfig(name: name, path: path);

    if (_repos.contains(repo)) {
      throw Exception('Repository already added');
    }

    _repos.add(repo);
    await _configService.saveRepos(_repos);

    if (_selectedRepo == null) {
      _selectedRepo = repo;
      await refreshWorktrees();
    }

    notifyListeners();
  }

  Future<void> renameRepo(RepoConfig repo, String newName) async {
    final index = _repos.indexOf(repo);
    if (index == -1) return;

    final updated = RepoConfig(
      name: newName,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      lastBaseBranch: repo.lastBaseBranch,
    );
    _repos[index] = updated;
    await _configService.saveRepos(_repos);

    if (_selectedRepo == repo) {
      _selectedRepo = updated;
    }

    notifyListeners();
  }

  Future<void> updateRepoVscodeConfigs(
      RepoConfig repo, List<VscodeConfig> configs) async {
    final index = _repos.indexOf(repo);
    if (index == -1) return;

    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: configs,
      customCommands: repo.customCommands,
      lastBaseBranch: repo.lastBaseBranch,
    );
    _repos[index] = updated;
    await _configService.saveRepos(_repos);

    if (_selectedRepo == repo) {
      _selectedRepo = updated;
    }

    notifyListeners();
  }

  Future<void> updateRepoCustomCommands(
      RepoConfig repo, List<CustomCommand> commands) async {
    final index = _repos.indexOf(repo);
    if (index == -1) return;

    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: commands,
      lastBaseBranch: repo.lastBaseBranch,
    );
    _repos[index] = updated;
    await _configService.saveRepos(_repos);

    if (_selectedRepo == repo) {
      _selectedRepo = updated;
    }

    notifyListeners();
  }

  Future<void> updateLastBaseBranch(RepoConfig repo, String branch) async {
    final index = _repos.indexOf(repo);
    if (index == -1) return;

    final updated = RepoConfig(
      name: repo.name,
      path: repo.path,
      vscodeConfigs: repo.vscodeConfigs,
      customCommands: repo.customCommands,
      lastBaseBranch: branch,
    );
    _repos[index] = updated;
    await _configService.saveRepos(_repos);

    if (_selectedRepo == repo) {
      _selectedRepo = updated;
    }

    notifyListeners();
  }

  Future<void> removeRepo(RepoConfig repo) async {
    _repos.remove(repo);
    await _configService.saveRepos(_repos);

    if (_selectedRepo == repo) {
      _selectedRepo = _repos.isNotEmpty ? _repos.first : null;
      if (_selectedRepo != null) {
        await refreshWorktrees();
      } else {
        _worktrees = [];
      }
    }

    notifyListeners();
  }

  Future<void> selectRepo(RepoConfig repo) async {
    if (_selectedRepo == repo) return;
    _selectedRepo = repo;
    notifyListeners();
    await refreshWorktrees();
  }

  Future<List<String>> listBranches() async {
    if (_selectedRepo == null) return [];
    return _gitService.listBranches(_selectedRepo!.path);
  }

  Future<String?> addWorktree(
    String name, {
    String? baseBranch,
    String? newBranch,
  }) async {
    if (_selectedRepo == null) return null;
    final path = await _gitService.addWorktree(
      _selectedRepo!.path,
      name,
      baseBranch: baseBranch,
      newBranch: newBranch,
    );
    await refreshWorktrees();
    return path;
  }

  Future<void> deleteWorktree(Worktree worktree) async {
    if (_selectedRepo == null) return;
    await _gitService.removeWorktree(_selectedRepo!.path, worktree.path);
    _worktrees.removeWhere((w) => w.path == worktree.path);
    notifyListeners();
    await refreshWorktrees();
  }

  Future<void> refreshWorktrees() async {
    if (_selectedRepo == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _gitService.getWorktrees(_selectedRepo!.path);
      _worktrees = result.worktrees;
      _isBareLayout = result.isBareLayout;
      _error = null;
    } catch (e) {
      _worktrees = [];
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }
}
