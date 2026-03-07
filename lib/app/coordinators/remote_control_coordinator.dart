import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/kanban/data/issue_api_controller.dart';
import 'package:tree_launcher/features/kanban/data/issue_api_service.dart';
import 'package:tree_launcher/features/kanban/presentation/controllers/kanban_controller.dart';
import 'package:tree_launcher/features/remote_control/data/remote_control_service.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

class RemoteControlCoordinator extends StatefulWidget {
  const RemoteControlCoordinator({required this.child, super.key});

  final Widget child;

  @override
  State<RemoteControlCoordinator> createState() =>
      _RemoteControlCoordinatorState();
}

class _RemoteControlCoordinatorState extends State<RemoteControlCoordinator> {
  RemoteControlService? _service;
  bool _lastEnabled = false;
  int _lastPort = 8422;
  String _lastBindAddress = '127.0.0.1';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsController>().settings;
    final enabled = settings.remoteControlEnabled;
    final port = settings.remoteControlPort;
    final bindAddress = settings.remoteControlBindAddress;

    if (enabled == _lastEnabled &&
        port == _lastPort &&
        bindAddress == _lastBindAddress) {
      return;
    }

    _lastEnabled = enabled;
    _lastPort = port;
    _lastBindAddress = bindAddress;
    _updateService(enabled, bindAddress, port);
  }

  Future<void> _updateService(
    bool enabled,
    String bindAddress,
    int port,
  ) async {
    if (enabled) {
      _service ??= RemoteControlService(
        copilotProvider: context.read<CopilotController>(),
        issueApiController: IssueApiController(
          issueService: IssueApiService(),
          onRepoMutated: (repoPath) async {
            context.read<KanbanController>().refreshLoadedRepoIfMatches(
              repoPath,
            );
          },
        ),
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
