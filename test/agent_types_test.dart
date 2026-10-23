import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_type.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';
import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

import 'fake_config_stores.dart';

void main() {
  group('the agent-type catalog', () {
    test('starts with the built-in types, Support included', () {
      final settings = AppSettings.fromJson({});
      expect(
        [for (final t in settings.agentTypes) t.kind.id],
        ['refine', 'build', 'verify', 'review', 'docs', 'support'],
      );
      expect(settings.agentType(AgentKind.build).ownsWorktree, isTrue);
      expect(settings.agentType(AgentKind.verify).ownsWorktree, isFalse);
    });

    test('round-trips through the settings JSON', () {
      final settings = AppSettings(
        agentTypes: const [
          AgentType(
            kind: AgentKind('triage'),
            label: 'Triage',
            icon: 'bug_report',
            color: 'red',
            ownsWorktree: true,
          ),
        ],
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.agentTypes, settings.agentTypes);
    });

    test('stands in for a kind it no longer has', () {
      final type = AppSettings(
        agentTypes: const [],
      ).agentType(const AgentKind('deploy'));
      expect(type.label, 'Deploy');
      expect(type.ownsWorktree, isFalse);
    });

    test('makes a unique id from a new label', () {
      expect(
        agentKindForLabel('Security Review!', const []),
        const AgentKind('security-review'),
      );
      expect(
        agentKindForLabel('Support', const [AgentKind.support]),
        const AgentKind('support-2'),
      );
      expect(agentKindForLabel('  !! ', const []), isNull);
    });

    test('is edited through the settings controller', () async {
      final store = FakeAppSettingsStore();
      final controller = SettingsController(store: store);
      addTearDown(controller.dispose);

      final added = await controller.addAgentType('Triage');
      expect(added!.kind, const AgentKind('triage'));
      await controller.updateAgentType(added.copyWith(label: 'Bug triage'));
      await controller.reorderAgentTypes(
        controller.settings.agentTypes.length - 1,
        0,
      );
      expect(store.savedSettings.agentTypes.first.label, 'Bug triage');

      await controller.removeAgentType(AgentKind.docs);
      expect(
        store.savedSettings.agentTypes.map((t) => t.kind),
        isNot(contains(AgentKind.docs)),
      );
    });
  });

  test('a repo keeps the agent types it switched off', () {
    final repo = RepoConfig(
      name: 'au2office',
      path: '/repos/au2',
      disabledAgentTypes: const [AgentKind.docs],
    );
    final restored = RepoConfig.fromJson(repo.toJson());
    expect(restored.usesAgentType(AgentKind.docs), isFalse);
    expect(restored.usesAgentType(AgentKind.build), isTrue);
    expect(
      RepoConfig(name: 'x', path: '/x').toJson(),
      isNot(contains('disabledAgentTypes')),
    );
  });
}
