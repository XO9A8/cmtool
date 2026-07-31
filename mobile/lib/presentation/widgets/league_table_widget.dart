import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';

/// Premier League-style league standings table widget.
/// Displays: Pos, Player, P, W, D, L, GF, GA, GD, Pts
/// with conditional row styling for promotion/relegation zones.
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
        return _buildTable(standings);
      },
    );
  }

  Widget _buildTable(List<dynamic> standings) {
    final totalPlayers = standings.length;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A1A2E), const Color(0xFF16213E).withOpacity(0.8)],
                ),
              ),
              child: Row(
                children: [
                  _headerCell('#', 28),
                  _headerCell('PLAYER', 0, flex: true),
                  _headerCell('P', 28),
                  _headerCell('W', 28),
                  _headerCell('D', 28),
                  _headerCell('L', 28),
                  _headerCell('GF', 30),
                  _headerCell('GA', 30),
                  _headerCell('GD', 32),
                  _headerCell('PTS', 36),
                ],
              ),
            ),

            // Rows
            ...standings.asMap().entries.map((entry) {
              final idx = entry.key;
              final s = entry.value;
              final pos = s['position'] ?? (idx + 1);
              final isTop = pos <= (totalPlayers > 4 ? 2 : 1); // Top zone (green)
              final isBottom = pos > totalPlayers - (totalPlayers > 4 ? 1 : 0); // Bottom zone (red)

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
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _headerCell(String label, double width, {bool flex = false}) {
    final text = Text(
      label,
      style: const TextStyle(
        color: Color(0xFFFF6D00),
        fontSize: 10,
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
    // Position indicator color
    Color posColor = Colors.white54;
    Color? leftBorderColor;
    if (position == 1) {
      posColor = Colors.amber;
      leftBorderColor = Colors.amber;
    } else if (isTop) {
      posColor = const Color(0xFF4CAF50);
      leftBorderColor = const Color(0xFF4CAF50);
    } else if (isBottom) {
      posColor = Colors.redAccent;
      leftBorderColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: position % 2 == 0 ? Colors.white.withOpacity(0.02) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: leftBorderColor ?? Colors.transparent,
            width: leftBorderColor != null ? 3 : 0,
          ),
          bottom: !isLast
              ? BorderSide(color: Colors.white.withOpacity(0.04))
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$position',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: posColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: position == 1 ? FontWeight.bold : FontWeight.w500,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _dataCell('$played', 28),
          _dataCell('$won', 28, color: won > 0 ? const Color(0xFF4CAF50) : null),
          _dataCell('$drawn', 28),
          _dataCell('$lost', 28, color: lost > 0 ? Colors.redAccent.withOpacity(0.7) : null),
          _dataCell('$gf', 30),
          _dataCell('$ga', 30),
          _dataCell(
            gd > 0 ? '+$gd' : '$gd',
            32,
            color: gd > 0 ? const Color(0xFF4CAF50) : (gd < 0 ? Colors.redAccent : null),
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: position == 1
                  ? const Color(0xFFFF6D00).withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$pts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: position == 1 ? const Color(0xFFFF6D00) : Colors.white,
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
        style: TextStyle(
          fontSize: 12,
          color: color ?? Colors.white70,
          fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Icon(Icons.leaderboard_outlined, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text('No standings data yet', style: TextStyle(color: Colors.white38)),
          Text('Start a league tournament to see standings here', style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}
