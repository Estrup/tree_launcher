import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_naming.dart';

void main() {
  group('normalizeWorktreeName', () {
    test('trims, lowercases, and turns spaces into dashes', () {
      expect(normalizeWorktreeName('  My Feature '), 'my-feature');
      expect(normalizeWorktreeName('AUTH login'), 'auth-login');
      expect(normalizeWorktreeName('already-fine'), 'already-fine');
    });
  });

  group('validateWorktreeName', () {
    test('accepts allowed names and empty', () {
      expect(validateWorktreeName(''), isNull);
      expect(validateWorktreeName('feature-auth'), isNull);
      expect(validateWorktreeName('a.b_c-1'), isNull);
    });

    test('rejects uppercase and illegal characters', () {
      expect(validateWorktreeName('Feature'), 'Must be lowercase');
      expect(validateWorktreeName('has/slash'), isNotNull);
      expect(validateWorktreeName('has space'), isNotNull);
    });
  });

  group('validateJiraKey', () {
    test('accepts well-formed keys and empty', () {
      expect(validateJiraKey(''), isNull);
      expect(validateJiraKey('AU2-1234'), isNull);
      expect(validateJiraKey('PROJ-1'), isNull);
    });

    test('rejects malformed keys', () {
      expect(validateJiraKey('au2-1234'), isNotNull);
      expect(validateJiraKey('AU2'), isNotNull);
      expect(validateJiraKey('1234'), isNotNull);
    });
  });

  group('buildBranchName', () {
    test('prepends the prefix when set', () {
      expect(buildBranchName('my-feature', 'feature'), 'feature/my-feature');
    });

    test('returns the suffix unchanged when no prefix', () {
      expect(buildBranchName('my-feature', null), 'my-feature');
      expect(buildBranchName('my-feature', ''), 'my-feature');
    });
  });

  group('worktreeNameForJiraIssue', () {
    test('puts a slug of the summary before the lowercased key', () {
      expect(
        worktreeNameForJiraIssue('AU2-5928', 'Værksted kontakt'),
        'vaerksted-kontakt-au2-5928',
      );
    });

    test('folds Danish letters and drops punctuation', () {
      expect(
        worktreeNameForJiraIssue('AU2-1', 'Én e-mail på kunden (Ø/Å)!'),
        'en-e-mail-paa-kunden-au2-1',
      );
    });

    test('stops at whole words within the length and word limits', () {
      final name = worktreeNameForJiraIssue(
        'AU2-5905',
        'Arbejdskort vælger forkert au2web-konto når værkstedet har 3',
      );
      expect(name, 'arbejdskort-vaelger-forkert-au2web-au2-5905');
      expect(name.length, lessThanOrEqualTo(48));
    });

    test('falls back to just the key for an empty summary', () {
      expect(worktreeNameForJiraIssue('AU2-7', '  —  '), 'au2-7');
    });

    test('always produces a valid worktree name', () {
      for (final summary in [
        'System: Natlige SQL Agent-jobs for åbne timeregistreringer',
        'S1 — Udgående Autodesktop-klient + konfiguration',
        '2.41.3 Release-noter',
      ]) {
        expect(
          validateWorktreeName(worktreeNameForJiraIssue('AU2-5950', summary)),
          isNull,
          reason: summary,
        );
      }
    });
  });

  group('worktreeNameForPrBranch', () {
    test('moves the Jira key after the rest of the branch name', () {
      expect(
        worktreeNameForPrBranch(
          'klp/AU2-5928-vaerksted-kontakt',
          jiraKey: 'AU2-5928',
        ),
        'vaerksted-kontakt-au2-5928',
      );
      expect(
        worktreeNameForPrBranch(
          'hkh/au2office/AU2-4973_salesorderdraft-0-price',
          jiraKey: 'AU2-4973',
        ),
        'salesorderdraft-0-price-au2-4973',
      );
    });

    test('matches the key case-insensitively and only as a whole key', () {
      expect(
        worktreeNameForPrBranch(
          'jlb/au2office/au2-5264-s1-backstage-schema',
          jiraKey: 'AU2-5264',
        ),
        's1-backstage-schema-au2-5264',
      );
      expect(
        worktreeNameForPrBranch('klp/AU2-52640-other', jiraKey: 'AU2-5264'),
        'au2-52640-other-au2-5264',
      );
    });

    test('appends the key when the branch does not contain it', () {
      expect(
        worktreeNameForPrBranch('feature/CarController', jiraKey: 'AU2-3799'),
        'carcontroller-au2-3799',
      );
      expect(worktreeNameForPrBranch('hkh/AU2-1', jiraKey: 'AU2-1'), 'au2-1');
    });

    test('keeps the branch with dashes for slashes when there is no key', () {
      expect(worktreeNameForPrBranch('klp/some-fix'), 'klp-some-fix');
    });
  });
}
