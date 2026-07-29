class AlertModel {
  const AlertModel({
    required this.id,
    required this.source,
    required this.title,
    required this.description,
    required this.linkUrl,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;
  final String source;
  final String title;
  final String description;
  final String linkUrl;
  final int sortOrder;
  final bool isActive;

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    return AlertModel(
      id: (map['id'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      linkUrl: (map['linkUrl'] ?? '').toString(),
      sortOrder: int.tryParse((map['sortOrder'] ?? 0).toString()) ?? 0,
      isActive: map['isActive'] != false && map['isActive'] != 0,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id.isNotEmpty) 'id': int.tryParse(id) ?? id,
        'source': source,
        'title': title,
        'description': description,
        'linkUrl': linkUrl,
        'sortOrder': sortOrder,
        'isActive': isActive,
      };
}
