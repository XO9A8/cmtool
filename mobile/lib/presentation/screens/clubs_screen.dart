import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import 'club_detail_screen.dart';

/// Club Hub landing page — lists the user's clubs as rich cards,
/// supports search, and exposes a FAB for creating / joining clubs.
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FAB bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _openAddClubSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddClubSheet(
        onDone: () => ref.invalidate(myClubsProvider),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddClubSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        elevation: 8,
        child: const Icon(Icons.add, size: 28),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async => ref.invalidate(myClubsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero Header ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeroHeader()),

            // ── Search Bar ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildSearchBar(),
              ),
            ),

            // ── Section label ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Icon(Icons.shield, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'MY CLUBS',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Club List ────────────────────────────────────────────────
            _buildClubList(clubsAsync),

            // Bottom padding for FAB clearance
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hero Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeroHeader() {
    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A0A00), const Color(0xFF0D0D1A), AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Neon glow circle
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.offWhite.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.offWhite.withValues(alpha: 0.08),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shield icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [AppColors.primary, const Color(0xFFFF9E00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield, color: Colors.black, size: 34),
                  )
                      .animate()
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(width: 18),
                  // Title block
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (b) => LinearGradient(
                            colors: [AppColors.primary, const Color(0xFFFF9E00)],
                          ).createShader(b),
                          child: Text(
                            'CLUB HUB',
                            style: GoogleFonts.rajdhani(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              color: Colors.white,
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 500.ms)
                            .slideX(begin: -0.2, duration: 400.ms),
                        Text(
                          'MANAGE YOUR SQUADS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.5,
                            color: AppColors.textMuted,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 150.ms, duration: 400.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Search Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search clubs...',
              hintStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
              prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Club List
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildClubList(AsyncValue<Map<String, dynamic>> clubsAsync) {
    return clubsAsync.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _shimmerCard(i),
          childCount: 3,
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: GlassCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          borderColor: AppColors.lossRed.withValues(alpha: 0.4),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: AppColors.lossRed),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to load clubs: $e',
                  style: GoogleFonts.rajdhani(color: AppColors.lossRed),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final allClubs = data['clubs'] as List<dynamic>? ?? [];
        final clubs = _searchQuery.isEmpty
            ? allClubs
            : allClubs.where((c) {
                final name = (c['name'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery);
              }).toList();

        if (allClubs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          );
        }

        if (clubs.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No clubs match "$_searchQuery"',
                    style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final club = clubs[i];
              return _ClubCard(
                club: club,
                index: i,
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => ClubDetailScreen(
                      clubId: club['id']?.toString() ?? '',
                      clubName: club['name']?.toString() ?? 'Club',
                    ),
                  ),
                ).then((_) => ref.invalidate(myClubsProvider)),
              );
            },
            childCount: clubs.length,
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Empty State
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 80, color: AppColors.textMuted)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.08, duration: 1600.ms, curve: Curves.easeInOut),
            const SizedBox(height: 24),
            Text(
              'NO CLUBS YET',
              style: GoogleFonts.rajdhani(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Colors.white,
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 10),
            Text(
              'Create a new club or join one with\nan invite code to command your squad.',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(
                fontSize: 15,
                color: AppColors.textMuted,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),
            EsportsButton(
              label: 'CREATE OR JOIN',
              icon: Icons.add,
              onPressed: _openAddClubSheet,
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shimmer placeholder
  // ─────────────────────────────────────────────────────────────────────────

  Widget _shimmerCard(int i) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
      ),
    ).animate(delay: Duration(milliseconds: i * 80)).fadeIn().shimmer(
          duration: 900.ms,
          color: Colors.white.withValues(alpha: 0.04),
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Club Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ClubCard extends StatelessWidget {
  final Map<String, dynamic> club;
  final int index;
  final VoidCallback onTap;

  const _ClubCard({
    required this.club,
    required this.index,
    required this.onTap,
  });

  Color get _roleColor {
    final role = (club['user_role'] ?? club['role'] ?? 'player').toString().toLowerCase();
    if (role == 'admin') return AppColors.primary;
    if (role == 'organizer') return AppColors.offWhite;
    return AppColors.cyan;
  }

  String get _roleLabel {
    return (club['user_role'] ?? club['role'] ?? 'PLAYER').toString().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = club['name']?.toString() ?? 'Club';
    final memberCount = club['member_count'] ?? club['members_count'] ?? 0;
    final wins = club['activity_count'] ?? club['wins'] ?? 0;
    final inviteCode = club['invite_code']?.toString() ?? '—';

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(18),
      borderColor: _roleColor.withValues(alpha: 0.2),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: name + role badge ────────────────────────────────
          Row(
            children: [
              // Shield icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _roleColor.withValues(alpha: 0.12),
                  border: Border.all(color: _roleColor.withValues(alpha: 0.3)),
                ),
                child: Icon(Icons.shield, color: _roleColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    GlowBadge(label: _roleLabel, color: _roleColor),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),

          // ── Stats row ─────────────────────────────────────────────────
          Row(
            children: [
              _StatChip(
                icon: Icons.group,
                label: '$memberCount',
                sublabel: 'MEMBERS',
                color: AppColors.cyan,
              ),
              const SizedBox(width: 10),
              _StatChip(
                icon: Icons.emoji_events,
                label: '$wins',
                sublabel: 'WINS',
                color: AppColors.winGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InviteCodeChip(code: inviteCode),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 60 + index * 70))
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.18, duration: 350.ms, curve: Curves.easeOut);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.rajdhani(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteCodeChip extends StatelessWidget {
  final String code;

  const _InviteCodeChip({required this.code});

  void _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Invite code copied!',
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.offWhite.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.offWhite.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key, size: 13, color: AppColors.offWhite),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              code,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.offWhite,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _copy(context),
            child: Icon(Icons.copy, size: 14, color: AppColors.offWhite),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Club Bottom Sheet  (Create + Join tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _AddClubSheet extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const _AddClubSheet({required this.onDone});

  @override
  ConsumerState<_AddClubSheet> createState() => _AddClubSheetState();
}

class _AddClubSheetState extends ConsumerState<_AddClubSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tc;

  // Create
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _creating = false;
  String? _createMsg;
  bool _createErr = false;

  // Join
  final _joinCtrl = TextEditingController();
  bool _joining = false;
  String? _joinMsg;
  bool _joinErr = false;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _codeCtrl.text.trim().isEmpty) {
      setState(() {
        _createMsg = 'Club name & invite code are required.';
        _createErr = true;
      });
      return;
    }
    setState(() {
      _creating = true;
      _createMsg = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.createClub(
        _nameCtrl.text.trim(),
        _codeCtrl.text.trim(),
      );
      widget.onDone();
      setState(() {
        _createMsg = 'Club created! ID: ${res['club_id']}';
        _createErr = false;
      });
      _nameCtrl.clear();
      _codeCtrl.clear();
    } catch (e) {
      setState(() {
        _createMsg = 'Error: $e';
        _createErr = true;
      });
    } finally {
      setState(() => _creating = false);
    }
  }

  Future<void> _join() async {
    if (_joinCtrl.text.trim().isEmpty) {
      setState(() {
        _joinMsg = 'Invite code is required.';
        _joinErr = true;
      });
      return;
    }
    setState(() {
      _joining = true;
      _joinMsg = null;
    });
    try {
      await ref.read(apiClientProvider).joinClub(_joinCtrl.text.trim());
      widget.onDone();
      setState(() {
        _joinMsg = 'Successfully joined club!';
        _joinErr = false;
      });
      _joinCtrl.clear();
    } catch (e) {
      setState(() {
        _joinMsg = 'Error: $e';
        _joinErr = true;
      });
    } finally {
      setState(() => _joining = false);
    }
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'ADD A CLUB',
                style: GoogleFonts.rajdhani(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tc,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [AppColors.primary, const Color(0xFFFF9E00)],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.black,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: const [
                    Tab(text: 'CREATE'),
                    Tab(text: 'JOIN'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab content
              SizedBox(
                height: 230,
                child: TabBarView(
                  controller: _tc,
                  children: [
                    // CREATE
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameCtrl,
                            style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
                            decoration: _field('Club Name', Icons.shield),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _codeCtrl,
                            style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
                            decoration: _field('Invite Code', Icons.vpn_key),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: EsportsButton(
                              label: 'CREATE CLUB',
                              icon: Icons.shield,
                              isLoading: _creating,
                              onPressed: _creating ? null : _create,
                            ),
                          ),
                          if (_createMsg != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _createMsg!,
                              style: GoogleFonts.rajdhani(
                                color: _createErr ? AppColors.lossRed : AppColors.winGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // JOIN
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          TextField(
                            controller: _joinCtrl,
                            style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
                            decoration: _field('Invite Code', Icons.vpn_key),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: EsportsButton(
                              label: 'JOIN CLUB',
                              icon: Icons.group_add,
                              isLoading: _joining,
                              gradient: [AppColors.cyan, const Color(0xFF00B0FF)],
                              onPressed: _joining ? null : _join,
                            ),
                          ),
                          if (_joinMsg != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _joinMsg!,
                              style: GoogleFonts.rajdhani(
                                color: _joinErr ? AppColors.lossRed : AppColors.winGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
