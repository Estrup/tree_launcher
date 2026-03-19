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

  /// Open documents keyed by worktree path (or [_globalKey] for standalone).
  final Map<String, List<MarkdownDocument>> _documents = {};

  /// Index of the active document within each key's list.
  final Map<String, int> _activeDocIndex = {};

  /// Current worktree key — null means the standalone Notes tab.
  String? _activeWorktreeKey;

  /// Active copilot session ID (for computing session folder paths).
  String? _activeCopilotSessionId;

  bool _isSidePanelOpen = false;
  double _sidePanelRatio = 0.4;

  String get _currentKey => _activeWorktreeKey ?? _globalKey;

  List<MarkdownDocument> get openDocuments =>
      _documents[_currentKey] ?? const [];

  int get activeDocumentIndex => _activeDocIndex[_currentKey] ?? 0;

  MarkdownDocument? get activeDocument {
    final docs = _documents[_currentKey];
    if (docs == null || docs.isEmpty) return null;
    final idx = (_activeDocIndex[_currentKey] ?? 0).clamp(0, docs.length - 1);
    return docs[idx];
  }

  String? get activeWorktreeKey => _activeWorktreeKey;
  String? get activeCopilotSessionId => _activeCopilotSessionId;
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

  /// Default directory for file dialogs (configured documents folder).
  String? get _defaultDialogDir =>
      _settingsController.settings.markdownDocumentsFolder ??
      sessionFilesFolder ??
      sessionFolder;

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

  /// Switch to a document by index within the current key's list.
  void switchToDocument(int index) {
    final docs = _documents[_currentKey];
    if (docs == null || index < 0 || index >= docs.length) return;
    _activeDocIndex[_currentKey] = index;
    notifyListeners();
  }

  Future<void> openFile([String? path]) async {
    String? filePath = path;

    if (filePath == null) {
      final result = await file_selector.openFile(
        acceptedTypeGroups: [
          const file_selector.XTypeGroup(
            label: 'Markdown',
            extensions: ['md', 'markdown', 'txt', 'mdx'],
          ),
          const file_selector.XTypeGroup(label: 'All files'),
        ],
        initialDirectory: _defaultDialogDir,
      );
      if (result == null) return;
      filePath = result.path;
    }

    try {
      final resolvedPath = filePath;
      final file = File(resolvedPath);
      if (!await file.exists()) return;

      // If already open, just switch to it
      final docs = _documents[_currentKey] ?? [];
      final existingIdx = docs.indexWhere((d) => d.path == resolvedPath);
      if (existingIdx != -1) {
        _activeDocIndex[_currentKey] = existingIdx;
        notifyListeners();
        return;
      }

      final content = await file.readAsString();
      final doc = MarkdownDocument(
        path: resolvedPath,
        content: content,
        savedContent: content,
      );
      _addDocument(doc);
      await _settingsController.addRecentMarkdownFile(resolvedPath);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to open file: $e');
    }
  }

  /// Create a new in-memory document. Not written to disk until saved.
  void createNewDocument(String fileName) {
    var name = fileName.trim();
    if (!name.endsWith('.md')) name = '$name.md';

    final doc = MarkdownDocument(
      path: name,
      content: '# ${name.replaceAll('.md', '')}\n\n',
      savedContent: '',
      isUntitled: true,
    );
    _addDocument(doc);
    notifyListeners();
  }

  /// Open the active copilot session's plan.md.
  Future<void> openPlanMd() async {
    final folder = sessionFolder;
    if (folder == null) return;
    final planPath = '$folder/plan.md';
    final file = File(planPath);
    if (!await file.exists()) {
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
    if (doc == null || doc.isUntitled) return;
    final terminal = _copilotController.activeTerminal;
    if (terminal == null) return;
    terminal.writeInput(doc.path);
  }

  Future<void> saveDocument() async {
    final doc = activeDocument;
    if (doc == null) return;

    if (doc.isUntitled) {
      await _saveAs(doc);
      return;
    }

    try {
      final file = File(doc.path);
      await file.writeAsString(doc.content);
      _replaceActiveDoc(doc.copyWith(savedContent: doc.content));
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save file: $e');
    }
  }

  /// Prompt the user for a save location and write the document.
  Future<void> _saveAs(MarkdownDocument doc) async {
    final result = await file_selector.getSaveLocation(
      acceptedTypeGroups: [
        const file_selector.XTypeGroup(
          label: 'Markdown',
          extensions: ['md', 'markdown', 'txt', 'mdx'],
        ),
        const file_selector.XTypeGroup(label: 'All files'),
      ],
      initialDirectory: _defaultDialogDir,
      suggestedName: doc.fileName,
    );
    if (result == null) return;

    try {
      final savePath = result.path;
      final file = File(savePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(doc.content);
      _replaceActiveDoc(doc.copyWith(
        path: savePath,
        savedContent: doc.content,
        isUntitled: false,
      ));
      await _settingsController.addRecentMarkdownFile(savePath);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save file: $e');
    }
  }

  void updateContent(String content) {
    final doc = activeDocument;
    if (doc == null) return;
    _replaceActiveDoc(doc.copyWith(content: content));
    notifyListeners();
  }

  void updateCursorOffset(int offset) {
    final doc = activeDocument;
    if (doc == null) return;
    _replaceActiveDoc(doc.copyWith(cursorOffset: offset));
  }

  void closeDocument([int? index]) {
    final docs = _documents[_currentKey];
    if (docs == null || docs.isEmpty) return;
    final idx = index ?? (_activeDocIndex[_currentKey] ?? 0);
    if (idx < 0 || idx >= docs.length) return;

    docs.removeAt(idx);
    if (docs.isEmpty) {
      _documents.remove(_currentKey);
      _activeDocIndex.remove(_currentKey);
    } else {
      final activeIdx = _activeDocIndex[_currentKey] ?? 0;
      if (activeIdx >= docs.length) {
        _activeDocIndex[_currentKey] = docs.length - 1;
      } else if (idx < activeIdx) {
        _activeDocIndex[_currentKey] = activeIdx - 1;
      }
    }
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

  // ── Helpers ──────────────────────────────────────────────────────────

  void _addDocument(MarkdownDocument doc) {
    final docs = _documents.putIfAbsent(_currentKey, () => []);
    docs.add(doc);
    _activeDocIndex[_currentKey] = docs.length - 1;
  }

  void _replaceActiveDoc(MarkdownDocument doc) {
    final docs = _documents[_currentKey];
    if (docs == null || docs.isEmpty) return;
    final idx = (_activeDocIndex[_currentKey] ?? 0).clamp(0, docs.length - 1);
    docs[idx] = doc;
  }
}
