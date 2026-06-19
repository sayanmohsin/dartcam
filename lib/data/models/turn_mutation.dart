class TurnMutation {
  final String playerId;
  final List<int> detectedScores;
  final int totalTurnScore;
  final int scoreBeforeTurn;

  const TurnMutation({
    required this.playerId,
    required this.detectedScores,
    required this.totalTurnScore,
    required this.scoreBeforeTurn,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'detectedScores': detectedScores,
        'totalTurnScore': totalTurnScore,
        'scoreBeforeTurn': scoreBeforeTurn,
      };

  factory TurnMutation.fromJson(Map<String, dynamic> json) => TurnMutation(
        playerId: json['playerId'] as String,
        detectedScores: List<int>.from(json['detectedScores'] as List),
        totalTurnScore: json['totalTurnScore'] as int,
        scoreBeforeTurn: json['scoreBeforeTurn'] as int,
      );
}
