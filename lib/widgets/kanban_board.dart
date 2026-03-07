import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum KanbanColumnStatus { todo, inProgress, inReview, done }

class KanbanBoard extends StatefulWidget {
  const KanbanBoard({super.key});

  @override
  State<KanbanBoard> createState() => _KanbanBoardState();
}

class _KanbanBoardState extends State<KanbanBoard> {
  late Map<KanbanColumnStatus, List<_KanbanCardData>> _columns;

  @override
  void initState() {
    super.initState();
    _columns = {
      KanbanColumnStatus.todo: [_DummyData.cards[0]],
      KanbanColumnStatus.inProgress: [_DummyData.cards[1]],
      KanbanColumnStatus.inReview: [_DummyData.cards[2]],
      KanbanColumnStatus.done: [_DummyData.cards[3], _DummyData.cards[4]],
    };
  }

  void _moveCard(_KanbanCardData card, KanbanColumnStatus targetStatus) {
    setState(() {
      for (var list in _columns.values) {
        list.removeWhere((c) => c.id == card.id);
      }
      _columns[targetStatus]?.add(card);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KanbanColumn(
            title: 'To do',
            status: KanbanColumnStatus.todo,
            cards: _columns[KanbanColumnStatus.todo] ?? [],
            onCardDrop: _moveCard,
          ),
          const SizedBox(width: 16),
          _KanbanColumn(
            title: 'In progress',
            status: KanbanColumnStatus.inProgress,
            cards: _columns[KanbanColumnStatus.inProgress] ?? [],
            onCardDrop: _moveCard,
          ),
          const SizedBox(width: 16),
          _KanbanColumn(
            title: 'In review',
            status: KanbanColumnStatus.inReview,
            cards: _columns[KanbanColumnStatus.inReview] ?? [],
            onCardDrop: _moveCard,
          ),
          const SizedBox(width: 16),
          _KanbanColumn(
            title: 'Done',
            status: KanbanColumnStatus.done,
            cards: _columns[KanbanColumnStatus.done] ?? [],
            onCardDrop: _moveCard,
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final KanbanColumnStatus status;
  final List<_KanbanCardData> cards;
  final void Function(_KanbanCardData card, KanbanColumnStatus target)
  onCardDrop;

  const _KanbanColumn({
    required this.title,
    required this.status,
    required this.cards,
    required this.onCardDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<_KanbanCardData>(
      onAcceptWithDetails: (details) {
        onCardDrop(details.data, status);
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
                        '${cards.length}',
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
                itemCount: cards.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return Draggable<_KanbanCardData>(
                    data: cards[index],
                    dragAnchorStrategy: pointerDragAnchorStrategy,
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: 304,
                        child: Transform.rotate(
                          angle: 0.03,
                          child: Opacity(
                            opacity: 0.8,
                            child: KanbanCard(data: cards[index]),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: KanbanCard(data: cards[index]),
                    ),
                    child: KanbanCard(data: cards[index]),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
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
            ],
          ),
        );
      },
    );
  }
}

class KanbanCard extends StatelessWidget {
  final _KanbanCardData data;

  const KanbanCard({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            data.id,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.description != null) ...[
            const SizedBox(height: 8),
            Text(
              data.description!,
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
              Icon(Icons.circle_outlined, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              if (data.tags.isNotEmpty)
                ...data.tags.map(
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
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  'https://ui-avatars.com/api/?name=AI&background=random&size=40',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.person, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KanbanCardData {
  final String id;
  final String title;
  final String? description;
  final List<String> tags;

  const _KanbanCardData({
    required this.id,
    required this.title,
    this.description,
    this.tags = const [],
  });
}

class _DummyData {
  static const List<_KanbanCardData> cards = [
    _KanbanCardData(
      id: 'ISS-11',
      title: 'Bug: Image generation sometimes stalls at 99%',
      description:
          'Description for AI Agent: Investigate and fix an issue where image generation occasionally stalls at 99% progress and never resolves. This happens...',
      tags: ['bug'],
    ),
    _KanbanCardData(
      id: 'ISS-12',
      title: 'Implement drag and drop for cards',
      description:
          'Users should be able to drag cards between columns to update their status.',
      tags: ['feature'],
    ),
    _KanbanCardData(
      id: 'ISS-13',
      title: 'Dark mode styling fixes',
      description:
          'In dark mode, the card borders are too bright. Needs adjustment.',
      tags: ['design'],
    ),
    _KanbanCardData(
      id: 'ISS-8',
      title: 'Set up initial repository structure',
      description:
          'Initialize flutter project and create basic folder structure.',
      tags: ['chore'],
    ),
    _KanbanCardData(
      id: 'ISS-10',
      title: 'Create dummy data for kanban board prototyping',
      tags: ['feature'],
    ),
  ];
}
