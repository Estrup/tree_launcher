import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/git_service.dart';
import 'services/config_service.dart';
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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
