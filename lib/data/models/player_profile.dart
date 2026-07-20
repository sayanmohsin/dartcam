class PlayerProfile {
  final String id;
  final String name;
  final int currentScore;

  // Lifetime stats (persisted across matches)
  final int totalMatches;
  final int totalWins;
  final int totalDartsThrown;
  final int oneEightyCount;
  final int centuryCount;
  final int highestCheckout;

  const PlayerProfile({
    required this.id,
    required this.name,
    required this.currentScore,
    this.totalMatches = 0,
    this.totalWins = 0,
    this.totalDartsThrown = 0,
    this.oneEightyCount = 0,
    this.centuryCount = 0,
    this.highestCheckout = 0,
  });

  PlayerProfile copyWith({
    String? id,
    String? name,
    int? currentScore,
    int? totalMatches,
    int? totalWins,
    int? totalDartsThrown,
    int? oneEightyCount,
    int? centuryCount,
    int? highestCheckout,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      currentScore: currentScore ?? this.currentScore,
      totalMatches: totalMatches ?? this.totalMatches,
      totalWins: totalWins ?? this.totalWins,
      totalDartsThrown: totalDartsThrown ?? this.totalDartsThrown,
      oneEightyCount: oneEightyCount ?? this.oneEightyCount,
      centuryCount: centuryCount ?? this.centuryCount,
      highestCheckout: highestCheckout ?? this.highestCheckout,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currentScore': currentScore,
        'totalMatches': totalMatches,
        'totalWins': totalWins,
        'totalDartsThrown': totalDartsThrown,
        'oneEightyCount': oneEightyCount,
        'centuryCount': centuryCount,
        'highestCheckout': highestCheckout,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        currentScore: json['currentScore'] as int,
        totalMatches: json['totalMatches'] as int? ?? 0,
        totalWins: json['totalWins'] as int? ?? 0,
        totalDartsThrown: json['totalDartsThrown'] as int? ?? 0,
        oneEightyCount: json['oneEightyCount'] as int? ?? 0,
        centuryCount: json['centuryCount'] as int? ?? 0,
        highestCheckout: json['highestCheckout'] as int? ?? 0,
      );
}
