import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

import '../widgets/tournament_leaders_widget.dart';

/// Premier League-style league standings table widget.
/// Redesigned with premium Glassmorphism and esports aesthetics.
class LeagueTableWidget extends ConsumerWidget {
  final String tournamentId;

  const LeagueTableWidget({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final standingsAsync = ref.watch(leagueStandingsProvider(tournamentId));

    return standingsAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Failed to load standings: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
      data: (data) {
        final standings = data['standings'] as List<dynamic>? ?? [];
        if (standings.isEmpty) return _buildEmptyState();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TournamentLeadersWidget(tournamentId: tournamentId),
            const SizedBox(height: 16),
            _buildTable(standings),
          ],
        );
      },
    );
  }

  Widget _buildTable(List<dynamic> standings) {
    final totalPlayers = standings.length;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                _headerCell('#', 28),
                _headerCell('PLAYER', 0, flex: true),
                _headerCell('P', 28),
                _headerCell('W', 28),
                _headerCell('D', 28),
                _headerCell('L', 28),
                _headerCell('GD', 32),
                _headerCell('PTS', 36, isHighlighted: true),
              ],
            ),
          ),

          // Rows
          ...standings.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final pos = s['position'] ?? (idx + 1);
            final isTop = pos <= (totalPlayers > 4 ? 2 : 1);
            final isBottom = pos > totalPlayers - (totalPlayers > 4 ? 1 : 0);

            return _buildRow(
              position: pos,
              name: s['player_name'] ?? 'Unknown',
              played: s['played'] ?? 0,
              won: s['won'] ?? 0,
              drawn: s['drawn'] ?? 0,
              lost: s['lost'] ?? 0,
              gf: s['goals_for'] ?? 0,
              ga: s['goals_against'] ?? 0,
              gd: s['goal_diff'] ?? 0,
              pts: s['points'] ?? 0,
              isTop: isTop,
              isBottom: isBottom,
              isLast: idx == standings.length - 1,
            );
          }),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _headerCell(String label, double width, {bool flex = false, bool isHighlighted = false}) {
    final text = Text(
      label,
      style: GoogleFonts.rajdhani(
        color: isHighlighted ? AppColors.cyan : AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );

    if (flex) {
      return Expanded(child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Align(alignment: Alignment.centerLeft, child: text),
      ));
    }
    return SizedBox(width: width, child: Center(child: text));
  }

  Widget _buildRow({
    required int position,
    required String name,
    required int played,
    required int won,
    required int drawn,
    required int lost,
    required int gf,
    required int ga,
    required int gd,
    required int pts,
    required bool isTop,
    required bool isBottom,
    required bool isLast,
  }) {
    Color posColor = Colors.white70;
    Color? leftBorderColor;
    if (position == 1) {
      posColor = Colors.amber;
      leftBorderColor = Colors.amber;
    } else if (isTop) {
      posColor = AppColors.winGreen;
      leftBorderColor = AppColors.winGreen;
    } else if (isBottom) {
      posColor = AppColors.lossRed;
      leftBorderColor = AppColors.lossRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: position % 2 == 0 ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: leftBorderColor ?? Colors.transparent,
            width: leftBorderColor != null ? 4 : 0,
          ),
          bottom: !isLast
              ? BorderSide(color: Colors.white.withValues(alpha: 0.04))
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$position',
              style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.bold, color: posColor),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: position == 1 ? FontWeight.bold : FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _dataCell('$played', 28),
          _dataCell('$won', 28, color: won > 0 ? AppColors.winGreen : null),
          _dataCell('$drawn', 28),
          _dataCell('$lost', 28, color: lost > 0 ? AppColors.lossRed.withValues(alpha: 0.8) : null),
          _dataCell(
            gd > 0 ? '+$gd' : '$gd',
            32,
            color: gd > 0 ? AppColors.winGreen : (gd < 0 ? AppColors.lossRed : null),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: position == 1
                  ? AppColors.cyan.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: position == 1 ? Border.all(color: AppColors.cyan.withValues(alpha: 0.3)) : null,
            ),
            child: Text(
              '$pts',
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: position == 1 ? AppColors.cyan : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCell(String value, double width, {Color? color}) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        style: GoogleFonts.rajdhani(
          fontSize: 13,
          color: color ?? AppColors.textMuted,
          fontWeight: color != null ? FontWeight.bold : FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSkeleton() {
    return SizedBox(
      height: 250,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.leaderboard_outlined, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text('No standings data yet', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text('Start a league tournament to see standings here', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
