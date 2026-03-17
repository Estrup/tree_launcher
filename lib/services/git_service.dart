import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/worktree.dart';

class GitService {
  /// Fetches worktrees for a given repo path using `git worktree list --porcelain`.
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    final result = await Process.run('git', [
      'worktree',
      'list',
      '--porcelain',
    ], workingDirectory: repoPath);

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to list worktrees: ${result.stderr.toString().trim()}',
      );
    }

    return _parsePorcelainOutput(result.stdout as String);
  }

  /// Validates that a path is a git repository.
  Future<bool> isGitRepo(String path) async {
    // Check for .git directory or file (worktree uses .git file)
    final gitDir = Directory('$path/.git');
    final gitFile = File('$path/.git');
    if (await gitDir.exists() || await gitFile.exists()) return true;

    // Also check if the path itself is a bare repo
    final result = await Process.run('git', [
      'rev-parse',
      '--git-dir',
    ], workingDirectory: path);
    return result.exitCode == 0;
  }

  /// Lists all branches (local and remote), sorted by most recent commit.
  Future<List<String>> listBranches(String repoPath) async {
    final result = await Process.run('git', [
      'branch',
      '-a',
      '--sort=-committerdate',
      '--format=%(refname:short)',
    ], workingDirectory: repoPath);

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to list branches: ${result.stderr.toString().trim()}',
      );
    }

    final lines = (result.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.contains(' -> '))
        .toList();

    // Normalize remote branches: strip origin/ prefix, deduplicate
    final seen = <String>{};
    final branches = <String>[];
    for (final line in lines) {
      final name = line.startsWith('origin/')
          ? line.substring('origin/'.length)
          : line;
      if (seen.add(name)) {
        branches.add(name);
      }
    }
    return branches;
  }

  /// Creates a new worktree as a sibling of the repo directory.
  /// Returns the path to the created worktree.
  Future<String> addWorktree(
    String repoPath,
    String name, {
    String? baseBranch,
    String? newBranch,
  }) async {
    // Worktrees are always placed alongside the repo directory.
    final parentDir = p.dirname(repoPath);
    final worktreePath = p.join(parentDir, name);

    // Check if folder already exists
    if (await Directory(worktreePath).exists()) {
      throw Exception('Folder "$name" already exists');
    }

    // Fetch latest changes from origin for the base branch so the worktree
    // is created from the newest remote state.
    if (baseBranch != null && baseBranch.isNotEmpty) {
      await Process.run('git', [
        'fetch',
        'origin',
        baseBranch,
      ], workingDirectory: repoPath);
    }

    final args = <String>['worktree', 'add'];
    if (newBranch != null && newBranch.isNotEmpty) {
      // Creating a new branch: base off the remote tracking branch.
      final startPoint = (baseBranch != null && baseBranch.isNotEmpty)
          ? 'origin/$baseBranch'
          : null;
      args.addAll(['-b', newBranch, worktreePath]);
      if (startPoint != null) {
        args.add(startPoint);
      }
    } else {
      // No new branch: check out the local base branch directly.
      args.add(worktreePath);
      if (baseBranch != null && baseBranch.isNotEmpty) {
        args.add(baseBranch);
      }
    }

    final result = await Process.run(
      'git',
      args,
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }

    return worktreePath;
  }

  /// Removes a worktree from disk and git.
  Future<void> removeWorktree(String repoPath, String worktreePath) async {
    final result = await Process.run('git', [
      'worktree',
      'remove',
      worktreePath,
      '--force',
    ], workingDirectory: repoPath);

    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
  }

  WorktreeListResult _parsePorcelainOutput(String output) {
    final worktrees = <Worktree>[];
    final blocks = output.trim().split('\n\n');
    bool isBareLayout = false;

    for (final block in blocks) {
      if (block.trim().isEmpty) continue;

      final lines = block.trim().split('\n');
      String? worktreePath;
      String commitHash = '';
      String branch = '';
      bool isBare = false;
      bool isDetached = false;

      for (final line in lines) {
        if (line.startsWith('worktree ')) {
          worktreePath = line.substring('worktree '.length);
        } else if (line.startsWith('HEAD ')) {
          commitHash = line.substring('HEAD '.length);
          if (commitHash.length > 7) {
            commitHash = commitHash.substring(0, 7);
          }
        } else if (line.startsWith('branch ')) {
          branch = line.substring('branch '.length);
          // Strip refs/heads/ prefix
          if (branch.startsWith('refs/heads/')) {
            branch = branch.substring('refs/heads/'.length);
          }
        } else if (line == 'bare') {
          isBare = true;
        } else if (line == 'detached') {
          isDetached = true;
        }
      }

      if (worktreePath == null) continue;
      if (isBare) {
        isBareLayout = true;
        continue;
      }

      if (isDetached) {
        branch = 'detached @ $commitHash';
      }

      final name = p.basename(worktreePath);
      // In bare layouts, no worktree is primary — all are equal peers.
      final isMain = !isBareLayout && worktrees.isEmpty;

      worktrees.add(
        Worktree(
          path: worktreePath,
          branch: branch,
          name: name,
          isMain: isMain,
          commitHash: commitHash,
        ),
      );
    }

    return WorktreeListResult(worktrees: worktrees, isBareLayout: isBareLayout);
  }
}
