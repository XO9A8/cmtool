import 'dart:math';
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
    setState(() {
      _p1Id = members[idx1]['user_id']?.toString();
      _p2Id = members[idx2]['user_id']?.toString();
      _currentParams = null;
    });
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
      builder: (ctx) => _PlayerPickerBottomSheet(
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
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _selectedClubId = clubs.first['id']);
                  });
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
            _buildHeroArena(
              context: context,
              members: members,
              p1Member: p1Member,
              p2Member: p2Member,
              isReadyToDuel: isReadyToDuel,
            ),
            const SizedBox(height: 16),

            // 🎛️ MATCH SCOPE & SAMPLE SIZE CONTROLS
            _buildMatchFilterBar(),
            const SizedBox(height: 16),

            // If a duel is analyzed, show the full result breakdown
            if (_currentParams != null) ...[
              _H2hResultWidget(
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

  Widget _buildHeroArena({
    required BuildContext context,
    required List<dynamic> members,
    required Map<String, dynamic>? p1Member,
    required Map<String, dynamic>? p2Member,
    required bool isReadyToDuel,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF161824).withValues(alpha: 0.95),
            const Color(0xFF0C0E17).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isReadyToDuel
              ? AppColors.primary.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isReadyToDuel
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Stage Status Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReadyToDuel
                            ? AppColors.winGreen
                            : AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: (isReadyToDuel
                                    ? AppColors.winGreen
                                    : AppColors.primary)
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isReadyToDuel
                          ? 'DUEL READY'
                          : (_p1Id != null || _p2Id != null
                              ? 'SELECT OPPONENT'
                              : 'CHOOSE CONTENDERS'),
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color:
                            isReadyToDuel ? AppColors.winGreen : Colors.white70,
                      ),
                    ),
                  ],
                ),
                // Random Duel Button
                InkWell(
                  onTap: () => _selectRandomDuel(members),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.casino_outlined,
                            size: 14, color: AppColors.cyan),
                        const SizedBox(width: 4),
                        Text(
                          'RANDOM DUEL',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Face-off Row: Challenger 1 vs Challenger 2
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Challenger 1 Slot (Orange)
                Expanded(
                  child: _buildChallengerCard(
                    title: 'CHALLENGER 1',
                    member: p1Member,
                    themeColor: AppColors.primary,
                    onTap: () => _showPlayerPickerModal(context, members,
                        isPlayer1: true),
                    onClear: () {
                      setState(() {
                        _p1Id = null;
                        _currentParams = null;
                      });
                    },
                  ),
                ),

                // Center VS & Swap Action
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.25),
                              AppColors.cyan.withValues(alpha: 0.25),
                            ],
                          ),
                          border: Border.all(
                            color:
                                isReadyToDuel ? Colors.white30 : Colors.white12,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isReadyToDuel
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          'VS',
                          style: GoogleFonts.orbitron(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      IconButton(
                        onPressed: (_p1Id != null || _p2Id != null)
                            ? _swapPlayers
                            : null,
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        color: (_p1Id != null || _p2Id != null)
                            ? Colors.white70
                            : Colors.white24,
                        tooltip: 'Swap Challengers',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                ),

                // Challenger 2 Slot (Cyan)
                Expanded(
                  child: _buildChallengerCard(
                    title: 'CHALLENGER 2',
                    member: p2Member,
                    themeColor: AppColors.cyan,
                    onTap: () => _showPlayerPickerModal(context, members,
                        isPlayer1: false),
                    onClear: () {
                      setState(() {
                        _p2Id = null;
                        _currentParams = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Analyze CTA Button
            SizedBox(
              width: double.infinity,
              child: EsportsButton(
                label: _currentParams == null
                    ? 'ANALYZE RIVALRY'
                    : 'UPDATE ANALYSIS',
                icon: Icons.flash_on,
                gradient: isReadyToDuel
                    ? const [AppColors.primary, AppColors.cyan]
                    : [Colors.white24, Colors.white12],
                textColor: isReadyToDuel ? Colors.black : Colors.white38,
                onPressed: isReadyToDuel ? _search : null,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.05);
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

  Widget _buildChallengerCard({
    required String title,
    required Map<String, dynamic>? member,
    required Color themeColor,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasPlayer = member != null;
    final username = member?['username']?.toString() ?? 'Select Player';
    final elo = (member?['skill_rating'] as num?)?.toInt() ?? 1000;
    final playStyle = member?['play_style']?.toString() ?? 'Balanced';
    final avatarId = member?['avatar_graphic']?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasPlayer
                ? themeColor.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasPlayer
                  ? themeColor.withValues(alpha: 0.5)
                  : Colors.white12,
              width: hasPlayer ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 10),

              // Avatar Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPlayer
                          ? LinearGradient(
                              colors: [
                                themeColor.withValues(alpha: 0.4),
                                themeColor.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      color: hasPlayer
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: hasPlayer ? themeColor : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      hasPlayer
                          ? getAvatarById(avatarId).icon
                          : Icons.person_add_alt_1,
                      color: hasPlayer ? themeColor : Colors.white38,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Username
              Text(
                username,
                style: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: hasPlayer ? Colors.white : Colors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // Rating / Action prompt
              if (hasPlayer) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: themeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$elo ELO',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  playStyle,
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Text(
                  'Tap to pick',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Searchable Player Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PlayerPickerBottomSheet extends StatefulWidget {
  final String title;
  final Color themeColor;
  final List<dynamic> members;
  final String? selectedId;
  final String? otherSelectedId;
  final ValueChanged<String> onSelect;

  const _PlayerPickerBottomSheet({
    required this.title,
    required this.themeColor,
    required this.members,
    required this.selectedId,
    required this.otherSelectedId,
    required this.onSelect,
  });

  @override
  State<_PlayerPickerBottomSheet> createState() =>
      _PlayerPickerBottomSheetState();
}

class _PlayerPickerBottomSheetState extends State<_PlayerPickerBottomSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.members.where((m) {
      final username = (m['username'] ?? '').toString().toLowerCase();
      final playStyle = (m['play_style'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return username.contains(query) || playStyle.contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: widget.themeColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.themeColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${filteredMembers.length} PLAYERS',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search player name or play style...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white60, size: 20),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.themeColor),
                ),
              ),
            ),
          ),

          // Members List
          Expanded(
            child: filteredMembers.isEmpty
                ? Center(
                    child: Text(
                      'No matching players found.',
                      style: GoogleFonts.rajdhani(
                          color: AppColors.textMuted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final m = filteredMembers[i] as Map<String, dynamic>;
                      final id = m['user_id']?.toString() ?? '';
                      final username = m['username']?.toString() ?? 'Player';
                      final elo = (m['skill_rating'] as num?)?.toInt() ?? 1000;
                      final form = (m['form_rating'] as num?)?.toInt() ?? 50;
                      final playStyle =
                          m['play_style']?.toString() ?? 'Balanced';
                      final avatarId = m['avatar_graphic']?.toString();
                      final isSelected = id == widget.selectedId;
                      final isOtherSelected = id == widget.otherSelectedId;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelect(id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.themeColor.withValues(alpha: 0.15)
                                  : (isOtherSelected
                                      ? Colors.white.withValues(alpha: 0.02)
                                      : Colors.white.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? widget.themeColor
                                    : (isOtherSelected
                                        ? Colors.white12
                                        : Colors.white.withValues(alpha: 0.06)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isSelected
                                      ? widget.themeColor.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                  child: Icon(
                                    getAvatarById(avatarId).icon,
                                    color: isSelected
                                        ? widget.themeColor
                                        : Colors.white70,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            username,
                                            style: GoogleFonts.rajdhani(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (isOtherSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.amber
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'OTHER SLOT',
                                                style: GoogleFonts.rajdhani(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        playStyle,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: widget.themeColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$elo ELO',
                                        style: GoogleFonts.orbitron(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: widget.themeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Form $form%',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white38),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Head-to-Head Result Widget
// ─────────────────────────────────────────────────────────────────────────────

class _H2hResultWidget extends ConsumerWidget {
  final H2hParams params;
  final Map<String, dynamic>? p1Fallback;
  final Map<String, dynamic>? p2Fallback;
  final ValueChanged<String>? onScopeChanged;
  final ValueChanged<int?>? onLimitChanged;

  const _H2hResultWidget({
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

        // AI Match Prediction Query
        final predictAsync = ref.watch(matchPredictionProvider(
          PredictParams(
            p1Rating: p1Elo,
            p2Rating: p2Elo,
            p1H2hWins: p1DirectWins,
            p2H2hWins: p2DirectWins,
          ),
        ));

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
              _buildPredictionCard(predictAsync, p1Name, p2Name),
            ],
          ).animate().fade().slideY(begin: 0.05);
        }

        // Active Comparison: Direct H2H OR Overall Career Average
        final isOverall = !isDirectScope;
        final displayTotal =
            isOverall ? max(p1OverallMatches, p2OverallMatches) : directTotal;
        final p1DisplayWins = isOverall ? p1OverallWins : p1DirectWins;
        final p2DisplayWins = isOverall ? p2OverallWins : p2DirectWins;
        final displayDraws =
            isOverall ? (p1OverallDraws + p2OverallDraws) ~/ 2 : directDraws;
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
                                '$p1OverallMatches played',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white38),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Center Matches Pillar
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
                            Text(
                              '$displayTotal',
                              style: GoogleFonts.orbitron(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              isOverall ? 'SAMPLE' : 'MATCHES',
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
                                '$displayDraws DRAWS',
                                style: GoogleFonts.rajdhani(
                                    fontSize: 10,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold),
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
                                '$p2OverallMatches played',
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
                          if (displayDraws > 0)
                            Expanded(
                              flex: displayDraws,
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
            _buildPredictionCard(predictAsync, p1Name, p2Name),
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
    AsyncValue<Map<String, dynamic>> predictAsync,
    String p1Name,
    String p2Name,
  ) {
    return predictAsync.when(
      loading: () => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (res) {
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

        final double p1Win = (p1Raw * 100).clamp(1.0, 98.0);
        final double draw = (drawRaw * 100).clamp(1.0, 98.0);
        final double p2Win = (p2Raw * 100).clamp(1.0, 98.0);

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
                    'AI MATCH WIN PROBABILITY FORECAST',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.purple,
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
                        flex: (p1Win * 10).toInt(),
                        child: Container(color: AppColors.primary),
                      ),
                      Expanded(
                        flex: (draw * 10).toInt(),
                        child: Container(
                            color: Colors.amber.withValues(alpha: 0.8)),
                      ),
                      Expanded(
                        flex: (p2Win * 10).toInt(),
                        child: Container(color: AppColors.cyan),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
