import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/settings/presentation/widgets/jira_settings_section.dart';
import 'package:tree_launcher/models/jira_tag.dart';
import 'package:tree_launcher/services/config_service.dart';

class _FakeConfigService extends ConfigService {
  _FakeConfigService(this.savedSettings);

  AppSettings savedSettings;

  @override
  Future<AppSettings> loadSettings() async => savedSettings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    savedSettings = settings;
  }
}

const _blocked = JiraTag(id: 'b', name: 'Blocked', color: 'red');
const _demo = JiraTag(id: 'd', name: 'Demo', color: 'blue');

Future<(SettingsController, _FakeConfigService)> _settings(
  AppSettings initial,
) async {
  final config = _FakeConfigService(initial);
  final controller = SettingsController(configService: config);
  await controller.loadSettings();
  return (controller, config);
}

void main() {
  group('AppSettings tags', () {
    test('round-trip through JSON', () {
      final restored = AppSettings.fromJson(
        AppSettings(
          jiraTags: const [_blocked, _demo],
          jiraTagsByIssue: const {
            'AU2-1': ['d', 'b'],
          },
        ).toJson(),
      );

      expect(restored.jiraTags.map((t) => t.name), ['Blocked', 'Demo']);
      expect(restored.jiraTags.first.color, 'red');
      // In tag order, not the order they were added.
      expect(restored.tagsFor('AU2-1').map((t) => t.name), ['Blocked', 'Demo']);
    });

    test('default to none, and skip deleted tags', () {
      expect(AppSettings().jiraTags, isEmpty);
      final settings = AppSettings(
        jiraTags: const [_blocked],
        jiraTagsByIssue: const {
          'AU2-1': ['gone', 'b'],
        },
      );
      expect(settings.tagsFor('AU2-1'), [_blocked]);
      expect(settings.tagsFor('AU2-2'), isEmpty);
    });
  });

  group('SettingsController tags', () {
    test('adds tags in colors not used yet', () async {
      final (settings, config) = await _settings(
        AppSettings(jiraTags: const [_demo]),
      );

      await settings.addJiraTag('  Waiting  ');
      await settings.addJiraTag(' ');

      final tags = config.savedSettings.jiraTags;
      expect(tags.map((t) => t.name), ['Demo', 'Waiting']);
      expect(tags.last.color, 'green');
      expect(tags.last.id, isNot(tags.first.id));
    });

    test('tags issues several times, renames and reorders', () async {
      final (settings, config) = await _settings(
        AppSettings(jiraTags: const [_blocked, _demo]),
      );

      await settings.setJiraTag('AU2-1', 'b', true);
      await settings.setJiraTag('AU2-1', 'd', true);
      await settings.setJiraTag('AU2-1', 'd', true);
      expect(config.savedSettings.jiraTagsByIssue, {
        'AU2-1': ['b', 'd'],
      });

      await settings.updateJiraTag(_blocked.copyWith(name: 'Stuck'));
      expect(config.savedSettings.tagsFor('AU2-1').first.name, 'Stuck');

      await settings.reorderJiraTags(0, 2);
      expect(config.savedSettings.jiraTags.map((t) => t.id), ['d', 'b']);

      await settings.setJiraTag('AU2-1', 'b', false);
      await settings.setJiraTag('AU2-1', 'd', false);
      expect(config.savedSettings.jiraTagsByIssue, isEmpty);
    });

    test('deleting a tag takes it off its issues', () async {
      final (settings, config) = await _settings(
        AppSettings(
          jiraTags: const [_blocked, _demo],
          jiraTagsByIssue: const {
            'AU2-1': ['b'],
            'AU2-2': ['b', 'd'],
          },
        ),
      );

      await settings.removeJiraTag('b');

      expect(config.savedSettings.jiraTags, [_demo]);
      expect(config.savedSettings.jiraTagsByIssue, {
        'AU2-2': ['d'],
      });
    });
  });

  group('JiraSettingsSection', () {
    Future<_FakeConfigService> pump(
      WidgetTester tester,
      AppSettings initial,
    ) async {
      final (settings, config) = await _settings(initial);
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsController>.value(
          value: settings,
          child: MaterialApp(
            theme: AppTheme.current,
            home: const Scaffold(body: JiraSettingsSection()),
          ),
        ),
      );
      return config;
    }

    testWidgets('adds a tag from the field', (tester) async {
      final config = await pump(tester, AppSettings());
      expect(find.text('No tags yet'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Blocked');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(config.savedSettings.jiraTags.single.name, 'Blocked');
      expect(find.text('0 issues'), findsOneWidget);
    });

    testWidgets('renames a tag on Enter', (tester) async {
      final config = await pump(
        tester,
        AppSettings(jiraTags: const [_blocked]),
      );

      await tester.enterText(find.byType(TextField).first, 'Stuck');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(config.savedSettings.jiraTags.single.name, 'Stuck');
    });

    testWidgets('asks before deleting a tag issues have', (tester) async {
      final config = await pump(
        tester,
        AppSettings(
          jiraTags: const [_blocked],
          jiraTagsByIssue: const {
            'AU2-1': ['b'],
            'AU2-2': ['b'],
          },
        ),
      );
      expect(find.text('2 issues'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete Blocked'));
      await tester.pumpAndSettle();
      expect(
        find.text('2 issues have this tag. It will be taken off them.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(config.savedSettings.jiraTags, isEmpty);
      expect(config.savedSettings.jiraTagsByIssue, isEmpty);
    });
  });
}
