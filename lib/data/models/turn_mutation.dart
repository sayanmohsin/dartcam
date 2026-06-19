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
}
