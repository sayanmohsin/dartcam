class TurnMutation {
  final String playerId;
  final List<int> detectedScores;
  final int totalTurnScore;
  final int scoreBeforeTurn;
  final List<String>? dartLabels;
  final List<int>? dartMultipliers;
  final bool isAutoDetected;

  const TurnMutation({
    required this.playerId,
    required this.detectedScores,
    required this.totalTurnScore,
    required this.scoreBeforeTurn,
    this.dartLabels,
    this.dartMultipliers,
    this.isAutoDetected = false,
  });

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'detectedScores': detectedScores,
        'totalTurnScore': totalTurnScore,
        'scoreBeforeTurn': scoreBeforeTurn,
        if (dartLabels != null) 'dartLabels': dartLabels,
        if (dartMultipliers != null) 'dartMultipliers': dartMultipliers,
        'isAutoDetected': isAutoDetected,
      };

  factory TurnMutation.fromJson(Map<String, dynamic> json) => TurnMutation(
        playerId: json['playerId'] as String,
        detectedScores: List<int>.from(json['detectedScores'] as List),
        totalTurnScore: json['totalTurnScore'] as int,
        scoreBeforeTurn: json['scoreBeforeTurn'] as int,
        dartLabels: json['dartLabels'] != null
            ? List<String>.from(json['dartLabels'] as List)
            : null,
        dartMultipliers: json['dartMultipliers'] != null
            ? List<int>.from(json['dartMultipliers'] as List)
            : null,
        isAutoDetected: json['isAutoDetected'] as bool? ?? false,
      );
}
