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
}
