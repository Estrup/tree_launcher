/// A reusable, named prompt template for launching Claude in a worktree.
/// Placeholders ({issue}, {base_branch}, {worktree}, {path}, {repo}) are filled
/// from the worktree before launch.
class ClaudePrompt {
  final String name;
  final String prompt;

  ClaudePrompt({required this.name, required this.prompt});

  factory ClaudePrompt.fromJson(Map<String, dynamic> json) {
    return ClaudePrompt(
      name: json['name'] as String,
      prompt: json['prompt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'prompt': prompt};

  ClaudePrompt copyWith({String? name, String? prompt}) {
    return ClaudePrompt(name: name ?? this.name, prompt: prompt ?? this.prompt);
  }
}
