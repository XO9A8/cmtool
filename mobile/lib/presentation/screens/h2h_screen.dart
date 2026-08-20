import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import 'player_profile_screen.dart';
import '../widgets/h2h/player_picker_bottom_sheet.dart';
import '../widgets/h2h/hero_arena.dart';
import '../widgets/h2h/h2h_result_widget.dart';

/// Head-to-Head Rivalry Tracker — redesigned with Graphify charts.
class H2hScreen extends ConsumerStatefulWidget {
  const H2hScreen({super.key});

  @override
  ConsumerState<H2hScreen> createState() => _H2hScreenState();
}

class _H2hScreenState extends ConsumerState<H2hScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedClubId;
  String? _p1Id;
  String? _p2Id;
  String _selectedScope = 'overall';
  int? _selectedMatchLimit = 10;
  H2hParams? _currentParams;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── State helpers ──────────────────────────────────────────────────────────

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
      _currentParams = autoSearch
          ? H2hParams(
              p1Id: p1,
              p2Id: p2,
              limit: _selectedMatchLimit,
              scope: _selectedScope,
            )
          : null;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);
    final currentUserId = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: clubsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: GlassCard(
            margin: const EdgeInsets.all(24),
            child: Text('Error loading clubs: $e',
                style: const TextStyle(color: Colors.redAccent)),
          ),
        ),
        data: (data) {
          final clubs = data['clubs'] as List<dynamic>? ?? [];

          if (clubs.isEmpty) {
            return _buildEmptyState();
          }

          if (_selectedClubId == null && clubs.isNotEmpty) {
            _selectedClubId = clubs.first['id']?.toString();
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── STICKY HEADER ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildHeader(),
                ),
              ),

              // ── CLUB SELECTOR ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _buildClubSelector(clubs),
                ),
              ),

              // ── ARENA ─────────────────────────────────────────────────────
              if (_selectedClubId != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildClubArena(
                        context, _selectedClubId!, currentUserId),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.cyan],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ARENA',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'RIVALRY HUB',
                      style: GoogleFonts.rajdhani(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Head-to-Head Matrix & Tactical Clash Analytics',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (_currentParams != null) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _clearSelection,
            icon: const Icon(Icons.refresh, size: 13, color: AppColors.cyan),
            label: Text(
              'RESET',
              style: GoogleFonts.rajdhani(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
                letterSpacing: 1.1,
              ),
            ),
            style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ],
    ).animate().fade(duration: 400.ms).slideY(begin: -0.1);
  }

  // ── CLUB SELECTOR ──────────────────────────────────────────────────────────

  Widget _buildClubSelector(List<dynamic> clubs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined,
                size: 13, color: AppColors.cyan),
            const SizedBox(width: 5),
            Text(
              'ACTIVE CLUB',
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                color: AppColors.textMuted,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: clubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final club = clubs[i];
              final isSelected = club['id'] == _selectedClubId;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: FilterChip(
                  avatar: Icon(
                    Icons.groups,
                    size: 14,
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
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.black,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  labelStyle: GoogleFonts.rajdhani(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── CLUB ARENA ─────────────────────────────────────────────────────────────

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
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.group_add_outlined,
                    color: AppColors.textMuted, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'At least 2 club members are required to compare head-to-head stats.',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        final p1Member = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id'] == _p1Id,
              orElse: () => null,
            );
        final p2Member = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id'] == _p2Id,
              orElse: () => null,
            );

        final isReadyToDuel =
            _p1Id != null && _p2Id != null && _p1Id != _p2Id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Arena face-off card
            HeroArena(
              members: members,
              p1Member: p1Member,
              p2Member: p2Member,
              p1Id: _p1Id,
              p2Id: _p2Id,
              isReadyToDuel: isReadyToDuel,
              isAnalyzing: _currentParams != null,
              onRandomDuel: () => _selectRandomDuel(members),
              onPickPlayer1: () =>
                  _showPlayerPickerModal(context, members, isPlayer1: true),
              onPickPlayer2: () =>
                  _showPlayerPickerModal(context, members, isPlayer1: false),
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
            const SizedBox(height: 12),

            // Filter bar (scope + sample size)
            _buildFilterBar(),
            const SizedBox(height: 16),

            // Results or Discovery
            if (_currentParams != null) ...[
              H2hResultWidget(
                params: _currentParams!,
                p1Fallback: p1Member,
                p2Fallback: p2Member,
                onScopeChanged: _setScope,
                onLimitChanged: _setLimit,
              ),
            ] else ...[
              _buildDiscovery(
                  members: members, currentUserId: currentUserId),
            ],
          ],
        );
      },
    );
  }

  // ── FILTER BAR ─────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scope toggle
            Container(
              height: 30,
              width: 164,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: [
                  Expanded(child: _buildScopeBtn('All', 'overall')),
                  Expanded(child: _buildScopeBtn('Direct', 'direct')),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(width: 1, height: 18, color: Colors.white12),
            const SizedBox(width: 8),
            // Sample size chips
            _buildLimitChip('L5', 5),
            const SizedBox(width: 4),
            _buildLimitChip('L10', 10),
            const SizedBox(width: 4),
            _buildLimitChip('L20', 20),
            const SizedBox(width: 4),
            _buildLimitChip('All', null),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeBtn(String label, String scopeVal) {
    final isSelected = _selectedScope == scopeVal;
    return GestureDetector(
      onTap: () => _setScope(scopeVal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.cyan.withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.cyan : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLimitChip(String label, int? limitVal) {
    final isSelected = _selectedMatchLimit == limitVal;
    return GestureDetector(
      onTap: () => _setLimit(limitVal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white10,
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

  // ── DISCOVERY STATE ────────────────────────────────────────────────────────

  Widget _buildDiscovery({
    required List<dynamic> members,
    required String? currentUserId,
  }) {
    final sortedMembers = List<dynamic>.from(members)
      ..sort((a, b) {
        final rA = (a['skill_rating'] as num?)?.toInt() ?? 1000;
        final rB = (b['skill_rating'] as num?)?.toInt() ?? 1000;
        return rB.compareTo(rA);
      });

    final currentUserMember = members.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['user_id'] == currentUserId,
          orElse: () => null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── My Rivalry Card ───────────────────────────────────────────────
        if (currentUserMember != null && _p1Id != currentUserId) ...[
          _buildMyRivalryCard(currentUserMember),
          const SizedBox(height: 16),
        ],

        // ── Hot Matchups ──────────────────────────────────────────────────
        _buildSectionHeader(
          icon: Icons.local_fire_department,
          color: AppColors.primary,
          title: 'HOT MATCHUPS',
          subtitle: '1-tap duel',
        ),
        const SizedBox(height: 10),
        _buildHotMatchups(sortedMembers),
        const SizedBox(height: 20),

        // ── Contender Roster ──────────────────────────────────────────────
        _buildSectionHeader(
          icon: Icons.sports_esports,
          color: AppColors.cyan,
          title: 'CLUB CONTENDERS (${members.length})',
          subtitle: 'Pick to slot',
        ),
        const SizedBox(height: 10),
        _buildContenderRoster(sortedMembers),
        const SizedBox(height: 20),

        // ── Feature Highlights ────────────────────────────────────────────
        _buildFeatureHighlights(),
      ],
    ).animate().fade(duration: 350.ms).slideY(begin: 0.06);
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Text(
          subtitle,
          style: GoogleFonts.rajdhani(
              fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildMyRivalryCard(Map<String, dynamic> userMember) {
    final username = userMember['username']?.toString() ?? 'You';
    final elo = (userMember['skill_rating'] as num?)?.toInt() ?? 1000;
    final avatarId = userMember['avatar_graphic']?.toString();

    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Icon(getAvatarById(avatarId).icon,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR RIVALRY DOSSIER',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '$username · $elo Elo',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'SET P1',
              style: GoogleFonts.rajdhani(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotMatchups(List<dynamic> sortedMembers) {
    if (sortedMembers.length < 2) return const SizedBox.shrink();

    final pairs = <Map<String, dynamic>>[];
    pairs.add({
      'title': 'TITAN CLASH',
      'label': '#1 vs #2',
      'p1': sortedMembers[0],
      'p2': sortedMembers[1],
      'color': AppColors.primary,
    });
    if (sortedMembers.length >= 3) {
      pairs.add({
        'title': 'PODIUM SHOWDOWN',
        'label': '#1 vs #3',
        'p1': sortedMembers[0],
        'p2': sortedMembers[2],
        'color': AppColors.offWhite,
      });
    }
    if (sortedMembers.length >= 4) {
      pairs.add({
        'title': 'MID-TABLE RIVALRY',
        'label': '#3 vs #4',
        'p1': sortedMembers[2],
        'p2': sortedMembers[3],
        'color': AppColors.cyan,
      });
    }

    return Column(
      children: pairs.asMap().entries.map((entry) {
        final i = entry.key;
        final pair = entry.value;
        final p1 = pair['p1'] as Map<String, dynamic>;
        final p2 = pair['p2'] as Map<String, dynamic>;
        final p1Name = p1['username']?.toString() ?? 'Player 1';
        final p2Name = p2['username']?.toString() ?? 'Player 2';
        final p1Elo = (p1['skill_rating'] as num?)?.toInt() ?? 1000;
        final p2Elo = (p2['skill_rating'] as num?)?.toInt() ?? 1000;
        final title = pair['title'] as String;
        final label = pair['label'] as String;
        final color = pair['color'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Left: title + players
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.rajdhani(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.rajdhani(
                              fontSize: 9,
                              color: color.withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$p1Name  vs  $p2Name',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$p1Elo  vs  $p2Elo ELO',
                      style: GoogleFonts.orbitron(
                          fontSize: 9, color: Colors.white54),
                    ),
                  ],
                ),
              ),

              // Duel button
              ElevatedButton(
                onPressed: () => _setMatchup(
                  p1['user_id'].toString(),
                  p2['user_id'].toString(),
                  autoSearch: true,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  elevation: 0,
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'DUEL',
                  style: GoogleFonts.rajdhani(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ).animate(delay: (60 * i).ms).fade().slideX(begin: 0.05);
      }).toList(),
    );
  }

  Widget _buildContenderRoster(List<dynamic> sortedMembers) {
    return SizedBox(
      height: 118,
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

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 102,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isP1 || isP2
                  ? (isP1 ? AppColors.primary : AppColors.cyan)
                      .withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: borderColor, width: isP1 || isP2 ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: (isP1
                          ? AppColors.primary
                          : isP2
                              ? AppColors.cyan
                              : Colors.white12)
                      .withValues(alpha: 0.2),
                  child: Icon(
                    getAvatarById(avatarId).icon,
                    size: 16,
                    color: isP1
                        ? AppColors.primary
                        : isP2
                            ? AppColors.cyan
                            : Colors.white70,
                  ),
                ),
                Text(
                  username,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$elo',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSlotBtn(
                      label: 'P1',
                      active: isP1,
                      color: AppColors.primary,
                      onTap: () {
                        setState(() {
                          _p1Id = id;
                          if (_p2Id == id) _p2Id = null;
                          _currentParams = null;
                        });
                      },
                    ),
                    const SizedBox(width: 4),
                    _buildSlotBtn(
                      label: 'P2',
                      active: isP2,
                      color: AppColors.cyan,
                      onTap: () {
                        setState(() {
                          _p2Id = id;
                          if (_p1Id == id) _p1Id = null;
                          _currentParams = null;
                        });
                      },
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

  Widget _buildSlotBtn({
    required String label,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: active ? color : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureHighlights() {
    final features = [
      (
        Icons.analytics_outlined,
        'All-Time Record',
        'Wins, draws, goal differentials.',
        AppColors.primary
      ),
      (
        Icons.radar,
        '5-Axis Radar',
        'Possession, pass, shot, def & form.',
        AppColors.cyan
      ),
      (
        Icons.psychology_outlined,
        'AI Win Odds',
        'Bayesian outcome predictions.',
        AppColors.offWhite
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RIVALRY INTELLIGENCE SUITE',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.4,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: features.asMap().entries.map((e) {
            final (icon, title, desc, color) = e.value;
            return Expanded(
              child: Container(
                margin:
                    EdgeInsets.only(left: e.key > 0 ? 6 : 0),
                padding: const EdgeInsets.all(10),
                height: 105,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                          height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined,
                color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              'NO CLUBS YET',
              style: GoogleFonts.orbitron(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join or create a club to start tracking head-to-head rivalries.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
