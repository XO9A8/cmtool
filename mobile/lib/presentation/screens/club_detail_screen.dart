import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import 'player_profile_screen.dart';

/// Full per-club deep-dive screen.
/// Navigation param: clubId + clubName.
class ClubDetailScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;

  const ClubDetailScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  int _selectedIndex = 0;

  // ── label / icon maps for the nav bar ────────────────────────────────────
  static const _navLabels = ['OVERVIEW', 'ROSTER', 'LEADERBOARD', 'ACTIVITY', 'RESOLVED'];
  static const _navIcons = [
    Icons.dashboard_outlined,
    Icons.group_outlined,
    Icons.leaderboard_outlined,
    Icons.timeline_outlined,
    Icons.verified_outlined,
  ];
  static const _navIconsFilled = [
    Icons.dashboard,
    Icons.group,
    Icons.leaderboard,
    Icons.timeline,
    Icons.verified,
  ];

  Future<void> _refresh() async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.clearAllCache();

    ref.invalidate(clubMembersProvider(widget.clubId));
    ref.invalidate(leaderboardProvider(widget.clubId));
    ref.invalidate(clubActivityProvider(widget.clubId));
    ref.invalidate(clubResolvedActivityProvider(widget.clubId));
    ref.invalidate(clubSeasonsProvider(widget.clubId));
    ref.invalidate(myClubsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _refresh,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.cyan,
        child: const Icon(Icons.refresh, size: 20),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar()],
        body: Column(
          children: [
            // NavigationBar
            _buildNavBar(),
            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sliver App Bar
  // ─────────────────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.background,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Text(
          widget.clubName.toUpperCase(),
          style: GoogleFonts.rajdhani(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: _buildExpandedHeader(),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildExpandedHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A0A00), Color(0xFF0D0D1A), AppColors.background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Glow
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.07),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        // Content
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Shield hero
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFFFF9E00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield, color: Colors.black, size: 38),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF9E00)],
                        ).createShader(b),
                        child: Text(
                          widget.clubName.toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.15),
                      const SizedBox(height: 4),
                      const GlowBadge(label: 'CLUB', color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: List.generate(_navLabels.length, (i) {
            final selected = _selectedIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(
                duration: 200.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? _navIconsFilled[i] : _navIcons[i],
                      size: 16,
                      color: selected ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _navLabels[i],
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body dispatcher
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        _OverviewTab(clubId: widget.clubId),
        _RosterTab(clubId: widget.clubId),
        _LeaderboardTab(clubId: widget.clubId),
        _ActivityTab(clubId: widget.clubId),
        const SizedBox.shrink(),
        _ResolvedTab(clubId: widget.clubId),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  final String clubId;
  const _OverviewTab({required this.clubId});

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  final _editNameCtrl = TextEditingController();
  final _editCodeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _editNameCtrl.dispose();
    _editCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_editNameCtrl.text.trim().isEmpty || _editCodeCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).updateClub(
            widget.clubId,
            _editNameCtrl.text.trim(),
            _editCodeCtrl.text.trim(),
          );
      ref.invalidate(myClubsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Club updated!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.winGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.lossRed),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code copied!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));
    final leaderboardAsync = ref.watch(leaderboardProvider(widget.clubId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load: $e'),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        final inviteCode = data['invite_code']?.toString() ?? data['club']?['invite_code']?.toString() ?? '—';
        final createdAt = data['club']?['created_at']?.toString() ?? '—';

        // Derive user's role from member list
        final myId = ref.read(authStateProvider) ?? '';
        final me = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id']?.toString() == myId,
              orElse: () => null,
            );
        final myRole = me?['role']?.toString() ?? 'player';
        final isAdmin = myRole == 'admin';

        // Top player from leaderboard
        String topPlayer = '—';
        leaderboardAsync.whenData((lb) {
          if (lb.isNotEmpty) {
            topPlayer = lb.first['player_name'] ?? lb.first['username'] ?? '—';
          }
        });

        // Prefill edit fields once
        if (_editNameCtrl.text.isEmpty) {
          final clubName = data['club']?['name']?.toString() ?? '';
          if (clubName.isNotEmpty) _editNameCtrl.text = clubName;
        }
        if (_editCodeCtrl.text.isEmpty && inviteCode != '—') {
          _editCodeCtrl.text = inviteCode;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Stats Summary Card ─────────────────────────────────────
            GlassCard(
              borderColor: AppColors.primary.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('CLUB STATISTICS', AppColors.primary),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: StatPill(label: 'MEMBERS', value: '${members.length}', color: AppColors.cyan)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          label: 'TOP PLAYER',
                          value: topPlayer.length > 10 ? '${topPlayer.substring(0, 10)}…' : topPlayer,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: StatPill(label: 'CREATED', value: _formatDate(createdAt), color: AppColors.purple)),
                      const SizedBox(width: 10),
                      Expanded(child: StatPill(label: 'ROLE', value: myRole.toUpperCase(), color: _roleColor(myRole))),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.1),

            const SizedBox(height: 14),

            // ── Invite Code ────────────────────────────────────────────
            GlassCard(
              borderColor: AppColors.purple.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('INVITE CODE', AppColors.purple),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.vpn_key, color: AppColors.purple, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          inviteCode,
                          style: GoogleFonts.rajdhani(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.purple.withValues(alpha: 0.2),
                          foregroundColor: AppColors.purple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: AppColors.purple.withValues(alpha: 0.4)),
                          elevation: 0,
                        ),
                        onPressed: () => _copyCode(inviteCode),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text('COPY', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.1),

            // ── Edit Club (admin only) ─────────────────────────────────
            if (isAdmin) ...[
              const SizedBox(height: 14),
              GlassCard(
                borderColor: AppColors.cyan.withValues(alpha: 0.25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _sectionLabel('EDIT CLUB', AppColors.cyan),
                        const SizedBox(width: 8),
                        const GlowBadge(label: 'ADMIN ONLY', color: AppColors.primary, icon: Icons.star),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _input(_editNameCtrl, 'Club Name', Icons.shield),
                    const SizedBox(height: 10),
                    _input(_editCodeCtrl, 'New Invite Code', Icons.vpn_key),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: EsportsButton(
                        label: 'SAVE CHANGES',
                        icon: Icons.save,
                        isLoading: _saving,
                        onPressed: _saving ? null : _save,
                        gradient: const [AppColors.cyan, Color(0xFF00B0FF)],
                        textColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.1),
            ],

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — ROSTER
// ─────────────────────────────────────────────────────────────────────────────

class _RosterTab extends ConsumerStatefulWidget {
  final String clubId;
  const _RosterTab({required this.clubId});

  @override
  ConsumerState<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends ConsumerState<_RosterTab> {
  void _showInviteDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.purple.withValues(alpha: 0.4)),
        ),
        title: Text(
          'INVITE CODE',
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.vpn_key, color: AppColors.purple, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    code,
                    style: GoogleFonts.rajdhani(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: EsportsButton(
                label: 'COPY CODE',
                icon: Icons.copy,
                gradient: const [AppColors.purple, Color(0xFFD500F9)],
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invite code copied!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
        title: Text(
          'CHANGE ROLE',
          style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['admin', 'organizer', 'player'].map((role) {
            final isCurrent = currentRole == role;
            final rColor = _roleColor(role);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isCurrent ? rColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent ? rColor.withValues(alpha: 0.4) : Colors.white12,
                ),
              ),
              child: ListTile(
                leading: Icon(
                  role == 'admin' ? Icons.star : (role == 'organizer' ? Icons.engineering : Icons.person),
                  color: isCurrent ? rColor : Colors.white54,
                ),
                title: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: isCurrent ? rColor : Colors.white,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                trailing: isCurrent ? Icon(Icons.check_circle, color: rColor, size: 18) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(apiClientProvider).updateMemberRole(clubId, playerId, role);
                    ref.invalidate(clubMembersProvider(clubId));
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update role: $e'), backgroundColor: AppColors.lossRed),
                      );
                    }
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmRemove(String clubId, String playerId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.4)),
        ),
        title: Text(
          'REMOVE MEMBER',
          style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove $username from the club? This action cannot be undone.',
          style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).removeMember(clubId, playerId);
                ref.invalidate(clubMembersProvider(clubId));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text('REMOVE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load roster: $e'),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        final inviteCode = data['invite_code']?.toString() ??
            data['club']?['invite_code']?.toString() ??
            '—';

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                children: [
                  Row(
                    children: [
                      _sectionLabel('SQUAD ROSTER', AppColors.cyan),
                      const Spacer(),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.purple,
                          side: BorderSide(color: AppColors.purple.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.link, size: 16),
                        label: Text('INVITE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () => _showInviteDialog(inviteCode),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (members.isEmpty)
                    GlassCard(
                      child: Center(
                        child: Text(
                          'No members in this club.',
                          style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
                        ),
                      ),
                    ),
                ],
              ),
              ),
            ),
            if (members.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final m = members[index] as Map<String, dynamic>;
                    final role = m['role']?.toString() ?? 'player';
                    final username = m['username']?.toString() ?? 'Player';
                    final pid = m['user_id']?.toString() ?? '';
                    final rating = m['skill_rating'] ?? 0;
                    final wins = m['wins'] ?? 0;
                    final losses = m['losses'] ?? 0;
                    final rColor = _roleColor(role);

                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      borderColor: rColor.withValues(alpha: 0.15),
                      onTap: () {
                        if (pid.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerProfileScreen(playerId: pid),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: getAvatarById(m['avatar_graphic']?.toString()).gradient.first.withValues(alpha: 0.2),
                            child: Icon(
                              getAvatarById(m['avatar_graphic']?.toString()).icon,
                              color: getAvatarById(m['avatar_graphic']?.toString()).gradient.first,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  username,
                                  style: GoogleFonts.rajdhani(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    GlowBadge(label: role.toUpperCase(), color: rColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'W:$wins / L:$losses',
                                      style: GoogleFonts.rajdhani(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // ELO badge
                          GlowBadge(label: '$rating ELO', color: AppColors.primary),
                          const SizedBox(width: 4),
                          // Options menu
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.white12),
                            ),
                            onSelected: (val) {
                              if (val == 'profile') {
                                if (pid.isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerProfileScreen(playerId: pid),
                                    ),
                                  );
                                }
                              } else if (val == 'role') {
                                _showRoleDialog(widget.clubId, pid, role);
                              } else if (val == 'remove') {
                                _confirmRemove(widget.clubId, pid, username);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, color: AppColors.cyan, size: 16),
                                    const SizedBox(width: 8),
                                    Text('View Profile', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'role',
                                child: Row(
                                  children: [
                                    const Icon(Icons.manage_accounts, color: AppColors.cyan, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Change Role', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Row(
                                  children: [
                                    const Icon(Icons.person_remove, color: AppColors.lossRed, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Remove Member', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                        .animate(delay: Duration(milliseconds: (index % 10) * 55))
                        .fadeIn(duration: 350.ms)
                        .slideY(begin: 0.12);
                  },
                  childCount: members.length,
                ),
              ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final String clubId;
  const _LeaderboardTab({required this.clubId});

  static const _gold = Color(0xFFFFD700);
  static const _silver = Color(0xFFC0C0C0);
  static const _bronze = Color(0xFFCD7F32);

  Color _rankColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return Colors.white70;
  }

  void _showPlayerSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> player) {
    final name = player['player_name'] ?? player['username'] ?? 'Player';
    final rating = player['skill_rating'] ?? 0;
    final pid = player['player_id']?.toString() ?? '';
    final wins = player['wins'] ?? 0;
    final losses = player['losses'] ?? 0;
    final total = (wins + losses) as int;
    final winRate = total > 0 ? (wins / total * 100) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Player header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: getAvatarById(player['avatar_graphic']?.toString()).gradient.first.withValues(alpha: 0.2),
                      child: Icon(
                        getAvatarById(player['avatar_graphic']?.toString()).icon,
                        size: 28,
                        color: getAvatarById(player['avatar_graphic']?.toString()).gradient.first,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$rating ELO • W:$wins / L:$losses',
                            style: GoogleFonts.rajdhani(color: AppColors.cyan, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Win rate bar
                Text(
                  'WIN RATE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: winRate / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      winRate >= 50 ? AppColors.winGreen : AppColors.lossRed,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${winRate.toStringAsFixed(1)}%',
                    style: GoogleFonts.rajdhani(
                      color: winRate >= 50 ? AppColors.winGreen : AppColors.lossRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cyan,
                          side: const BorderSide(color: AppColors.cyan),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.compare_arrows, size: 16),
                        label: Text('H2H', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EsportsButton(
                        label: 'PROFILE',
                        icon: Icons.person,
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (pid.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerProfileScreen(playerId: pid),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider(clubId));

    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
      error: (e, _) => _errorCard('Failed to load leaderboard: $e'),
      data: (players) {
        if (players.isEmpty) {
          return Center(
            child: Text(
              'No ranked players yet.',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('ELO LEADERBOARD', Colors.amber),
            const SizedBox(height: 4),
            Text(
              'Tap any player for details & H2H',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Top 3 podium
            if (players.length >= 3)
              _buildPodium(context, ref, players)
            else
              const SizedBox.shrink(),

            if (players.length >= 3) const SizedBox(height: 16),

            // Full ranked list
            ...players.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final p = entry.value as Map<String, dynamic>;
              final name = p['player_name'] ?? p['username'] ?? 'Player';
              final rating = p['skill_rating'] ?? 0;
              final wins = p['wins'] ?? 0;
              final losses = p['losses'] ?? 0;
              final total = (wins + losses) as int;
              final winRate = total > 0 ? (wins / total * 100) : 0.0;
              final rColor = _rankColor(rank);

              // Skip top 3 if we rendered podium
              if (players.length >= 3 && rank <= 3) return const SizedBox.shrink();

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => _showPlayerSheet(context, ref, p),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rColor.withValues(alpha: 0.1),
                        border: Border.all(color: rColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13, color: rColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: winRate / 100,
                              minHeight: 4,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                winRate >= 50 ? AppColors.winGreen : AppColors.lossRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatPill(label: 'ELO', value: '$rating', color: AppColors.primary),
                  ],
                ),
              ).animate(delay: Duration(milliseconds: rank * 50)).fadeIn().slideY(begin: 0.1);
            }),

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildPodium(BuildContext context, WidgetRef ref, List<dynamic> players) {
    final top3 = players.take(3).toList();
    final p1 = top3[0] as Map<String, dynamic>;
    final p2 = top3[1] as Map<String, dynamic>;
    final p3 = top3[2] as Map<String, dynamic>;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd
        Expanded(
          child: _podiumCard(context, ref, p2, 2, 80),
        ),
        const SizedBox(width: 8),
        // 1st
        Expanded(
          child: _podiumCard(context, ref, p1, 1, 110),
        ),
        const SizedBox(width: 8),
        // 3rd
        Expanded(
          child: _podiumCard(context, ref, p3, 3, 65),
        ),
      ],
    );
  }

  Widget _podiumCard(BuildContext context, WidgetRef ref, Map<String, dynamic> p, int rank, double height) {
    final name = p['player_name'] ?? p['username'] ?? 'Player';
    final rating = p['skill_rating'] ?? 0;
    final rColor = _rankColor(rank);
    final medalIcon = rank == 1 ? '🥇' : (rank == 2 ? '🥈' : '🥉');

    return GestureDetector(
      onTap: () => _showPlayerSheet(context, ref, p),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [rColor.withValues(alpha: 0.15), rColor.withValues(alpha: 0.04)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: rColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: rColor.withValues(alpha: rank == 1 ? 0.25 : 0.1),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(medalIcon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(
                name.length > 8 ? '${name.substring(0, 8)}…' : name,
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
              Text(
                '$rating',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: rColor,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: rank * 80)).slideY(begin: 0.15),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  final String clubId;
  const _ActivityTab({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(clubActivityProvider(clubId));

    return activityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load activity: $e'),
      data: (matches) {
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timeline, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No match activity yet.', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16)),
              ],
            ),
          );
        }

        // Group by date
        final Map<String, List<dynamic>> grouped = {};
        for (final m in matches) {
          final raw = m['played_at'] ?? m['created_at'] ?? '';
          final dateKey = raw.toString().length >= 10 ? raw.toString().substring(0, 10) : 'Unknown';
          grouped.putIfAbsent(dateKey, () => []).add(m);
        }

        final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('MATCH ACTIVITY', AppColors.primary),
            const SizedBox(height: 12),
            for (final date in sortedDates) ...[
              // Date separator
              Container(
                margin: const EdgeInsets.only(bottom: 10, top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _formatDate(date),
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...grouped[date]!.asMap().entries.map((entry) {
                final idx = entry.key;
                final match = entry.value as Map<String, dynamic>;
                final pName = match['player_name'] ?? 'Unknown';
                final oName = match['opponent_name'] ?? 'Unknown';
                final gf = (match['goals_for'] ?? match['score_for'] ?? 0) as int;
                final ga = (match['goals_against'] ?? match['score_against'] ?? 0) as int;
                final isWin = gf > ga;
                final isDraw = gf == ga;
                final matchType = match['match_type']?.toString() ?? 'MATCH';

                final resultColor = isWin
                    ? AppColors.winGreen
                    : isDraw
                        ? Colors.amber
                        : AppColors.lossRed;
                final resultLabel = isWin ? 'WIN' : (isDraw ? 'DRAW' : 'LOSS');

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  borderColor: resultColor.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      // Result color stripe
                      Container(
                        width: 4,
                        height: 56,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: resultColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: resultColor.withValues(alpha: 0.4), blurRadius: 6),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pName vs $oName',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  '$gf – $ga',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: resultColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlowBadge(label: matchType.toUpperCase(), color: AppColors.cyan),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GlowBadge(label: resultLabel, color: resultColor),
                    ],
                  ),
                )
                    .animate(delay: Duration(milliseconds: idx * 45))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.06);
              }),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — SEASONS
// ─────────────────────────────────────────────────────────────────────────────

class _SeasonsTab extends ConsumerStatefulWidget {
  final String clubId;
  const _SeasonsTab({required this.clubId});

  @override
  ConsumerState<_SeasonsTab> createState() => _SeasonsTabState();
}

class _SeasonsTabState extends ConsumerState<_SeasonsTab> {
  Future<void> _endSeason(String seasonId) async {
    setState(() => _endingScene = true);
    try {
      await ref.read(apiClientProvider).snapshotSeason(seasonId);
      ref.invalidate(clubSeasonsProvider(widget.clubId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Season ended & archived!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.winGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.lossRed),
        );
      }
    } finally {
      if (mounted) setState(() => _endingScene = false);
    }
  }

  // ignore: non_constant_identifier_names -- keeps local flag readable
  bool _endingScene = false;

  @override
  Widget build(BuildContext context) {
    final seasonsAsync = ref.watch(clubSeasonsProvider(widget.clubId));
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));

    // Determine if current user is admin
    final myId = ref.watch(authStateProvider) ?? '';
    bool isAdmin = false;
    membersAsync.whenData((data) {
      final members = data['members'] as List<dynamic>? ?? [];
      final me = members.cast<Map<String, dynamic>?>().firstWhere(
            (m) => m?['user_id']?.toString() == myId,
            orElse: () => null,
          );
      if (me?['role'] == 'admin') isAdmin = true;
    });

    return seasonsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.purple)),
      error: (e, _) => _errorCard('Failed to load seasons: $e'),
      data: (seasons) {
        // Find active season
        final activeSeasons = seasons.where((s) => s['is_active'] == true || s['end_date'] == null).toList();
        final activeSeason = activeSeasons.isNotEmpty ? activeSeasons.first : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _sectionLabel('SEASONS ARCHIVE', AppColors.purple),
                const Spacer(),
                if (isAdmin && activeSeason != null)
                  AnimatedContainer(
                    duration: 600.ms,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.lossRed.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lossRed.withValues(alpha: 0.15),
                        foregroundColor: AppColors.lossRed,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: _endingScene
                          ? null
                          : () => _endSeason(activeSeason['id']?.toString() ?? ''),
                      icon: _endingScene
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lossRed),
                            )
                          : const Icon(Icons.archive, size: 16),
                      label: Text(
                        'END SEASON',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (seasons.isEmpty)
              GlassCard(
                child: Center(
                  child: Text(
                    'No seasons recorded yet.',
                    style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
                  ),
                ),
              )
            else
              ...seasons.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value as Map<String, dynamic>;
                final sName = s['name']?.toString() ?? 'Season ${i + 1}';
                final startDate = _formatDate(s['start_date']?.toString() ?? '—');
                final endDate = s['end_date'] != null ? _formatDate(s['end_date'].toString()) : 'Ongoing';
                final champion = s['champion_name'] ?? s['champion'] ?? '—';
                final isActive = s['is_active'] == true || s['end_date'] == null;

                return _SeasonCard(
                  name: sName,
                  startDate: startDate,
                  endDate: endDate,
                  champion: champion.toString(),
                  isActive: isActive,
                  index: i,
                );
              }),

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final String name;
  final String startDate;
  final String endDate;
  final String champion;
  final bool isActive;
  final int index;

  const _SeasonCard({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.champion,
    required this.isActive,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: isActive ? AppColors.cyan.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
      gradientColors: isActive
          ? [AppColors.cyan.withValues(alpha: 0.07), AppColors.purple.withValues(alpha: 0.04)]
          : null,
      child: Row(
        children: [
          // Season icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isActive ? AppColors.cyan.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isActive ? AppColors.cyan.withValues(alpha: 0.4) : Colors.white12,
              ),
            ),
            child: Icon(
              isActive ? Icons.bolt : Icons.workspace_premium,
              color: isActive ? AppColors.cyan : AppColors.textMuted,
              size: 24,
            ),
          )
              .animate(
                onPlay: isActive ? (c) => c.repeat(reverse: true) : null,
              )
              .then()
              .shimmer(
                duration: isActive ? 1200.ms : Duration.zero,
                color: AppColors.cyan.withValues(alpha: 0.3),
              ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.rajdhani(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (isActive)
                      const GlowBadge(label: 'ACTIVE', color: AppColors.cyan)
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(duration: 800.ms),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$startDate → $endDate',
                  style: GoogleFonts.rajdhani(fontSize: 12, color: AppColors.textMuted),
                ),
                if (champion != '—') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Champion: $champion',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ).animate(delay: Duration(milliseconds: index * 70)).fadeIn().slideY(begin: 0.1);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _roleColor(String role) {
  if (role == 'admin') return AppColors.primary;
  if (role == 'organizer') return AppColors.purple;
  return AppColors.cyan;
}

Widget _sectionLabel(String label, Color color) {
  return Text(
    label,
    style: GoogleFonts.rajdhani(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
      color: color,
    ),
  );
}

Widget _errorCard(String msg) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        borderColor: AppColors.lossRed.withValues(alpha: 0.4),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.lossRed),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: const TextStyle(color: AppColors.lossRed))),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(String raw) {
  if (raw.isEmpty || raw == '—') return raw;
  try {
    final dt = DateTime.parse(raw);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resolved Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ResolvedTab extends ConsumerWidget {
  final String clubId;
  const _ResolvedTab({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedAsync = ref.watch(clubResolvedActivityProvider(clubId));

    return resolvedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load resolved activity: $e'),
      data: (activity) {
        if (activity.isEmpty) {
          return Center(
            child: Text(
              'No resolved matches yet.',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activity.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _sectionLabel('RESOLVED MATCHES', AppColors.winGreen),
              );
            }
            final match = activity[index - 1] as Map<String, dynamic>;
            final matchType = match['match_type']?.toString().toUpperCase() ?? 'FRIENDLY';
            final pName = match['player_name'] ?? 'Player 1';
            final oName = match['opponent_name'] ?? 'Player 2';
            final gf = match['goals_for']?.toString() ?? '0';
            final ga = match['goals_against']?.toString() ?? '0';
            final date = _formatDate(match['created_at']?.toString() ?? '');
            final verifier = match['verifier_username'] ?? 'Unknown Admin';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                borderColor: Colors.white10,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GlowBadge(
                          label: matchType,
                          color: AppColors.cyan,
                          icon: Icons.sports_soccer,
                        ),
                        Text(date, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            pName,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$gf - $ga',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            oName,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.verified, color: AppColors.winGreen, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Verified by $verifier',
                          style: const TextStyle(color: AppColors.winGreen, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
