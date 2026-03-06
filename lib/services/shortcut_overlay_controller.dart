import 'package:flutter/foundation.dart';

enum ShortcutOverlayPhase { closed, listening, sending }

class ShortcutOverlayController extends ChangeNotifier {
  ShortcutOverlayController({Duration sendDelay = const Duration(seconds: 4)})
    : _sendDelay = sendDelay;

  final Duration _sendDelay;
  bool _disposed = false;
  ShortcutOverlayPhase _phase = ShortcutOverlayPhase.closed;

  ShortcutOverlayPhase get phase => _phase;
  bool get isVisible => _phase != ShortcutOverlayPhase.closed;
  bool get isSending => _phase == ShortcutOverlayPhase.sending;
  bool get canDismiss => _phase == ShortcutOverlayPhase.listening;
  bool get canSubmit => _phase == ShortcutOverlayPhase.listening;
  String get statusLabel => switch (_phase) {
    ShortcutOverlayPhase.closed => '',
    ShortcutOverlayPhase.listening => 'Listening',
    ShortcutOverlayPhase.sending => 'Sending...',
  };

  Future<void> handleShortcut() async {
    if (_phase == ShortcutOverlayPhase.closed) {
      _setPhase(ShortcutOverlayPhase.listening);
      return;
    }

    await submit();
  }

  Future<void> submit() async {
    if (_phase != ShortcutOverlayPhase.listening) {
      return;
    }

    _setPhase(ShortcutOverlayPhase.sending);
    await Future<void>.delayed(_sendDelay);

    if (_disposed) {
      return;
    }

    _setPhase(ShortcutOverlayPhase.closed);
  }

  void dismiss() {
    if (_phase != ShortcutOverlayPhase.listening) {
      return;
    }

    _setPhase(ShortcutOverlayPhase.closed);
  }

  void _setPhase(ShortcutOverlayPhase phase) {
    if (_disposed || _phase == phase) {
      return;
    }

    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
