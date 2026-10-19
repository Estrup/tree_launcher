import 'package:tree_launcher/features/workspace/domain/repo_config.dart';

/// The repos in the running app, for readers outside the UI such as the agent
/// HTTP API.
///
/// Implemented by the live `WorkspaceController`, whose in-memory repos are
/// the ones the app saves, so readers never see a stale copy from disk.
abstract interface class RepoCatalog {
  /// Every repo, in sidebar order. Empty until [whenLoaded] completes.
  List<RepoConfig> get repos;

  /// Completes once the saved repos have been read at startup (also when
  /// that failed, leaving [repos] empty).
  Future<void> get whenLoaded;
}
