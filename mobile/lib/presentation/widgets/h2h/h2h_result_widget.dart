import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../providers/match_provider.dart';
import '../mps_radar_chart.dart';
import '../../screens/player_profile_screen.dart';

/// Head-to-Head Result Widget rendering direct matrix, overall career comparisons,
/// 5-axis radar chart, AI win probabilities, and recent encounters.
class H2hResultWidget extends ConsumerWidget {
  final H2hParams params;
  final Map<String, dynamic>? p1Fallback;
  final Map<String, dynamic>? p2Fallback;
  final ValueChanged<String>? onScopeChanged;
  final ValueChanged<int?>? onLimitChanged;

  const H2hResultWidget({
    super.key,
    required this.params,
    this.p1Fallback,
    this.p2Fallback,
    this.onScopeChanged,
    this.onLimitChanged,
  });

  String _formatDate(dynamic dtVal) {
    if (dtVal == null) return '';
    try {
      final dt = DateTime.parse(dtVal.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncH2h = ref.watch(h2hProvider(params));

    return asyncH2h.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => GlassCard(
        child: Text('Failed to load H2H: $e',
            style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final isDirectScope = params.scope == 'direct';
        final matchLimit = params.limit;

        // Direct H2H aggregate numbers
        final directTotal = (data['total_matches'] as num?)?.toInt() ?? 0;
        final p1DirectWins = (data['player_1_wins'] as num?)?.toInt() ?? 0;
        final directDraws = (data['draws'] as num?)?.toInt() ?? 0;
        final p2DirectWins = (data['player_2_wins'] as num?)?.toInt() ?? 0;
        final p1DirectGoals = (data['player_1_goals'] as num?)?.toInt() ?? 0;
        final p2DirectGoals = (data['player_2_goals'] as num?)?.toInt() ?? 0;
        final avgDiff = (data['avg_goal_diff'] as num?)?.toDouble() ?? 0.0;

        // Overall stats for each player
        final p1OverallMatches =
            (data['player_1_overall_matches'] as num?)?.toInt() ?? directTotal;
        final p1OverallWins =
            (data['player_1_overall_wins'] as num?)?.toInt() ?? p1DirectWins;
        final p1OverallDraws =
            (data['player_1_overall_draws'] as num?)?.toInt() ?? directDraws;
        final p1OverallGoals =
            (data['player_1_overall_goals'] as num?)?.toInt() ?? p1DirectGoals;

        final p2OverallMatches =
            (data['player_2_overall_matches'] as num?)?.toInt() ?? directTotal;
        final p2OverallWins =
            (data['player_2_overall_wins'] as num?)?.toInt() ?? p2DirectWins;
        final p2OverallDraws =
            (data['player_2_overall_draws'] as num?)?.toInt() ?? directDraws;
        final p2OverallGoals =
            (data['player_2_overall_goals'] as num?)?.toInt() ?? p2DirectGoals;

        final p1Elo = (data['player_1_elo'] as num?)?.toInt() ??
            (p1Fallback?['skill_rating'] as num?)?.toInt() ??
            1000;
        final p2Elo = (data['player_2_elo'] as num?)?.toInt() ??
            (p2Fallback?['skill_rating'] as num?)?.toInt() ??
            1000;
        final eloDelta =
            (data['elo_delta'] as num?)?.toInt() ?? (p1Elo - p2Elo);

        final p1Name = data['player_1_name']?.toString() ??
            p1Fallback?['username']?.toString() ??
            (params.p1Id.length > 8
                ? params.p1Id.substring(0, 8)
                : params.p1Id);
        final p2Name = data['player_2_name']?.toString() ??
            p2Fallback?['username']?.toString() ??
            (params.p2Id.length > 8
                ? params.p2Id.substring(0, 8)
                : params.p2Id);
        final p1Avatar = data['player_1_avatar']?.toString() ??
            p1Fallback?['avatar_graphic']?.toString();
        final p2Avatar = data['player_2_avatar']?.toString() ??
            p2Fallback?['avatar_graphic']?.toString();

        final p1Stats =
            Map<String, dynamic>.from(data['player_1_stats'] as Map? ?? {});
        final p2Stats =
            Map<String, dynamic>.from(data['player_2_stats'] as Map? ?? {});

        final recentMatches = (data['recent_matches'] as List<dynamic>? ?? []);

        // Embedded prediction from backend response
        final embeddedPrediction = data['prediction'] as Map<String, dynamic>?;

        // When DIRECT scope is selected but NO direct matches exist yet
        if (isDirectScope && directTotal == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                gradientColors: const [Color(0xFF191C2B), Color(0xFF0F111A)],
                borderColor: AppColors.cyan.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'DIRECT HEAD-TO-HEAD MATRIX',
                          style: GoogleFonts.rajdhani(
                            fontSize: 12,
                            letterSpacing: 2,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '0 CLASHES',
                            style: GoogleFonts.rajdhani(
                                fontSize: 10,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: _buildPlayerProfileHeader(
                                p1Name, p1Avatar, p1Elo, AppColors.primary,
                                alignLeft: true)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              'VS',
                              style: GoogleFonts.orbitron(
                                  fontSize: 12,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(
                            child: _buildPlayerProfileHeader(
                                p2Name, p2Avatar, p2Elo, AppColors.cyan,
                                alignLeft: false)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.sports_esports_outlined,
                              color: AppColors.cyan.withValues(alpha: 0.7),
                              size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'NO DIRECT RIVALRY MATCHES RECORDED YET',
                            style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'These two players have not faced each other directly yet. Switch to "All Opponents Avg" to compare their tactical profiles and career form.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => onScopeChanged?.call('overall'),
                            icon: const Icon(Icons.public, size: 16),
                            label: Text(
                              'SWITCH TO ALL OPPONENTS AVG',
                              style: GoogleFonts.rajdhani(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Match Prediction Card
              _buildPredictionCard(embeddedPrediction, p1Name, p2Name, ref, p1Elo, p2Elo, p1DirectWins, p2DirectWins),
            ],
          ).animate().fade().slideY(begin: 0.05);
        }

        // Active Comparison: Direct H2H OR Overall Career Average
        final isOverall = !isDirectScope;
        final p1DisplayWins = isOverall ? p1OverallWins : p1DirectWins;
        final p2DisplayWins = isOverall ? p2OverallWins : p2DirectWins;
        final p1WinRate = isOverall
            ? (p1OverallMatches > 0
                ? ((p1OverallWins / p1OverallMatches) * 100).toStringAsFixed(0)
                : '0')
            : (directTotal > 0
                ? ((p1DirectWins / directTotal) * 100).toStringAsFixed(0)
                : '0');
        final p2WinRate = isOverall
            ? (p2OverallMatches > 0
                ? ((p2OverallWins / p2OverallMatches) * 100).toStringAsFixed(0)
                : '0')
            : (directTotal > 0
                ? ((p2DirectWins / directTotal) * 100).toStringAsFixed(0)
                : '0');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              gradientColors: const [Color(0xFF191C2B), Color(0xFF0F111A)],
              borderColor: AppColors.primary.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header badge indicating active scope & sample limit
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isOverall
                            ? 'OVERALL CAREER COMPARISON'
                            : 'HISTORICAL HEAD-TO-HEAD',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              (isOverall ? AppColors.cyan : AppColors.primary)
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                (isOverall ? AppColors.cyan : AppColors.primary)
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          isOverall
                              ? 'ALL OPPONENTS (${matchLimit == null ? 'ALL' : 'L$matchLimit'})'
                              : 'DIRECT (${matchLimit == null ? 'ALL' : 'L$matchLimit'})',
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color:
                                isOverall ? AppColors.cyan : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Players Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Player 1 Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildAvatarCircle(p1Avatar, AppColors.primary),
                            const SizedBox(height: 8),
                            Text(
                              p1Name,
                              style: GoogleFonts.rajdhani(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            _buildEloBadge(p1Elo, AppColors.primary),
                            const SizedBox(height: 10),
                            Text(
                              '$p1DisplayWins WINS',
                              style: GoogleFonts.rajdhani(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '$p1WinRate% Win Rate',
                              style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (isOverall) ...[
                              const SizedBox(height: 2),
                              Text(
                                '$p1OverallMatches matches • $p1OverallDraws D',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white38),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Center Pillar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            if (isOverall) ...[
                              Text(
                                'CAREER',
                                style: GoogleFonts.orbitron(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Text(
                                'PROFILES',
                                style: GoogleFonts.rajdhani(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70),
                              ),
                            ] else ...[
                              Text(
                                '$directTotal',
                                style: GoogleFonts.orbitron(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              Text(
                                'MATCHES',
                                style: GoogleFonts.rajdhani(
                                    fontSize: 10,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$directDraws DRAWS',
                                  style: GoogleFonts.rajdhani(
                                      fontSize: 10,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Player 2 Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildAvatarCircle(p2Avatar, AppColors.cyan),
                            const SizedBox(height: 8),
                            Text(
                              p2Name,
                              style: GoogleFonts.rajdhani(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            _buildEloBadge(p2Elo, AppColors.cyan),
                            const SizedBox(height: 10),
                            Text(
                              '$p2DisplayWins WINS',
                              style: GoogleFonts.rajdhani(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cyan,
                              ),
                            ),
                            Text(
                              '$p2WinRate% Win Rate',
                              style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (isOverall) ...[
                              const SizedBox(height: 2),
                              Text(
                                '$p2OverallMatches matches • $p2OverallDraws D',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white38),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Visual comparison bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(
                            flex: p1DisplayWins > 0 ? p1DisplayWins : 1,
                            child: Container(
                                color: p1DisplayWins > 0
                                    ? AppColors.primary
                                    : Colors.transparent),
                          ),
                          if (!isOverall && directDraws > 0)
                            Expanded(
                              flex: directDraws,
                              child: Container(
                                  color: Colors.amber.withValues(alpha: 0.6)),
                            ),
                          Expanded(
                            flex: p2DisplayWins > 0 ? p2DisplayWins : 1,
                            child: Container(
                                color: p2DisplayWins > 0
                                    ? AppColors.cyan
                                    : Colors.transparent),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Secondary Stats Grid
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatComparison(
                          'GOALS SCORED',
                          isOverall
                              ? '$p1OverallGoals – $p2OverallGoals'
                              : '$p1DirectGoals – $p2DirectGoals',
                          Icons.sports_soccer,
                          AppColors.cyan,
                        ),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildStatComparison(
                          isOverall ? 'DIRECT CLASHES' : 'AVG GOAL DIFF',
                          isOverall
                              ? '$directTotal'
                              : '${avgDiff > 0 ? '+' : ''}${avgDiff.toStringAsFixed(1)}',
                          isOverall ? Icons.compare_arrows : Icons.timeline,
                          AppColors.purple,
                        ),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildStatComparison(
                          'ELO GAP',
                          eloDelta == 0
                              ? 'EVEN'
                              : '${eloDelta > 0 ? '+' : ''}$eloDelta',
                          Icons.trending_up,
                          eloDelta >= 0 ? AppColors.primary : AppColors.cyan,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // AI Match Prediction Card
            _buildPredictionCard(embeddedPrediction, p1Name, p2Name, ref, p1Elo, p2Elo, p1DirectWins, p2DirectWins),
            const SizedBox(height: 16),

            // Performance Radar Chart Comparison
            H2hDualRadarChart(
              p1Name: p1Name,
              p2Name: p2Name,
              p1Stats: p1Stats,
              p2Stats: p2Stats,
              title: isOverall
                  ? 'OVERALL PERFORMANCE RADAR (ALL OPPONENTS)'
                  : 'DIRECT HEAD-TO-HEAD PERFORMANCE RADAR',
              subtitle:
                  matchLimit == null ? 'ALL TIME' : 'LAST $matchLimit MATCHES',
            ),

            // Recent Encounters Section (when direct matches exist)
            if (recentMatches.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.history, color: AppColors.cyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'RECENT ENCOUNTERS (${recentMatches.length})',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...recentMatches.map((m) {
                final p1Sc = (m['player_1_score'] as num?)?.toInt() ?? 0;
                final p2Sc = (m['player_2_score'] as num?)?.toInt() ?? 0;
                final winnerId = m['winner_id']?.toString();
                final matchType =
                    (m['match_type'] ?? 'MATCH').toString().toUpperCase();
                final dateStr = _formatDate(m['created_at']);

                final isP1Winner = winnerId != null && winnerId == params.p1Id;
                final isP2Winner = winnerId != null && winnerId == params.p2Id;
                final isDraw = p1Sc == p2Sc;

                Color borderColor = isDraw
                    ? Colors.white12
                    : (isP1Winner
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : AppColors.cyan.withValues(alpha: 0.3));

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      // Match Type & Date
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              matchType.replaceAll('_', ' '),
                              style: GoogleFonts.rajdhani(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10),
                              ),
                          ],
                        ),
                      ),

                      // Player 1 Name
                      Expanded(
                        flex: 3,
                        child: Text(
                          p1Name,
                          style: GoogleFonts.rajdhani(
                            color:
                                isP1Winner ? AppColors.primary : Colors.white70,
                            fontWeight:
                                isP1Winner ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Score Pill
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$p1Sc – $p2Sc',
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Player 2 Name
                      Expanded(
                        flex: 3,
                        child: Text(
                          p2Name,
                          style: GoogleFonts.rajdhani(
                            color: isP2Winner ? AppColors.cyan : Colors.white70,
                            fontWeight:
                                isP2Winner ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ).animate().fade().slideY(begin: 0.05);
      },
    );
  }

  Widget _buildPredictionCard(
    Map<String, dynamic>? embeddedPrediction,
    String p1Name,
    String p2Name,
    WidgetRef ref,
    int p1Elo,
    int p2Elo,
    int p1Wins,
    int p2Wins,
  ) {
    if (embeddedPrediction != null) {
      return _renderPredictionCardContent(embeddedPrediction, p1Name, p2Name);
    }

    // Fallback if not embedded
    final predictAsync = ref.watch(matchPredictionProvider(
      PredictParams(
        p1Rating: p1Elo,
        p2Rating: p2Elo,
        p1H2hWins: p1Wins,
        p2H2hWins: p2Wins,
      ),
    ));

    return predictAsync.when(
      loading: () => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (res) => _renderPredictionCardContent(res, p1Name, p2Name),
    );
  }

  Widget _renderPredictionCardContent(
    Map<String, dynamic> res,
    String p1Name,
    String p2Name,
  ) {
    final double p1Raw = ((res['player_1_win_prob'] ??
            res['player_1_win_probability'] ??
            res['p1_win_probability'] ??
            0.39) as num)
        .toDouble();
    final double drawRaw =
        ((res['draw_prob'] ?? res['draw_probability'] ?? 0.22) as num)
            .toDouble();
    final double p2Raw = ((res['player_2_win_prob'] ??
            res['player_2_win_probability'] ??
            res['p2_win_probability'] ??
            0.39) as num)
        .toDouble();

    // Multiply by 100
    final double p1Win = p1Raw <= 1.0 ? p1Raw * 100.0 : p1Raw;
    final double draw = drawRaw <= 1.0 ? drawRaw * 100.0 : drawRaw;
    final double p2Win = p2Raw <= 1.0 ? p2Raw * 100.0 : p2Raw;

    return GlassCard(
      gradientColors: const [Color(0xFF141724), Color(0xFF0D0F18)],
      borderColor: AppColors.purple.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology,
                  size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              Text(
                'AI WIN PROBABILITY',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 220, 221, 222),
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '${p1Win.toStringAsFixed(1)}%',
                    style: GoogleFonts.rajdhani(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    p1Name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${draw.toStringAsFixed(1)}%',
                    style: GoogleFonts.rajdhani(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber,
                    ),
                  ),
                  Text(
                    'Draw',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Text(
                    '${p2Win.toStringAsFixed(1)}%',
                    style: GoogleFonts.rajdhani(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cyan,
                    ),
                  ),
                  Text(
                    p2Name,
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: max(1, (p1Win * 10).toInt()),
                    child: Container(color: AppColors.primary),
                  ),
                  Expanded(
                    flex: max(1, (draw * 10).toInt()),
                    child: Container(
                        color: Colors.amber.withValues(alpha: 0.8)),
                  ),
                  Expanded(
                    flex: max(1, (p2Win * 10).toInt()),
                    child: Container(color: AppColors.cyan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(String? avatarGraphic, Color color) {
    return CircleAvatar(
      radius: 24,
      backgroundColor:
          getAvatarById(avatarGraphic).gradient.first.withValues(alpha: 0.25),
      child: Icon(
        getAvatarById(avatarGraphic).icon,
        size: 26,
        color: getAvatarById(avatarGraphic).gradient.first,
      ),
    );
  }

  Widget _buildEloBadge(int elo, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$elo ELO',
        style: GoogleFonts.orbitron(
            fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlayerProfileHeader(
      String name, String? avatar, int elo, Color color,
      {required bool alignLeft}) {
    return Column(
      crossAxisAlignment:
          alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        _buildAvatarCircle(avatar, color),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.rajdhani(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        _buildEloBadge(elo, color),
      ],
    );
  }

  Widget _buildStatComparison(
      String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: GoogleFonts.orbitron(
              fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
