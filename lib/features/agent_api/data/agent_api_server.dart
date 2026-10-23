import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'package:tree_launcher/features/activity/domain/activity_service.dart';
import 'package:tree_launcher/features/activity/domain/manual_post_writer.dart';
import 'package:tree_launcher/core/logging/app_log.dart';
import 'package:tree_launcher/features/agent_api/data/api_http.dart';
import 'package:tree_launcher/features/agent_api/data/routes/activity_routes.dart';
import 'package:tree_launcher/features/agent_api/data/routes/agent_routes.dart';
import 'package:tree_launcher/features/agent_api/data/routes/claude_session_routes.dart';
import 'package:tree_launcher/features/agent_api/data/routes/document_routes.dart';
import 'package:tree_launcher/features/agent_api/data/routes/jira_routes.dart';
import 'package:tree_launcher/features/agent_api/data/routes/worktree_routes.dart';
import 'package:tree_launcher/features/agents/domain/agent_registry.dart';
import 'package:tree_launcher/features/agents/domain/claude_session_starter.dart';
import 'package:tree_launcher/features/documents/domain/document_library.dart';
import 'package:tree_launcher/features/jira/data/jira_api_service.dart';
import 'package:tree_launcher/features/jira/domain/jira_tag_editor.dart';
import 'package:tree_launcher/features/settings/domain/app_settings_source.dart';
import 'package:tree_launcher/features/workspace/data/git_service.dart';
import 'package:tree_launcher/features/workspace/domain/issue_base_branches.dart';
import 'package:tree_launcher/features/workspace/domain/repo_catalog.dart';
import 'package:tree_launcher/features/workspace/domain/worktree_creator.dart';

/// A small HTTP server, bound to loopback only, that exposes app data to local
/// AI agents (for use in Claude Code skills).
///
/// v1 surfaces the Activity timeline (and manual posts into it), worktree
/// creation, starting Claude in a worktree, Jira issues with the user's local tags (which it can set, but
/// never anything in Jira), agent runs, which agents register and report
/// their progress to, and the documents sessions save about their work. Each area's routes live in `routes/`; adding a
/// capability is a handler there, mounted in [_router].
///
/// Requests a web page could send are refused: see [_localClientsOnly].
///
/// Everything goes through the running app's controllers rather than the
/// saved files, so the API and the UI always agree.
class AgentApiServer {
  AgentApiServer({
    required RepoCatalog repos,
    required AppSettingsSource settings,
    required WorktreeCreator worktreeCreator,
    required JiraTagEditor jiraTagEditor,
    required AgentRegistry agentRegistry,
    required ClaudeSessionStarter claudeSessions,
    required ActivityService activity,
    required ManualPostWriter manualPosts,
    required DocumentLibrary documents,
    required DocumentSaver documentSaver,
    required GitService gitService,
    JiraApiService? jiraService,
    IssueBaseBranches? issueBaseBranches,
  }) : _activityRoutes = ActivityRoutes(
         repos: repos,
         gitService: gitService,
         activity: activity,
         manualPosts: manualPosts,
       ),
       _worktreeRoutes = WorktreeRoutes(
         settings: settings,
         creator: worktreeCreator,
         baseBranches: issueBaseBranches,
       ),
       _claudeSessionRoutes = ClaudeSessionRoutes(
         settings: settings,
         starter: claudeSessions,
         baseBranches: issueBaseBranches,
       ),
       _jiraRoutes = JiraRoutes(
         repos: repos,
         tags: jiraTagEditor,
         jira: jiraService ?? JiraApiService(),
       ),
       _agentRoutes = AgentRoutes(
         repos: repos,
         gitService: gitService,
         registry: agentRegistry,
         settings: settings,
       ),
       _documentRoutes = DocumentRoutes(
         repos: repos,
         library: documents,
         saver: documentSaver,
         settings: settings,
       );

  /// Default loopback port the agent API listens on.
  static const int defaultPort = 8765;

  final ActivityRoutes _activityRoutes;
  final WorktreeRoutes _worktreeRoutes;
  final ClaudeSessionRoutes _claudeSessionRoutes;
  final JiraRoutes _jiraRoutes;
  final AgentRoutes _agentRoutes;
  final DocumentRoutes _documentRoutes;

  HttpServer? _server;
  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// Starts the server on `127.0.0.1:[port]`. Never throws — if the bind fails
  /// (e.g. the port is already in use) it logs and leaves the server stopped so
  /// the app keeps launching normally.
  Future<void> start({int port = defaultPort}) async {
    if (_server != null) return;
    final handler = const Pipeline()
        .addMiddleware(_logRequests)
        .addMiddleware(_localClientsOnly(port))
        .addHandler(_router.call);
    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        port,
      );
      appLog(_source, 'Listening on http://127.0.0.1:${_server!.port}');
    } catch (e) {
      appLog(
        _source,
        'Failed to start on port $port: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> stop() async {
    final server = _server;
    if (server == null) return;
    _server = null;
    await server.close(force: true);
    appLog(_source, 'Stopped');
  }

  static const _source = 'agent-api';

  /// Logs each request with its status and time: reads as debug, changes as
  /// info, refusals as warnings and failures as errors.
  static Handler _logRequests(Handler inner) => (request) async {
    final watch = Stopwatch()..start();
    final query = request.url.hasQuery ? '?${request.url.query}' : '';
    final what = '${request.method} /${request.url.path}$query';
    try {
      final response = await inner(request);
      final status = response.statusCode;
      appLog(
        _source,
        '$what → $status (${watch.elapsedMilliseconds} ms)',
        level: status >= 500
            ? LogLevel.error
            : status >= 400
            ? LogLevel.warning
            : request.method == 'GET'
            ? LogLevel.debug
            : LogLevel.info,
      );
      return response;
    } catch (e) {
      appLog(_source, '$what failed: $e', level: LogLevel.error);
      rethrow;
    }
  };

  /// Stops the server (if running) and starts it again on [port]. Like [start],
  /// never throws — a failed rebind leaves the server stopped.
  Future<void> restart({int port = defaultPort}) async {
    await stop();
    await start(port: port);
  }

  /// Refuses what a web page open in a browser could send here:
  /// - a `Host` other than `127.0.0.1:<port>` or `localhost:<port>` (403),
  ///   which blocks DNS rebinding;
  /// - a POST or PUT that isn't `application/json` (415). Browsers send a
  ///   "simple" cross-site `text/plain` POST without asking, but must ask
  ///   first (a CORS preflight, which this server never answers) for JSON.
  Middleware _localClientsOnly(int requestedPort) =>
      (inner) => (request) {
        // The bound port: [requestedPort] is 0 when the OS picks one.
        final port = _server?.port ?? requestedPort;
        final host = request.headers['host']?.toLowerCase();
        if (host != '127.0.0.1:$port' && host != 'localhost:$port') {
          return jsonResponse({
            'error': 'Host must be 127.0.0.1:$port or localhost:$port',
          }, status: 403);
        }
        if ((request.method == 'POST' || request.method == 'PUT') &&
            _mimeType(request) != 'application/json') {
          return jsonResponse({
            'error': 'Content-Type must be application/json',
          }, status: 415);
        }
        return inner(request);
      };

  static String? _mimeType(Request request) {
    try {
      return request.mimeType;
    } on FormatException {
      return null;
    }
  }

  Router get _router {
    final router = Router()..get('/health', _health);
    _activityRoutes.mount(router);
    _worktreeRoutes.mount(router);
    _claudeSessionRoutes.mount(router);
    _jiraRoutes.mount(router);
    _agentRoutes.mount(router);
    _documentRoutes.mount(router);
    return router;
  }

  Response _health(Request request) =>
      jsonResponse({'status': 'ok', 'service': 'tree_launcher', 'version': 1});
}
