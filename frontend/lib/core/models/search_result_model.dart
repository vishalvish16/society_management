class GlobalSearchResult {
  final String type;
  final String id;
  final String title;
  final String subtitle;
  final String route;

  const GlobalSearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  factory GlobalSearchResult.fromJson(Map<String, dynamic> json) {
    return GlobalSearchResult(
      type: (json['type'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
    );
  }
}

