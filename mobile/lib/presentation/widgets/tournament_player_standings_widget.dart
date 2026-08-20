import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

/// Esports-grade Tournament Top 5 Player Standings Widget.
/// Displays Top 5 Scorers, Top 5 Accurate Passers, Top 5 Best Defenders,
/// Top 5 Clean Sheet Leaders, and Top 5 Most Dominant Players.
class TournamentPlayerStandingsWidget extends ConsumerStatefulWidget {
  final String tournamentId;

  const TournamentPlayerStandingsWidget({
    super.key,
    required this.tournamentId,
  });

  @override
  ConsumerState<TournamentPlayerStandingsWidget> createState() =>
      _TournamentPlayerStandingsWidgetState();
}

class _TournamentPlayerStandingsWidgetState
    extends ConsumerState<TournamentPlayerStandingsWidget> {
  int _selectedCategory = 0; // 0: All, 1: Scorers, 2: Passers, 3: Defenders, 4: Clean Sheets, 5: Dominant

  static const List<String> _categories = [
    'ALL LEADERS',
    'TOP SCORERS',
    'PASS ACCURACY',
    'DEFENDERS',
    'CLEAN SHEETS',
    'DOMINANT',
  ];

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(tournamentPlayerStatsProvider(widget.tournamentId));

    return statsAsync.when(
      loading: () => _buildLoadingSkeleton(),
      error: (err, stack) => _buildErrorCard(err.toString()),
      data: (data) {
        final rawList = data['player_stats'] as List<dynamic>? ?? [];
        final players = rawList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        if (players.isEmpty) {
          return _buildEmptyState();
        }

        // Only include players who have played at least 1 match
        final activePlayers = players.where((p) => ((p['played'] as num?)?.toInt() ?? 0) > 0).toList();
        if (activePlayers.isEmpty) {
          return _buildEmptyState();
        }

        // Calculate Leader Lists (Top 5 each)

        // 1. Top Scorers (Goals DESC, then Goals/Match DESC)
        final topScorers = [...activePlayers]..sort((a, b) {
            final gA = (a['goals_for'] as num?)?.toInt() ?? 0;
            final gB = (b['goals_for'] as num?)?.toInt() ?? 0;
            if (gB != gA) return gB.compareTo(gA);
            final pA = (a['played'] as num?)?.toInt() ?? 1;
            final pB = (b['played'] as num?)?.toInt() ?? 1;
            final gpmA = gA / (pA > 0 ? pA : 1);
            final gpmB = gB / (pB > 0 ? pB : 1);
            return gpmB.compareTo(gpmA);
          });

        // 2. Top Accurate Passers (Pass Acc %, then Completed Passes)
        final accuratePassers = [...activePlayers]..sort((a, b) {
            final pcA = (a['passes_completed'] as num?)?.toInt() ?? 0;
            final paA = (a['passes_attempted'] as num?)?.toInt() ?? 0;
            final pcB = (b['passes_completed'] as num?)?.toInt() ?? 0;
            final paB = (b['passes_attempted'] as num?)?.toInt() ?? 0;

            final accA = paA > 0 ? (pcA / paA) : 0.0;
            final accB = paB > 0 ? (pcB / paB) : 0.0;
            if ((accB - accA).abs() > 0.001) return accB.compareTo(accA);
            return pcB.compareTo(pcA);
          });

        // 3. Best Defenders (Goals Conceded / Match ASC, then Tackles + Interceptions DESC)
        final bestDefenders = [...activePlayers]..sort((a, b) {
            final gaA = (a['goals_against'] as num?)?.toInt() ?? 0;
            final pA = (a['played'] as num?)?.toInt() ?? 1;
            final gaB = (b['goals_against'] as num?)?.toInt() ?? 0;
            final pB = (b['played'] as num?)?.toInt() ?? 1;

            final gapmA = gaA / (pA > 0 ? pA : 1);
            final gapmB = gaB / (pB > 0 ? pB : 1);
            if ((gapmA - gapmB).abs() > 0.001) return gapmA.compareTo(gapmB);

            final defA = ((a['tackles'] as num?)?.toInt() ?? 0) + ((a['interceptions'] as num?)?.toInt() ?? 0);
            final defB = ((b['tackles'] as num?)?.toInt() ?? 0) + ((b['interceptions'] as num?)?.toInt() ?? 0);
            return defB.compareTo(defA);
          });

        // 4. Clean Sheet Leaders (Clean Sheets DESC, then Goals Conceded ASC)
        final cleanSheetLeaders = [...activePlayers]..sort((a, b) {
            final csA = (a['clean_sheets'] as num?)?.toInt() ?? 0;
            final csB = (b['clean_sheets'] as num?)?.toInt() ?? 0;
            if (csB != csA) return csB.compareTo(csA);
            final gaA = (a['goals_against'] as num?)?.toInt() ?? 0;
            final gaB = (b['goals_against'] as num?)?.toInt() ?? 0;
            return gaA.compareTo(gaB);
          });

        // 5. Most Dominant (Win Rate % DESC, then Points DESC)
        final dominantPlayers = [...activePlayers]..sort((a, b) {
            final wA = (a['won'] as num?)?.toInt() ?? 0;
            final pA = (a['played'] as num?)?.toInt() ?? 1;
            final wB = (b['won'] as num?)?.toInt() ?? 0;
            final pB = (b['played'] as num?)?.toInt() ?? 1;

            final wrA = pA > 0 ? (wA / pA) : 0.0;
            final wrB = pB > 0 ? (wB / pB) : 0.0;
            if ((wrB - wrA).abs() > 0.001) return wrB.compareTo(wrA);
            final ptsA = (a['points'] as num?)?.toInt() ?? 0;
            final ptsB = (b['points'] as num?)?.toInt() ?? 0;
            return ptsB.compareTo(ptsA);
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Selector Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isSelected = _selectedCategory == index;
                  return ChoiceChip(
                    label: Text(_categories[index]),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = index),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceLight.withValues(alpha: 0.3),
                    ),
                    labelStyle: GoogleFonts.orbitron(
                      color: isSelected ? Colors.black : AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Filtered Leaderboard Cards
            if (_selectedCategory == 0 || _selectedCategory == 1) ...[
              _buildTop5Card(
                title: 'TOP 5 GOAL SCORERS',
                subtitle: 'Most goals scored in tournament',
                icon: Icons.sports_soccer,
                accentColor: Colors.amber,
                items: topScorers.take(5).toList(),
                getPrimaryStat: (p) => '${(p['goals_for'] as num?)?.toInt() ?? 0} GOALS',
                getSubStat: (p) {
                  final g = (p['goals_for'] as num?)?.toInt() ?? 0;
                  final pl = (p['played'] as num?)?.toInt() ?? 1;
                  return '${(g / (pl > 0 ? pl : 1)).toStringAsFixed(1)} Goals / Match ($pl GP)';
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedCategory == 0 || _selectedCategory == 2) ...[
              _buildTop5Card(
                title: 'TOP 5 ACCURATE PASSERS',
                subtitle: 'Highest pass completion percentage',
                icon: Icons.alt_route,
                accentColor: AppColors.cyan,
                items: accuratePassers.take(5).toList(),
                getPrimaryStat: (p) {
                  final pc = (p['passes_completed'] as num?)?.toInt() ?? 0;
                  final pa = (p['passes_attempted'] as num?)?.toInt() ?? 0;
                  final acc = pa > 0 ? (pc / pa * 100).toStringAsFixed(1) : '0.0';
                  return '$acc% PASS ACC';
                },
                getSubStat: (p) {
                  final pc = (p['passes_completed'] as num?)?.toInt() ?? 0;
                  final pa = (p['passes_attempted'] as num?)?.toInt() ?? 0;
                  return '$pc Completed ($pa Attempted)';
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedCategory == 0 || _selectedCategory == 3) ...[
              _buildTop5Card(
                title: 'TOP 5 BEST DEFENDERS',
                subtitle: 'Lowest goals conceded & defensive stops',
                icon: Icons.shield,
                accentColor: AppColors.winGreen,
                items: bestDefenders.take(5).toList(),
                getPrimaryStat: (p) {
                  final ga = (p['goals_against'] as num?)?.toInt() ?? 0;
                  final pl = (p['played'] as num?)?.toInt() ?? 1;
                  final gapm = ga / (pl > 0 ? pl : 1);
                  return '${gapm.toStringAsFixed(1)} GA / Match';
                },
                getSubStat: (p) {
                  final ga = (p['goals_against'] as num?)?.toInt() ?? 0;
                  final t = (p['tackles'] as num?)?.toInt() ?? 0;
                  final i = (p['interceptions'] as num?)?.toInt() ?? 0;
                  return '$ga Conceded • ${t + i} Stops (Tackles/Intercepts)';
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedCategory == 0 || _selectedCategory == 4) ...[
              _buildTop5Card(
                title: 'TOP 5 CLEAN SHEET LEADERS',
                subtitle: 'Matches finished without conceding a goal',
                icon: Icons.workspace_premium,
                accentColor: AppColors.offWhite,
                items: cleanSheetLeaders.take(5).toList(),
                getPrimaryStat: (p) => '${(p['clean_sheets'] as num?)?.toInt() ?? 0} CLEAN SHEETS',
                getSubStat: (p) {
                  final cs = (p['clean_sheets'] as num?)?.toInt() ?? 0;
                  final pl = (p['played'] as num?)?.toInt() ?? 1;
                  final pct = pl > 0 ? (cs / pl * 100).toStringAsFixed(0) : '0';
                  return '$pct% Clean Sheet Rate ($pl Matches Played)';
                },
              ),
              const SizedBox(height: 16),
            ],

            if (_selectedCategory == 0 || _selectedCategory == 5) ...[
              _buildTop5Card(
                title: 'TOP 5 MOST DOMINANT',
                subtitle: 'Highest match win rate & tournament points',
                icon: Icons.military_tech,
                accentColor: Colors.deepOrangeAccent,
                items: dominantPlayers.take(5).toList(),
                getPrimaryStat: (p) {
                  final w = (p['won'] as num?)?.toInt() ?? 0;
                  final pl = (p['played'] as num?)?.toInt() ?? 1;
                  final wr = pl > 0 ? (w / pl * 100).toStringAsFixed(0) : '0';
                  return '$wr% WIN RATE';
                },
                getSubStat: (p) {
                  final w = (p['won'] as num?)?.toInt() ?? 0;
                  final d = (p['drawn'] as num?)?.toInt() ?? 0;
                  final l = (p['lost'] as num?)?.toInt() ?? 0;
                  final pts = (p['points'] as num?)?.toInt() ?? 0;
                  return '${w}W-${d}D-${l}L • $pts Points';
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ).animate().fade(duration: 300.ms).slideY(begin: 0.04, duration: 300.ms);
      },
    );
  }

  Widget _buildTop5Card({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) getPrimaryStat,
    required String Function(Map<String, dynamic>) getSubStat,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    final topPlayer = items.first;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(color: accentColor.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'TOP ${items.length}',
                    style: GoogleFonts.orbitron(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // #1 Rank Highlight Spotlight
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    accentColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  // Gold #1 Badge
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '#1',
                        style: GoogleFonts.orbitron(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Player Initial/Avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accentColor.withValues(alpha: 0.3),
                    child: Text(
                      (topPlayer['player_name']?.toString() ?? 'P').isNotEmpty
                          ? (topPlayer['player_name']?.toString() ?? 'P')[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.orbitron(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name and Substat
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topPlayer['player_name']?.toString() ?? 'Player',
                          style: GoogleFonts.rajdhani(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          getSubStat(topPlayer),
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Primary Stat Badge
                  Text(
                    getPrimaryStat(topPlayer),
                    style: GoogleFonts.orbitron(
                      color: accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Ranks #2 through #5 List
          if (items.length > 1) ...[
            const Divider(color: AppColors.surfaceLight, height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length - 1,
              separatorBuilder: (_, __) => const Divider(
                color: AppColors.surfaceLight,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                final item = items[index + 1];
                final rank = index + 2;

                Color rankColor;
                if (rank == 2) {
                  rankColor = const Color(0xFFC0C0C0); // Silver
                } else if (rank == 3) {
                  rankColor = const Color(0xFFCD7F32); // Bronze
                } else {
                  rankColor = AppColors.textMuted;
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Rank Badge
                      SizedBox(
                        width: 28,
                        child: Text(
                          '#$rank',
                          style: GoogleFonts.orbitron(
                            color: rankColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Player Name & Substat
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['player_name']?.toString() ?? 'Player',
                              style: GoogleFonts.rajdhani(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              getSubStat(item),
                              style: GoogleFonts.rajdhani(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Primary Stat
                      Text(
                        getPrimaryStat(item),
                        style: GoogleFonts.orbitron(
                          color: rankColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          Text(
            'NO PLAYER STATS YET',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Play matches in this tournament to record player stats and populate Top 5 leaderboards for scorers, passers, defenders, and clean sheet leaders.',
            style: GoogleFonts.rajdhani(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lossRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.lossRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load player statistics: $error',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(
        2,
        (index) => Container(
          height: 180,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceLight),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.3, end: 0.7),
      ),
    );
  }
}
