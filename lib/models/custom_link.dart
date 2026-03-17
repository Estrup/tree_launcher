class CustomLink {
  final String name;
  final String url;
  final String? iconName;
  final String? colorHex;

  CustomLink({
    required this.name,
    required this.url,
    this.iconName,
    this.colorHex,
  });

  factory CustomLink.fromJson(Map<String, dynamic> json) {
    return CustomLink(
      name: json['name'] as String,
      url: json['url'] as String,
      iconName: json['iconName'] as String?,
      colorHex: json['colorHex'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    if (iconName != null) 'iconName': iconName,
    if (colorHex != null) 'colorHex': colorHex,
  };

  CustomLink copyWith({
    String? name,
    String? url,
    String? iconName,
    String? colorHex,
  }) {
    return CustomLink(
      name: name ?? this.name,
      url: url ?? this.url,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
    );
  }
}
