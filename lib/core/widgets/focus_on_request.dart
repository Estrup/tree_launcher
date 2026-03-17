import 'package:flutter/material.dart';

class FocusOnRequest extends StatefulWidget {
  const FocusOnRequest({
    super.key,
    required this.focusNode,
    required this.isActive,
    required this.requestVersion,
    required this.child,
  });

  final FocusNode focusNode;
  final bool isActive;
  final int requestVersion;
  final Widget child;

  @override
  State<FocusOnRequest> createState() => _FocusOnRequestState();
}

class _FocusOnRequestState extends State<FocusOnRequest> {
  int _lastHandledRequestVersion = 0;

  @override
  void initState() {
    super.initState();
    _scheduleFocusIfNeeded();
  }

  @override
  void didUpdateWidget(FocusOnRequest oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleFocusIfNeeded();
  }

  void _scheduleFocusIfNeeded() {
    if (!widget.isActive ||
        widget.requestVersion == 0 ||
        widget.requestVersion == _lastHandledRequestVersion) {
      return;
    }

    _lastHandledRequestVersion = widget.requestVersion;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.focusNode.canRequestFocus) {
        return;
      }
      widget.focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
