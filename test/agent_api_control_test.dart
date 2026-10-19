import 'package:flutter_test/flutter_test.dart';
import 'package:tree_launcher/app/use_cases/agent_api_control.dart';
import 'package:tree_launcher/features/agent_api/data/agent_api_server.dart';
import 'package:tree_launcher/features/settings/domain/app_settings.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

import 'fake_config_stores.dart';

/// Records the ports it is started on instead of binding them.
class _FakeServer implements AgentApiServer {
  final starts = <int>[];
  int? _port;

  @override
  bool get isRunning => _port != null;

  @override
  int? get port => _port;

  @override
  Future<void> start({int port = AgentApiServer.defaultPort}) async {
    starts.add(port);
    _port = port;
  }

  @override
  Future<void> stop() async => _port = null;

  @override
  Future<void> restart({int port = AgentApiServer.defaultPort}) async {
    await stop();
    await start(port: port);
  }
}

void main() {
  // The settings controller syncs the window's colors over a channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAppSettingsStore store;
  late SettingsController settings;
  late _FakeServer server;

  setUp(() async {
    store = FakeAppSettingsStore(AppSettings(agentApiPort: 9001));
    settings = SettingsController(store: store);
    await settings.loadSettings();
    server = _FakeServer();
  });

  tearDown(() => settings.dispose());

  AgentApiControl control({int portOverride = 0}) {
    final control = AgentApiControl(
      server: server,
      settings: settings,
      portOverride: portOverride,
    );
    addTearDown(control.dispose);
    return control;
  }

  test('starts on the saved port', () async {
    final api = control();

    await api.start();

    expect(api.portOverride, isNull);
    expect(api.configuredPort, 9001);
    expect(server.starts, [9001]);
    expect(api.isRunning, isTrue);
  });

  test('changing the port saves it and restarts there', () async {
    final api = control();
    await api.start();
    final states = <bool>[];
    api.addListener(() => states.add(api.restarting));

    await api.changePort(9002);

    expect(store.savedSettings.agentApiPort, 9002);
    expect(server.starts, [9001, 9002]);
    expect(api.port, 9002);
    expect(states, [true, false]);
  });

  test('the same port changes nothing', () async {
    final api = control();
    await api.start();

    await api.changePort(9001);

    expect(server.starts, [9001]);
  });

  test('a debug override wins and is never saved', () async {
    final api = control(portOverride: 8766);
    await api.start();

    await api.changePort(9002);
    await api.restart();

    expect(api.portOverride, 8766);
    expect(api.configuredPort, 8766);
    expect(store.savedSettings.agentApiPort, 9001);
    expect(server.starts, [8766, 8766]);
  });
}
