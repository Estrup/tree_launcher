/// Identifies an agent type by its id (e.g. `build`), the name the API, the
/// database and saved prompts use. What the type is called, looks like and
/// does is its `AgentType` in the app settings' catalog, which the user
/// edits; an agent run of a kind is one of that type's runs, and a saved
/// prompt with a kind starts one.
extension type const AgentKind(String id) {
  /// The ids of the types the catalog starts with.
  static const refine = AgentKind('refine');
  static const build = AgentKind('build');
  static const verify = AgentKind('verify');
  static const review = AgentKind('review');
  static const docs = AgentKind('docs');
  static const support = AgentKind('support');

  /// The kind called [name] (any case), or null for none. Whether the
  /// catalog has it is for the caller to check.
  static AgentKind? tryParse(String? name) {
    final id = name?.trim().toLowerCase();
    return id == null || id.isEmpty ? null : AgentKind(id);
  }
}
