import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

import 'tournament_leaders_widget.dart';

/// Group Stage Standings widget for Group-First Knockout tournaments (`group_knockout`).
/// Renders group-segmented standings (Group A, Group B, etc.) with qualified playoff spot indicators.
class GroupStandingsWidget extends ConsumerStatefulWidget {
  final String tournamentId;
  final int groupsCount;
  final int advancingPerGroup;

  const GroupStandingsWidget({
    super.key,
    required this.tournamentId,
    this.groupsCount = 2,
    this.advancingPerGroup = 2,
  });

  @override
  ConsumerState<GroupStandingsWidget> createState() => _GroupStandingsWidgetState();
}

class _GroupStandingsWidgetState extends ConsumerState<GroupStandingsWidget> {
  int _selectedGroupIdx = -1; // -1 means All Groups

  static const _groupLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  @override
  Widget build(BuildContext context) {
    final standingsAsync = ref.watch(leagueStandingsProvider(widget.tournamentId));

    return standingsAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Failed to load group standings: $e', style: const TextStyle(color: Colors.redAccent)),
        ),
      ),
      data: (data) {
        final standings = (data['standings'] as List<dynamic>? ?? []);
        if (standings.isEmpty) return _buildEmptyState();

        final groupsCount = (data['groups_count'] as num?)?.toInt() ?? widget.groupsCount;
        final advancingPerGroup = (data['advancing_per_group'] as num?)?.toInt() ?? widget.advancingPerGroup;

        final groupedStandings = _partitionIntoGroups(standings, groupsCount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header Info Card ───
            _buildHeaderCard(advancingPerGroup),
            const SizedBox(height: 16),

            // ─── Tournament Leaders & Stats ───
            TournamentLeadersWidget(tournamentId: widget.tournamentId),
            const SizedBox(height: 16),

            // ─── Group Filter Tabs ───
            _buildGroupFilterChips(groupedStandings.length),
            const SizedBox(height: 16),

            // ─── Group Standings Cards ───
            if (_selectedGroupIdx == -1)
              ...groupedStandings.entries.map((entry) => _buildGroupCard(
                    groupName: entry.key,
                    players: entry.value,
                    advancingPerGroup: advancingPerGroup,
                  ))
            else ...[
              if (_selectedGroupIdx < groupedStandings.length)
                _buildGroupCard(
                  groupName: groupedStandings.keys.elementAt(_selectedGroupIdx),
                  players: groupedStandings.values.elementAt(_selectedGroupIdx),
                  advancingPerGroup: advancingPerGroup,
                ),
            ],
          ],
        );
      },
    );
  }

  /// Partition flat standings into N groups
  Map<String, List<dynamic>> _partitionIntoGroups(List<dynamic> standings, int count) {
    final Map<String, List<dynamic>> result = {};
    final totalGroups = count > 0 ? count : 2;

    for (int i = 0; i < totalGroups; i++) {
      final groupName = 'GROUP ${_groupLetters[i % _groupLetters.length]}';
      result[groupName] = [];
    }

    // Partition by explicit group tag if available, otherwise round-robin chunking
    for (int i = 0; i < standings.length; i++) {
      final s = standings[i];
      final explicitGroup = s['group_name'] ?? s['group'];
      if (explicitGroup != null && explicitGroup.toString().isNotEmpty) {
        final gName = explicitGroup.toString().toUpperCase();
        result.putIfAbsent(gName, () => []).add(s);
      } else {
        final groupIdx = i % totalGroups;
        final gName = 'GROUP ${_groupLetters[groupIdx % _groupLetters.length]}';
        result[gName]!.add(s);
      }
    }

    // Sort players in each group by points DESC, goal_diff DESC, goals_for DESC
    for (final key in result.keys) {
      result[key]!.sort((a, b) {
        final ptsA = (a['points'] as num?)?.toInt() ?? 0;
        final ptsB = (b['points'] as num?)?.toInt() ?? 0;
        if (ptsA != ptsB) return ptsB.compareTo(ptsA);

        final gdA = (a['goal_diff'] as num?)?.toInt() ?? 0;
        final gdB = (b['goal_diff'] as num?)?.toInt() ?? 0;
        if (gdA != gdB) return gdB.compareTo(gdA);

        final gfA = (a['goals_for'] as num?)?.toInt() ?? 0;
        final gfB = (b['goals_for'] as num?)?.toInt() ?? 0;
        return gfB.compareTo(gfA);
      });
    }

    return result;
  }

  Widget _buildHeaderCard(int advancingPerGroup) {
    return GlassCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.grid_view, color: AppColors.cyan, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GROUP STAGE STANDINGS',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.winGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Top $advancingPerGroup advance to Knockout Playoffs',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFilterChips(int groupCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('ALL GROUPS', -1),
          for (int i = 0; i < groupCount; i++) ...[
            const SizedBox(width: 8),
            _chip('GROUP ${_groupLetters[i % _groupLetters.length]}', i),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, int idx) {
    final selected = _selectedGroupIdx == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedGroupIdx = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.cyan : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            color: selected ? AppColors.cyan : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupCard({required String groupName, required List<dynamic> players, required int advancingPerGroup}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderColor: AppColors.purple.withValues(alpha: 0.3),
        child: Column(
          children: [
            // Group Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                border: Border(bottom: BorderSide(color: AppColors.purple.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppColors.purple, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    groupName,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.winGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.winGreen.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'TOP $advancingPerGroup ADVANCE',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.winGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Columns Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.white.withValues(alpha: 0.02),
              child: Row(
                children: [
                  _headerCell('#', 28),
                  _headerCell('PLAYER', 0, flex: true),
                  _headerCell('P', 26),
                  _headerCell('W', 26),
                  _headerCell('D', 26),
                  _headerCell('L', 26),
                  _headerCell('GD', 30),
                  _headerCell('PTS', 34, isHighlighted: true),
                ],
              ),
            ),

            // Rows
            if (players.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('No players assigned yet', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: players.length,
                itemBuilder: (context, idx) {
                  final s = players[idx];
                  final pos = idx + 1;
                  final isQualified = pos <= widget.advancingPerGroup;

                  return _buildRow(
                    position: pos,
                    name: s['player_name'] ?? s['username'] ?? 'Player $pos',
                    played: (s['played'] as num?)?.toInt() ?? 0,
                    won: (s['won'] as num?)?.toInt() ?? 0,
                    drawn: (s['drawn'] as num?)?.toInt() ?? 0,
                    lost: (s['lost'] as num?)?.toInt() ?? 0,
                    gf: (s['goals_for'] as num?)?.toInt() ?? 0,
                    ga: (s['goals_against'] as num?)?.toInt() ?? 0,
                    gd: (s['goal_diff'] as num?)?.toInt() ?? 0,
                    pts: (s['points'] as num?)?.toInt() ?? 0,
                    isQualified: isQualified,
                    isLast: idx == players.length - 1,
                  );
                },
              ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.04, duration: 300.ms);
  }

  Widget _headerCell(String label, double width, {bool flex = false, bool isHighlighted = false}) {
    final text = Text(
      label,
      style: GoogleFonts.rajdhani(
        color: isHighlighted ? AppColors.cyan : AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );

    if (flex) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Align(alignment: Alignment.centerLeft, child: text),
        ),
      );
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
    required bool isQualified,
    required bool isLast,
  }) {
    Color posColor = isQualified ? AppColors.winGreen : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isQualified ? AppColors.winGreen.withValues(alpha: 0.04) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isQualified ? AppColors.winGreen : Colors.transparent,
            width: isQualified ? 4 : 0,
          ),
          bottom: !isLast ? BorderSide(color: Colors.white.withValues(alpha: 0.04)) : BorderSide.none,
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
                    radius: 11,
                    backgroundColor: isQualified ? AppColors.winGreen.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isQualified ? AppColors.winGreen : Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.rajdhani(
                              fontSize: 13,
                              fontWeight: isQualified ? FontWeight.bold : FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isQualified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.winGreen.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Q',
                              style: GoogleFonts.rajdhani(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.winGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _dataCell('$played', 26),
          _dataCell('$won', 26, color: won > 0 ? AppColors.winGreen : null),
          _dataCell('$drawn', 26),
          _dataCell('$lost', 26, color: lost > 0 ? AppColors.lossRed.withValues(alpha: 0.8) : null),
          _dataCell(
            gd > 0 ? '+$gd' : '$gd',
            30,
            color: gd > 0 ? AppColors.winGreen : (gd < 0 ? AppColors.lossRed : null),
          ),
          Container(
            width: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: isQualified ? AppColors.cyan.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isQualified ? Border.all(color: AppColors.cyan.withValues(alpha: 0.3)) : null,
            ),
            child: Text(
              '$pts',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isQualified ? AppColors.cyan : Colors.white,
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
          fontSize: 12,
          color: color ?? AppColors.textMuted,
          fontWeight: color != null ? FontWeight.bold : FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildSkeleton() {
    return const SizedBox(
      height: 250,
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.grid_view, color: AppColors.textMuted, size: 48),
          const SizedBox(height: 12),
          Text('No Group Standings Available', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Start the tournament to generate group stage tables', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
