import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/errors/user_message.dart';

class AddRepoDialog extends StatelessWidget {
  const AddRepoDialog({super.key});

  static const _channel = MethodChannel('tree_launcher/directory_picker');

  static Future<void> show(BuildContext context) async {
    final repoProvider = context.read<WorkspaceController>();
    final String? result = await _channel.invokeMethod<String>('pickDirectory');

    if (result == null) return;

    final dir = Directory(result);
    if (!await dir.exists()) {
      showAppSnackBar('Selected path is not a valid directory');
      return;
    }

    try {
      await repoProvider.addRepo(result);
      showAppSnackBar('Added repository: ${result.split('/').last}');
    } catch (e) {
      showAppSnackBar(userMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
