import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/features/builds/data/azure_devops_service.dart';
import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/domain/build_result.dart';
import 'package:tree_launcher/features/builds/presentation/controllers/builds_controller.dart';

/// Fake service that returns scripted build results and counts fetch calls.
class _FakeAzureDevopsService extends AzureDevopsService {
  _FakeAzureDevopsService(this._results);

  Map<int, BuildResult?> _results;
  int fetchCalls = 0;

  void setResults(Map<int, BuildResult?> results) => _results = results;

  @override
  Future<Map<int, BuildResult?>> fetchLatestBuilds(
    AzureDevopsConfig config,
    List<int> definitionIds,
  ) async {
    fetchCalls++;
    return Map.of(_results);
  }
}

BuildResult _build(int definitionId, BuildStatus status) => BuildResult(
      id: definitionId,
      definitionId: definitionId,
      definitionName: 'pipeline-$definitionId',
      status: status,
      result: BuildResultType.none,
    );

AzureDevopsConfig _config() => AzureDevopsConfig(
      serverUrl: 'https://dev.azure.com/org',
      project: 'proj',
      pat: 'token',
      selectedPipelines: [BuildPipelineRef(id: 1, name: 'pipeline-1')],
    );

void main() {
  group('BuildsController polling', () {
    test('polls while a build is in progress and stops once it settles', () {
      fakeAsync((async) {
        final service = _FakeAzureDevopsService({
          1: _build(1, BuildStatus.inProgress),
        });
        final controller = BuildsController(service: service);

        controller.loadBuilds(_config());
        async.flushMicrotasks();
        expect(service.fetchCalls, 1); // initial load

        // Timer fires every 5s while the build is in progress.
        async.elapse(const Duration(seconds: 5));
        expect(service.fetchCalls, 2);

        // Build completes; the next poll observes it and stops the timer.
        service.setResults({1: _build(1, BuildStatus.completed)});
        async.elapse(const Duration(seconds: 5));
        expect(service.fetchCalls, 3);

        // No further polls after the build settled.
        async.elapse(const Duration(seconds: 30));
        expect(service.fetchCalls, 3);

        controller.dispose();
      });
    });

    test('does not poll when the latest build is already completed', () {
      fakeAsync((async) {
        final service = _FakeAzureDevopsService({
          1: _build(1, BuildStatus.completed),
        });
        final controller = BuildsController(service: service);

        controller.loadBuilds(_config());
        async.flushMicrotasks();
        expect(service.fetchCalls, 1);

        async.elapse(const Duration(seconds: 30));
        expect(service.fetchCalls, 1); // no polling

        controller.dispose();
      });
    });
  });
}
