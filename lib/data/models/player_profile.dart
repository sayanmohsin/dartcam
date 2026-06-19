class PlayerProfile {
  final String id;
  final String name;
  final int currentScore;

  const PlayerProfile({
    required this.id,
    required this.name,
    required this.currentScore,
  });

  PlayerProfile copyWith({
    String? id,
    String? name,
    int? currentScore,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      currentScore: currentScore ?? this.currentScore,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currentScore': currentScore,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        currentScore: json['currentScore'] as int,
      );
}
