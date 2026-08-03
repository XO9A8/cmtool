import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'presentation/theme/app_theme.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/h2h_screen.dart';
import 'presentation/screens/tournament_screen.dart';
import 'presentation/screens/clubs_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/player_profile_screen.dart';
import 'presentation/screens/admin_dispute_screen.dart';
import 'presentation/widgets/pending_verifications_modal.dart';
import 'presentation/providers/match_provider.dart';
import 'infrastructure/api_client.dart';
import 'infrastructure/offline_sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const ProviderScope(child: EFootballApp()));
}

class EFootballApp extends StatelessWidget {
  const EFootballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eFootball Club Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _syncStarted = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider);

    if (userId == null) {
      _syncStarted = false;
      return const AuthScreen();
    }

    if (!_syncStarted) {
      _syncStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(offlineSyncProvider).startAutoSync(ref);
      });
    }

    return const NavigationRootScreen();
  }
}

class NavigationRootScreen extends StatefulWidget {
  const NavigationRootScreen({super.key});

  @override
  State<NavigationRootScreen> createState() => _NavigationRootScreenState();
}

class _NavigationRootScreenState extends State<NavigationRootScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    TournamentScreen(),
    ClubsScreen(),
    AnalyticsHubScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background.withOpacity(0.8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.cyan],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.sports_soccer, color: Colors.black, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'eFootball Hub',
              style: GoogleFonts.orbitron(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_unread_outlined, color: AppColors.cyan),
            tooltip: 'Pending Approvals',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const PendingVerificationsModal(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.gavel_outlined, color: AppColors.primary),
            tooltip: 'Admin Disputes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDisputeScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final userId = ref.watch(authStateProvider);
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PlayerProfileScreen()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.surfaceLight,
                    child: Text(
                      userId != null && userId.isNotEmpty ? userId.substring(0, 1).toUpperCase() : 'U',
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: Colors.white10, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (idx) => setState(() => _selectedIndex = idx),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Hub',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events_outlined),
              activeIcon: Icon(Icons.emoji_events),
              label: 'Tournaments',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shield_outlined),
              activeIcon: Icon(Icons.shield),
              label: 'Clubs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Analytics & H2H',
            ),
          ],
        ),
      ),
    );
  }
}

/// Consolidated Hub / Dashboard Screen - Modern & Interactive
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {

  @override
  Widget build(BuildContext context) {
    final authUserId = ref.watch(authStateProvider);
    final myClubsAsync = ref.watch(myClubsProvider);
    final clubsList = myClubsAsync.asData?.value['clubs'] as List<dynamic>? ?? [];
    final clubId = clubsList.isNotEmpty ? clubsList.first['id'].toString() : '00000000-0000-0000-0000-000000000001';
    final userId = authUserId ?? '00000000-0000-0000-0000-000000000001';
    final analyticsAsync = ref.watch(analyticsProvider(userId));

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(analyticsProvider(userId));
        ref.invalidate(leaderboardProvider(clubId));
        ref.invalidate(myClubsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Score Marquee Ticker
            _buildLiveScoreTicker(),
            const SizedBox(height: 16),

            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAYER DASHBOARD',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Season 1 Match Center',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const GlowBadge(label: 'LIVE ONLINE', color: AppColors.winGreen, icon: Icons.sensors),
              ],
            ).animate().fade().slideX(begin: -0.1, end: 0),

            const SizedBox(height: 20),

            // Hero Player Card
            analyticsAsync.when(
              loading: () => const _SkeletonCard(),
              error: (_, __) => const _PlayerCardStub(),
              data: (data) => _PlayerStatsCard(data: data),
            ).animate().fade(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 20),

            // Live "Next Match Up" Interactive Hero Card
            _buildScheduledMatchesCard(context, userId),

            const SizedBox(height: 20),

            // Interactive ELO Sparkline & Form Tracker Card
            _buildEloTrajectoryCard(userId),

            const SizedBox(height: 20),



            // Quick Interactive Command Grid (4 Action Tiles)
            _buildInteractiveCommandGrid(context),

            const SizedBox(height: 24),

            // Dual-Player Pending Confirmations & Official Action Center
            _buildPendingConfirmationsCard(context, ref),

            const SizedBox(height: 24),

            // Interactive AI Coaching Advice Cycler
            _buildInteractiveAiCoach(),

            const SizedBox(height: 24),

            // Club Lounge & Captain's Announcement Board
            _buildClubLoungeWidget(),

            const SizedBox(height: 24),

            // Season 1 Daily Goals & Operations Tracker
            _buildSeasonQuestsTracker(),

            const SizedBox(height: 28),

            // Activity Feed Section
            Text(
              'CLUB ACTIVITY FEED',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildActivityFeed(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveScoreTicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.winGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.winGreen, shape: BoxShape.circle),
            child: const Icon(Icons.sensors, color: Colors.black, size: 12),
          ),
          const SizedBox(width: 8),
          Text('LIVE TICKER', style: GoogleFonts.rajdhani(color: AppColors.winGreen, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No live matches at the moment.',
              style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.2);
  }

  Widget _buildScheduledMatchesCard(BuildContext context, String userId) {
    final scheduledAsync = ref.watch(playerScheduledMatchesProvider(userId));

    return scheduledAsync.when(
      loading: () => const _SkeletonCard(),
      error: (err, stack) => GlassCard(
        borderColor: AppColors.lossRed.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(16),
        child: Text('Error loading scheduled matches: $err', style: GoogleFonts.rajdhani(color: Colors.white)),
      ),
      data: (data) {
        final matches = data['matches'] as List<dynamic>? ?? [];
        if (matches.isEmpty) {
          return GlassCard(
            borderColor: AppColors.primary.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'SCHEDULED MATCHES',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'No upcoming scheduled matches at the moment.',
                  style: GoogleFonts.rajdhani(fontSize: 14, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        return GlassCard(
          borderColor: AppColors.primary,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'SCHEDULED MATCHES',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  GlowBadge(label: '${matches.length} UPCOMING', color: AppColors.cyan),
                ],
              ),
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matches.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 16),
                itemBuilder: (context, idx) {
                  final m = matches[idx];
                  final tName = m['tournament_name'] ?? 'Tournament';
                  final round = m['round_number'] ?? 1;
                  final p1 = m['player_1_name'] ?? 'TBD';
                  final p2 = m['player_2_name'] ?? 'TBD';

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tName.toString().toUpperCase(),
                              style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.cyan, fontWeight: FontWeight.bold, letterSpacing: 1),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$p1 vs $p2',
                              style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'ROUND $round',
                        style: GoogleFonts.rajdhani(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ).animate().fade().slideY(begin: 0.1);
      },
    );
  }

  Widget _buildEloTrajectoryCard(String userId) {
    final matchesAsync = ref.watch(matchHistoryProvider(userId));

    return matchesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final matches = (data['matches'] as List<dynamic>? ?? []).take(5).toList();
        if (matches.isEmpty) return const SizedBox.shrink();

        return GlassCard(
          borderColor: AppColors.cyan.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('RATING TRAJECTORY & RECENT FORM', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.2)),
                  Text('RECENT MATCHES', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.winGreen)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: matches.map((m) {
                  final gf = m['goals_for'] ?? 0;
                  final ga = m['goals_against'] ?? 0;
                  final isW = gf > ga;
                  final isL = gf < ga;
                  final res = isW ? 'W' : (isL ? 'L' : 'D');
                  final col = isW ? AppColors.winGreen : (isL ? AppColors.lossRed : Colors.grey);
                  final score = '$gf-$ga';

                  return GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Match Result: $score vs ${m['opponent_name'] ?? 'Opponent'}')),
                      );
                    },
                    child: Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: col.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: col.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Text(res, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: col)),
                          Text(score, style: GoogleFonts.rajdhani(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _buildInteractiveCommandGrid(BuildContext context) {
    final commands = [
      {
        'title': 'Approvals',
        'sub': 'Match Verification',
        'icon': Icons.mark_email_unread_outlined,
        'color': Colors.amber,
        'action': () {
          showDialog(
            context: context,
            builder: (_) => const PendingVerificationsModal(),
          );
        },
      },
      {
        'title': 'Disputes',
        'sub': 'Admin Judgments',
        'icon': Icons.gavel_outlined,
        'color': AppColors.purple,
        'action': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminDisputeScreen()),
          );
        },
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemCount: commands.length,
      itemBuilder: (context, idx) {
        final item = commands[idx];
        final col = item['color'] as Color;
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          borderColor: col.withValues(alpha: 0.3),
          onTap: item['action'] as VoidCallback,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(item['icon'] as IconData, color: col, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] as String,
                      style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      item['sub'] as String,
                      style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveAiCoach() {
    return GlassCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.cyan, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'AI COACHING ASSISTANT',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyan,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const GlowBadge(label: 'COMING SOON', color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI coaching insights will appear here after you play more matches.',
                  style: const TextStyle(fontSize: 12, color: Colors.white54, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClubLoungeWidget() {
    return GlassCard(
      borderColor: AppColors.purple.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign, color: AppColors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'CAPTAINS ANNOUNCEMENT BOARD',
                    style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple, letterSpacing: 1.2),
                  ),
                ],
              ),
              const GlowBadge(label: 'COMING SOON', color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.announcement_outlined, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Club announcements from your captain will appear here.',
                  style: GoogleFonts.rajdhani(fontSize: 12, color: Colors.white54, height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSeasonQuestsTracker() {
    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DAILY QUESTS',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const GlowBadge(label: 'COMING SOON', color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.lock_clock, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Season quests will unlock once your club is enrolled in an active tournament.',
                  style: GoogleFonts.rajdhani(fontSize: 12, color: Colors.white54),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  void _showPlayerH2hBottomSheet(BuildContext context, String playerId, dynamic rating) {
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
                      Text('Player $playerId', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Rating: $rating PTS', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
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

  Widget _buildPendingConfirmationsCard(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingMatchesProvider);
    final pendingCount = pendingAsync.asData?.value.length ?? 0;

    return GlassCard(
      borderColor: Colors.amber.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PENDING MATCH VERIFICATIONS',
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  letterSpacing: 1.2,
                ),
              ),
              GlowBadge(
                label: pendingCount > 0 ? '$pendingCount PENDING' : 'ALL CLEAR',
                color: pendingCount > 0 ? Colors.amber : AppColors.winGreen,
                icon: Icons.gavel,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Requires verification by Opponent OR Club Official (President, Captain, Vice-Captain, Admin).',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                pendingCount > 0 ? Icons.notification_important : Icons.check_circle_outline,
                color: pendingCount > 0 ? Colors.amber : AppColors.winGreen,
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pendingCount > 0
                      ? '$pendingCount match result(s) awaiting dual-confirmation or official review.'
                      : 'No pending verifications at the moment. All match records are verified.',
                  style: GoogleFonts.rajdhani(fontSize: 12, color: Colors.white70, height: 1.4),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.winGreen,
                  side: const BorderSide(color: AppColors.winGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: Text('REVIEW', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 11)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const PendingVerificationsModal(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildActivityFeed() {
    final myClubsAsync = ref.watch(myClubsProvider);
    final clubsList = myClubsAsync.asData?.value['clubs'] as List<dynamic>? ?? [];
    final clubId = clubsList.isNotEmpty ? clubsList.first['id'].toString() : '';

    if (clubId.isEmpty) {
      return const GlassCard(
        child: Center(
          child: Text(
            'Join a club to see activity.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final activityAsync = ref.watch(clubActivityProvider(clubId));

    return activityAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (activities) {
        if (activities.isEmpty) {
          return const GlassCard(
            child: Center(
              child: Text(
                'No recent club activity.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          );
        }

        return Column(
          children: activities.take(5).map((a) {
            final act = a as Map<String, dynamic>;
            final playerName = act['player_name']?.toString() ?? '—';
            final opponentName = act['opponent_name']?.toString() ?? '—';
            final goalsFor = act['goals_for']?.toString() ?? '?';
            final goalsAgainst = act['goals_against']?.toString() ?? '?';
            final matchType = act['match_type']?.toString() ?? 'Match';
            final time = act['created_at']?.toString() ?? '';

            // Build a human-readable title from the match result
            final gf = int.tryParse(goalsFor) ?? 0;
            final ga = int.tryParse(goalsAgainst) ?? 0;
            final resultLabel = gf > ga ? 'Win' : (gf < ga ? 'Loss' : 'Draw');
            final title = '$playerName $goalsFor – $goalsAgainst $opponentName';
            final subtitle = '$matchType · $resultLabel';

            final col = gf > ga
                ? AppColors.winGreen
                : (gf < ga ? AppColors.lossRed : Colors.grey);

            return GlassCard(
              margin: const EdgeInsets.only(bottom: 8),
              borderColor: col.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: col.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sports_soccer, color: col, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (time.isNotEmpty)
                              Text(
                                time.length > 10 ? time.substring(0, 10) : time,
                                style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
class AnalyticsHubScreen extends StatefulWidget {
  const AnalyticsHubScreen({super.key});

  @override
  State<AnalyticsHubScreen> createState() => _AnalyticsHubScreenState();
}

class _AnalyticsHubScreenState extends State<AnalyticsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.compare_arrows, size: 18), text: 'H2H RIVALRY'),
              Tab(icon: Icon(Icons.person, size: 18), text: 'PROFILE & BADGES'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              H2hScreen(),
              PlayerProfileScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _PlayerCardStub extends StatelessWidget {
  const _PlayerCardStub();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          const Icon(Icons.person, size: 44, color: AppColors.cyan),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Skill Rating: — PTS', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Form Rating: — / 100', style: TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerStatsCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PlayerStatsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final skill = data['skill_rating'] ?? 0;
    final form = (data['form_rating'] as num?)?.toDouble() ?? 0.0;
    final style = data['play_style'] ?? '—';

    return GlassCard(
      gradientColors: const [Color(0xFF28180A), Color(0xFF12141F)],
      borderColor: AppColors.primary.withOpacity(0.6),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT PLAYER RATING',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$skill',
                        style: GoogleFonts.orbitron(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PTS',
                        style: GoogleFonts.rajdhani(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GlowBadge(label: style.toString(), color: AppColors.cyan, icon: Icons.sports),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('EWMA Form Index', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  Text(
                    '${form.toStringAsFixed(1)} / 100',
                    style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: AppColors.winGreen),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (form / 100.0).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.winGreen),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
