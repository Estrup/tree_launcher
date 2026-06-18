import 'dart:io';
import 'package:path/path.dart' as p;
import '../features/workspace/domain/worktree_naming.dart';
import '../models/worktree.dart';

class GitService {
  /// Runs git with config that allows operating on bare-repository worktree
  /// layouts even when the user has set `safe.bareRepository=explicit`
  /// (git's hardened default since 2.45.1).
  Future<ProcessResult> _runGit(
    List<String> args, {
    required String workingDirectory,
  }) {
    return Process.run(
      '/usr/bin/git',
      ['-c', 'safe.bareRepository=all', ...args],
      workingDirectory: workingDirectory,
    );
  }

  /// Fetches worktrees for a given repo path using `git worktree list --porcelain`.
  Future<WorktreeListResult> getWorktrees(String repoPath) async {
    final result = await _runGit([
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
    final result = await _runGit([
      'rev-parse',
      '--git-dir',
    ], workingDirectory: path);
    return result.exitCode == 0;
  }

  /// Lists all branches (local and remote), sorted by most recent commit.
  Future<List<String>> listBranches(String repoPath) async {
    final result = await _runGit([
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

  /// Creates a new worktree and returns the path to it.
  ///
  /// By default the worktree is placed as a sibling of the repo directory.
  /// When [useNestedWorktrees] is true and the repo is not bare, it is placed
  /// in a `.worktrees/` subfolder inside the repo instead, and that folder is
  /// added to git's exclude so it never shows up as untracked.
  Future<String> addWorktree(
    String repoPath,
    String name, {
    String? baseBranch,
    String? newBranch,
    bool useNestedWorktrees = false,
  }) async {
    // Bare repos have no working tree, so nesting (and its exclude entry) makes
    // no sense — keep them on the sibling layout.
    final nested = useNestedWorktrees && !await _isBareRepository(repoPath);
    final worktreePath = nested
        ? p.join(repoPath, '.worktrees', name)
        : p.join(p.dirname(repoPath), name);

    // Check if folder already exists
    if (await Directory(worktreePath).exists()) {
      throw Exception('Folder "$name" already exists');
    }

    // Fetch latest changes from origin for the base branch so the worktree
    // is created from the newest remote state.
    if (baseBranch != null && baseBranch.isNotEmpty) {
      await _runGit([
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

    final result = await _runGit(
      args,
      workingDirectory: repoPath,
    );

    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }

    if (nested) {
      await _ensureIgnored(repoPath, '.worktrees/');
    }

    return worktreePath;
  }

  /// Writes [content] to `<worktreePath>/.tree-launcher/kickoff-prompt.md`
  /// (see [kickoffPromptRelativePath]), ensures `.tree-launcher/` is git-excluded
  /// so it never shows as untracked, and returns the absolute file path.
  Future<String> writeKickoffPrompt({
    required String repoPath,
    required String worktreePath,
    required String content,
  }) async {
    final filePath = p.join(worktreePath, kickoffPromptRelativePath);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    await _ensureIgnored(repoPath, '.tree-launcher/');
    return filePath;
  }

  /// Returns true if [repoPath] is a bare git repository.
  Future<bool> _isBareRepository(String repoPath) async {
    final result = await _runGit(
      ['rev-parse', '--is-bare-repository'],
      workingDirectory: repoPath,
    );
    return result.exitCode == 0 && (result.stdout as String).trim() == 'true';
  }

  /// Idempotently adds [entry] to the repo's local git exclude
  /// (`.git/info/exclude`) so the matching files never appear as untracked.
  ///
  /// Best-effort: any git/IO failure is swallowed so it never blocks worktree
  /// creation. Uses `.git/info/exclude` rather than a tracked `.gitignore` so
  /// it leaves no working-tree diff to commit. The exclude is shared across a
  /// repo's worktrees (it lives in the common git dir).
  Future<void> _ensureIgnored(String repoPath, String entry) async {
    final result = await _runGit(
      ['rev-parse', '--git-common-dir'],
      workingDirectory: repoPath,
    );
    if (result.exitCode != 0) return;
    var gitCommonDir = (result.stdout as String).trim();
    if (gitCommonDir.isEmpty) return;
    // git may return a path relative to repoPath.
    if (!p.isAbsolute(gitCommonDir)) {
      gitCommonDir = p.join(repoPath, gitCommonDir);
    }
    final excludeFile = File(p.join(gitCommonDir, 'info', 'exclude'));

    var existing = '';
    try {
      if (await excludeFile.exists()) {
        existing = await excludeFile.readAsString();
        final present = existing
            .split('\n')
            .map((l) => l.trim())
            .contains(entry);
        if (present) return;
      } else {
        await excludeFile.parent.create(recursive: true);
      }
      final prefix =
          existing.isEmpty || existing.endsWith('\n') ? '' : '\n';
      await excludeFile.writeAsString(
        '$prefix$entry\n',
        mode: FileMode.append,
      );
    } catch (_) {
      // Never let an exclude-write failure block worktree creation.
    }
  }

  /// Removes a worktree from disk and git.
  Future<void> removeWorktree(String repoPath, String worktreePath) async {
    final result = await _runGit([
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
