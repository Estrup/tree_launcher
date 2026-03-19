import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:tree_launcher/features/markdown_editor/domain/markdown_document.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

class MarkdownEditorController extends ChangeNotifier {
  MarkdownEditorController({required SettingsController settingsController})
    : _settingsController = settingsController;

  final SettingsController _settingsController;

  MarkdownDocument? _activeDocument;
  bool _isSidePanelOpen = false;
  double _sidePanelRatio = 0.4;

  MarkdownDocument? get activeDocument => _activeDocument;
  bool get isSidePanelOpen => _isSidePanelOpen;
  double get sidePanelRatio => _sidePanelRatio;
  bool get hasDocument => _activeDocument != null;
  List<String> get recentFiles => _settingsController.settings.markdownRecentFiles;

  Future<void> openFile([String? path]) async {
    String? filePath = path;

    if (filePath == null) {
      final docsFolder = _settingsController.settings.markdownDocumentsFolder;
      final result = await file_selector.openFile(
        acceptedTypeGroups: [
          const file_selector.XTypeGroup(
            label: 'Markdown',
            extensions: ['md', 'markdown', 'txt', 'mdx'],
          ),
          const file_selector.XTypeGroup(label: 'All files'),
        ],
        initialDirectory: docsFolder,
      );
      if (result == null) return;
      filePath = result.path;
    }

    try {
      final resolvedPath = filePath;
      final file = File(resolvedPath);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      _activeDocument = MarkdownDocument(
        path: resolvedPath,
        content: content,
        savedContent: content,
      );
      await _settingsController.addRecentMarkdownFile(resolvedPath);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to open file: $e');
    }
  }

  Future<void> saveDocument() async {
    final doc = _activeDocument;
    if (doc == null) return;
    try {
      final file = File(doc.path);
      await file.writeAsString(doc.content);
      _activeDocument = doc.copyWith(savedContent: doc.content);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save file: $e');
    }
  }

  void updateContent(String content) {
    final doc = _activeDocument;
    if (doc == null) return;
    _activeDocument = doc.copyWith(content: content);
    notifyListeners();
  }

  void updateCursorOffset(int offset) {
    final doc = _activeDocument;
    if (doc == null) return;
    _activeDocument = doc.copyWith(cursorOffset: offset);
    // No notify — cursor updates shouldn't trigger rebuilds
  }

  void closeDocument() {
    _activeDocument = null;
    notifyListeners();
  }

  void removeRecentFile(String path) {
    _settingsController.removeRecentMarkdownFile(path);
    notifyListeners();
  }

  void toggleSidePanel() {
    _isSidePanelOpen = !_isSidePanelOpen;
    notifyListeners();
  }

  void openSidePanel() {
    if (!_isSidePanelOpen) {
      _isSidePanelOpen = true;
      notifyListeners();
    }
  }

  void closeSidePanel() {
    if (_isSidePanelOpen) {
      _isSidePanelOpen = false;
      notifyListeners();
    }
  }

  void setSidePanelRatio(double ratio) {
    _sidePanelRatio = ratio.clamp(0.2, 0.8);
    notifyListeners();
  }
}
