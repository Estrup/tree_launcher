import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tree_launcher/core/design_system/app_form_fields.dart';
import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/logging/app_log.dart';
import 'package:tree_launcher/core/platform/open_external.dart';

/// The Log window: the app's log, newest at the bottom, filtered by level,
/// source and text. It follows new entries while scrolled to the bottom.
class LogDialog extends StatefulWidget {
  const LogDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<AppLog>(),
      child: const LogDialog(),
    ),
  );

  @override
  State<LogDialog> createState() => _LogDialogState();
}

class _LogDialogState extends State<LogDialog> {
  LogLevel _minLevel = LogLevel.info;
  String? _source;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final log = context.watch<AppLog>();
    final entries = log.entries;
    final sources = {for (final e in entries) e.source}.toList()..sort();
    final query = _query.toLowerCase();
    final shown = [
      for (final e in entries)
        if (e.level.index >= _minLevel.index &&
            (_source == null || e.source == _source) &&
            (query.isEmpty ||
                e.message.toLowerCase().contains(query) ||
                e.source.contains(query)))
          e,
    ];
    final size = MediaQuery.sizeOf(context);
    final directory = log.directory;

    return Dialog(
      backgroundColor: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.all(32),
      child: SizedBox(
        width: (size.width - 64).clamp(600, 1200),
        height: (size.height - 64).clamp(400, 900),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 12, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 130,
                    child: AppDropdownField<LogLevel>(
                      initialValue: _minLevel,
                      items: [
                        for (final level in LogLevel.values)
                          DropdownMenuItem(
                            value: level,
                            child: Text(
                              level == LogLevel.debug
                                  ? 'Everything'
                                  : '${_levelName(level)}+',
                            ),
                          ),
                      ],
                      onChanged: (level) =>
                          setState(() => _minLevel = level ?? LogLevel.info),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 170,
                    child: AppDropdownField<String>(
                      // Rebuilt when a new source shows up.
                      key: ValueKey(sources.length),
                      initialValue: _source ?? '',
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('All sources'),
                        ),
                        for (final source in sources)
                          DropdownMenuItem(value: source, child: Text(source)),
                      ],
                      onChanged: (source) => setState(
                        () => _source = source == null || source.isEmpty
                            ? null
                            : source,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      style: appFormFieldTextStyle(context),
                      decoration: InputDecoration(
                        hintText: 'Filter',
                        hintStyle: appFormFieldHintStyle(context),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                  if (directory != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: 'Copy the log folder path',
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: directory));
                        showAppSnackBar('Copied $directory');
                      },
                    ),
                    IconButton(
                      tooltip: 'Open the log folder',
                      icon: const Icon(Icons.folder_open_outlined, size: 16),
                      onPressed: () => openExternal(directory),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(
                        entries.isEmpty
                            ? 'Nothing logged yet'
                            : 'Nothing matches the filter',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : SelectionArea(
                      // Reversed, so it starts at the newest entry and stays
                      // there as entries come in.
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: shown.length,
                        itemBuilder: (context, index) =>
                            _LogRow(entry: shown[shown.length - 1 - index]),
                      ),
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Text(
                '${shown.length} of ${entries.length} entries'
                '${directory == null ? '' : ' · one file a day in $directory'}',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _levelName(LogLevel level) =>
    '${level.name[0].toUpperCase()}${level.name.substring(1)}';

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      LogLevel.debug => AppColors.textMuted,
      LogLevel.info => AppColors.accent,
      LogLevel.warning => AppColors.claude,
      LogLevel.error => AppColors.error,
    };
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
      color: entry.level == LogLevel.debug
          ? AppColors.textMuted
          : AppColors.textPrimary,
    );
    final time = entry.at.toIso8601String();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              time.substring(11, 23),
              style: mono.copyWith(color: AppColors.textMuted),
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              entry.level.name.toUpperCase(),
              style: mono.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 116,
            child: Text(
              entry.source,
              overflow: TextOverflow.ellipsis,
              style: mono.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(child: Text(entry.message, style: mono)),
        ],
      ),
    );
  }
}
