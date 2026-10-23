import 'package:tree_launcher/features/agents/domain/agent_kind.dart';

/// A type of agent in the catalog the user keeps in the app settings (e.g.
/// "Build", "Support"). Each repo has a tab per type it has switched on and
/// has prompts or runs of; agents register with the type's [kind].
class AgentType {
  /// Stable id that runs, documents, prompts and the API refer to, so
  /// renaming keeps them.
  final AgentKind kind;

  /// Name shown in the UI (tab title, prompt editor).
  final String label;

  /// One of [agentTypeIcons].
  final String icon;

  /// One of [agentTypeColors].
  final String color;

  /// Whether the agent works in an issue's worktree of its own (like a build
  /// agent) rather than reading code in a shared one: its start dialog
  /// offers new worktrees, the worktree's Claude session is remembered, and
  /// the sidebar lists the agent instead of that session.
  final bool ownsWorktree;

  const AgentType({
    required this.kind,
    required this.label,
    this.icon = defaultAgentTypeIcon,
    this.color = defaultAgentTypeColor,
    this.ownsWorktree = false,
  });

  /// Stands in for a [kind] the catalog no longer has, for the runs,
  /// documents and prompts that still name it.
  factory AgentType.unknown(AgentKind kind) => AgentType(
    kind: kind,
    label: kind.id.isEmpty
        ? kind.id
        : kind.id[0].toUpperCase() + kind.id.substring(1),
  );

  factory AgentType.fromJson(Map<String, dynamic> json) => AgentType(
    kind: AgentKind(json['id'] as String),
    label: json['label'] as String,
    icon: json['icon'] as String? ?? defaultAgentTypeIcon,
    color: json['color'] as String? ?? defaultAgentTypeColor,
    ownsWorktree: json['ownsWorktree'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': kind.id,
    'label': label,
    'icon': icon,
    'color': color,
    if (ownsWorktree) 'ownsWorktree': true,
  };

  AgentType copyWith({
    String? label,
    String? icon,
    String? color,
    bool? ownsWorktree,
  }) => AgentType(
    kind: kind,
    label: label ?? this.label,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    ownsWorktree: ownsWorktree ?? this.ownsWorktree,
  );

  @override
  bool operator ==(Object other) =>
      other is AgentType &&
      other.kind == kind &&
      other.label == label &&
      other.icon == icon &&
      other.color == color &&
      other.ownsWorktree == ownsWorktree;

  @override
  int get hashCode => Object.hash(kind, label, icon, color, ownsWorktree);
}

/// The catalog a new install starts with.
const defaultAgentTypes = [
  AgentType(
    kind: AgentKind.refine,
    label: 'Refinement',
    icon: 'edit_note',
    color: 'magenta',
  ),
  AgentType(
    kind: AgentKind.build,
    label: 'Build',
    icon: 'construction',
    color: 'accent',
    ownsWorktree: true,
  ),
  AgentType(
    kind: AgentKind.verify,
    label: 'Verify',
    icon: 'fact_check',
    color: 'green',
  ),
  AgentType(
    kind: AgentKind.review,
    label: 'Review',
    icon: 'rate_review',
    color: 'blue',
  ),
  AgentType(
    kind: AgentKind.docs,
    label: 'Docs',
    icon: 'menu_book',
    color: 'branch',
  ),
  AgentType(
    kind: AgentKind.support,
    label: 'Support',
    icon: 'support_agent',
    color: 'cyan',
  ),
];

/// Icons an [AgentType] can have, by name.
const agentTypeIcons = [
  'edit_note',
  'construction',
  'fact_check',
  'rate_review',
  'menu_book',
  'support_agent',
  'bug_report',
  'science',
  'search',
  'rocket_launch',
  'security',
  'speed',
  'psychology',
  'forum',
  'smart_toy',
];

const defaultAgentTypeIcon = 'smart_toy';

/// Colors an [AgentType] can have, by name.
const agentTypeColors = [
  'accent',
  'magenta',
  'green',
  'blue',
  'branch',
  'cyan',
  'yellow',
  'red',
  'gray',
];

const defaultAgentTypeColor = 'gray';

/// The type of [kind] in [types], or a stand-in when it has none.
AgentType agentTypeIn(List<AgentType> types, AgentKind kind) =>
    types.where((t) => t.kind == kind).firstOrNull ?? AgentType.unknown(kind);

/// An id for a new type called [label]: its letters and digits in lower case,
/// words joined by `-`, made unique among [taken]. Null when [label] has
/// none.
AgentKind? agentKindForLabel(String label, Iterable<AgentKind> taken) {
  final base = label
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) return null;
  final used = {for (final kind in taken) kind.id};
  var id = base;
  for (var n = 2; used.contains(id); n++) {
    id = '$base-$n';
  }
  return AgentKind(id);
}
