import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:webview_flutter/webview_flutter.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/features/documents/domain/markdown_html.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';

/// Shows one document file in a WKWebView: HTML as written, Markdown
/// rendered in the app's palette (to [renderedPath]), and PDF in WebKit's
/// PDF view.
///
/// Links within the document load in place; web and mail links open
/// outside; anything else (other local files) is blocked. Change [version]
/// to load the file again.
class DocumentView extends StatefulWidget {
  const DocumentView({
    super.key,
    required this.filePath,
    required this.format,
    required this.title,
    required this.renderedPath,
    this.version = 0,
  });

  final String filePath;
  final DocumentFormat format;
  final String title;

  /// Where rendered Markdown is written; unused for HTML and PDF.
  final String renderedPath;
  final Object version;

  @override
  State<DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<DocumentView> {
  WebViewController? _controller;
  String? _error;

  /// The file the web view shows, which links back to it may load.
  String? _shownPath;

  /// The palette rendered Markdown was made in.
  int? _renderedIn;

  @override
  void initState() {
    super.initState();
    if (WebViewPlatform.instance != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(onNavigationRequest: _onNavigation),
        );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The palette lives outside the widget tree; the app rebuilds on a
    // theme change, which lands here and in build.
    _loadIfNeeded();
  }

  @override
  void didUpdateWidget(DocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.version != widget.version ||
        oldWidget.format != widget.format) {
      _renderedIn = null;
      _shownPath = null;
      _loadIfNeeded();
    }
  }

  void _loadIfNeeded() {
    final palette = AppColors.base.toARGB32();
    final markdown = widget.format == DocumentFormat.markdown;
    if (_shownPath != null && (!markdown || _renderedIn == palette)) return;
    _renderedIn = palette;
    _load();
  }

  Future<void> _load() async {
    final controller = _controller;
    try {
      final path = widget.format == DocumentFormat.markdown
          ? await _render()
          : widget.filePath;
      if (!await File(path).exists()) {
        throw FileSystemException('The file is gone', path);
      }
      _shownPath = path;
      if (mounted) setState(() => _error = null);
      await controller?.loadFile(path);
    } catch (e) {
      debugPrint('DocumentView: could not show ${widget.filePath}: $e');
      if (mounted) setState(() => _error = "Couldn't show ${widget.filePath}");
    }
  }

  /// Writes the Markdown, rendered, to [DocumentView.renderedPath].
  Future<String> _render() async {
    final markdown = await File(widget.filePath).readAsString();
    final page = markdownPage(
      markdown,
      title: widget.title,
      style: documentPageStyle(),
    );
    final out = File(widget.renderedPath);
    await out.parent.create(recursive: true);
    await out.writeAsString(page, flush: true);
    return out.path;
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    if (!request.isMainFrame) return NavigationDecision.navigate;
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.isScheme('file')) {
      final shown = _shownPath;
      return shown != null && p.equals(uri.toFilePath(), shown)
          ? NavigationDecision.navigate
          : NavigationDecision.prevent;
    }
    if (uri.isScheme('about')) return NavigationDecision.navigate;
    if (uri.isScheme('http') ||
        uri.isScheme('https') ||
        uri.isScheme('mailto')) {
      openExternal(request.url);
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final controller = _controller;
    if (error != null || controller == null) {
      return Center(
        child: Text(
          error ?? 'The document viewer is not available here.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }
    return WebViewWidget(controller: controller);
  }
}

/// The app's palette as the colours of a rendered Markdown page.
DocumentPageStyle documentPageStyle() => DocumentPageStyle(
  dark: AppColors.brightness == Brightness.dark,
  background: _css(AppColors.base),
  text: _css(AppColors.textPrimary),
  mutedText: _css(AppColors.textSecondary),
  link: _css(AppColors.accent),
  border: _css(AppColors.borderSubtle),
  codeBackground: _css(AppColors.surface1),
);

String _css(Color color) {
  final argb = color.toARGB32();
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final alpha = (argb >> 24) & 0xFF;
  return alpha == 0xFF
      ? '#$rgb'
      : 'rgba(${(argb >> 16) & 0xFF}, ${(argb >> 8) & 0xFF}, ${argb & 0xFF}, '
            '${(alpha / 255).toStringAsFixed(3)})';
}
