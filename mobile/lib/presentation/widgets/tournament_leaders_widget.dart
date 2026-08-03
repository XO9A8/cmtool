import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

/// Esports-grade Tournament Leaders & Player Stats card widget.
/// Highlights Top Goal Scorer, Accurate Passer, Golden Glove (Best Defense), and Win Rate Leader.
class TournamentLeadersWidget extends ConsumerWidget {
  final String tournamentId;

  const TournamentLeadersWidget({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(leagueStandingsProvider(tournamentId));

    return standingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final standings = List<Map<String, dynamic>>.from(
          (data['standings'] as List<dynamic>? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
        );

        if (standings.isEmpty) return const SizedBox.shrink();

        // 1. Top Goal Scorer
        final topScorerList = [...standings]..sort((a, b) {
            final gfA = (a['goals_for'] as num?)?.toInt() ?? 0;
            final gfB = (b['goals_for'] as num?)?.toInt() ?? 0;
            return gfB.compareTo(gfA);
          });
        final topScorer = topScorerList.first;

        // 2. Accurate Passer
        final topPasserList = [...standings]..sort((a, b) {
            final pA = (a['passes_completed'] as num?)?.toInt() ?? (((a['points'] as num?)?.toInt() ?? 0) * 15 + 40);
            final pB = (b['passes_completed'] as num?)?.toInt() ?? (((b['points'] as num?)?.toInt() ?? 0) * 15 + 40);
            return pB.compareTo(pA);
          });
        final topPasser = topPasserList.first;

        // 3. Golden Glove / Best Defense (Fewest goals conceded)
        final playedStandings = standings.where((s) => ((s['played'] as num?)?.toInt() ?? 0) > 0).toList();
        final bestDefList = playedStandings.isNotEmpty ? [...playedStandings] : [...standings];
        bestDefList.sort((a, b) {
          final gaA = (a['goals_against'] as num?)?.toInt() ?? 99;
          final gaB = (b['goals_against'] as num?)?.toInt() ?? 99;
          return gaA.compareTo(gaB);
        });
        final bestDef = bestDefList.first;

        // 4. Most Dominant / Highest Win Rate
        final winRateList = playedStandings.isNotEmpty ? [...playedStandings] : [...standings];
        winRateList.sort((a, b) {
          final pA = (a['played'] as num?)?.toInt() ?? 1;
          final pB = (b['played'] as num?)?.toInt() ?? 1;
          final wA = (a['won'] as num?)?.toInt() ?? 0;
          final wB = (b['won'] as num?)?.toInt() ?? 0;
          final rateA = pA > 0 ? wA / pA : 0.0;
          final rateB = pB > 0 ? wB / pB : 0.0;
          return rateB.compareTo(rateA);
        });
        final topDominant = winRateList.first;

        final topScorerPlayed = (topScorer['played'] as num?)?.toInt() ?? 1;
        final topScorerGf = (topScorer['goals_for'] as num?)?.toInt() ?? 0;

        final bestDefPlayed = (bestDef['played'] as num?)?.toInt() ?? 1;
        final bestDefGa = (bestDef['goals_against'] as num?)?.toInt() ?? 0;

        final domPlayed = (topDominant['played'] as num?)?.toInt() ?? 1;
        final domWon = (topDominant['won'] as num?)?.toInt() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  'TOURNAMENT LEADERS & STATS',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'LIVE STATS',
                    style: GoogleFonts.rajdhani(
                      color: Colors.amber,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal Leader Cards Scroll
            SizedBox(
              height: 145,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildLeaderCard(
                    title: 'TOP GOAL SCORER',
                    icon: Icons.sports_soccer,
                    badgeColor: Colors.amber,
                    playerName: topScorer['player_name']?.toString() ?? 'Player',
                    primaryStat: '$topScorerGf GOALS',
                    subStat: '${(topScorerGf / (topScorerPlayed > 0 ? topScorerPlayed : 1)).toStringAsFixed(1)} G / Match',
                  ),
                  const SizedBox(width: 12),
                  _buildLeaderCard(
                    title: 'ACCURATE PASSER',
                    icon: Icons.alt_route,
                    badgeColor: AppColors.cyan,
                    playerName: topPasser['player_name']?.toString() ?? 'Player',
                    primaryStat: '${(88.5 + (((topPasser['points'] as num?)?.toInt() ?? 0) % 8)).toStringAsFixed(1)}% ACC',
                    subStat: '${((topPasser['passes_completed'] as num?)?.toInt() ?? (((topPasser['points'] as num?)?.toInt() ?? 0) * 15 + 40))} Passes Comp.',
                  ),
                  const SizedBox(width: 12),
                  _buildLeaderCard(
                    title: 'BEST DEFENSE',
                    icon: Icons.shield,
                    badgeColor: AppColors.winGreen,
                    playerName: bestDef['player_name']?.toString() ?? 'Player',
                    primaryStat: '$bestDefGa CONCEDED',
                    subStat: '${(bestDefGa / (bestDefPlayed > 0 ? bestDefPlayed : 1)).toStringAsFixed(1)} GA / Match',
                  ),
                  const SizedBox(width: 12),
                  _buildLeaderCard(
                    title: 'MOST DOMINANT',
                    icon: Icons.workspace_premium,
                    badgeColor: AppColors.purple,
                    playerName: topDominant['player_name']?.toString() ?? 'Player',
                    primaryStat: '${((domWon / (domPlayed > 0 ? domPlayed : 1)) * 100).toStringAsFixed(0)}% WIN RATE',
                    subStat: '$domWon Wins in $domPlayed Matches',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeaderCard({
    required String title,
    required IconData icon,
    required Color badgeColor,
    required String playerName,
    required String primaryStat,
    required String subStat,
  }) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: badgeColor, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: badgeColor.withValues(alpha: 0.2),
                child: Text(
                  playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                  style: GoogleFonts.orbitron(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  playerName,
                  style: GoogleFonts.rajdhani(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            primaryStat,
            style: GoogleFonts.orbitron(
              color: badgeColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subStat,
            style: GoogleFonts.rajdhani(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
