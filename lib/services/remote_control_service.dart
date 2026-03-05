import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../providers/copilot_provider.dart';

/// Embedded HTTP + WebSocket server for remote-controlling Copilot terminals.
class RemoteControlService {
  final CopilotProvider _copilotProvider;

  HttpServer? _server;
  bool _running = false;

  // Cached asset bytes (loaded once from Flutter asset bundle)
  final Map<String, List<int>> _assetCache = {};

  RemoteControlService({required CopilotProvider copilotProvider})
      : _copilotProvider = copilotProvider;

  bool get isRunning => _running;
  String? get url =>
      _server != null ? 'http://${_server!.address.host}:${_server!.port}' : null;

  /// Start the HTTP server on the given address and port.
  Future<void> start({
    String bindAddress = '127.0.0.1',
    int port = 8422,
  }) async {
    if (_running) await stop();

    try {
      await _loadAssets();
      _server = await HttpServer.bind(bindAddress, port);
      _running = true;
      debugPrint('[RemoteControl] Server started on http://$bindAddress:$port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[RemoteControl] Server error: $e');
      });
    } catch (e) {
      debugPrint('[RemoteControl] Failed to start server: $e');
      _running = false;
    }
  }

  /// Stop the server.
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _running = false;
      debugPrint('[RemoteControl] Server stopped');
    }
  }

  /// Restart with new settings.
  Future<void> restart({
    required String bindAddress,
    required int port,
  }) async {
    await stop();
    await start(bindAddress: bindAddress, port: port);
  }

  Future<void> _loadAssets() async {
    if (_assetCache.isNotEmpty) return;
    const assets = [
      'assets/remote/index.html',
      'assets/remote/xterm.min.js',
      'assets/remote/xterm.min.css',
      'assets/remote/addon-fit.min.js',
    ];
    for (final path in assets) {
      try {
        final data = await rootBundle.load(path);
        _assetCache[path] = data.buffer.asUint8List();
      } catch (e) {
        debugPrint('[RemoteControl] Failed to load asset $path: $e');
      }
    }
  }

  void _handleRequest(HttpRequest request) {
    final path = request.uri.path;

    if (path.startsWith('/ws/')) {
      _handleWebSocket(request);
      return;
    }

    switch (path) {
      case '/':
        _serveAsset(request, 'assets/remote/index.html', 'text/html');
      case '/assets/xterm.min.js':
        _serveAsset(request, 'assets/remote/xterm.min.js', 'application/javascript');
      case '/assets/xterm.min.css':
        _serveAsset(request, 'assets/remote/xterm.min.css', 'text/css');
      case '/assets/addon-fit.min.js':
        _serveAsset(request, 'assets/remote/addon-fit.min.js', 'application/javascript');
      case '/api/sessions':
        _handleSessionsApi(request);
      default:
        request.response
          ..statusCode = HttpStatus.notFound
          ..write('Not found')
          ..close();
    }
  }

  void _serveAsset(HttpRequest request, String assetPath, String contentType) {
    final data = _assetCache[assetPath];
    if (data == null) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Asset not loaded')
        ..close();
      return;
    }
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.parse(contentType)
      ..add(data)
      ..close();
  }

  void _handleSessionsApi(HttpRequest request) {
    final sessions = _copilotProvider.allSessions;
    final jsonList = sessions.map((s) {
      final status = _copilotProvider.statusForSession(s.id);
      return <String, dynamic>{
        'id': s.id,
        'name': s.name,
        'repoPath': s.repoPath,
        'workingDirectory': s.workingDirectory,
        'status': status.name,
        'hasTerminal': _copilotProvider.terminalForSession(s.id) != null,
      };
    }).toList();

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(jsonList))
      ..close();
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    final sessionId = request.uri.pathSegments.last;
    final terminal = _copilotProvider.terminalForSession(sessionId);

    if (terminal == null || terminal.isDisposed) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Session not found or not running')
        ..close();
      return;
    }

    WebSocket ws;
    try {
      ws = await WebSocketTransformer.upgrade(request);
    } catch (e) {
      debugPrint('[RemoteControl] WebSocket upgrade failed: $e');
      return;
    }

    debugPrint('[RemoteControl] WebSocket connected for session $sessionId');

    // Send current buffer content as catch-up, line by line with \r\n
    // so xterm.js renders proper line breaks (getText() uses \n which
    // doesn't carriage-return the cursor back to column 0).
    try {
      final buf = terminal.terminal.buffer;
      final lineCount = buf.lines.length;
      final sb = StringBuffer();
      for (var i = 0; i < lineCount; i++) {
        final line = buf.lines[i];
        if (i > 0 && !line.isWrapped) {
          sb.write('\r\n');
        }
        sb.write(line.getText());
      }
      final catchUp = sb.toString();
      if (catchUp.isNotEmpty) {
        ws.add(catchUp);
      }
    } catch (e) {
      debugPrint('[RemoteControl] Failed to send buffer catch-up: $e');
    }

    // Register output listener for live streaming
    void outputListener(String data) {
      if (ws.readyState == WebSocket.open) {
        ws.add(data);
      }
    }
    terminal.addOutputListener(outputListener);

    // Listen for input from the web client
    ws.listen(
      (message) {
        if (terminal.isDisposed) return;
        if (message is String) {
          // Check if it's a JSON control message (resize)
          if (message.startsWith('{')) {
            try {
              final json = jsonDecode(message) as Map<String, dynamic>;
              if (json['type'] == 'resize') {
                // Resize is handled by the terminal view in the Flutter app,
                // we don't forward it to the PTY from here since the Flutter
                // app's TerminalView controls the canonical size.
                return;
              }
            } catch (_) {
              // Not JSON — treat as terminal input
            }
          }
          terminal.writeInput(message);
        }
      },
      onDone: () {
        terminal.removeOutputListener(outputListener);
        debugPrint('[RemoteControl] WebSocket disconnected for session $sessionId');
      },
      onError: (e) {
        terminal.removeOutputListener(outputListener);
        debugPrint('[RemoteControl] WebSocket error: $e');
      },
    );
  }

  void dispose() {
    stop();
  }
}
