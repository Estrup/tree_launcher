/// Greek alphabet slot names for worktrees.
///
/// Each worktree in a repo is assigned a unique slot from this list.
const List<String> greekSlots = [
  'alpha',
  'beta',
  'gamma',
  'delta',
  'epsilon',
  'zeta',
  'eta',
  'theta',
  'iota',
  'kappa',
  'lambda',
  'mu',
  'nu',
  'xi',
  'omicron',
  'pi',
  'rho',
  'sigma',
  'tau',
  'upsilon',
  'phi',
  'chi',
  'psi',
  'omega',
];

/// Returns the first Greek slot not present in [usedSlots].
/// Falls back to 'alpha' if all 24 are taken (unlikely).
String nextAvailableSlot(Set<String> usedSlots) {
  for (final slot in greekSlots) {
    if (!usedSlots.contains(slot)) return slot;
  }
  return greekSlots.first;
}
