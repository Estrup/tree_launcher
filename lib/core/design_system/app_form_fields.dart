import 'package:flutter/material.dart';

import 'package:tree_launcher/core/design_system/app_theme.dart';

TextStyle appFormFieldTextStyle(
  BuildContext context, {
  bool monospace = false,
  FontWeight? fontWeight,
  double? letterSpacing,
  double? height,
}) {
  final base =
      Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 15);
  return base.copyWith(
    color: AppColors.textPrimary,
    fontFamily: monospace ? 'monospace' : base.fontFamily,
    fontWeight: fontWeight,
    letterSpacing: letterSpacing,
    height: height,
  );
}

TextStyle? appFormFieldHintStyle(
  BuildContext context, {
  bool monospace = false,
}) {
  return Theme.of(context).inputDecorationTheme.hintStyle?.copyWith(
    fontFamily: monospace ? 'monospace' : null,
  );
}

class AppDropdownField<T> extends StatelessWidget {
  final T? initialValue;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final TextStyle? style;
  final Widget? icon;
  final bool isExpanded;

  const AppDropdownField({
    super.key,
    required this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.style,
    this.icon,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      isExpanded: isExpanded,
      dropdownColor: AppColors.surface1,
      style: style ?? appFormFieldTextStyle(context),
      icon:
          icon ??
          Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
      decoration: decoration,
      items: items,
      onChanged: onChanged,
    );
  }
}
