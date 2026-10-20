import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:tree_launcher/core/design_system/app_snackbar.dart';
import 'package:tree_launcher/core/design_system/app_theme.dart';
import 'package:tree_launcher/core/platform/open_external.dart';
import 'package:tree_launcher/core/widgets/issue_list.dart';
import 'package:tree_launcher/features/agents/domain/agent_kind.dart';
import 'package:tree_launcher/features/agents/presentation/widgets/agent_kind_style.dart';
import 'package:tree_launcher/features/documents/domain/session_document.dart';
import 'package:tree_launcher/features/documents/presentation/controllers/documents_controller.dart';
import 'package:tree_launcher/features/documents/presentation/widgets/document_panel.dart';
import 'package:tree_launcher/features/workspace/presentation/controllers/workspace_controller.dart';

/// A repo page listing the documents its sessions saved, newest first and
/// grouped by when, with the selected one in the viewer beside the list.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _search = TextEditingController();
  AgentKind? _kind;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<WorkspaceController>().selectedRepo;
    final documents = context.watch<DocumentsController>();
    if (repo == null) return const SizedBox.shrink();

    final all = documents.documentsFor(repoName: repo.name);
    final kinds = {for (final d in all) ?d.agentKind};
    final query = _search.text.trim().toLowerCase();
    final visible = [
      for (final d in all)
        if ((_kind == null || d.agentKind == _kind) && _matches(d, query)) d,
    ];
    final selectedId = documents.selectedFor(repo.name);
    final selected = visible.any((d) => d.id == selectedId)
        ? selectedId
        : visible.firstOrNull?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchField(
                  controller: _search,
                  onChanged: () => setState(() {}),
                ),
                if (kinds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _KindChip(
                        label: 'All',
                        selected: _kind == null,
                        onTap: () => setState(() => _kind = null),
                      ),
                      for (final kind in AgentKind.values)
                        if (kinds.contains(kind))
                          _KindChip(
                            label: kind.label,
                            icon: kind.icon,
                            color: kind.color,
                            selected: _kind == kind,
                            onTap: () => setState(() => _kind = kind),
                          ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            'No documents match.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : _DocumentList(
                          documents: visible,
                          selectedId: selected,
                          onSelect: (id) => documents.select(repo.name, id),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface0,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              clipBehavior: Clip.antiAlias,
              child: selected == null
                  ? Center(
                      child: Text(
                        'Select a document',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : DocumentPanel(
                      key: ValueKey(selected),
                      documentId: selected,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _matches(SessionDocument d, String query) {
    if (query.isEmpty) return true;
    return d.title.toLowerCase().contains(query) ||
        d.issueKeys.any((k) => k.toLowerCase().contains(query)) ||
        (d.worktreePath != null &&
            p.basename(d.worktreePath!).toLowerCase().contains(query));
  }
}

/// The list, under Today / Yesterday / This week / Older headings.
class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.documents,
    required this.selectedId,
    required this.onSelect,
  });

  final List<SessionDocument> documents;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final items = <Widget>[];
    String? group;
    for (final d in documents) {
      final g = documentDateGroup(d.updatedAt, now);
      if (g != group) {
        group = g;
        items.add(
          Padding(
            padding: EdgeInsets.only(top: items.isEmpty ? 4 : 14, bottom: 6),
            child: Text(
              g.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
          ),
        );
      }
      items.add(
        _DocumentRow(
          document: d,
          selected: d.id == selectedId,
          onTap: () => onSelect(d.id),
        ),
      );
    }
    return ListView(children: items);
  }
}

/// Which heading [at] goes under, seen at [now].
String documentDateGroup(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo <= 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  final monday = today.subtract(Duration(days: today.weekday - 1));
  if (!day.isBefore(monday)) return 'This week';
  return 'Older';
}

class _DocumentRow extends StatefulWidget {
  const _DocumentRow({
    required this.document,
    required this.selected,
    required this.onTap,
  });

  final SessionDocument document;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DocumentRow> createState() => _DocumentRowState();
}

class _DocumentRowState extends State<_DocumentRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.document;
    final kind = d.agentKind;
    final details = [
      ...d.issueKeys,
      if (d.worktreePath != null) p.basename(d.worktreePath!),
      formatRelativeTime(d.updatedAt),
    ];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (e) => _showMenu(context, e.globalPosition),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.surface2
                : _hovered
                ? AppColors.surface1
                : AppColors.surface0,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected
                  ? AppColors.border
                  : AppColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  kind?.icon ?? documentIcon(d.format),
                  size: 16,
                  color: kind?.color ?? AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              DocumentFormatTag(format: d.format),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final d = widget.document;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'open', child: Text('Open in default app')),
        PopupMenuItem(value: 'reveal', child: Text('Reveal in Finder')),
        PopupMenuItem(value: 'copy', child: Text('Copy path')),
        PopupMenuItem(value: 'delete', child: Text('Delete…')),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'open':
        openExternal(d.filePath);
      case 'reveal':
        revealInFinder(d.filePath);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: d.filePath));
        showAppSnackBar('Copied ${d.filePath}');
      case 'delete':
        await confirmDeleteDocument(context, d);
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: (_) => onChanged(),
    style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
    decoration: InputDecoration(
      isDense: true,
      hintText: 'Search title, issue, worktree',
      prefixIcon: const Icon(Icons.search_rounded, size: 16),
      prefixIconConstraints: const BoxConstraints(minWidth: 32),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded, size: 14),
              onPressed: () {
                controller.clear();
                onChanged();
              },
            ),
    ),
  );
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface2 : AppColors.surface1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.border : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color ?? AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
