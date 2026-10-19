import 'package:flutter/foundation.dart';

import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

/// Debug-only agent API port override, supplied via
/// `--dart-define=AGENT_API_PORT=NNNN`. Lets `flutter run` bind a non-default
/// port without touching the saved config, so a debug instance doesn't collide
/// with a normally-running one. `0` means "not set" — fall back to the config.
const int agentApiPortOverride = int.fromEnvironment('AGENT_API_PORT');

/// Runs the agent API on the right port — the debug override when there is
/// one, else the saved setting — and changes or restarts it for the Settings
/// dialog's Agent API section.
class AgentApiControl extends ChangeNotifier {
  AgentApiControl({
    required AgentApiServer server,
    required SettingsController settings,
    int portOverride = agentApiPortOverride,
  }) : _server = server,
       _settings = settings,
       portOverride = portOverride == 0 ? null : portOverride;

  final AgentApiServer _server;
  final SettingsController _settings;

  /// The port `AGENT_API_PORT` pins this process to, or null when it isn't
  /// set. It wins over the saved setting and is never saved.
  final int? portOverride;

  bool get isRunning => _server.isRunning;

  /// The port the server is listening on, or null when it isn't running.
  int? get port => _server.port;

  /// The port this process uses: [portOverride] when set, else the saved one.
  int get configuredPort => portOverride ?? _settings.settings.agentApiPort;

  bool _restarting = false;

  /// Whether a [restart] is under way.
  bool get restarting => _restarting;

  /// Starts the server on [configuredPort]. Never throws.
  Future<void> start() async {
    await _server.start(port: configuredPort);
    notifyListeners();
  }

  /// Saves [port] as the agent API's port and restarts the server on it.
  /// Does nothing while [portOverride] pins the port, or when [port] is the
  /// saved one already.
  Future<void> changePort(int port) async {
    if (portOverride != null || port == _settings.settings.agentApiPort) {
      return;
    }
    await _settings.updateAgentApiPort(port);
    await restart();
  }

  /// Stops the server and starts it again on [configuredPort]. Never throws;
  /// a failed rebind leaves it stopped.
  Future<void> restart() async {
    if (_restarting) return;
    _restarting = true;
    notifyListeners();
    try {
      await _server.restart(port: configuredPort);
    } finally {
      _restarting = false;
      notifyListeners();
    }
  }
}
