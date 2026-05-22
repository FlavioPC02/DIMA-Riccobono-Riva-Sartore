class Profile {
  final String nickname;
  final String mail;
  double xp;
  int level;
  
  Profile({
    required this.nickname,
    required this.mail,
    required this.xp,
    required this.level,
  });

  Profile copyWith({
    String? nickname,
    String? mail,
    double? xp,
    int? level,
  }) {
    return Profile(
      nickname: nickname ?? this.nickname, 
      mail: mail ?? this.mail, 
      xp: xp ?? this.xp,
      level: level ?? this.level,
    );
  }

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'email': mail,
    'xp': xp,
    'level': level,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      nickname: json['nickname'] ?? 'name', 
      mail: json['email'] ?? 'placeholder@mail.com', 
      xp: (json['xp'] ?? 0.0).toDouble(),
      level: (json['level'] ?? 0).toInt(),
    );
  }
}