import re

new_content = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/api_client.dart';
import 'squad_verification_screen.dart';

/// Redesigned Esports Club Command Hub with 4 sub-views:
/// 1. Roster & 1v1 Challenge Launcher
/// 2. Top Club Leaderboard (with H2H comparison modals)
/// 3. Match Activity Feed
/// 4. Seasons Archive
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _clubNameCtrl   = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  bool _creating = false;
  String? _createResult;
  bool _createError = false;

  final _joinCodeCtrl = TextEditingController();
  bool _joining = false;
  String? _joinResult;
  bool _joinError = false;

  String? _selectedClubId;
  int _clubViewMode = 0; // 0 = Roster & Challenges, 1 = Leaderboard, 2 = Activity, 3 = Seasons

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clubNameCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (_clubNameCtrl.text.trim().isEmpty || _inviteCodeCtrl.text.trim().isEmpty) {
      setState(() { _createResult = 'Name & Invite Code required.'; _createError = true; });
      return;
    }
    setState(() { _creating = true; _createResult = null; });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.createClub(_clubNameCtrl.text.trim(), _inviteCodeCtrl.text.trim());
      setState(() {
        _createResult = '✅ Club Created! ID: ${res['club_id']}';
        _createError = false;
      });
      ref.invalidate(myClubsProvider);
    } catch (e) {
      setState(() { _createResult = 'Failed: $e'; _createError = true; });
    } finally {
      setState(() => _creating = false);
    }
  }

  Future<void> _joinClub() async {
    if (_joinCodeCtrl.text.trim().isEmpty) {
      setState(() { _joinResult = 'Invite code required.'; _joinError = true; });
      return;
    }
    setState(() { _joining = true; _joinResult = null; });
    try {
      final client = ref.read(apiClientProvider);
      await client.joinClub(_joinCodeCtrl.text.trim());
      setState(() {
        _joinResult = '✅ Successfully joined club!';
        _joinError = false;
      });
      ref.invalidate(myClubsProvider);
    } catch (e) {
      setState(() { _joinResult = 'Failed: $e'; _joinError = true; });
    } finally {
      setState(() => _joining = false);
    }
  }

  void _showRoleDialog(String clubId, String playerId, String currentRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        title: Text('CHANGE MEMBER ROLE', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['admin', 'organizer', 'player'].map((role) {
            final isCurrent = currentRole == role;
            return ListTile(
              leading: Icon(
                role == 'admin' ? Icons.star : (role == 'organizer' ? Icons.engineering : Icons.person),
                color: isCurrent ? AppColors.primary : Colors.white54,
              ),
              title: Text(
                role.toUpperCase(),
                style: GoogleFonts.rajdhani(
                  color: isCurrent ? AppColors.primary : Colors.white,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final client = ref.read(apiClientProvider);
                  await client.updateMemberRole(clubId, playerId, role);
                  ref.invalidate(clubMembersProvider(clubId));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update role: $e')),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'CLUB COMMAND & ROSTER',
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'MY CLUBS'),
            Tab(text: 'CREATE CLUB'),
            Tab(text: 'JOIN CLUB'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyClubsTab(clubsAsync),
          _buildCreateClubTab(),
          _buildJoinClubTab(),
        ],
      ),
    );
  }

  Widget _buildMyClubsTab(AsyncValue<Map<String, dynamic>> clubsAsync) {
    return clubsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => GlassCard(
        margin: const EdgeInsets.all(16),
        child: Text('Failed to load clubs: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final clubs = data['clubs'] as List<dynamic>? ?? [];

        if (clubs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'NO CLUBS JOINED YET',
                    style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a new club or join one with an invite code to command your squad.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          );
        }

        if (_selectedClubId == null && clubs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedClubId = clubs.first['id']);
          });
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(myClubsProvider);
            if (_selectedClubId != null) {
              ref.invalidate(clubMembersProvider(_selectedClubId!));
              ref.invalidate(leaderboardProvider(_selectedClubId!));
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal Club Selector Chips
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: clubs.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) {
                      final c = clubs[i];
                      final isSelected = c['id'] == _selectedClubId;
                      return ChoiceChip(
                        label: Text(c['name'] ?? 'Club'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedClubId = c['id']),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        selectedColor: AppColors.primary,
                        labelStyle: GoogleFonts.rajdhani(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // 4 Sub-Tabs: ROSTER, LEADERBOARD, ACTIVITY, SEASONS
                if (_selectedClubId != null) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildViewModeChip(0, 'ROSTER & 1v1', AppColors.cyan),
                        const SizedBox(width: 8),
                        _buildViewModeChip(1, 'LEADERBOARD', Colors.amber),
                        const SizedBox(width: 8),
                        _buildViewModeChip(2, 'ACTIVITY', AppColors.primary),
                        const SizedBox(width: 8),
                        _buildViewModeChip(3, 'SEASONS', AppColors.purple),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_clubViewMode == 0) ...[
                    // Challenge Online Commanders Component
                    _buildH2hChallengeWidget(),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SQUAD ROSTER & ROLES',
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                            letterSpacing: 1.5,
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.verified_user_outlined, size: 16),
                          label: Text('VERIFY SQUAD', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TournamentLobbyScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildMembersList(_selectedClubId!),
                  ] else if (_clubViewMode == 1) ...[
                    _buildLeaderboardTab(_selectedClubId!),
                  ] else if (_clubViewMode == 2) ...[
                    _buildActivityFeed(_selectedClubId!),
                  ] else if (_clubViewMode == 3) ...[
                    _buildSeasonsArchive(_selectedClubId!),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewModeChip(int index, String label, Color color) {
    final isSelected = _clubViewMode == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _clubViewMode = index),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      selectedColor: color,
      labelStyle: GoogleFonts.rajdhani(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildH2hChallengeWidget() {
    final rivals = [
      {'name': 'Commander David', 'elo': '1420', 'status': 'ONLINE'},
      {'name': 'Commander Chris', 'elo': '1380', 'status': 'IN LOBBY'},
      {'name': 'Commander Mark', 'elo': '1290', 'status': 'ONLINE'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHALLENGE ONLINE COMMANDERS',
          style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: rivals.length,
            itemBuilder: (context, idx) {
              final r = rivals[idx];
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.cyan.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              r['name']!,
                              style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GlowBadge(label: r['elo']!, color: AppColors.primary),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.5)),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 24),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Issued 1v1 H2H Challenge to ${r['name']}!')),
                            );
                          },
                          child: Text('CHALLENGE 1v1', style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTab(String clubId) {
    final leaderboardAsync = ref.watch(leaderboardProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CLUB ELO LEADERBOARD',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Colors.amber,
              ),
            ),
            Text(
              'Tap player for H2H',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        leaderboardAsync.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => Container(
                height: 54,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          error: (err, _) => GlassCard(
            child: Text(
              'Could not load leaderboard: ${ApiClient.formatErrorMessage(err)}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          data: (players) {
            if (players.isEmpty) {
              return const GlassCard(
                child: Center(
                  child: Text(
                    'No ranked players in this club yet.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              );
            }
            return Column(
              children: players.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final p = entry.value;
                final String pid = p['player_id']?.toString() ?? 'Player';
                final String displayId = pid.length > 8 ? pid.substring(0, 8) : pid;

                Color rankColor;
                if (rank == 1) {
                  rankColor = const Color(0xFFFFD700); // Gold
                } else if (rank == 2) {
                  rankColor = const Color(0xFFC0C0C0); // Silver
                } else if (rank == 3) {
                  rankColor = const Color(0xFFCD7F32); // Bronze
                } else {
                  rankColor = Colors.white70;
                }

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  borderColor: rank == 1 ? rankColor.withValues(alpha: 0.4) : null,
                  onTap: () {
                    _showPlayerH2hBottomSheet(displayId, p['skill_rating'] ?? 1000);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rank <= 3 ? rankColor.withValues(alpha: 0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: rankColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '#$rank',
                          style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: rankColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commander $displayId',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Matches: ${p['matches_played'] ?? 0}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      StatPill(
                        label: 'RATING',
                        value: '${p['skill_rating'] ?? 1000}',
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fade();
  }

  void _showPlayerH2hBottomSheet(String playerId, dynamic rating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderColor: AppColors.cyan,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                  child: Text(playerId[0].toUpperCase(), style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commander $playerId', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Rating: $rating ELO', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cyan,
                      side: const BorderSide(color: AppColors.cyan),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.compare_arrows, size: 16),
                    label: Text('H2H COMPARISON', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityFeed(String clubId) {
    final activityAsync = ref.watch(clubActivityProvider(clubId));
    return activityAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (data) {
        if (data.isEmpty) return const GlassCard(child: Text('No activity found.', style: TextStyle(color: AppColors.textMuted)));
        return Column(
          children: data.map((match) {
            final pName = match['player_name'] ?? 'Unknown';
            final oName = match['opponent_name'] ?? 'Unknown';
            final gf = match['goals_for'] ?? 0;
            final ga = match['goals_against'] ?? 0;
            final isWin = gf > ga;
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              borderColor: isWin ? AppColors.winGreen.withValues(alpha: 0.3) : AppColors.lossRed.withValues(alpha: 0.3),
              child: ListTile(
                title: Text('$pName vs $oName', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text('Score: $gf - $ga', style: const TextStyle(color: AppColors.textMuted)),
                trailing: Text(match['match_type']?.toString().toUpperCase() ?? 'MATCH', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSeasonsArchive(String clubId) {
    final seasonsAsync = ref.watch(clubSeasonsProvider(clubId));
    return seasonsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.purple))),
      error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
      data: (data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.archive, color: Colors.white),
              label: Text('END CURRENT SEASON (Admin)', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not implemented in UI yet.')));
              },
            ),
            const SizedBox(height: 16),
            if (data.isEmpty) const GlassCard(child: Text('No past seasons recorded.', style: TextStyle(color: AppColors.textMuted))),
            ...data.map((season) {
              final sName = season['name'] ?? 'Season';
              final start = season['start_date'] ?? '';
              final end = season['end_date'] ?? 'Ongoing';
              return GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(sName, style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: Text('$start to $end', style: const TextStyle(color: AppColors.textMuted)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildMembersList(String clubId) {
    final membersAsync = ref.watch(clubMembersProvider(clubId));

    return membersAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.primary))),
      error: (e, _) => GlassCard(
        child: Text('Failed to load roster: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        if (members.isEmpty) {
          return const GlassCard(
            child: Text('No members found in this club.', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        return Column(
          children: members.map((m) {
            final role = m['role'] ?? 'player';
            final username = m['username'] ?? 'Unknown Commander';
            final pid = m['user_id'] ?? '';
            final rating = m['skill_rating'] ?? 1000;

            Color roleColor;
            if (role == 'admin') roleColor = AppColors.primary;
            else if (role == 'organizer') roleColor = AppColors.purple;
            else roleColor = AppColors.cyan;

            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.15),
                    child: Icon(
                      role == 'admin' ? Icons.star : (role == 'organizer' ? Icons.engineering : Icons.person),
                      color: roleColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Rating: $rating • ${role.toUpperCase()}',
                          style: TextStyle(fontSize: 12, color: roleColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white54),
                    onPressed: () => _showRoleDialog(clubId, pid, role),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCreateClubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CREATE A NEW CLUB', style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: _clubNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Club Name',
              labelStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inviteCodeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Invite Code',
              labelStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: EsportsButton(
              label: _creating ? 'CREATING...' : 'CREATE CLUB',
              icon: Icons.add_shield,
              isLoading: _creating,
              onPressed: _creating ? () {} : _createClub,
            ),
          ),
          if (_createResult != null) ...[
            const SizedBox(height: 16),
            Text(_createResult!, style: TextStyle(color: _createError ? AppColors.lossRed : AppColors.winGreen, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinClubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JOIN AN EXISTING CLUB', style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: _joinCodeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Invite Code',
              labelStyle: const TextStyle(color: Colors.white54),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: EsportsButton(
              label: _joining ? 'JOINING...' : 'JOIN CLUB',
              icon: Icons.group_add,
              isLoading: _joining,
              gradient: const [AppColors.cyan, Color(0xFF00B0FF)],
              onPressed: _joining ? () {} : _joinClub,
            ),
          ),
          if (_joinResult != null) ...[
            const SizedBox(height: 16),
            Text(_joinResult!, style: TextStyle(color: _joinError ? AppColors.lossRed : AppColors.winGreen, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}
"""

with open('lib/presentation/screens/clubs_screen.dart', 'w') as f:
    f.write(new_content)
print('Redesigned ClubsScreen successfully!')
