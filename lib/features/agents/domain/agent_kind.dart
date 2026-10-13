/// What an agent does. Each kind has its own tab under a repo, and a saved
/// prompt tagged with a kind is one of that kind's subtypes (e.g. "Factory
/// track: feature" is a build agent).
enum AgentKind {
  refine('Refinement'),
  build('Build'),
  verify('Verify'),
  review('Review'),
  docs('Docs');

  const AgentKind(this.label);

  /// Name shown in the UI (tab title, prompt editor).
  final String label;

  /// The kind called [name] (its API/JSON name, any case), or null.
  static AgentKind? tryParse(String? name) {
    if (name == null) return null;
    final lower = name.trim().toLowerCase();
    for (final kind in values) {
      if (kind.name == lower) return kind;
    }
    return null;
  }
}
