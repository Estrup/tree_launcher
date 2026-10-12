import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/agents/domain/agent_event.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/domain/agent_run.dart';

void main() {
  final t0 = DateTime(2026, 10, 12, 9);
  final t1 = t0.add(const Duration(minutes: 5));

  AgentRun run({List<String> stages = const ['spec', 'plan', 'implement']}) =>
      AgentRun(
        id: 'ag_1',
        kind: AgentKind.build,
        repoName: 'au2office',
        startedAt: t0,
        updatedAt: t0,
      ).registered(AgentRegistration(stages: stages), t0);

  List<String> states(AgentRun run) => [
    for (final stage in run.stages) stage.state.name,
  ];

  test('the first report moves a run out of starting', () {
    final result = run().reported(const AgentReport(message: 'hej'), t1);

    expect(result.run.state, AgentState.running);
    expect(result.run.summary, 'hej');
    expect(result.run.updatedAt, t1);
    expect(result.event!.message, 'hej');
  });

  test('a waiting run without a stage parks its current stage', () {
    var r = run().reported(const AgentReport(stage: 'spec'), t1).run;
    r = r
        .reported(
          const AgentReport(state: AgentState.waiting, message: 'Gate 1'),
          t1,
        )
        .run;
    expect(states(r), ['waiting', 'pending', 'pending']);

    final resumed = r.reported(
      const AgentReport(state: AgentState.running),
      t1,
    );
    expect(states(resumed.run), ['running', 'pending', 'pending']);
    expect(resumed.event!.message, 'Running');
  });

  test('an unknown stage is added at the end', () {
    final r = run().reported(const AgentReport(stage: 'ship'), t1).run;

    expect(
      [for (final s in r.stages) s.name],
      ['spec', 'plan', 'implement', 'ship'],
    );
    expect(r.currentStage, 'ship');
  });

  test('failing marks the active stages failed and finishes the run', () {
    var r = run().reported(const AgentReport(stage: 'plan'), t1).run;
    final result = r.reported(
      const AgentReport(state: AgentState.failed, message: 'build fejler'),
      t1,
    );
    r = result.run;

    expect(states(r), ['pending', 'failed', 'pending']);
    expect(r.finishedAt, t1);
    expect(result.event!.level, AgentEventLevel.error);
  });

  test('a running stage reopens a finished run', () {
    var r = run().reported(const AgentReport(state: AgentState.done), t1).run;
    expect(r.finishedAt, isNotNull);

    r = r.reported(const AgentReport(stage: 'implement'), t1).run;
    expect(r.state, AgentState.running);
    expect(r.finishedAt, isNull);
  });

  test('re-declaring stages keeps the state of those that remain', () {
    var r = run().reported(const AgentReport(stage: 'spec'), t1).run;
    r = r
        .reported(
          const AgentReport(stages: ['triage', 'spec', 'implement']),
          t1,
        )
        .run;

    expect(states(r), ['pending', 'running', 'pending']);
    expect(r.currentStage, 'spec');
  });

  test('without a message the event says what changed', () {
    final first = run().reported(const AgentReport(stage: 'spec'), t1);
    expect(first.event!.message, 'spec started');

    final done = first.run.reported(
      const AgentReport(stage: 'spec', stageState: AgentStageState.done),
      t1,
    );
    expect(done.event!.message, 'spec done');

    final nothing = done.run.reported(
      const AgentReport(stage: 'spec', stageState: AgentStageState.done),
      t1,
    );
    expect(nothing.event, isNull);
  });

  test('links replace those with the same label', () {
    var r = run()
        .reported(
          const AgentReport(
            links: [AgentLink(label: 'spec', target: '.factory/spec.md')],
          ),
          t1,
        )
        .run;
    r = r
        .reported(
          const AgentReport(
            links: [
              AgentLink(label: 'spec', target: '.factory/spec-v2.md'),
              AgentLink(label: 'PR', target: 'https://github.com/x/y/pull/1'),
            ],
          ),
          t1,
        )
        .run;

    expect(
      [for (final l in r.links) l.target],
      ['.factory/spec-v2.md', 'https://github.com/x/y/pull/1'],
    );
    expect(r.links.last.isUrl, isTrue);
  });

  test('round-trips through JSON', () {
    final r = run()
        .reported(
          const AgentReport(
            stage: 'implement',
            progressDone: 4,
            progressTotal: 7,
            result: 'PR #1',
            links: [AgentLink(label: 'spec', target: '.factory/spec.md')],
          ),
          t1,
        )
        .run;

    final copy = AgentRun.fromJson(r.toJson());
    expect(copy.toJson(), r.toJson());
    expect(copy.activeStage!.progressDone, 4);
  });
}
