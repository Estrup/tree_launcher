import 'dart:convert';
import 'dart:io';

/// Where each repo's GitHub token is kept, outside `config.json`. Keyed by
/// the repo's path.
abstract interface class GithubTokenStore {
  /// The saved token, or null when there is none.
  Future<String?> read(String repoPath);

  /// Saves [token], replacing any earlier one.
  Future<void> write(String repoPath, String token);

  /// Removes the token. Does nothing when there is none.
  Future<void> delete(String repoPath);
}

/// Keeps the tokens in the login Keychain as generic passwords: service
/// [service], account = the repo's path.
///
/// Goes through the `security` CLI rather than a Keychain plugin: that needs
/// no entitlements or signing team, and because the items trust
/// `/usr/bin/security` rather than this app's binary, a rebuilt debug app
/// reads them without a Keychain prompt. The token reaches `security` on
/// stdin, never on its command line, so it doesn't show up in `ps`.
class KeychainGithubTokenStore implements GithubTokenStore {
  KeychainGithubTokenStore({this.service = defaultService});

  static const defaultService = 'com.treelauncher.treeLauncher.github-token';
  static const _security = '/usr/bin/security';

  /// `errSecItemNotFound`, as `security` reports it.
  static const _notFound = 44;

  final String service;

  @override
  Future<String?> read(String repoPath) async {
    final result = await Process.run(_security, [
      'find-generic-password',
      '-s',
      service,
      '-a',
      repoPath,
      '-w',
    ]);
    if (result.exitCode == _notFound) return null;
    _check('read', result.exitCode, result.stderr);
    final token = (result.stdout as String).trim();
    return token.isEmpty ? null : token;
  }

  @override
  Future<void> write(String repoPath, String token) async {
    // `security -i` reads commands from stdin, one per line, with
    // double-quoted arguments.
    final command = [
      'add-generic-password',
      '-U',
      '-s',
      _quote(service),
      '-a',
      _quote(repoPath),
      '-l',
      _quote('Tree Launcher GitHub token'),
      '-w',
      _quote(token),
    ].join(' ');
    final process = await Process.start(_security, ['-i']);
    final stderr = process.stderr.transform(utf8.decoder).join();
    final stdout = process.stdout.drain<void>();
    process.stdin.writeln(command);
    await process.stdin.close();
    final exitCode = await process.exitCode;
    await stdout;
    _check('write', exitCode, await stderr);
  }

  @override
  Future<void> delete(String repoPath) async {
    final result = await Process.run(_security, [
      'delete-generic-password',
      '-s',
      service,
      '-a',
      repoPath,
    ]);
    if (result.exitCode == _notFound) return;
    _check('delete', result.exitCode, result.stderr);
  }

  static String _quote(String value) {
    if (value.contains('\n') || value.contains('\r')) {
      throw ArgumentError('Keychain values cannot contain line breaks');
    }
    return '"${value.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
  }

  static void _check(String action, int exitCode, Object? stderr) {
    if (exitCode == 0) return;
    throw Exception(
      'Keychain $action failed (security exit $exitCode): '
      '${'$stderr'.trim()}',
    );
  }
}
