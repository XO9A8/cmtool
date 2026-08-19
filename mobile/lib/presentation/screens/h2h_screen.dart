import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import 'player_profile_screen.dart';
import '../widgets/h2h/player_picker_bottom_sheet.dart';
import '../widgets/h2h/hero_arena.dart';
import '../widgets/h2h/h2h_result_widget.dart';

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
  String _selectedScope =
      'overall'; // 'overall' (All opponents avg) or 'direct' (Direct H2H only)
  int? _selectedMatchLimit = 10; // 5, 10, 20, or null (All)
  H2hParams? _currentParams;

  void _search() {
    if (_p1Id == null || _p2Id == null || _p1Id == _p2Id) return;
    setState(() {
      _currentParams = H2hParams(
        p1Id: _p1Id!,
        p2Id: _p2Id!,
        limit: _selectedMatchLimit,
        scope: _selectedScope,
      );
    });
  }

  void _setScope(String scope) {
    setState(() {
      _selectedScope = scope;
      if (_currentParams != null && _p1Id != null && _p2Id != null) {
        _currentParams = H2hParams(
          p1Id: _p1Id!,
          p2Id: _p2Id!,
          limit: _selectedMatchLimit,
          scope: _selectedScope,
        );
      }
    });
  }

  void _setLimit(int? limit) {
    setState(() {
      _selectedMatchLimit = limit;
      if (_currentParams != null && _p1Id != null && _p2Id != null) {
        _currentParams = H2hParams(
          p1Id: _p1Id!,
          p2Id: _p2Id!,
          limit: _selectedMatchLimit,
          scope: _selectedScope,
        );
      }
    });
  }

  void _swapPlayers() {
    if (_p1Id == null && _p2Id == null) return;
    setState(() {
      final temp = _p1Id;
      _p1Id = _p2Id;
      _p2Id = temp;
      if (_currentParams != null && _p1Id != null && _p2Id != null) {
        _currentParams = H2hParams(
          p1Id: _p1Id!,
          p2Id: _p2Id!,
          limit: _selectedMatchLimit,
          scope: _selectedScope,
        );
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _p1Id = null;
      _p2Id = null;
      _currentParams = null;
    });
  }

  void _selectRandomDuel(List<dynamic> members) {
    if (members.length < 2) return;
    final random = Random();
    final idx1 = random.nextInt(members.length);
    var idx2 = random.nextInt(members.length);
    while (idx2 == idx1) {
      idx2 = random.nextInt(members.length);
    }
    final p1 = members[idx1]['user_id']?.toString();
    final p2 = members[idx2]['user_id']?.toString();
    if (p1 != null && p2 != null) {
      _setMatchup(p1, p2, autoSearch: true);
    }
  }

  void _setMatchup(String p1, String p2, {bool autoSearch = true}) {
    setState(() {
      _p1Id = p1;
      _p2Id = p2;
      if (autoSearch) {
        _currentParams = H2hParams(
          p1Id: p1,
          p2Id: p2,
          limit: _selectedMatchLimit,
          scope: _selectedScope,
        );
      } else {
        _currentParams = null;
      }
    });
  }

  void _showPlayerPickerModal(BuildContext context, List<dynamic> members,
      {required bool isPlayer1}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PlayerPickerBottomSheet(
        title: isPlayer1 ? 'SELECT CHALLENGER 1' : 'SELECT CHALLENGER 2',
        themeColor: isPlayer1 ? AppColors.primary : AppColors.cyan,
        members: members,
        selectedId: isPlayer1 ? _p1Id : _p2Id,
        otherSelectedId: isPlayer1 ? _p2Id : _p1Id,
        onSelect: (selectedMemberId) {
          Navigator.pop(ctx);
          setState(() {
            if (isPlayer1) {
              _p1Id = selectedMemberId;
              if (_p2Id == selectedMemberId) _p2Id = null;
            } else {
              _p2Id = selectedMemberId;
              if (_p1Id == selectedMemberId) _p1Id = null;
            }
            if (_currentParams != null) {
              if (_p1Id != null && _p2Id != null) {
                _currentParams = H2hParams(
                  p1Id: _p1Id!,
                  p2Id: _p2Id!,
                  limit: _selectedMatchLimit,
                  scope: _selectedScope,
                );
              } else {
                _currentParams = null;
              }
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);
    final currentUserId = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Header Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ARENA',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'RIVALRY HUB',
                          style: GoogleFonts.rajdhani(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Historical Head-to-Head Matrix & Tactical Clash',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                if (_currentParams != null)
                  TextButton.icon(
                    onPressed: _clearSelection,
                    icon: const Icon(Icons.refresh,
                        size: 14, color: AppColors.cyan),
                    label: Text(
                      'RESET',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                        letterSpacing: 1.1,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Club Selector Bar
            clubsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (e, _) => GlassCard(
                child: Text('Error loading clubs: $e',
                    style: const TextStyle(color: Colors.redAccent)),
              ),
              data: (data) {
                final clubs = data['clubs'] as List<dynamic>? ?? [];
                if (clubs.isEmpty) {
                  return const GlassCard(
                    child: Text('Join a club first to track rivalries.',
                        style: TextStyle(color: AppColors.textMuted)),
                  );
                }

                if (_selectedClubId == null && clubs.isNotEmpty) {
                  _selectedClubId = clubs.first['id']?.toString();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 14, color: AppColors.cyan),
                        const SizedBox(width: 6),
                        Text(
                          'ACTIVE CLUB',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: clubs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final club = clubs[i];
                          final isSelected = club['id'] == _selectedClubId;
                          return ChoiceChip(
                            avatar: Icon(
                              Icons.groups,
                              size: 16,
                              color: isSelected ? Colors.black : Colors.white60,
                            ),
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
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.04),
                            selectedColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            labelStyle: GoogleFonts.rajdhani(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Main Duel Stage & Discovery
            if (_selectedClubId != null) ...[
              _buildClubArena(context, _selectedClubId!, currentUserId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClubArena(
      BuildContext context, String clubId, String? currentUserId) {
    final membersAsync = ref.watch(clubMembersProvider(clubId));

    return membersAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => GlassCard(
        child: Text('Error loading members: $e',
            style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        if (members.length < 2) {
          return const GlassCard(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'At least 2 club members are required to compare head-to-head stats.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          );
        }

        // Find selected member objects
        final p1Member = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id'] == _p1Id,
              orElse: () => null,
            );
        final p2Member = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id'] == _p2Id,
              orElse: () => null,
            );

        final isReadyToDuel = _p1Id != null && _p2Id != null && _p1Id != _p2Id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🏟️ HERO DUEL ARENA (Face-Off Card)
            HeroArena(
              members: members,
              p1Member: p1Member,
              p2Member: p2Member,
              p1Id: _p1Id,
              p2Id: _p2Id,
              isReadyToDuel: isReadyToDuel,
              isAnalyzing: _currentParams != null,
              onRandomDuel: () => _selectRandomDuel(members),
              onPickPlayer1: () => _showPlayerPickerModal(context, members, isPlayer1: true),
              onPickPlayer2: () => _showPlayerPickerModal(context, members, isPlayer1: false),
              onClearPlayer1: () {
                setState(() {
                  _p1Id = null;
                  _currentParams = null;
                });
              },
              onClearPlayer2: () {
                setState(() {
                  _p2Id = null;
                  _currentParams = null;
                });
              },
              onSwapPlayers: _swapPlayers,
              onAnalyze: _search,
            ),
            const SizedBox(height: 16),

            // 🎛️ MATCH SCOPE & SAMPLE SIZE CONTROLS
            _buildMatchFilterBar(),
            const SizedBox(height: 16),

            // If a duel is analyzed, show the full result breakdown
            if (_currentParams != null) ...[
              H2hResultWidget(
                params: _currentParams!,
                p1Fallback: p1Member,
                p2Fallback: p2Member,
                onScopeChanged: _setScope,
                onLimitChanged: _setLimit,
              ),
            ] else ...[
              // 🌟 RICH INITIAL DISCOVERY STATE
              _buildInitialDiscovery(
                context: context,
                members: members,
                currentUserId: currentUserId,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMatchFilterBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Scope Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune, size: 14, color: AppColors.cyan),
                  const SizedBox(width: 6),
                  Text(
                    'COMPARISON SCOPE',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildScopeButton('🌐 All Opponents', 'overall'),
                    const SizedBox(width: 4),
                    _buildScopeButton('⚔️ Direct H2H', 'direct'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Row 2: Match Sample Size / Count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MATCH SAMPLE',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textMuted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLimitChip('Last 5', 5),
                  const SizedBox(width: 6),
                  _buildLimitChip('Last 10', 10),
                  const SizedBox(width: 6),
                  _buildLimitChip('Last 20', 20),
                  const SizedBox(width: 6),
                  _buildLimitChip('All', null),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopeButton(String label, String scopeVal) {
    final isSelected = _selectedScope == scopeVal;
    return InkWell(
      onTap: () => _setScope(scopeVal),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cyan.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.cyan : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildLimitChip(String label, int? limitVal) {
    final isSelected = _selectedMatchLimit == limitVal;
    return InkWell(
      onTap: () => _setLimit(limitVal),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white10,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialDiscovery({
    required BuildContext context,
    required List<dynamic> members,
    required String? currentUserId,
  }) {
    // Sort members by Elo descending for quick rankings
    final sortedMembers = List<dynamic>.from(members)
      ..sort((a, b) {
        final rA = (a['skill_rating'] as num?)?.toInt() ?? 1000;
        final rB = (b['skill_rating'] as num?)?.toInt() ?? 1000;
        return rB.compareTo(rA);
      });

    // Check if logged-in user is in the club
    final currentUserMember = members.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['user_id'] == currentUserId,
          orElse: () => null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ⚔️ Current User Fast Challenge Prompt
        if (currentUserMember != null && _p1Id != currentUserId) ...[
          _buildUserQuickChallengeCard(currentUserMember),
          const SizedBox(height: 18),
        ],

        // 🔥 TOP CLUB RIVALRIES SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'HOT CLUB MATCHUPS',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              '1-Tap Duel',
              style: GoogleFonts.rajdhani(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildHotMatchupsList(sortedMembers),
        const SizedBox(height: 22),

        // ⚡ CLUB CONTENDERS ROSTER
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports,
                    color: AppColors.cyan, size: 18),
                const SizedBox(width: 6),
                Text(
                  'CLUB CONTENDERS (${members.length})',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.3,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              'Pick to slot',
              style: GoogleFonts.rajdhani(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildContendersRoster(sortedMembers),
        const SizedBox(height: 24),

        // 📊 RIVALRY INTELLIGENCE HIGHLIGHTS
        _buildFeatureHighlights(),
      ],
    );
  }

  Widget _buildUserQuickChallengeCard(Map<String, dynamic> userMember) {
    final username = userMember['username']?.toString() ?? 'You';
    final elo = (userMember['skill_rating'] as num?)?.toInt() ?? 1000;
    final avatarId = userMember['avatar_graphic']?.toString();

    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Icon(getAvatarById(avatarId).icon,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR RIVALRY DOSSIER',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '$username ($elo Elo)',
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _p1Id = userMember['user_id']?.toString();
                if (_p2Id == _p1Id) _p2Id = null;
                _currentParams = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'SET AS P1',
              style: GoogleFonts.rajdhani(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotMatchupsList(List<dynamic> sortedMembers) {
    if (sortedMembers.length < 2) return const SizedBox.shrink();

    final List<Map<String, dynamic>> pairs = [];

    // Pair 1: #1 vs #2 (Clash of Titans)
    pairs.add({
      'title': 'TITAN CLASH (#1 vs #2)',
      'p1': sortedMembers[0],
      'p2': sortedMembers[1],
      'color': AppColors.primary,
    });

    // Pair 2: #1 vs #3
    if (sortedMembers.length >= 3) {
      pairs.add({
        'title': 'PODIUM SHOWDOWN',
        'p1': sortedMembers[0],
        'p2': sortedMembers[2],
        'color': AppColors.purple,
      });
    }

    // Pair 3: #2 vs #3
    if (sortedMembers.length >= 4) {
      pairs.add({
        'title': 'MID-TABLE RIVALRY',
        'p1': sortedMembers[2],
        'p2': sortedMembers[3],
        'color': AppColors.cyan,
      });
    }

    return Column(
      children: pairs.map((pair) {
        final p1 = pair['p1'] as Map<String, dynamic>;
        final p2 = pair['p2'] as Map<String, dynamic>;
        final p1Name = p1['username']?.toString() ?? 'Player 1';
        final p2Name = p2['username']?.toString() ?? 'Player 2';
        final p1Elo = (p1['skill_rating'] as num?)?.toInt() ?? 1000;
        final p2Elo = (p2['skill_rating'] as num?)?.toInt() ?? 1000;
        final title = pair['title'] as String;
        final color = pair['color'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Badge & Title
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$p1Name vs $p2Name',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Elo Comparison
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$p1Elo vs $p2Elo',
                  style:
                      GoogleFonts.orbitron(fontSize: 11, color: Colors.white60),
                ),
              ),

              // Load Action Button
              ElevatedButton(
                onPressed: () => _setMatchup(
                  p1['user_id'].toString(),
                  p2['user_id'].toString(),
                  autoSearch: true,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                  elevation: 0,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  '⚔️ DUEL',
                  style: GoogleFonts.rajdhani(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContendersRoster(List<dynamic> sortedMembers) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sortedMembers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final m = sortedMembers[i] as Map<String, dynamic>;
          final id = m['user_id']?.toString();
          final username = m['username']?.toString() ?? 'Player';
          final elo = (m['skill_rating'] as num?)?.toInt() ?? 1000;
          final avatarId = m['avatar_graphic']?.toString();
          final isP1 = id == _p1Id;
          final isP2 = id == _p2Id;

          Color borderColor = Colors.white12;
          if (isP1) borderColor = AppColors.primary;
          if (isP2) borderColor = AppColors.cyan;

          return Container(
            width: 110,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isP1 || isP2
                  ? (isP1 ? AppColors.primary : AppColors.cyan)
                      .withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: borderColor, width: isP1 || isP2 ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: (isP1
                          ? AppColors.primary
                          : (isP2 ? AppColors.cyan : Colors.white12))
                      .withValues(alpha: 0.2),
                  child: Icon(
                    getAvatarById(avatarId).icon,
                    size: 18,
                    color: isP1
                        ? AppColors.primary
                        : (isP2 ? AppColors.cyan : Colors.white70),
                  ),
                ),
                Text(
                  username,
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$elo ELO',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          _p1Id = id;
                          if (_p2Id == id) _p2Id = null;
                          _currentParams = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isP1
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'P1',
                          style: GoogleFonts.rajdhani(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isP1 ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _p2Id = id;
                          if (_p1Id == id) _p1Id = null;
                          _currentParams = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isP2
                              ? AppColors.cyan
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'P2',
                          style: GoogleFonts.rajdhani(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isP2 ? Colors.black : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIVALRY INTELLIGENCE SUITE',
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.analytics_outlined,
                title: 'All-Time Record',
                desc:
                    'Wins, draws, goal differentials & historical clash record.',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.radar,
                title: '5-Axis Radar',
                desc:
                    'Tactical clash across possession, pass, shot, def & form.',
                color: AppColors.cyan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFeatureCard(
                icon: Icons.psychology_outlined,
                title: 'AI Win Odds',
                desc: 'Real-time Bayesian outcome predictions.',
                color: AppColors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted, height: 1.2),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
