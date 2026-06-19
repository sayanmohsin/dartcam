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
}
