class CustomCommand {
  final String name;
  final String command;

  CustomCommand({required this.name, required this.command});

  factory CustomCommand.fromJson(Map<String, dynamic> json) {
    return CustomCommand(
      name: json['name'] as String,
      command: json['command'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'command': command,
      };
}
