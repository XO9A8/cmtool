class MatchRecord {
  final String id;
  final String playerId;
  final String opponentId;
  final String matchType;
  final int goalsFor;
  final int goalsAgainst;
  final double possession;
  final int passesCompleted;
  final int passesAttempted;
  final int shotsOnTarget;
  final int shotsTotal;
  final int interceptions;
  final String screenshotHash;

  MatchRecord({
    required this.id,
    required this.playerId,
    required this.opponentId,
    required this.matchType,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.possession,
    required this.passesCompleted,
    required this.passesAttempted,
    required this.shotsOnTarget,
    required this.shotsTotal,
    required this.interceptions,
    required this.screenshotHash,
  });

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'opponent_id': opponentId,
        'match_type': matchType,
        'goals_for': goalsFor,
        'goals_against': goalsAgainst,
        'possession': possession,
        'passes_completed': passesCompleted,
        'passes_attempted': passesAttempted,
        'shots_on_target': shotsOnTarget,
        'shots_total': shotsTotal,
        'interceptions': interceptions,
        'screenshot_hash': screenshotHash,
      };
}

class OcrSubmitResult {
  final String matchId;
  final String playerId;
  final int newSkillRating;
  final int ratingDelta;
  final double matchPerformanceScore;
  final String playStyleTag;
  final InsightReportResult insights;

  OcrSubmitResult({
    required this.matchId,
    required this.playerId,
    required this.newSkillRating,
    required this.ratingDelta,
    required this.matchPerformanceScore,
    required this.playStyleTag,
    required this.insights,
  });

  factory OcrSubmitResult.fromJson(Map<String, dynamic> json) {
    return OcrSubmitResult(
      matchId: json['match_id'],
      playerId: json['player_id'],
      newSkillRating: json['new_skill_rating'],
      ratingDelta: json['rating_delta'],
      matchPerformanceScore: (json['match_performance_score'] as num).toDouble(),
      playStyleTag: json['play_style_tag'],
      insights: InsightReportResult.fromJson(json['insights']),
    );
  }
}

class InsightReportResult {
  final String summary;
  final List<String> strengths;
  final List<String> areasForImprovement;

  InsightReportResult({
    required this.summary,
    required this.strengths,
    required this.areasForImprovement,
  });

  factory InsightReportResult.fromJson(Map<String, dynamic> json) {
    return InsightReportResult(
      summary: json['summary'],
      strengths: List<String>.from(json['strengths'] ?? []),
      areasForImprovement: List<String>.from(json['areas_for_improvement'] ?? []),
    );
  }
}
