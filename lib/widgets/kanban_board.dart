import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/issue.dart';
import '../providers/kanban_provider.dart';
import '../theme/app_theme.dart';
import 'create_issue_dialog.dart';
import 'issue_view_dialog.dart';

enum KanbanColumnStatus { todo, inProgress, inReview, done }

class KanbanBoard extends StatelessWidget {
  final String projectId;

  const KanbanBoard({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final kanbanProvider = context.watch<KanbanProvider>();
    final columns = kanbanProvider.issuesByStatus(projectId);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KanbanColumn(
            title: 'To do',
            status: KanbanColumnStatus.todo,
            issues: columns[KanbanColumnStatus.todo] ?? [],
            projectId: projectId,
          ),
          const SizedBox(width: 16),
          _KanbanColumn(
            title: 'In progress',
            status: KanbanColumnStatus.inProgress,
            issues: columns[KanbanColumnStatus.inProgress] ?? [],
            projectId: projectId,
          ),
          const SizedBox(width: 16),
          _KanbanColumn(
            title: 'In review',
            status: KanbanColumnStatus.inReview,
            issues: columns[KanbanColumnStatus.inReview] ?? [],
            projectId: projectId,
          ),
          const SizedBox(width: 16),
          _KanbanColumn(
            title: 'Done',
            status: KanbanColumnStatus.done,
            issues: columns[KanbanColumnStatus.done] ?? [],
            projectId: projectId,
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final KanbanColumnStatus status;
  final List<Issue> issues;
  final String projectId;

  const _KanbanColumn({
    required this.title,
    required this.status,
    required this.issues,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Issue>(
      onAcceptWithDetails: (details) {
        context.read<KanbanProvider>().moveIssue(
          details.data.id,
          details.data.projectId,
          status,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          width: 320,
          decoration: BoxDecoration(
            color: isHovered ? AppColors.surface2 : AppColors.surface0,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHovered ? AppColors.accent : AppColors.borderSubtle,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${issues.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.more_horiz,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              ListView.separated(
                padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: issues.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return Draggable<Issue>(
                    data: issues[index],
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 304,
                        child: Transform.rotate(
                          angle: 0.03,
                          child: Opacity(
                            opacity: 0.8,
                            child: _KanbanCard(issue: issues[index]),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _KanbanCard(issue: issues[index]),
                    ),
                    child: _KanbanCard(issue: issues[index]),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: GestureDetector(
                  onTap: () => CreateIssueDialog.show(context, projectId),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Add card',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final Issue issue;

  const _KanbanCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => IssueViewDialog(issue: issue),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                issue.id.substring(0, 8),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                issue.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (issue.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  issue.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.circle_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  if (issue.tags.isNotEmpty)
                    ...issue.tags.map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.borderSubtle),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
