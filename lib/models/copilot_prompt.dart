class CopilotPrompt {
  final String name;
  final String prompt;

  CopilotPrompt({
    required this.name,
    required this.prompt,
  });

  factory CopilotPrompt.fromJson(Map<String, dynamic> json) {
    return CopilotPrompt(
      name: json['name'] as String,
      prompt: json['prompt'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'prompt': prompt,
      };

  CopilotPrompt copyWith({
    String? name,
    String? prompt,
  }) {
    return CopilotPrompt(
      name: name ?? this.name,
      prompt: prompt ?? this.prompt,
    );
  }
}
