import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/git_service.dart';
import 'services/config_service.dart';
import 'services/remote_control_service.dart';
import 'providers/copilot_provider.dart';
import 'providers/repo_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/terminal_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const TreeLauncherApp());
}

class TreeLauncherApp extends StatelessWidget {
  const TreeLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final gitService = GitService();
    final configService = ConfigService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => RepoProvider(
            gitService: gitService,
            configService: configService,
          )..loadRepos(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            configService: configService,
          )..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => TerminalProvider(),
        ),
        ChangeNotifierProxyProvider<RepoProvider, CopilotProvider>(
          create: (ctx) => CopilotProvider(
            repoProvider: ctx.read<RepoProvider>(),
          ),
          update: (ctx, repoProvider, previous) =>
              previous ?? CopilotProvider(repoProvider: repoProvider),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Watch settings so MaterialApp rebuilds on theme change.
          context.watch<SettingsProvider>();
          return MaterialApp(
            title: 'TreeLauncher',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            home: const _RemoteControlManager(child: HomeScreen()),
          );
        },
      ),
    );
  }
}

/// Manages the RemoteControlService lifecycle based on settings.
class _RemoteControlManager extends StatefulWidget {
  final Widget child;
  const _RemoteControlManager({required this.child});

  @override
  State<_RemoteControlManager> createState() => _RemoteControlManagerState();
}

class _RemoteControlManagerState extends State<_RemoteControlManager> {
  RemoteControlService? _service;
  bool _lastEnabled = false;
  int _lastPort = 8422;
  String _lastBindAddress = '127.0.0.1';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsProvider>().settings;
    final enabled = settings.remoteControlEnabled;
    final port = settings.remoteControlPort;
    final bindAddress = settings.remoteControlBindAddress;

    if (enabled != _lastEnabled || port != _lastPort || bindAddress != _lastBindAddress) {
      _lastEnabled = enabled;
      _lastPort = port;
      _lastBindAddress = bindAddress;
      _updateService(enabled, bindAddress, port);
    }
  }

  Future<void> _updateService(bool enabled, String bindAddress, int port) async {
    if (enabled) {
      _service ??= RemoteControlService(
        copilotProvider: context.read<CopilotProvider>(),
      );
      await _service!.restart(bindAddress: bindAddress, port: port);
    } else {
      await _service?.stop();
    }
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
