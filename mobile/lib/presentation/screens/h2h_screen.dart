import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import 'match_predictor_screen.dart';

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                TextButton.icon(
                  icon: const Icon(Icons.psychology, color: AppColors.primary, size: 16),
                  label: Text('AI PREDICTOR', style: GoogleFonts.rajdhani(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => DraggableScrollableSheet(
                        initialChildSize: 0.85,
                        maxChildSize: 0.95,
                        minChildSize: 0.5,
                        builder: (_, controller) => Container(
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: const MatchPredictorScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ],
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
                            backgroundColor: Colors.white.withOpacity(0.05),
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
          borderColor: AppColors.cyan.withOpacity(0.3),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _p1Id,
                dropdownColor: AppColors.surface,
                style: GoogleFonts.rajdhani(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Player 1',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
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
                value: _p2Id,
                dropdownColor: AppColors.surface,
                style: GoogleFonts.rajdhani(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Player 2',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
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
        final total   = data['total_matches'] ?? 0;
        final p1Wins  = data['player_1_wins'] ?? 0;
        final draws   = data['draws'] ?? 0;
        final p2Wins  = data['player_2_wins'] ?? 0;
        final avgDiff = (data['avg_goal_diff'] as num?)?.toDouble() ?? 0.0;

        final eloDelta = (data['elo_delta'] as num?)?.toInt() ?? 0;

        final p1Name = data['player_1_name'] ?? (params.p1Id.length > 8 ? params.p1Id.substring(0, 8) : params.p1Id);
        final p2Name = data['player_2_name'] ?? (params.p2Id.length > 8 ? params.p2Id.substring(0, 8) : params.p2Id);

        return GlassCard(
          gradientColors: const [Color(0xFF191C2B), Color(0xFF0F111A)],
          borderColor: AppColors.primary.withOpacity(0.5),
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
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          p1Name,
                          style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$p1Wins WINS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$total MATCHES',
                          style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$draws DRAWS',
                          style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          p2Name,
                          style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$p2Wins WINS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (total > 0) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        Expanded(
                          flex: p1Wins > 0 ? p1Wins : (total == 0 ? 1 : 0),
                          child: Container(color: p1Wins > 0 ? AppColors.primary : Colors.transparent),
                        ),
                        Expanded(
                          flex: draws > 0 ? draws : (total == 0 ? 1 : 0),
                          child: Container(color: draws > 0 ? Colors.white24 : Colors.transparent),
                        ),
                        Expanded(
                          flex: p2Wins > 0 ? p2Wins : (total == 0 ? 1 : 0),
                          child: Container(color: p2Wins > 0 ? AppColors.cyan : Colors.transparent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_soccer, color: AppColors.cyan, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Avg Goal Diff: ${avgDiff > 0 ? '+' : ''}${avgDiff.toStringAsFixed(2)}',
                    style: GoogleFonts.rajdhani(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.trending_up, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Elo Delta: ${eloDelta > 0 ? '+' : ''}$eloDelta',
                    style: GoogleFonts.rajdhani(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fade().slideY(begin: 0.1);
      },
    );
  }
}
