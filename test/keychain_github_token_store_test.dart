@TestOn('mac-os')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/github_prs/data/github_token_store.dart';

void main() {
  final store = KeychainGithubTokenStore(
    service: '${KeychainGithubTokenStore.defaultService}.test',
  );

  test(
    'round-trips a token through the login Keychain',
    () async {
      // Quotes, a backslash and spaces, to exercise `security -i` quoting.
      const repo = r'/tmp/tree launcher "test" \ repo';
      addTearDown(() => store.delete(repo));

      expect(await store.read(repo), isNull);
      await store.write(repo, 'ghp_first');
      expect(await store.read(repo), 'ghp_first');
      await store.write(repo, 'ghp_second');
      expect(await store.read(repo), 'ghp_second');
      await store.delete(repo);
      expect(await store.read(repo), isNull);
      await store.delete(repo);
    },
    skip: Platform.environment['KEYCHAIN_TESTS'] == '1'
        ? false
        : 'Writes to the login Keychain; run with KEYCHAIN_TESTS=1',
  );

  test('refuses a token with a line break before running security', () {
    expect(
      () => store.write('/tmp/repo', 'ghp_a\nadd-generic-password'),
      throwsArgumentError,
    );
  });
}
