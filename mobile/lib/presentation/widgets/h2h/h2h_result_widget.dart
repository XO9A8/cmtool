import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphify/graphify.dart';

import '../../theme/app_theme.dart';
import '../../providers/match_provider.dart';
import '../../screens/player_profile_screen.dart';

/// Head-to-Head Result Widget — redesigned with Graphify (Apache ECharts) charts.
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
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => GlassCard(
        child: Text('Failed to load H2H: $e',
            style: TextStyle(color: AppColors.lossRed)),
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

        // Overall stats
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
            (p1Fallback?['skill_rating'] as num?)?.toInt() ?? 1000;
        final p2Elo = (data['player_2_elo'] as num?)?.toInt() ??
            (p2Fallback?['skill_rating'] as num?)?.toInt() ?? 1000;
        final eloDelta =
            (data['elo_delta'] as num?)?.toInt() ?? (p1Elo - p2Elo);

        final p1Name = data['player_1_name']?.toString() ??
            p1Fallback?['username']?.toString() ??
            (params.p1Id.length > 8 ? params.p1Id.substring(0, 8) : params.p1Id);
        final p2Name = data['player_2_name']?.toString() ??
            p2Fallback?['username']?.toString() ??
            (params.p2Id.length > 8 ? params.p2Id.substring(0, 8) : params.p2Id);
        final p1Avatar = data['player_1_avatar']?.toString() ??
            p1Fallback?['avatar_graphic']?.toString();
        final p2Avatar = data['player_2_avatar']?.toString() ??
            p2Fallback?['avatar_graphic']?.toString();

        final p1Stats =
            Map<String, dynamic>.from(data['player_1_stats'] as Map? ?? {});
        final p2Stats =
            Map<String, dynamic>.from(data['player_2_stats'] as Map? ?? {});

        final recentMatches = (data['recent_matches'] as List<dynamic>? ?? []);
        final embeddedPrediction = data['prediction'] as Map<String, dynamic>?;

        // No-data state for Direct H2H
        if (isDirectScope && directTotal == 0) {
          return _buildNoDirectMatchesCard(
            p1Name, p2Name, p1Avatar, p2Avatar, p1Elo, p2Elo,
            embeddedPrediction, ref,
          ).animate().fade().slideY(begin: 0.05);
        }

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
            // ── HEAD CARD ────────────────────────────────────────────────────
            _buildHeadCard(
              isOverall: isOverall,
              matchLimit: matchLimit,
              directTotal: directTotal,
              directDraws: directDraws,
              avgDiff: avgDiff,
              eloDelta: eloDelta,
              p1Name: p1Name,
              p2Name: p2Name,
              p1Avatar: p1Avatar,
              p2Avatar: p2Avatar,
              p1Elo: p1Elo,
              p2Elo: p2Elo,
              p1DisplayWins: p1DisplayWins,
              p2DisplayWins: p2DisplayWins,
              p1WinRate: p1WinRate,
              p2WinRate: p2WinRate,
              p1OverallMatches: p1OverallMatches,
              p2OverallMatches: p2OverallMatches,
              p1OverallDraws: p1OverallDraws,
              p2OverallDraws: p2OverallDraws,
              p1OverallGoals: p1OverallGoals,
              p2OverallGoals: p2OverallGoals,
              p1DirectGoals: p1DirectGoals,
              p2DirectGoals: p2DirectGoals,
            ),
            const SizedBox(height: 14),

            // ── WIN DISTRIBUTION BAR CHART (Graphify) ────────────────────────
            _buildWinDistributionChart(
              p1Name: p1Name,
              p2Name: p2Name,
              p1Wins: p1DisplayWins,
              p2Wins: p2DisplayWins,
              draws: isOverall ? 0 : directDraws,
              isOverall: isOverall,
            ),
            const SizedBox(height: 14),

            // ── AI WIN PROBABILITY CARD ───────────────────────────────────────
            _buildPredictionCard(
              embeddedPrediction, p1Name, p2Name, ref,
              p1Elo, p2Elo, p1DirectWins, p2DirectWins,
            ),
            const SizedBox(height: 14),

            // ── PERFORMANCE RADAR (Graphify ECharts) ─────────────────────────
            _buildRadarChart(
              p1Name: p1Name,
              p2Name: p2Name,
              p1Stats: p1Stats,
              p2Stats: p2Stats,
              isOverall: isOverall,
              matchLimit: matchLimit,
            ),
            const SizedBox(height: 14),

            // ── STAT COMPARISON TABLE ─────────────────────────────────────────
            _buildStatTable(
              p1Name: p1Name,
              p2Name: p2Name,
              p1Stats: p1Stats,
              p2Stats: p2Stats,
            ),

            // ── RECENT ENCOUNTERS ─────────────────────────────────────────────
            if (recentMatches.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildRecentEncounters(recentMatches, p1Name, p2Name),
            ],

            const SizedBox(height: 24),
          ],
        ).animate().fade().slideY(begin: 0.05);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEAD CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeadCard({
    required bool isOverall,
    required int? matchLimit,
    required int directTotal,
    required int directDraws,
    required double avgDiff,
    required int eloDelta,
    required String p1Name,
    required String p2Name,
    required String? p1Avatar,
    required String? p2Avatar,
    required int p1Elo,
    required int p2Elo,
    required int p1DisplayWins,
    required int p2DisplayWins,
    required String p1WinRate,
    required String p2WinRate,
    required int p1OverallMatches,
    required int p2OverallMatches,
    required int p1OverallDraws,
    required int p2OverallDraws,
    required int p1OverallGoals,
    required int p2OverallGoals,
    required int p1DirectGoals,
    required int p2DirectGoals,
  }) {
    return GlassCard(
      gradientColors: [AppColors.surfaceLight, AppColors.surface],
      borderColor: AppColors.primary.withValues(alpha: 0.45),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          // Scope badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOverall ? 'OVERALL COMPARISON' : 'HISTORICAL HEAD-TO-HEAD',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOverall ? AppColors.cyan : AppColors.primary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (isOverall ? AppColors.cyan : AppColors.primary)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  isOverall
                      ? 'ALL OPP. (${matchLimit == null ? 'ALL' : 'L$matchLimit'})'
                      : 'DIRECT (${matchLimit == null ? 'ALL' : 'L$matchLimit'})',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isOverall ? AppColors.cyan : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Player vs Player
          Row(
            children: [
              // P1
              Expanded(
                child: _buildPlayerColumn(
                  name: p1Name,
                  avatar: p1Avatar,
                  elo: p1Elo,
                  color: AppColors.primary,
                  wins: p1DisplayWins,
                  winRate: p1WinRate,
                  extraLine: isOverall
                      ? '$p1OverallMatches G · $p1OverallDraws D · $p1OverallGoals GF'
                      : '$p1DirectGoals goals',
                ),
              ),

              // Center
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          if (!isOverall) ...[
                            Text(
                              '$directTotal',
                              style: GoogleFonts.orbitron(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'CLASHES',
                              style: GoogleFonts.rajdhani(
                                fontSize: 9,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                            if (directDraws > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$directDraws D',
                                  style: GoogleFonts.rajdhani(
                                      fontSize: 10,
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ] else ...[
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
                                fontSize: 9,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Elo delta badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (eloDelta >= 0 ? AppColors.primary : AppColors.cyan)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (eloDelta >= 0
                                  ? AppColors.primary
                                  : AppColors.cyan)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Δ ${eloDelta >= 0 ? '+' : ''}$eloDelta',
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: eloDelta >= 0
                              ? AppColors.primary
                              : AppColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // P2
              Expanded(
                child: _buildPlayerColumn(
                  name: p2Name,
                  avatar: p2Avatar,
                  elo: p2Elo,
                  color: AppColors.cyan,
                  wins: p2DisplayWins,
                  winRate: p2WinRate,
                  extraLine: isOverall
                      ? '$p2OverallMatches G · $p2OverallDraws D · $p2OverallGoals GF'
                      : '$p2DirectGoals goals',
                  alignRight: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Goals row (direct mode)
          if (!isOverall) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat(
                    label: 'GOALS',
                    value: '$p1DirectGoals – $p2DirectGoals',
                    icon: Icons.sports_soccer,
                    color: AppColors.cyan,
                  ),
                  Container(width: 1, height: 24, color: Colors.white10),
                  _buildMiniStat(
                    label: 'AVG DIFF',
                    value:
                        '${avgDiff >= 0 ? '+' : ''}${avgDiff.toStringAsFixed(1)}',
                    icon: Icons.timeline,
                    color: AppColors.offWhite,
                  ),
                  Container(width: 1, height: 24, color: Colors.white10),
                  _buildMiniStat(
                    label: 'DRAWS',
                    value: '$directDraws',
                    icon: Icons.handshake_outlined,
                    color: AppColors.amber,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerColumn({
    required String name,
    required String? avatar,
    required int elo,
    required Color color,
    required int wins,
    required String winRate,
    required String extraLine,
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _buildAvatarCircle(avatar, color),
        const SizedBox(height: 8),
        Text(
          name,
          style: GoogleFonts.rajdhani(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
        const SizedBox(height: 3),
        _buildEloBadge(elo, color),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$wins',
            style: GoogleFonts.rajdhani(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        Text(
          'WINS',
          style: GoogleFonts.rajdhani(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: color.withValues(alpha: 0.7),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$winRate% win rate',
          style: GoogleFonts.rajdhani(
            fontSize: 10.5,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          extraLine,
          style: const TextStyle(fontSize: 9.5, color: Colors.white38),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WIN DISTRIBUTION BAR CHART (Graphify)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWinDistributionChart({
    required String p1Name,
    required String p2Name,
    required int p1Wins,
    required int p2Wins,
    required int draws,
    required bool isOverall,
  }) {
    final p1Short = p1Name.length > 9 ? '${p1Name.substring(0, 8)}…' : p1Name;
    final p2Short = p2Name.length > 9 ? '${p2Name.substring(0, 8)}…' : p2Name;
    final hasDraws = !isOverall && draws > 0;

    final maxVal = [p1Wins, p2Wins, if (hasDraws) draws].reduce((a, b) => a > b ? a : b);

    final options = <String, dynamic>{
      'backgroundColor': 'transparent',
      'grid': {
        'left': '3%',
        'right': '10%',
        'top': '6%',
        'bottom': '6%',
        'containLabel': true,
      },
      'tooltip': {
        'trigger': 'axis',
        'axisPointer': {'type': 'shadow'},
        'backgroundColor': '#1C1F2E',
        'borderColor': '#FF6D00',
        'borderWidth': 1,
        'textStyle': {'color': '#FFFFFF', 'fontSize': 11},
      },
      'xAxis': {
        'type': 'value',
        'minInterval': 1,
        'max': maxVal == 0 ? 1 : null,
        'axisLine': {'lineStyle': {'color': '#FFFFFF20'}},
        'splitLine': {'lineStyle': {'color': '#FFFFFF10'}},
        'axisLabel': {'color': '#A5ACBC', 'fontSize': 9},
      },
      'yAxis': {
        'type': 'category',
        'data': [p2Short, if (hasDraws) 'Draw', p1Short],
        'axisLabel': {
          'color': '#FFFFFFB3',
          'fontSize': 11,
          'fontWeight': 'bold',
        },
        'axisLine': {'lineStyle': {'color': '#FFFFFF15'}},
      },
      'series': [
        {
          'name': 'Wins',
          'type': 'bar',
          'barMaxWidth': 20,
          'data': [
            {
              'value': p2Wins,
              'itemStyle': {
                'color': {
                  'type': 'linear',
                  'x': 0,
                  'y': 0,
                  'x2': 1,
                  'y2': 0,
                  'colorStops': [
                    {'offset': 0, 'color': '#00B8CC'},
                    {'offset': 1, 'color': '#00E5FF'},
                  ],
                },
                'borderRadius': [0, 6, 6, 0],
              },
            },
            if (hasDraws)
              {
                'value': draws,
                'itemStyle': {
                  'color': {
                    'type': 'linear',
                    'x': 0,
                    'y': 0,
                    'x2': 1,
                    'y2': 0,
                    'colorStops': [
                      {'offset': 0, 'color': '#CC8800'},
                      {'offset': 1, 'color': '#FFB300'},
                    ],
                  },
                  'borderRadius': [0, 6, 6, 0],
                },
              },
            {
              'value': p1Wins,
              'itemStyle': {
                'color': {
                  'type': 'linear',
                  'x': 0,
                  'y': 0,
                  'x2': 1,
                  'y2': 0,
                  'colorStops': [
                    {'offset': 0, 'color': '#CC5700'},
                    {'offset': 1, 'color': '#FF6D00'},
                  ],
                },
                'borderRadius': [0, 6, 6, 0],
              },
            },
          ],
          'label': {
            'show': true,
            'position': 'right',
            'distance': 6,
            'color': '#FFFFFF',
            'fontSize': 11,
            'fontWeight': 'bold',
            'fontFamily': 'sans-serif',
          },
          'showBackground': true,
          'backgroundStyle': {
            'color': '#FFFFFF08',
            'borderRadius': [0, 6, 6, 0],
          },
        },
      ],
    };

    return GlassCard(
      gradientColors: [AppColors.surfaceLight, AppColors.surface],
      borderColor: AppColors.primary.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary, size: 15),
              const SizedBox(width: 6),
              Text(
                'WIN DISTRIBUTION',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: hasDraws ? 165 : 135,
              child: GraphifyView(
                controller: GraphifyController(),
                initialOptions: options,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PERFORMANCE RADAR (Graphify)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRadarChart({
    required String p1Name,
    required String p2Name,
    required Map<String, dynamic> p1Stats,
    required Map<String, dynamic> p2Stats,
    required bool isOverall,
    required int? matchLimit,
  }) {
    final p1Poss = ((p1Stats['possession'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);
    final p1Pass = ((p1Stats['passing'] as num?)?.toDouble() ?? 70.0).clamp(0.0, 100.0);
    final p1Shot = ((p1Stats['shooting'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);
    final p1Def  = ((p1Stats['defending'] as num?)?.toDouble() ?? 60.0).clamp(0.0, 100.0);
    final p1Form = ((p1Stats['form'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);

    final p2Poss = ((p2Stats['possession'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);
    final p2Pass = ((p2Stats['passing'] as num?)?.toDouble() ?? 70.0).clamp(0.0, 100.0);
    final p2Shot = ((p2Stats['shooting'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);
    final p2Def  = ((p2Stats['defending'] as num?)?.toDouble() ?? 60.0).clamp(0.0, 100.0);
    final p2Form = ((p2Stats['form'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);

    final p1Short = p1Name.length > 10 ? '${p1Name.substring(0, 9)}…' : p1Name;
    final p2Short = p2Name.length > 10 ? '${p2Name.substring(0, 9)}…' : p2Name;

    final options = <String, dynamic>{
      'backgroundColor': 'transparent',
      'legend': {
        'bottom': '0%',
        'textStyle': {'color': '#A5ACBC', 'fontSize': 11},
        'itemWidth': 10,
        'itemHeight': 10,
        'data': [p1Short, p2Short],
      },
      'radar': {
        'indicator': [
          {'name': 'POSSESS', 'max': 100},
          {'name': 'PASSING', 'max': 100},
          {'name': 'SHOOTING', 'max': 100},
          {'name': 'DEFENDING', 'max': 100},
          {'name': 'FORM', 'max': 100},
        ],
        'shape': 'polygon',
        'center': ['50%', '46%'],
        'radius': '60%',
        'splitNumber': 4,
        'axisName': {
          'color': '#A5ACBC',
          'fontSize': 10,
          'fontWeight': 'bold',
        },
        'splitLine': {
          'lineStyle': {'color': '#FFFFFF15'},
        },
        'splitArea': {
          'show': true,
          'areaStyle': {
            'color': ['#FFFFFF04', '#FFFFFF08'],
          },
        },
        'axisLine': {
          'lineStyle': {'color': '#FFFFFF20'},
        },
      },
      'series': [
        {
          'type': 'radar',
          'data': [
            {
              'value': [p1Poss, p1Pass, p1Shot, p1Def, p1Form],
              'name': p1Short,
              'areaStyle': {'opacity': 0.25, 'color': '#FF6D00'},
              'lineStyle': {'color': '#FF6D00', 'width': 2.5},
              'itemStyle': {'color': '#FF6D00'},
              'symbol': 'circle',
              'symbolSize': 6,
            },
            {
              'value': [p2Poss, p2Pass, p2Shot, p2Def, p2Form],
              'name': p2Short,
              'areaStyle': {'opacity': 0.25, 'color': '#00E5FF'},
              'lineStyle': {'color': '#00E5FF', 'width': 2.5},
              'itemStyle': {'color': '#00E5FF'},
              'symbol': 'circle',
              'symbolSize': 6,
            },
          ],
          'emphasis': {
            'lineStyle': {'width': 4},
          },
        },
      ],
      'tooltip': {
        'trigger': 'item',
        'backgroundColor': '#1C1F2E',
        'borderColor': '#00E5FF',
        'borderWidth': 1,
        'textStyle': {'color': '#FFFFFF', 'fontSize': 11},
      },
    };

    return GlassCard(
      gradientColors: [AppColors.surfaceLight, AppColors.surface],
      borderColor: AppColors.cyan.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.radar, color: AppColors.cyan, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    isOverall
                        ? 'OVERALL PERFORMANCE RADAR'
                        : 'DIRECT H2H RADAR',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  matchLimit == null ? 'ALL TIME' : 'L$matchLimit',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 270,
            child: GraphifyView(
              controller: GraphifyController(),
              initialOptions: options,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAT COMPARISON TABLE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatTable({
    required String p1Name,
    required Map<String, dynamic> p1Stats,
    required String p2Name,
    required Map<String, dynamic> p2Stats,
  }) {
    final rows = [
      ('Possession', 'possession', '%'),
      ('Passing Acc.', 'passing', '%'),
      ('Shooting Acc.', 'shooting', '%'),
      ('Defending', 'defending', ''),
      ('Form Index', 'form', ''),
    ];

    return GlassCard(
      gradientColors: [AppColors.surface, AppColors.surface],
      borderColor: Colors.white.withValues(alpha: 0.08),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.compare_arrows,
                  color: AppColors.offWhite, size: 14),
              const SizedBox(width: 6),
              Text(
                'STAT COMPARISON',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Column headers
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  p1Name,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    'CATEGORY',
                    style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  p2Name,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 6),

          ...rows.map((row) {
            final (label, key, suffix) = row;
            final v1 = (p1Stats[key] as num?)?.toDouble() ?? 50.0;
            final v2 = (p2Stats[key] as num?)?.toDouble() ?? 50.0;
            final p1Higher = v1 > v2;
            final isDraw = (v1 - v2).abs() < 0.1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${v1.toStringAsFixed(1)}$suffix',
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDraw
                                  ? Colors.white70
                                  : (p1Higher
                                      ? AppColors.primary
                                      : Colors.white54),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: FittedBox(
                          alignment: Alignment.centerRight,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${v2.toStringAsFixed(1)}$suffix',
                            textAlign: TextAlign.right,
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDraw
                                  ? Colors.white70
                                  : (!p1Higher
                                      ? AppColors.cyan
                                      : Colors.white54),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Mini comparison bar
                  _buildComparisonMiniBar(v1, v2),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparisonMiniBar(double v1, double v2) {
    final total = v1 + v2;
    final p1Flex = total > 0 ? (v1 / total * 100).round() : 50;
    final p2Flex = total > 0 ? (v2 / total * 100).round() : 50;

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: Row(
          children: [
            Expanded(
              flex: max(1, p1Flex),
              child: Container(color: AppColors.primary),
            ),
            const SizedBox(width: 1),
            Expanded(
              flex: max(1, p2Flex),
              child: Container(color: AppColors.cyan),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREDICTION CARD
  // ─────────────────────────────────────────────────────────────────────────

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
      return _renderPrediction(embeddedPrediction, p1Name, p2Name);
    }

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
      data: (res) => _renderPrediction(res, p1Name, p2Name),
    );
  }

  Widget _renderPrediction(
      Map<String, dynamic> res, String p1Name, String p2Name) {
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

    final double p1Win = p1Raw <= 1.0 ? p1Raw * 100.0 : p1Raw;
    final double draw = drawRaw <= 1.0 ? drawRaw * 100.0 : drawRaw;
    final double p2Win = p2Raw <= 1.0 ? p2Raw * 100.0 : p2Raw;

    final p1Short = p1Name.length > 10 ? '${p1Name.substring(0, 9)}…' : p1Name;
    final p2Short = p2Name.length > 10 ? '${p2Name.substring(0, 9)}…' : p2Name;

    final options = <String, dynamic>{
      'backgroundColor': 'transparent',
      'series': [
        {
          'type': 'pie',
          'radius': ['50%', '78%'],
          'center': ['50%', '55%'],
          'padAngle': 3,
          'itemStyle': {'borderRadius': 6},
          'data': [
            {
              'value': p1Win.toStringAsFixed(1),
              'name': p1Short,
              'itemStyle': {
                'color': {
                  'type': 'radial',
                  'x': 0.5,
                  'y': 0.5,
                  'r': 0.5,
                  'colorStops': [
                    {'offset': 0, 'color': '#FF9E00'},
                    {'offset': 1, 'color': '#FF6D00'},
                  ],
                },
              },
            },
            {
              'value': draw.toStringAsFixed(1),
              'name': 'Draw',
              'itemStyle': {'color': '#FFB300'},
            },
            {
              'value': p2Win.toStringAsFixed(1),
              'name': p2Short,
              'itemStyle': {
                'color': {
                  'type': 'radial',
                  'x': 0.5,
                  'y': 0.5,
                  'r': 0.5,
                  'colorStops': [
                    {'offset': 0, 'color': '#00B8CC'},
                    {'offset': 1, 'color': '#00E5FF'},
                  ],
                },
              },
            },
          ],
          'label': {
            'show': true,
            'color': '#FFFFFF',
            'fontSize': 11,
            'formatter': '{b}\n{d}%',
          },
          'emphasis': {
            'itemStyle': {
              'shadowBlur': 12,
              'shadowColor': '#00000066',
            },
          },
        },
      ],
      'tooltip': {
        'trigger': 'item',
        'backgroundColor': '#1C1F2E',
        'borderColor': '#E2E8F0',
        'borderWidth': 1,
        'textStyle': {'color': '#FFFFFF', 'fontSize': 12},
        'formatter': '{b}: {d}%',
      },
    };

    return GlassCard(
      gradientColors: [AppColors.surfaceLight, AppColors.surface],
      borderColor: AppColors.offWhite.withValues(alpha: 0.25),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.psychology,
                  size: 14, color: AppColors.offWhite),
              const SizedBox(width: 6),
              Text(
                'AI WIN PROBABILITY',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.offWhite,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 200,
            child: GraphifyView(
              controller: GraphifyController(),
              initialOptions: options,
            ),
          ),
          // Quick legend row
          Row(
            children: [
              _buildProbPill(p1Short, '${p1Win.toStringAsFixed(1)}%',
                  AppColors.primary),
              _buildProbPill(
                  'Draw', '${draw.toStringAsFixed(1)}%', AppColors.amber),
              _buildProbPill(
                  p2Short, '${p2Win.toStringAsFixed(1)}%', AppColors.cyan),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildProbPill(String label, String pct, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pct,
              style: GoogleFonts.rajdhani(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NO DIRECT MATCHES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNoDirectMatchesCard(
    String p1Name,
    String p2Name,
    String? p1Avatar,
    String? p2Avatar,
    int p1Elo,
    int p2Elo,
    Map<String, dynamic>? prediction,
    WidgetRef ref,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          gradientColors: [AppColors.surfaceLight, AppColors.surface],
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
                      letterSpacing: 1.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '0 CLASHES',
                      style: GoogleFonts.rajdhani(
                          fontSize: 10,
                          color: AppColors.amber,
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
                  Container(
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
                      'NO DIRECT RIVALRY MATCHES YET',
                      style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These two players have not faced each other directly. Switch to "All Opponents Avg" to compare tactical profiles.',
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
        const SizedBox(height: 14),
        _buildPredictionCard(
            prediction, p1Name, p2Name, ref, p1Elo, p2Elo, 0, 0),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECENT ENCOUNTERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRecentEncounters(
      List<dynamic> matches, String p1Name, String p2Name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, color: AppColors.cyan, size: 15),
            const SizedBox(width: 6),
            Text(
              'RECENT ENCOUNTERS (${matches.length})',
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
        ...matches.map((m) {
          final p1Sc = (m['player_1_score'] as num?)?.toInt() ?? 0;
          final p2Sc = (m['player_2_score'] as num?)?.toInt() ?? 0;
          final winnerId = m['winner_id']?.toString();
          final matchType =
              (m['match_type'] ?? 'MATCH').toString().toUpperCase();
          final dateStr = _formatDate(m['created_at']);

          final isP1Winner = winnerId != null && winnerId == params.p1Id;
          final isP2Winner = winnerId != null && winnerId == params.p2Id;
          final isDraw = p1Sc == p2Sc;

          Color accentColor = isDraw
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
              border: Border.all(color: accentColor),
            ),
            child: Row(
              children: [
                // Type & Date
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        matchType.replaceAll('_', ' '),
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
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
                // P1 Name
                Expanded(
                  flex: 3,
                  child: Text(
                    p1Name,
                    style: GoogleFonts.rajdhani(
                      color: isP1Winner ? AppColors.primary : Colors.white70,
                      fontWeight:
                          isP1Winner ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Score
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$p1Sc – $p2Sc',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // P2 Name
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAvatarCircle(String? avatarGraphic, Color color) {
    return CircleAvatar(
      radius: 22,
      backgroundColor:
          getAvatarById(avatarGraphic).gradient.first.withValues(alpha: 0.25),
      child: Icon(
        getAvatarById(avatarGraphic).icon,
        size: 24,
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
          textAlign: alignLeft ? TextAlign.left : TextAlign.right,
        ),
        const SizedBox(height: 2),
        _buildEloBadge(elo, color),
      ],
    );
  }
}
