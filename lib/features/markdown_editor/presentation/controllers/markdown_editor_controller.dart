import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:tree_launcher/features/markdown_editor/domain/markdown_document.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

/// Global key used for the standalone Notes tab (not tied to a worktree).
const _globalKey = '__global__';

class MarkdownEditorController extends ChangeNotifier {
  MarkdownEditorController({required SettingsController settingsController})
    : _settingsController = settingsController;

  final SettingsController _settingsController;

  /// Documents keyed by worktree path (or [_globalKey] for standalone tab).
  final Map<String, MarkdownDocument?> _documents = {};

  /// Current worktree key — null means the standalone Notes tab.
  String? _activeWorktreeKey;

  bool _isSidePanelOpen = false;
  double _sidePanelRatio = 0.4;

  String get _currentKey => _activeWorktreeKey ?? _globalKey;

  MarkdownDocument? get activeDocument => _documents[_currentKey];
  String? get activeWorktreeKey => _activeWorktreeKey;
  bool get isSidePanelOpen => _isSidePanelOpen;
  double get sidePanelRatio => _sidePanelRatio;
  bool get hasDocument => activeDocument != null;
  List<String> get recentFiles =>
      _settingsController.settings.markdownRecentFiles;

  /// Switch which worktree's notes are active.
  /// Pass null to switch to the standalone Notes tab.
  void setActiveWorktree(String? workingDirectory) {
    _activeWorktreeKey = workingDirectory;
    notifyListeners();
  }

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
      _documents[_currentKey] = MarkdownDocument(
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
    final doc = activeDocument;
    if (doc == null) return;
    try {
      final file = File(doc.path);
      await file.writeAsString(doc.content);
      _documents[_currentKey] = doc.copyWith(savedContent: doc.content);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save file: $e');
    }
  }

  void updateContent(String content) {
    final doc = activeDocument;
    if (doc == null) return;
    _documents[_currentKey] = doc.copyWith(content: content);
    notifyListeners();
  }

  void updateCursorOffset(int offset) {
    final doc = activeDocument;
    if (doc == null) return;
    _documents[_currentKey] = doc.copyWith(cursorOffset: offset);
  }

  void closeDocument() {
    _documents.remove(_currentKey);
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
