class CustomCommand {
  final String name;
  final String command;
  final String? iconName;
  final String? colorHex;

  CustomCommand({
    required this.name,
    required this.command,
    this.iconName,
    this.colorHex,
  });

  factory CustomCommand.fromJson(Map<String, dynamic> json) {
    return CustomCommand(
      name: json['name'] as String,
      command: json['command'] as String,
      iconName: json['iconName'] as String?,
      colorHex: json['colorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'command': command,
        if (iconName != null) 'iconName': iconName,
        if (colorHex != null) 'colorHex': colorHex,
      };

  CustomCommand copyWith({
    String? name,
    String? command,
    String? iconName,
    String? colorHex,
  }) {
    return CustomCommand(
      name: name ?? this.name,
      command: command ?? this.command,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}
