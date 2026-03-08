import 'package:flutter/material.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';

class BranchSearchDropdown extends StatefulWidget {
  final List<String> branches;
  final String? selectedBranch;
  final ValueChanged<String> onSelected;
  final bool enabled;

  const BranchSearchDropdown({
    super.key,
    required this.branches,
    required this.onSelected,
    this.selectedBranch,
    this.enabled = true,
  });

  @override
  State<BranchSearchDropdown> createState() => _BranchSearchDropdownState();
}

class _BranchSearchDropdownState extends State<BranchSearchDropdown> {
  static const double _fallbackFieldWidth = 360;
  static const double _fallbackFieldHeight = 44;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    if (widget.selectedBranch != null) {
      _controller.text = widget.selectedBranch!;
    }
    _filtered = widget.branches;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(BranchSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branches != widget.branches) {
      _filtered = _filterBranches(_controller.text);
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      // Delay to allow tap on overlay item
      Future.delayed(const Duration(milliseconds: 200), _removeOverlay);
    }
  }

  List<String> _filterBranches(String query) {
    if (query.isEmpty) return widget.branches;
    final lower = query.toLowerCase();
    return widget.branches
        .where((b) => b.toLowerCase().contains(lower))
        .toList();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(builder: (context) => _buildOverlay());
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Size _getFieldSize() {
    final renderObject = _fieldKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size;
    }
    return const Size(_fallbackFieldWidth, _fallbackFieldHeight);
  }

  Widget _buildOverlay() {
    final fieldSize = _getFieldSize();
    return Positioned(
      width: fieldSize.width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, fieldSize.height + 4),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'No branches found',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final branch = _filtered[index];
                      final isSelected = branch == _controller.text;
                      return _BranchItem(
                        branch: branch,
                        isSelected: isSelected,
                        onTap: () {
                          _controller.text = branch;
                          widget.onSelected(branch);
                          _focusNode.unfocus();
                          _removeOverlay();
                        },
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        key: _fieldKey,
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        style: appFormFieldTextStyle(context, monospace: true),
        decoration: InputDecoration(
          hintText: 'Search branches...',
          hintStyle: appFormFieldHintStyle(context, monospace: true),
          suffixIcon: Icon(
            Icons.unfold_more_rounded,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
        onChanged: (value) {
          setState(() {
            _filtered = _filterBranches(value);
          });
          _overlayEntry?.markNeedsBuild();
          if (_overlayEntry == null && _focusNode.hasFocus) {
            _showOverlay();
          }
        },
      ),
    );
  }
}

class _BranchItem extends StatefulWidget {
  final String branch;
  final bool isSelected;
  final VoidCallback onTap;

  const _BranchItem({
    required this.branch,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_BranchItem> createState() => _BranchItemState();
}

class _BranchItemState extends State<_BranchItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: widget.isSelected
              ? AppColors.accentMuted
              : _hovered
              ? AppColors.surfaceHover
              : Colors.transparent,
          child: Text(
            widget.branch,
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              color: widget.isSelected
                  ? AppColors.accent
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
