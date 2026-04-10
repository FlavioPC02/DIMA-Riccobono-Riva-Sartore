class Profile {
  final String nickname;
  final String mail;
  final double xp;
  
  Profile({
    required this.nickname,
    required this.mail,
    required this.xp,
  });

  Profile copyWith({
    String? nickname,
    String? mail,
    double? xp,
  }) {
    return Profile(
      nickname: nickname ?? this.nickname, 
      mail: mail ?? this.mail, 
      xp: xp ?? this.xp,
    );
  }

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'email': mail,
    'xp': xp,
  };

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      nickname: json['nickname'] ?? 'name', 
      mail: json['email'] ?? 'placeholder@mail.com', 
      xp: (json['xp'] ?? 0.0).toDouble(),
    );
  }
}