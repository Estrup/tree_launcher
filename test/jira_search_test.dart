import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/domain/jira_search.dart';

void main() {
  group('jiraKeyInQuery', () {
    test('reads a full key in any case and project', () {
      expect(jiraKeyInQuery('AU2', ' au2-5928 '), 'AU2-5928');
      expect(jiraKeyInQuery('AU2', 'OA-12'), 'OA-12');
    });

    test('reads a bare number as a key in the project', () {
      expect(jiraKeyInQuery('AU2', '5928'), 'AU2-5928');
    });

    test('finds no key in words', () {
      expect(jiraKeyInQuery('AU2', 'konto'), isNull);
      expect(jiraKeyInQuery('AU2', 'AU2-5928 konto'), isNull);
    });
  });

  group('jiraSearchJql', () {
    test('finds the named issue or issues mentioning it', () {
      expect(
        jiraSearchJql('AU2', 'au2-5928'),
        'key = "AU2-5928" OR (project = "AU2" AND issuetype not in '
        'subTaskIssueTypes() AND text ~ "au2 5928*") ORDER BY updated DESC',
      );
    });

    test('matches every word, the last as a prefix', () {
      expect(
        jiraSearchJql('AU2', '  udlån  kont'),
        '(project = "AU2" AND issuetype not in subTaskIssueTypes() '
        'AND text ~ "udlån kont*") ORDER BY updated DESC',
      );
    });

    test("drops characters Jira's text search would read as operators", () {
      expect(
        jiraSearchJql('AU2', r'"fix" (konto) a\b*'),
        contains('text ~ "fix konto a b*"'),
      );
    });

    test('is null when there is nothing to search for', () {
      expect(jiraSearchJql('AU2', ''), isNull);
      expect(jiraSearchJql('AU2', ' -* '), isNull);
    });
  });
}
