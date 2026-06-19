class ActivityNote {
  final String id;
  final String text;
  final List<String> imageUrls;
  final DateTime createdAt;

  ActivityNote({
    required this.id,
    required this.text,
    this.imageUrls = const [],
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'imageUrls': imageUrls,
    'createdAt': createdAt.millisecondsSinceEpoch, 
  };

  factory ActivityNote.fromJson(Map<String, dynamic> json) {
    return ActivityNote(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      imageUrls: (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? 
          const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] ?? 0),
    );
  }
}