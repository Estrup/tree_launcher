import 'package:path/path.dart' as p;

import '../models/repo_config.dart';
import '../models/worktree.dart';
import '../providers/repo_provider.dart';

class RepoActionToolResult {
  const RepoActionToolResult({required this.payload, required this.summary});

  final Map<String, dynamic> payload;
  final String summary;
}

class _RepoActionToolDefinition {
  const _RepoActionToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toOpenAiJson() => {
    'type': 'function',
    'function': {
      'name': name,
      'description': description,
      'parameters': parameters,
    },
  };
}

class RepoActionToolRegistry {
  RepoActionToolRegistry({required RepoProvider repoProvider})
    : _repoProvider = repoProvider;

  static final RegExp _validWorktreeName = RegExp(r'^[a-z0-9._\-]+$');

  final RepoProvider _repoProvider;

  List<Map<String, dynamic>> buildToolDefinitions() =>
      _toolDefinitions.map((tool) => tool.toOpenAiJson()).toList();

  Map<String, dynamic> describeContext() => {
    'selectedRepository': _repoProvider.selectedRepo?.name,
    'repositories': _repoProvider.repos
        .map((repo) => {'name': repo.name, 'path': repo.path})
        .toList(),
    'worktrees': _repoProvider.worktrees
        .map(
          (worktree) => {
            'name': worktree.name,
            'branch': worktree.branch,
            'path': worktree.path,
          },
        )
        .toList(),
  };

  Future<RepoActionToolResult> executeTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    switch (name) {
      case 'list_repositories':
        return _listRepositories();
      case 'select_repository':
        return _selectRepository(arguments);
      case 'list_worktrees':
        return _listWorktrees(arguments);
      case 'list_branches':
        return _listBranches(arguments);
      case 'create_worktree':
        return _createWorktree(arguments);
    }

    throw ArgumentError('Unsupported repo action tool: $name');
  }

  List<_RepoActionToolDefinition> get _toolDefinitions => [
    const _RepoActionToolDefinition(
      name: 'list_repositories',
      description:
          'List the repositories currently registered in TreeLauncher.',
      parameters: {
        'type': 'object',
        'properties': {},
        'required': [],
        'additionalProperties': false,
      },
    ),
    const _RepoActionToolDefinition(
      name: 'select_repository',
      description:
          'Select the active repository by name so later repo/worktree actions use it.',
      parameters: {
        'type': 'object',
        'properties': {
          'repoName': {
            'type': 'string',
            'description': 'The name of the repository to select.',
          },
        },
        'required': ['repoName'],
        'additionalProperties': false,
      },
    ),
    const _RepoActionToolDefinition(
      name: 'list_worktrees',
      description:
          'Refresh and list worktrees for the selected repository, or optionally for a named repository.',
      parameters: {
        'type': 'object',
        'properties': {
          'repoName': {
            'type': 'string',
            'description':
                'Optional repository name to select before listing worktrees.',
          },
        },
        'required': [],
        'additionalProperties': false,
      },
    ),
    const _RepoActionToolDefinition(
      name: 'list_branches',
      description:
          'List git branches for the selected repository, or optionally for a named repository.',
      parameters: {
        'type': 'object',
        'properties': {
          'repoName': {
            'type': 'string',
            'description':
                'Optional repository name to select before listing branches.',
          },
        },
        'required': [],
        'additionalProperties': false,
      },
    ),
    const _RepoActionToolDefinition(
      name: 'create_worktree',
      description:
          'Create a new git worktree in the selected repository. Use lowercase names with dashes, dots, or underscores.',
      parameters: {
        'type': 'object',
        'properties': {
          'repoName': {
            'type': 'string',
            'description':
                'Optional repository name to select before creating the worktree.',
          },
          'name': {
            'type': 'string',
            'description': 'The new worktree folder name.',
          },
          'baseBranch': {
            'type': 'string',
            'description': 'Optional base branch to create the worktree from.',
          },
          'newBranch': {
            'type': 'string',
            'description':
                'Optional branch name to create for the new worktree.',
          },
        },
        'required': ['name'],
        'additionalProperties': false,
      },
    ),
  ];

  Future<RepoActionToolResult> _listRepositories() async {
    final repos = _repoProvider.repos
        .map(
          (repo) => {
            'name': repo.name,
            'path': repo.path,
            'isSelected': identical(repo, _repoProvider.selectedRepo),
          },
        )
        .toList();

    return RepoActionToolResult(
      payload: {
        'repositories': repos,
        'selectedRepository': _repoProvider.selectedRepo?.name,
      },
      summary: repos.isEmpty
          ? 'There are no repositories configured in TreeLauncher yet.'
          : 'Listed ${repos.length} repositories.',
    );
  }

  Future<RepoActionToolResult> _selectRepository(
    Map<String, dynamic> arguments,
  ) async {
    final repoName = _requireString(arguments, 'repoName');
    final repo = _findRepository(repoName);
    await _repoProvider.selectRepo(repo);

    return RepoActionToolResult(
      payload: {'selectedRepository': repo.name, 'path': repo.path},
      summary: 'Selected repository ${repo.name}.',
    );
  }

  Future<RepoActionToolResult> _listWorktrees(
    Map<String, dynamic> arguments,
  ) async {
    await _selectRepositoryIfProvided(arguments);

    final repo = _requireSelectedRepository();
    await _repoProvider.refreshWorktrees();

    return RepoActionToolResult(
      payload: {
        'selectedRepository': repo.name,
        'worktrees': _repoProvider.worktrees.map(_serializeWorktree).toList(),
      },
      summary:
          'Loaded ${_repoProvider.worktrees.length} worktrees for ${repo.name}.',
    );
  }

  Future<RepoActionToolResult> _listBranches(
    Map<String, dynamic> arguments,
  ) async {
    await _selectRepositoryIfProvided(arguments);

    final repo = _requireSelectedRepository();
    final branches = await _repoProvider.listBranches();

    return RepoActionToolResult(
      payload: {'selectedRepository': repo.name, 'branches': branches},
      summary: 'Loaded ${branches.length} branches for ${repo.name}.',
    );
  }

  Future<RepoActionToolResult> _createWorktree(
    Map<String, dynamic> arguments,
  ) async {
    await _selectRepositoryIfProvided(arguments);

    final repo = _requireSelectedRepository();
    final name = _requireString(arguments, 'name').trim();
    final baseBranch = _readOptionalString(arguments, 'baseBranch');
    final newBranch = _readOptionalString(arguments, 'newBranch');

    if (!_validWorktreeName.hasMatch(name)) {
      throw ArgumentError(
        'Worktree names must use lowercase letters, digits, dots, dashes, or underscores.',
      );
    }

    final createdPath = await _repoProvider.addWorktree(
      name,
      baseBranch: baseBranch,
      newBranch: newBranch,
    );

    return RepoActionToolResult(
      payload: {
        'selectedRepository': repo.name,
        'worktree': {
          'name': name,
          'path': createdPath ?? p.join(p.dirname(repo.path), name),
          'baseBranch': baseBranch,
          'newBranch': newBranch,
        },
      },
      summary: 'Created worktree $name in ${repo.name}.',
    );
  }

  Future<void> _selectRepositoryIfProvided(
    Map<String, dynamic> arguments,
  ) async {
    final repoName = _readOptionalString(arguments, 'repoName');
    if (repoName == null) {
      return;
    }

    final repo = _findRepository(repoName);
    await _repoProvider.selectRepo(repo);
  }

  RepoConfig _findRepository(String repoName) {
    final normalizedTarget = _normalize(repoName);
    for (final repo in _repoProvider.repos) {
      if (_normalize(repo.name) == normalizedTarget) {
        return repo;
      }
    }

    throw ArgumentError('Could not find a repository named "$repoName".');
  }

  RepoConfig _requireSelectedRepository() {
    final repo = _repoProvider.selectedRepo;
    if (repo == null) {
      throw StateError('No repository is currently selected.');
    }
    return repo;
  }

  Map<String, dynamic> _serializeWorktree(Worktree worktree) => {
    'name': worktree.name,
    'branch': worktree.branch,
    'path': worktree.path,
    'commitHash': worktree.commitHash,
    'isMain': worktree.isMain,
  };

  String _normalize(String value) => value.trim().toLowerCase();

  String _requireString(Map<String, dynamic> arguments, String key) {
    final value = arguments[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    throw ArgumentError('Expected a non-empty string argument for "$key".');
  }

  String? _readOptionalString(Map<String, dynamic> arguments, String key) {
    final value = arguments[key];
    if (value is! String) {
      return null;
    }

    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
