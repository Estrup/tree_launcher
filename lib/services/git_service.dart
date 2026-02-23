import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/worktree.dart';

class GitService {
  /// Fetches worktrees for a given repo path using `git worktree list --porcelain`.
  Future<List<Worktree>> getWorktrees(String repoPath) async {
    final result = await Process.run(
      '/usr/bin/git',
      ['worktree', 'list', '--porcelain'],
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      throw Exception(
          'Failed to list worktrees: ${result.stderr.toString().trim()}');
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
    final result = await Process.run(
      '/usr/bin/git',
      ['rev-parse', '--git-dir'],
      workingDirectory: path,
    );
    return result.exitCode == 0;
  }

  List<Worktree> _parsePorcelainOutput(String output) {
    final worktrees = <Worktree>[];
    final blocks = output.trim().split('\n\n');

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

      if (worktreePath == null || isBare) continue;

      if (isDetached) {
        branch = 'detached @ $commitHash';
      }

      final name = p.basename(worktreePath);
      final isMain = worktrees.isEmpty; // First worktree is the main one

      worktrees.add(Worktree(
        path: worktreePath,
        branch: branch,
        name: name,
        isMain: isMain,
        commitHash: commitHash,
      ));
    }

    return worktrees;
  }
}
