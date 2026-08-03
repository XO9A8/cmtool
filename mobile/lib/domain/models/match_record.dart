/// Match Record domain data model for OCR post-match statistics.
class MatchRecord {
  /// Unique player UUID string.
  final String playerId;

  /// Unique opponent UUID string.
  final String opponentId;

  /// Partner UUID for 2v2 co-op matches.
  final String? partnerId;

  /// Opponent partner UUID for 2v2 co-op matches.
  final String? opponentPartnerId;

  /// Match category ('friendly', 'league', 'tournament_final').
  final String matchType;

  /// Goals scored by primary player.
  final int goalsFor;

  /// Goals conceded by primary player.
  final int goalsAgainst;

  /// Possession percentage (0.0 to 100.0).
  final double possession;

  /// Number of completed passes.
  final int passesCompleted;

  /// Total attempted passes.
  final int passesAttempted;

  /// Shots on target.
  final int shotsOnTarget;

  /// Total shots taken.
  final int shotsTotal;

  /// Defensive interceptions.
  final int interceptions;

  final int fouls;
  final int offsides;
  final int corners;
  final int freeKicks;
  final int crosses;
  final int tackles;
  final int saves;

  /// SHA-256 hash string of match screenshot for deduplication.
  final String screenshotHash;

  /// Optional tournament fixture ID (t_match_id).
  final String? tMatchId;

  const MatchRecord({
    required this.playerId,
    required this.opponentId,
    this.partnerId,
    this.opponentPartnerId,
    this.tMatchId,
    required this.matchType,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.possession,
    required this.passesCompleted,
    required this.passesAttempted,
    required this.shotsOnTarget,
    required this.shotsTotal,
    required this.interceptions,
    this.fouls = 0,
    this.offsides = 0,
    this.corners = 0,
    this.freeKicks = 0,
    this.crosses = 0,
    this.tackles = 0,
    this.saves = 0,
    required this.screenshotHash,
  });

  /// Converts model instance to JSON map payload for API submission.
  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'opponent_id': opponentId,
        if (partnerId != null && partnerId!.isNotEmpty) 'partner_id': partnerId,
        if (opponentPartnerId != null && opponentPartnerId!.isNotEmpty) 'opponent_partner_id': opponentPartnerId,
        if (tMatchId != null && tMatchId!.isNotEmpty) 't_match_id': tMatchId,
        'match_type': matchType,
        'goals_for': goalsFor,
        'goals_against': goalsAgainst,
        'possession': possession,
        'passes_completed': passesCompleted,
        'passes_attempted': passesAttempted,
        'shots_on_target': shotsOnTarget,
        'shots_total': shotsTotal,
        'interceptions': interceptions,
        'fouls': fouls,
        'offsides': offsides,
        'corners': corners,
        'free_kicks': freeKicks,
        'crosses': crosses,
        'tackles': tackles,
        'saves': saves,
        'screenshot_hash': screenshotHash,
      };
}

/// Response data model returned by `/api/v1/matches/ocr-submit`.
class OcrSubmitResult {
  /// Unique match ID.
  final String matchId;

  /// Updated skill Elo rating.
  final int newSkillRating;

  /// Net rating delta.
  final int ratingDelta;

  /// Match Performance Score (0.0 to 100.0).
  final double matchPerformanceScore;

  /// Classified tactical play style tag.
  final String playStyleTag;

  /// Strengths list from AI coaching report.
  final List<String> strengths;

  /// Weaknesses list from AI coaching report.
  final List<String> weaknesses;

  const OcrSubmitResult({
    required this.matchId,
    required this.newSkillRating,
    required this.ratingDelta,
    required this.matchPerformanceScore,
    required this.playStyleTag,
    required this.strengths,
    required this.weaknesses,
  });

  /// Constructs result model from JSON API response map.
  factory OcrSubmitResult.fromJson(Map<String, dynamic> json) {
    final insights = json['insights'] ?? {};
    return OcrSubmitResult(
      matchId: json['match_id'] ?? '',
      newSkillRating: json['new_skill_rating'] ?? 0,
      ratingDelta: json['rating_delta'] ?? 0,
      matchPerformanceScore: (json['match_performance_score'] as num?)?.toDouble() ?? 0.0,
      playStyleTag: json['play_style_tag'] ?? '—',
      strengths: List<String>.from(insights['strengths'] ?? []),
      weaknesses: List<String>.from(insights['weaknesses'] ?? []),
    );
  }
}
