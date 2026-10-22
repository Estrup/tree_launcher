import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/jira/domain/jira_wiki_markup.dart';

/// [pieces] as readable strings: `text`, `text<bold>`, `@user`, `!image!`,
/// `[text](url)`.
List<String> _show(List<WikiInline> pieces) => [
  for (final piece in pieces)
    switch (piece) {
      WikiText(:final text, :final style) =>
        style == WikiStyle.plain ? text : '$text<$style>',
      WikiLink(:final text, :final url) => '[$text]($url)',
      WikiMention(:final user) => '@$user',
      WikiImage(:final source) => '!$source!',
    },
];

void main() {
  group('blocks', () {
    test('headings, paragraphs and rules', () {
      final blocks = parseJiraWiki(
        'h4. Baggrund\nFørste linje\nanden linje\n\n----\nh1.Titel',
      );
      expect(blocks, hasLength(4));
      final heading = blocks[0] as WikiHeading;
      expect(heading.level, 4);
      expect(_show(heading.content), ['Baggrund']);
      expect(_show((blocks[1] as WikiParagraph).content), [
        'Første linje\nanden linje',
      ]);
      expect(blocks[2], isA<WikiRule>());
      expect((blocks[3] as WikiHeading).level, 1);
    });

    test('lists keep their depth and kind', () {
      final blocks = parseJiraWiki('* a\n** b\n# c\n- d\n*bold* is no item');
      final items = blocks.whereType<WikiListItem>().toList();
      expect([for (final i in items) i.markers], ['*', '**', '#', '*']);
      expect(items[1].depth, 2);
      expect(items[2].ordered, isTrue);
      expect(_show((blocks.last as WikiParagraph).content), [
        'bold<bold>',
        ' is no item',
      ]);
    });

    test('code blocks keep their text as written', () {
      final blocks = parseJiraWiki(
        'før\n{code:java}\nint *a* = 1;\n{code}\nefter',
      );
      expect(blocks, hasLength(3));
      expect((blocks[1] as WikiCode).text, 'int *a* = 1;');
      expect(_show((blocks[2] as WikiParagraph).content), ['efter']);
    });

    test('a code block on one line', () {
      final blocks = parseJiraWiki('{noformat}x = 1{noformat} og mere');
      expect((blocks[0] as WikiCode).text, 'x = 1');
      expect(_show((blocks[1] as WikiParagraph).content), [' og mere']);
    });

    test('quotes and panels hold blocks', () {
      final blocks = parseJiraWiki(
        '{quote}\nh4. Inde\ntekst\n{quote}\n{panel:title=Note|bg=#fff}\nx\n{panel}',
      );
      final quote = blocks[0] as WikiQuote;
      expect(quote.children.first, isA<WikiHeading>());
      final panel = blocks[1] as WikiQuote;
      expect(panel.title, 'Note');
      expect(panel.children, hasLength(1));
    });

    test('tables split cells but not links', () {
      final blocks = parseJiraWiki(
        '||Navn||Link||\n|Kunde|[side|https://x.dk]|',
      );
      final table = blocks.single as WikiTable;
      expect(table.rows, hasLength(2));
      expect([for (final c in table.rows[0]) c.header], [true, true]);
      expect(_show(table.rows[1][1].content), ['[side](https://x.dk)']);
      expect(table.rows[1][0].header, isFalse);
    });
  });

  group('inline', () {
    test('emphasis', () {
      expect(_show(parseJiraInline('*fed* _kursiv_ -slet- +under+ {{kode}}')), [
        'fed<bold>',
        ' ',
        'kursiv<italic>',
        ' ',
        'slet<strike>',
        ' ',
        'under<underline>',
        ' ',
        'kode<mono>',
      ]);
    });

    test('markers inside words or before spaces stay text', () {
      expect(_show(parseJiraInline('a - b, snake_case_name, 2*3*4')), [
        'a - b, snake_case_name, 2*3*4',
      ]);
    });

    test('nested emphasis', () {
      expect(_show(parseJiraInline('*fed _og kursiv_*')), [
        'fed <bold>',
        'og kursiv<bold+italic>',
      ]);
    });

    test('mentions, links and bare URLs', () {
      expect(
        _show(
          parseJiraInline(
            '[~sun@cac.dk] se [her|https://a.dk/x] og https://b.dk/y.',
          ),
        ),
        [
          '@sun@cac.dk',
          ' se ',
          '[her](https://a.dk/x)',
          ' og ',
          '[https://b.dk/y](https://b.dk/y)',
          '.',
        ],
      );
    });

    test('image references, with and without options', () {
      expect(
        _show(
          parseJiraInline(
            'Se !image-2025-11-11-10-29-42-413.png! og !x.png|thumbnail!',
          ),
        ),
        ['Se ', '!image-2025-11-11-10-29-42-413.png!', ' og ', '!x.png!'],
      );
    });

    test('exclamation marks that are not images stay text', () {
      expect(_show(parseJiraInline('Hej! Det virker!')), ['Hej! Det virker!']);
    });

    test('square brackets that are not links stay text', () {
      expect(_show(parseJiraInline('[TODO] lav det')), ['[TODO] lav det']);
    });

    test('colour tags are dropped, escapes kept', () {
      expect(_show(parseJiraInline(r'{color:red}rød{color} \*ikke fed\*')), [
        'rød *ikke fed*',
      ]);
    });
  });

  test('mentions are collected once each', () {
    expect(jiraWikiMentions('[~a@x.dk] og [~b] og [~a@x.dk]'), ['a@x.dk', 'b']);
  });
}
