import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../widgets/mps_radar_chart.dart';
import 'player_profile_screen.dart';

/// Head-to-Head Rivalry Tracker screen showing live H2H stats between two players.
class H2hScreen extends ConsumerStatefulWidget {
  const H2hScreen({super.key});

  @override
  ConsumerState<H2hScreen> createState() => _H2hScreenState();
}

class _H2hScreenState extends ConsumerState<H2hScreen> {
  String? _selectedClubId;
  String? _p1Id;
  String? _p2Id;
  H2hParams? _currentParams;

  void _search() {
    if (_p1Id == null || _p2Id == null) return;
    setState(() {
      _currentParams = H2hParams(p1Id: _p1Id!, p2Id: _p2Id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RIVALRY STATS TRACKER',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Compare historical head-to-head records between players.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Club Selection Chips
            clubsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => GlassCard(
                child: Text('Error loading clubs: $e', style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (data) {
                final clubs = data['clubs'] as List<dynamic>? ?? [];
                if (clubs.isEmpty) {
                  return const GlassCard(
                    child: Text('Join a club first to track rivalries.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }

                if (_selectedClubId == null && clubs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _selectedClubId = clubs.first['id']);
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT CLUB',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: clubs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final club = clubs[i];
                          final isSelected = club['id'] == _selectedClubId;
                          return ChoiceChip(
                            label: Text(club['name'] ?? 'Club'),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedClubId = club['id'];
                                _p1Id = null;
                                _p2Id = null;
                                _currentParams = null;
                              });
                            },
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            selectedColor: AppColors.primary,
                            labelStyle: GoogleFonts.rajdhani(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Player Selectors
            if (_selectedClubId != null) ...[
              _buildPlayerSelectors(),
            ],

            const SizedBox(height: 20),
            if (_currentParams != null) _H2hResultWidget(params: _currentParams!),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSelectors() {
    final membersAsync = ref.watch(clubMembersProvider(_selectedClubId!));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => GlassCard(
        child: Text('Error loading members: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        if (members.length < 2) {
          return const GlassCard(
            child: Text('Not enough members in this club to compare.', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        return GlassCard(
          borderColor: AppColors.cyan.withValues(alpha: 0.3),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _p1Id,
                dropdownColor: AppColors.surface,
                style: GoogleFonts.rajdhani(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Player 1',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                ),
                items: members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['user_id'],
                    child: Text(m['username'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _p1Id = val;
                    if (_p2Id == val) _p2Id = null;
                  });
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _p2Id,
                dropdownColor: AppColors.surface,
                style: GoogleFonts.rajdhani(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Player 2',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.person, color: AppColors.cyan),
                ),
                items: members.where((m) => m['user_id'] != _p1Id).map((m) {
                  return DropdownMenuItem<String>(
                    value: m['user_id'],
                    child: Text(m['username'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _p2Id = val),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: EsportsButton(
                  label: 'COMPARE RIVALRY STATS',
                  icon: Icons.compare_arrows,
                  gradient: const [AppColors.primary, AppColors.cyan],
                  onPressed: (_p1Id != null && _p2Id != null && _p1Id != _p2Id) ? _search : null,
                ),
              ),
            ],
          ),
        ).animate().fade().slideY(begin: 0.05);
      },
    );
  }
}

class _H2hResultWidget extends ConsumerWidget {
  final H2hParams params;
  const _H2hResultWidget({required this.params});

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
        child: Text('Failed to load H2H: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final total = (data['total_matches'] as num?)?.toInt() ?? 0;
        final p1Wins = (data['player_1_wins'] as num?)?.toInt() ?? 0;
        final draws = (data['draws'] as num?)?.toInt() ?? 0;
        final p2Wins = (data['player_2_wins'] as num?)?.toInt() ?? 0;
        final p1Goals = (data['player_1_goals'] as num?)?.toInt() ?? 0;
        final p2Goals = (data['player_2_goals'] as num?)?.toInt() ?? 0;
        final avgDiff = (data['avg_goal_diff'] as num?)?.toDouble() ?? 0.0;

        final p1Elo = (data['player_1_elo'] as num?)?.toInt() ?? 1000;
        final p2Elo = (data['player_2_elo'] as num?)?.toInt() ?? 1000;
        final eloDelta = (data['elo_delta'] as num?)?.toInt() ?? (p1Elo - p2Elo);

        final p1Name = data['player_1_name']?.toString() ??
            (params.p1Id.length > 8 ? params.p1Id.substring(0, 8) : params.p1Id);
        final p2Name = data['player_2_name']?.toString() ??
            (params.p2Id.length > 8 ? params.p2Id.substring(0, 8) : params.p2Id);
        final p1Avatar = data['player_1_avatar']?.toString();
        final p2Avatar = data['player_2_avatar']?.toString();

        final p1Stats = Map<String, dynamic>.from(data['player_1_stats'] as Map? ?? {});
        final p2Stats = Map<String, dynamic>.from(data['player_2_stats'] as Map? ?? {});

        final recentMatches = (data['recent_matches'] as List<dynamic>? ?? []);

        // When no matches have been played yet
        if (total == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                gradientColors: const [Color(0xFF191C2B), Color(0xFF0F111A)],
                borderColor: AppColors.cyan.withValues(alpha: 0.3),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'HISTORICAL HEAD-TO-HEAD',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildPlayerProfileHeader(p1Name, p1Avatar, p1Elo, AppColors.primary, alignLeft: true)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              'VS',
                              style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(child: _buildPlayerProfileHeader(p2Name, p2Avatar, p2Elo, AppColors.cyan, alignLeft: false)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.sports_esports_outlined, color: AppColors.cyan.withValues(alpha: 0.7), size: 36),
                          const SizedBox(height: 10),
                          Text(
                            'NO RIVALRY MATCHES RECORDED YET',
                            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Play matches in a tournament or friendly games and submit results to track the head-to-head records between $p1Name and $p2Name.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              H2hDualRadarChart(
                p1Name: p1Name,
                p2Name: p2Name,
                p1Stats: p1Stats,
                p2Stats: p2Stats,
              ),
            ],
          ).animate().fade().slideY(begin: 0.05);
        }

        final p1WinRate = total > 0 ? ((p1Wins / total) * 100).toStringAsFixed(0) : '0';
        final p2WinRate = total > 0 ? ((p2Wins / total) * 100).toStringAsFixed(0) : '0';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassCard(
              gradientColors: const [Color(0xFF191C2B), Color(0xFF0F111A)],
              borderColor: AppColors.primary.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'HISTORICAL HEAD-TO-HEAD',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      letterSpacing: 2,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            _buildEloBadge(p1Elo, AppColors.primary),
                            const SizedBox(height: 10),
                            Text(
                              '$p1Wins WINS',
                              style: GoogleFonts.rajdhani(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '$p1WinRate% Win Rate',
                              style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      // Center Matches Pillar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$total',
                              style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              'MATCHES',
                              style: GoogleFonts.rajdhani(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$draws DRAWS',
                                style: GoogleFonts.rajdhani(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                              ),
                            ),
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
                              style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            _buildEloBadge(p2Elo, AppColors.cyan),
                            const SizedBox(height: 10),
                            Text(
                              '$p2Wins WINS',
                              style: GoogleFonts.rajdhani(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cyan,
                              ),
                            ),
                            Text(
                              '$p2WinRate% Win Rate',
                              style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
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
                            flex: p1Wins > 0 ? p1Wins : (total == 0 ? 1 : 0),
                            child: Container(color: p1Wins > 0 ? AppColors.primary : Colors.transparent),
                          ),
                          if (draws > 0)
                            Expanded(
                              flex: draws,
                              child: Container(color: Colors.amber.withValues(alpha: 0.6)),
                            ),
                          Expanded(
                            flex: p2Wins > 0 ? p2Wins : (total == 0 ? 1 : 0),
                            child: Container(color: p2Wins > 0 ? AppColors.cyan : Colors.transparent),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatComparison('GOALS SCORED', '$p1Goals – $p2Goals', Icons.sports_soccer, AppColors.cyan),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildStatComparison('AVG GOAL DIFF', '${avgDiff > 0 ? '+' : ''}${avgDiff.toStringAsFixed(1)}', Icons.timeline, AppColors.purple),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildStatComparison(
                          'ELO GAP',
                          eloDelta == 0 ? 'EVEN' : '${eloDelta > 0 ? '+' : ''}$eloDelta',
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

            // Performance Radar Chart Comparison
            H2hDualRadarChart(
              p1Name: p1Name,
              p2Name: p2Name,
              p1Stats: p1Stats,
              p2Stats: p2Stats,
            ),

            // Recent Encounters Section
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
                final matchType = (m['match_type'] ?? 'MATCH').toString().toUpperCase();
                final dateStr = _formatDate(m['created_at']);

                final isP1Winner = winnerId != null && winnerId == params.p1Id;
                final isP2Winner = winnerId != null && winnerId == params.p2Id;
                final isDraw = p1Sc == p2Sc;

                Color borderColor = isDraw ? Colors.white12 : (isP1Winner ? AppColors.primary.withValues(alpha: 0.3) : AppColors.cyan.withValues(alpha: 0.3));

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
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
                            color: isP1Winner ? AppColors.primary : Colors.white70,
                            fontWeight: isP1Winner ? FontWeight.bold : FontWeight.w500,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                            fontWeight: isP2Winner ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildAvatarCircle(String? avatarGraphic, Color color) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: getAvatarById(avatarGraphic).gradient.first.withValues(alpha: 0.25),
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
        style: GoogleFonts.orbitron(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPlayerProfileHeader(String name, String? avatar, int elo, Color color, {required bool alignLeft}) {
    return Column(
      crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        _buildAvatarCircle(avatar, color),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        _buildEloBadge(elo, color),
      ],
    );
  }

  Widget _buildStatComparison(String label, String val, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: GoogleFonts.orbitron(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
