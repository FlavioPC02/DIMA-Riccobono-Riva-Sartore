class Settings {
  final bool notifications;
  final bool ferrata;
  final double difficulty;

  Settings({
    required this.notifications,
    required this.ferrata,
    required this.difficulty,
  });

  Settings copyWith({
    bool? notifications,
    bool? ferrata,
    double? difficulty,
  }) {
    return Settings(
      notifications: notifications ?? this.notifications, 
      ferrata: ferrata ?? this.ferrata, 
      difficulty: difficulty ?? this.difficulty,
    );
  }

  Map<String, dynamic> toJson() => {
    'notifications': notifications,
    'ferrata': ferrata,
    'difficulty': difficulty,
  };

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      notifications: json['notifications'] ?? true, 
      ferrata: json['ferrata'] ?? false, 
      difficulty: (json['difficulty'] ?? 0.0).toDouble(),
    );
  }
}