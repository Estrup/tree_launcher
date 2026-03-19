import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart';
import 'package:tree_launcher/features/copilot/presentation/controllers/copilot_controller.dart';
import 'package:tree_launcher/features/markdown_editor/domain/markdown_document.dart';
import 'package:tree_launcher/features/settings/presentation/controllers/settings_controller.dart';

/// Global key used for the standalone Notes tab (not tied to a worktree).
const _globalKey = '__global__';

class MarkdownEditorController extends ChangeNotifier {
  MarkdownEditorController({
    required SettingsController settingsController,
    required CopilotController copilotController,
  }) : _settingsController = settingsController,
       _copilotController = copilotController;

  final SettingsController _settingsController;
  final CopilotController _copilotController;

  /// Documents keyed by worktree path (or [_globalKey] for standalone tab).
  final Map<String, MarkdownDocument?> _documents = {};

  /// Current worktree key — null means the standalone Notes tab.
  String? _activeWorktreeKey;

  /// Active copilot session ID (for computing session folder paths).
  String? _activeCopilotSessionId;

  bool _isSidePanelOpen = false;
  double _sidePanelRatio = 0.4;

  String get _currentKey => _activeWorktreeKey ?? _globalKey;

  MarkdownDocument? get activeDocument => _documents[_currentKey];
  String? get activeWorktreeKey => _activeWorktreeKey;
  bool get isSidePanelOpen => _isSidePanelOpen;
  double get sidePanelRatio => _sidePanelRatio;
  bool get hasDocument => activeDocument != null;
  bool get hasCopilotSession => _activeCopilotSessionId != null;
  List<String> get recentFiles =>
      _settingsController.settings.markdownRecentFiles;

  /// Path to the active copilot session's state folder.
  String? get sessionFolder {
    final id = _activeCopilotSessionId;
    if (id == null) return null;
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return '$home/.copilot/session-state/$id';
  }

  /// Path to the active copilot session's files folder.
  String? get sessionFilesFolder {
    final folder = sessionFolder;
    if (folder == null) return null;
    return '$folder/files';
  }

  /// Switch which worktree's notes are active.
  /// Pass null to switch to the standalone Notes tab.
  void setActiveWorktree({
    String? workingDirectory,
    String? copilotSessionId,
  }) {
    _activeWorktreeKey = workingDirectory;
    _activeCopilotSessionId = copilotSessionId;
    notifyListeners();
  }

  Future<void> openFile([String? path]) async {
    String? filePath = path;

    if (filePath == null) {
      // Default to session files folder, then documents folder
      final initialDir = sessionFilesFolder ??
          sessionFolder ??
          _settingsController.settings.markdownDocumentsFolder;
      final result = await file_selector.openFile(
        acceptedTypeGroups: [
          const file_selector.XTypeGroup(
            label: 'Markdown',
            extensions: ['md', 'markdown', 'txt', 'mdx'],
          ),
          const file_selector.XTypeGroup(label: 'All files'),
        ],
        initialDirectory: initialDir,
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

  /// Create a new markdown file in the session files folder.
  Future<void> createNewDocument(String fileName) async {
    final filesFolder = sessionFilesFolder;
    if (filesFolder == null) return;

    try {
      final dir = Directory(filesFolder);
      if (!await dir.exists()) await dir.create(recursive: true);

      var name = fileName.trim();
      if (!name.endsWith('.md')) name = '$name.md';

      final filePath = '$filesFolder/$name';
      final file = File(filePath);
      if (await file.exists()) {
        // Open existing file instead of overwriting
        await openFile(filePath);
        return;
      }

      await file.writeAsString('# $name\n\n');
      await openFile(filePath);
    } catch (e) {
      debugPrint('Failed to create document: $e');
    }
  }

  /// Open the active copilot session's plan.md.
  Future<void> openPlanMd() async {
    final folder = sessionFolder;
    if (folder == null) return;
    final planPath = '$folder/plan.md';
    final file = File(planPath);
    if (!await file.exists()) {
      // Create it if it doesn't exist
      await file.parent.create(recursive: true);
      await file.writeAsString('');
    }
    await openFile(planPath);
  }

  /// Paste the full file contents into the active copilot terminal.
  void sendContentToCopilot() {
    final doc = activeDocument;
    if (doc == null) return;
    final terminal = _copilotController.activeTerminal;
    if (terminal == null) return;
    terminal.writeInput(doc.content);
  }

  /// Type the file's absolute path into the active copilot terminal.
  void insertFilePathInCopilot() {
    final doc = activeDocument;
    if (doc == null) return;
    final terminal = _copilotController.activeTerminal;
    if (terminal == null) return;
    terminal.writeInput(doc.path);
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
