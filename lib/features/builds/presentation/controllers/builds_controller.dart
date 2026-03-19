import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/builds/data/azure_devops_service.dart';
import 'package:tree_launcher/features/builds/domain/azure_devops_config.dart';
import 'package:tree_launcher/features/builds/domain/build_definition.dart';
import 'package:tree_launcher/features/builds/domain/build_result.dart';

class BuildsController extends ChangeNotifier {
  BuildsController({AzureDevopsService? service})
    : _service = service ?? AzureDevopsService();

  final AzureDevopsService _service;

  Map<int, BuildResult?> _latestBuilds = {};
  List<BuildDefinition> _availableDefinitions = [];
  List<String> _branches = [];
  bool _isLoading = false;
  bool _isFetchingDefinitions = false;
  bool _isFetchingBranches = false;
  String? _error;
  String? _definitionsError;

  Map<int, BuildResult?> get latestBuilds => _latestBuilds;
  List<BuildDefinition> get availableDefinitions => _availableDefinitions;
  List<String> get branches => _branches;
  bool get isLoading => _isLoading;
  bool get isFetchingDefinitions => _isFetchingDefinitions;
  bool get isFetchingBranches => _isFetchingBranches;
  String? get error => _error;
  String? get definitionsError => _definitionsError;

  /// Loads the latest build for each selected pipeline.
  Future<void> loadBuilds(AzureDevopsConfig config) async {
    if (!config.isConfigured || config.selectedPipelines.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ids = config.selectedPipelines.map((p) => p.id).toList();
      _latestBuilds = await _service.fetchLatestBuilds(config, ids);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches all pipeline definitions from the project (for settings selector).
  Future<void> fetchDefinitions(AzureDevopsConfig config) async {
    _isFetchingDefinitions = true;
    _definitionsError = null;
    notifyListeners();

    try {
      _availableDefinitions = await _service.fetchDefinitions(config);
    } catch (e) {
      _definitionsError = e.toString();
      _availableDefinitions = [];
    } finally {
      _isFetchingDefinitions = false;
      notifyListeners();
    }
  }

  /// Queues a new build for a pipeline on the given branch.
  Future<BuildResult?> queueBuild(
    AzureDevopsConfig config,
    int definitionId,
    String branch,
  ) async {
    try {
      final result = await _service.queueBuild(config, definitionId, branch);
      _latestBuilds[definitionId] = result;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Fetches branch list from Azure DevOps for the queue build dialog.
  Future<void> loadBranches(AzureDevopsConfig config) async {
    if (!config.isConfigured) return;

    _isFetchingBranches = true;
    notifyListeners();

    try {
      _branches = await _service.fetchBranches(config);
    } catch (e) {
      _branches = [];
    } finally {
      _isFetchingBranches = false;
      notifyListeners();
    }
  }

  /// Refreshes the latest builds for all selected pipelines.
  Future<void> refresh(AzureDevopsConfig config) async {
    await loadBuilds(config);
  }

  void clear() {
    _latestBuilds = {};
    _availableDefinitions = [];
    _branches = [];
    _error = null;
    _definitionsError = null;
    notifyListeners();
  }
}
