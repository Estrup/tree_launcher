import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:tree_launcher/providers/repo_provider.dart';

class AddRepoDialog extends StatelessWidget {
  const AddRepoDialog({super.key});

  static const _channel = MethodChannel('tree_launcher/directory_picker');

  static Future<String?> _pickDirectory() async {
    if (Platform.isWindows) {
      return FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select a Git Repository',
      );
    }
    return _channel.invokeMethod<String>('pickDirectory');
  }

  static Future<void> show(BuildContext context) async {
    final repoProvider = context.read<RepoProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final String? result = await _pickDirectory();

    if (result == null) return;

    final dir = Directory(result);
    if (!await dir.exists()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Selected path is not a valid directory')),
      );
      return;
    }

    try {
      await repoProvider.addRepo(result);
      messenger.showSnackBar(
        SnackBar(content: Text('Added repository: ${p.basename(result)}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
