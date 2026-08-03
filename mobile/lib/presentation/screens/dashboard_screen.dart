import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../screens/admin_dispute_screen.dart';
import '../screens/clubs_screen.dart';
import '../screens/player_profile_screen.dart';
import '../screens/tournament_screen.dart';
import '../widgets/pending_verifications_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter — subtle diagonal grid for hero banner background
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0;

    const spacing = 40.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Diagonal lines (top-left to bottom-right)
    for (double d = -size.height; d < size.width; d += spacing * 2) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShimmerCard — animated loading placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  final double height;
  const _ShimmerCard({this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
          duration: 1200.ms,
          color: Colors.white.withValues(alpha: 0.07),
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FormChip — W / D / L chip for the recent form strip
// ─────────────────────────────────────────────────────────────────────────────

class _FormChip extends StatelessWidget {
  final String result;   // 'W', 'D', or 'L'
  final String score;    // e.g. '3-1'
  final String opponent;
  final VoidCallback? onTap;

  const _FormChip({
    required this.result,
    required this.score,
    required this.opponent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color col = result == 'W'
        ? AppColors.winGreen
        : result == 'L'
            ? AppColors.lossRed
            : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: col.withValues(alpha: 0.45), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result,
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: col,
              ),
            ),
            Text(
              score,
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PodiumPlayer — one slot in the top-3 leaderboard podium
// ─────────────────────────────────────────────────────────────────────────────

class _PodiumPlayer extends StatelessWidget {
  final int rank;
  final String name;
  final dynamic rating;
  final VoidCallback? onTap;

  const _PodiumPlayer({
    required this.rank,
    required this.name,
    required this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    final double avatarRadius = rank == 1 ? 30 : 24;
    final double fontSize = rank == 1 ? 14 : 12;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: medalColor.withValues(alpha: 0.18),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.orbitron(
                    fontWeight: FontWeight.bold,
                    fontSize: avatarRadius * 0.7,
                    color: medalColor,
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                right: -6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: medalColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name.length > 8 ? '${name.substring(0, 7)}…' : name,
            style: GoogleFonts.rajdhani(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
          ),
          Text(
            '$rating pts',
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              color: medalColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // ── helpers ────────────────────────────────────────────────────────────────

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 17) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authUserId = ref.watch(authStateProvider);
    final userId =
        authUserId ?? '00000000-0000-0000-0000-000000000001';

    final myClubsAsync = ref.watch(myClubsProvider);
    final clubsList =
        myClubsAsync.asData?.value['clubs'] as List<dynamic>? ?? [];
    final hasClub = clubsList.isNotEmpty;
    final clubId = hasClub
        ? clubsList.first['id'].toString()
        : '00000000-0000-0000-0000-000000000001';
    final clubName = hasClub
        ? (clubsList.first['name']?.toString() ?? 'My Club')
        : null;

    final pendingAsync = ref.watch(pendingMatchesProvider);
    final pendingCount = pendingAsync.asData?.value.length ?? 0;

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(analyticsProvider(userId));
        ref.invalidate(matchHistoryProvider(userId));
        ref.invalidate(playerScheduledMatchesProvider(userId));
        ref.invalidate(leaderboardProvider(clubId));
        ref.invalidate(myClubsProvider);
        ref.invalidate(clubActivityProvider(clubId));
        ref.invalidate(pendingMatchesProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Hero Banner ──────────────────────────────────────────────
            _buildHeroBanner(userId),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── 2. Player Rating Hero Card ──────────────────────────
                  _buildRatingHeroCard(userId)
                      .animate()
                      .fade(duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── 3. Recent Form Strip ────────────────────────────────
                  _buildRecentFormStrip(userId)
                      .animate()
                      .fade(delay: 80.ms, duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── 4. Upcoming Matches ─────────────────────────────────
                  _buildUpcomingMatchesCard(userId)
                      .animate()
                      .fade(delay: 160.ms, duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── 5. Quick Action Grid ────────────────────────────────
                  _buildQuickActionGrid(pendingCount)
                      .animate()
                      .fade(delay: 240.ms, duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 24),

                  // ── 6. Club Leaderboard Snapshot ────────────────────────
                  _buildLeaderboardSnapshot(hasClub, clubId, clubName)
                      .animate()
                      .fade(delay: 320.ms, duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 24),

                  // ── 7. Club Activity Feed ───────────────────────────────
                  _buildActivityFeed(hasClub, clubId)
                      .animate()
                      .fade(delay: 400.ms, duration: 400.ms)
                      .slideY(begin: 0.05, duration: 400.ms),

                  const SizedBox(height: 24),

                  // ── 8. Pending Verifications Banner ─────────────────────
                  if (pendingCount > 0)
                    _buildPendingBanner(pendingCount)
                        .animate()
                        .fade(delay: 480.ms, duration: 400.ms)
                        .slideY(begin: 0.05, duration: 400.ms),

                  if (pendingCount > 0) const SizedBox(height: 24),

                  // ── 9. Bottom spacer ────────────────────────────────────
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Section builders
  // ══════════════════════════════════════════════════════════════════════════

  // ── 1. Hero Banner ────────────────────────────────────────────────────────

  Widget _buildHeroBanner(String userId) {
    final initial =
        userId.isNotEmpty ? userId[0].toUpperCase() : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0E16), Color(0xFF090A0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          // Subtle grid overlay
          Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),

          // Content
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting, COMMANDER',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                        letterSpacing: 2.0,
                      ),
                    ).animate().fade(duration: 500.ms).slideX(begin: -0.1),
                    const SizedBox(height: 6),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AppColors.primary,
                          Colors.white,
                          AppColors.cyan,
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ).createShader(bounds),
                      child: Text(
                        'MATCH CENTER',
                        style: GoogleFonts.orbitron(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .shimmer(
                          duration: 3000.ms,
                          color: AppColors.cyan.withValues(alpha: 0.15),
                        ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Avatar button
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PlayerProfileScreen()),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.surfaceLight,
                    child: Text(
                      initial,
                      style: GoogleFonts.orbitron(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ).animate().fade(delay: 200.ms).scale(begin: const Offset(0.85, 0.85)),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. Player Rating Hero Card ────────────────────────────────────────────

  Widget _buildRatingHeroCard(String userId) {
    final analyticsAsync = ref.watch(analyticsProvider(userId));

    return analyticsAsync.when(
      loading: () => const _ShimmerCard(height: 150),
      error: (_, __) => _errorCard('Could not load player stats'),
      data: (data) {
        final skill = data['skill_rating'] ?? 0;
        final form = (data['form_rating'] as num?)?.toDouble() ?? 0.0;
        final wins = data['wins'] ?? 0;
        final losses = data['losses'] ?? 0;
        final winRate = data['win_rate'];
        final winRateStr = winRate != null
            ? '${(winRate as num).toStringAsFixed(0)}%'
            : '—';

        return GlassCard(
          gradientColors: const [Color(0xFF1C0A00), Color(0xFF090A0F)],
          borderColor: AppColors.primary.withValues(alpha: 0.6),
          padding: const EdgeInsets.all(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlayerProfileScreen()),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left — rating + form bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SKILL RATING',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$skill',
                          style: GoogleFonts.orbitron(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PTS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FORM',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          form.toStringAsFixed(1),
                          style: GoogleFonts.rajdhani(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.winGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (form / 100.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.winGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right — stat pills
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  StatPill(
                    label: 'WINS',
                    value: '$wins',
                    color: AppColors.winGreen,
                  ),
                  const SizedBox(height: 8),
                  StatPill(
                    label: 'LOSS',
                    value: '$losses',
                    color: AppColors.lossRed,
                  ),
                  const SizedBox(height: 8),
                  StatPill(
                    label: 'WIN%',
                    value: winRateStr,
                    color: AppColors.cyan,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 3. Recent Form Strip ──────────────────────────────────────────────────

  Widget _buildRecentFormStrip(String userId) {
    final matchesAsync = ref.watch(matchHistoryProvider(userId));

    return matchesAsync.when(
      loading: () => const _ShimmerCard(height: 80),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final allMatches =
            (data['matches'] as List<dynamic>? ?? []).take(5).toList();
        if (allMatches.isEmpty) return const SizedBox.shrink();

        // Calculate current win streak
        int streak = 0;
        String streakLabel = '';
        for (final m in allMatches) {
          final gf = m['goals_for'] as num? ?? 0;
          final ga = m['goals_against'] as num? ?? 0;
          if (gf > ga) {
            streak++;
          } else {
            break;
          }
        }
        if (streak >= 2) streakLabel = '${streak}W STREAK';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'RECENT FORM',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                    letterSpacing: 1.5,
                  ),
                ),
                if (streakLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.winGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.winGreen.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      streakLabel,
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.winGreen,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: allMatches.map((m) {
                final gf = m['goals_for'] as num? ?? 0;
                final ga = m['goals_against'] as num? ?? 0;
                final res = gf > ga
                    ? 'W'
                    : gf < ga
                        ? 'L'
                        : 'D';
                final score = '$gf-$ga';
                final opponent =
                    m['opponent_name']?.toString() ?? 'Opponent';

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FormChip(
                    result: res,
                    score: score,
                    opponent: opponent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'vs $opponent  •  $score',
                            style: GoogleFonts.rajdhani(fontSize: 14),
                          ),
                          backgroundColor: AppColors.surface,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // ── 4. Upcoming Matches Card ──────────────────────────────────────────────

  Widget _buildUpcomingMatchesCard(String userId) {
    final scheduledAsync = ref.watch(playerScheduledMatchesProvider(userId));

    return scheduledAsync.when(
      loading: () => const _ShimmerCard(height: 120),
      error: (err, _) => _errorCard('Could not load scheduled matches'),
      data: (data) {
        final matches = data['matches'] as List<dynamic>? ?? [];

        return GlassCard(
          borderColor: AppColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_month,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'UPCOMING MATCHES',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (matches.isNotEmpty)
                    GlowBadge(
                      label: '${matches.length} UPCOMING',
                      color: AppColors.cyan,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (matches.isEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_available,
                        color: AppColors.textMuted, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'No upcoming matches',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: math.min(matches.length, 4),
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white10, height: 16),
                  itemBuilder: (_, idx) {
                    final m = matches[idx];
                    final tName =
                        m['tournament_name']?.toString() ?? 'Tournament';
                    final round = m['round_number'] ?? 1;
                    final p1 = m['player_1_name']?.toString() ?? 'TBD';
                    final p2 = m['player_2_name']?.toString() ?? 'TBD';

                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tName.toUpperCase(),
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  color: AppColors.cyan,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$p1  vs  $p2',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ROUND $round',
                            style: GoogleFonts.rajdhani(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 5. Quick Action Grid ──────────────────────────────────────────────────

  Widget _buildQuickActionGrid(int pendingCount) {
    final actions = <Map<String, dynamic>>[
      {
        'label': 'APPROVALS',
        'sub': 'Pending Verifications',
        'icon': Icons.mark_email_unread_outlined,
        'color': Colors.amber,
        'badge': pendingCount > 0 ? pendingCount : null,
        'action': () => showDialog(
              context: context,
              builder: (_) => const PendingVerificationsModal(),
            ),
      },
      {
        'label': 'DISPUTES',
        'sub': 'Admin Judgments',
        'icon': Icons.gavel_outlined,
        'color': AppColors.purple,
        'badge': null,
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminDisputeScreen()),
            ),
      },
      {
        'label': 'MY CLUBS',
        'sub': 'Roster & Leaderboards',
        'icon': Icons.shield_outlined,
        'color': AppColors.cyan,
        'badge': null,
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClubsScreen()),
            ),
      },
      {
        'label': 'TOURNAMENTS',
        'sub': 'Brackets & Leagues',
        'icon': Icons.emoji_events_outlined,
        'color': AppColors.primary,
        'badge': null,
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TournamentScreen()),
            ),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: actions.length,
      itemBuilder: (_, idx) {
        final item = actions[idx];
        final col = item['color'] as Color;
        final badge = item['badge'] as int?;

        return GlassCard(
          borderColor: col.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(14),
          onTap: item['action'] as VoidCallback,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: col.withValues(alpha: 0.25),
                          blurRadius: 10,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child:
                        Icon(item['icon'] as IconData, color: col, size: 22),
                  ),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lossRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.rajdhani(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    item['sub'] as String,
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 6. Club Leaderboard Snapshot ─────────────────────────────────────────

  Widget _buildLeaderboardSnapshot(
      bool hasClub, String clubId, String? clubName) {
    if (!hasClub) {
      return _noClubCard(
          'CLUB STANDINGS', 'Join a club to see the leaderboard.');
    }

    final lbAsync = ref.watch(leaderboardProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CLUB STANDINGS',
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
                letterSpacing: 1.5,
              ),
            ),
            if (clubName != null)
              GlowBadge(label: clubName, color: AppColors.purple),
          ],
        ),
        const SizedBox(height: 14),

        lbAsync.when(
          loading: () => const _ShimmerCard(height: 160),
          error: (_, __) => _errorCard('Could not load leaderboard'),
          data: (players) {
            if (players.isEmpty) {
              return _noClubCard('STANDINGS', 'No players found.');
            }

            final top3 = players.take(3).toList();
            final rest = players.skip(3).take(3).toList();

            return GlassCard(
              borderColor: AppColors.cyan.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Podium row: 2nd | 1st | 3rd
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (top3.length > 1)
                        _PodiumPlayer(
                          rank: 2,
                          name: top3[1]['player_name']?.toString() ?? '—',
                          rating: top3[1]['skill_rating'] ?? 0,
                          onTap: () => _showPlayerBottomSheet(
                            top3[1]['player_name']?.toString() ?? '—',
                            top3[1]['skill_rating'],
                          ),
                        ),
                      if (top3.isNotEmpty)
                        _PodiumPlayer(
                          rank: 1,
                          name: top3[0]['player_name']?.toString() ?? '—',
                          rating: top3[0]['skill_rating'] ?? 0,
                          onTap: () => _showPlayerBottomSheet(
                            top3[0]['player_name']?.toString() ?? '—',
                            top3[0]['skill_rating'],
                          ),
                        ),
                      if (top3.length > 2)
                        _PodiumPlayer(
                          rank: 3,
                          name: top3[2]['player_name']?.toString() ?? '—',
                          rating: top3[2]['skill_rating'] ?? 0,
                          onTap: () => _showPlayerBottomSheet(
                            top3[2]['player_name']?.toString() ?? '—',
                            top3[2]['skill_rating'],
                          ),
                        ),
                    ],
                  ),

                  if (rest.isNotEmpty) ...[
                    const Divider(color: Colors.white10, height: 24),
                    ...rest.asMap().entries.map((entry) {
                      final rank = entry.key + 4;
                      final p = entry.value;
                      final name =
                          p['player_name']?.toString() ?? '—';
                      final rating = p['skill_rating'] ?? 0;

                      return GestureDetector(
                        onTap: () =>
                            _showPlayerBottomSheet(name, rating),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '#$rank',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '$rating pts',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showPlayerBottomSheet(String name, dynamic rating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderColor: AppColors.cyan.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: GoogleFonts.orbitron(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.cyan,
                    ),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rating: $rating PTS',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: EsportsButton(
                label: 'VIEW FULL LEADERBOARD',
                icon: Icons.leaderboard,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ClubsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7. Club Activity Feed ─────────────────────────────────────────────────

  Widget _buildActivityFeed(bool hasClub, String clubId) {
    if (!hasClub) {
      return _noClubCard(
          'CLUB ACTIVITY', 'Join a club to see activity.');
    }

    final activityAsync = ref.watch(clubActivityProvider(clubId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLUB ACTIVITY',
          style: GoogleFonts.rajdhani(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.cyan,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        activityAsync.when(
          loading: () => const _ShimmerCard(height: 200),
          error: (_, __) => _errorCard('Could not load activity'),
          data: (activities) {
            if (activities.isEmpty) {
              return _noClubCard('ACTIVITY', 'No recent club activity.');
            }

            return Column(
              children: activities.take(5).map((a) {
                final act = a as Map<String, dynamic>;
                final playerName =
                    act['player_name']?.toString() ?? '—';
                final opponentName =
                    act['opponent_name']?.toString() ?? '—';
                final gf = int.tryParse(
                        act['goals_for']?.toString() ?? '') ??
                    0;
                final ga = int.tryParse(
                        act['goals_against']?.toString() ?? '') ??
                    0;
                final matchType =
                    act['match_type']?.toString() ?? 'Match';
                final time = act['created_at']?.toString() ?? '';
                final dateStr = time.length >= 10
                    ? time.substring(0, 10)
                    : time;

                final isWin = gf > ga;
                final isLoss = gf < ga;
                final col = isWin
                    ? AppColors.winGreen
                    : isLoss
                        ? AppColors.lossRed
                        : Colors.grey;
                final resultLabel =
                    isWin ? 'WIN' : (isLoss ? 'LOSS' : 'DRAW');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      left: BorderSide(color: col, width: 3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$playerName  vs  $opponentName',
                                style: GoogleFonts.rajdhani(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                matchType,
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Score
                        Text(
                          '$gf – $ga',
                          style: GoogleFonts.orbitron(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Result chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: col.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: col.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            resultLabel,
                            style: GoogleFonts.rajdhani(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: col,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Date
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: GoogleFonts.rajdhani(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── 8. Pending Verifications Banner ──────────────────────────────────────

  Widget _buildPendingBanner(int count) {
    return GlassCard(
      borderColor: Colors.amber.withValues(alpha: 0.6),
      gradientColors: [
        Colors.amber.withValues(alpha: 0.12),
        AppColors.surface,
      ],
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.notification_important, color: Colors.amber, size: 28)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1500.ms, color: Colors.amber),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count PENDING VERIFICATION${count == 1 ? '' : 'S'}',
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Match results require your review',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          EsportsButton(
            label: 'REVIEW NOW',
            gradient: const [Colors.amber, Color(0xFFFFB300)],
            height: 40,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const PendingVerificationsModal(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Utility widgets ───────────────────────────────────────────────────────

  Widget _errorCard(String message) {
    return GlassCard(
      borderColor: AppColors.lossRed.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.lossRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noClubCard(String section, String message) {
    return GlassCard(
      borderColor: AppColors.surfaceLight,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
