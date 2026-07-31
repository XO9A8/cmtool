import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/h2h_screen.dart';
import 'presentation/screens/tournament_screen.dart';
import 'presentation/screens/clubs_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/player_profile_screen.dart';
import 'presentation/widgets/ocr_upload_modal.dart';
import 'presentation/providers/match_provider.dart';
import 'infrastructure/offline_sync_service.dart';

import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const ProviderScope(child: EFootballApp()));
}

class EFootballApp extends StatelessWidget {
  const EFootballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eFootball Club Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6D00),
          secondary: Color(0xFFFFFFFF),
          surface: Color(0xFF111111),
          onPrimary: Colors.black,
        ),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider);

    if (userId == null) {
      return const AuthScreen();
    }

    ref.read(offlineSyncProvider).startAutoSync(ref);

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
    ClubsScreen(),
    TournamentScreen(),
    MatchPredictorScreen(),
    H2hScreen(),
    PlayerProfileScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: const Color(0xFFFF6D00),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'Clubs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events_outlined),
            activeIcon: Icon(Icons.emoji_events),
            label: 'Tournaments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_outlined),
            activeIcon: Icon(Icons.insights),
            label: 'Predictions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.compare_arrows_outlined),
            activeIcon: Icon(Icons.compare_arrows),
            label: 'H2H',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider) ?? '00000000-0000-0000-0000-000000000001';
    final analyticsAsync = ref.watch(analyticsProvider(userId));
    final leaderboardAsync = ref.watch(leaderboardProvider('00000000-0000-0000-0000-000000000001'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sports_soccer, color: Color(0xFFFF6D00)),
            SizedBox(width: 8),
            Text(
              'eFootball Club Analytics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            analyticsAsync.when(
              loading: () => const _SkeletonCard(),
              error: (_, __) => const _PlayerCardStub(),
              data: (data) => _PlayerStatsCard(data: data),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6D00),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text(
                      'Upload Match OCR',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const OcrUploadModal(),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Club Leaderboard (Top Ratings)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            leaderboardAsync.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => Container(
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              error: (err, _) => Text(
                'Could not load leaderboard: $err',
                style: const TextStyle(color: Colors.redAccent),
              ),
              data: (players) {
                if (players.isEmpty) {
                  return const Text(
                    'No players ranked yet.',
                    style: TextStyle(color: Colors.white54),
                  );
                }
                return Column(
                  children: players.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final p = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '#$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: rank == 1
                                  ? Colors.amber
                                  : (rank == 2 ? Colors.grey : Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              p['player_id']?.toString().substring(0, 8) ?? 'Player',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${p['skill_rating']} Elo',
                            style: const TextStyle(
                              color: Color(0xFFFF6D00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MatchPredictorScreen extends ConsumerStatefulWidget {
  const MatchPredictorScreen({super.key});

  @override
  ConsumerState<MatchPredictorScreen> createState() => _MatchPredictorScreenState();
}

class _MatchPredictorScreenState extends ConsumerState<MatchPredictorScreen> {
  int _r1 = 1000;
  int _r2 = 1000;

  @override
  Widget build(BuildContext context) {
    final e1 = 1 / (1 + dynamicEloExponent(_r2 - _r1));
    final e2 = 1 - e1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('AI MATCH PREDICTOR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elo Rating Win Probability Calculator',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Text('Player 1 Rating: $_r1', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _r1.toDouble(),
              min: 800,
              max: 2200,
              activeColor: const Color(0xFFFF6D00),
              onChanged: (v) => setState(() => _r1 = v.toInt()),
            ),
            const SizedBox(height: 16),
            Text('Player 2 Rating: $_r2', style: const TextStyle(fontWeight: FontWeight.bold)),
            Slider(
              value: _r2.toDouble(),
              min: 800,
              max: 2200,
              activeColor: Colors.white,
              onChanged: (v) => setState(() => _r2 = v.toInt()),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('PREDICTED WIN PROBABILITY', style: TextStyle(fontSize: 12, color: Colors.white54, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('${(e1 * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF6D00))),
                          const Text('Player 1', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                      const Text('VS', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                      Column(
                        children: [
                          Text('${(e2 * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                          const Text('Player 2', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double dynamicEloExponent(int diff) {
    return num.parse((diff / 400.0).toStringAsFixed(4)) is double
        ? double.parse((diff / 400.0).toStringAsFixed(4))
        : diff / 400.0;
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _PlayerCardStub extends StatelessWidget {
  const _PlayerCardStub();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.person, size: 40, color: Colors.white38),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Skill Rating: 1000 Elo', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Form Rating: 50.0', style: TextStyle(color: Colors.white54)),
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
    final skill = data['skill_rating'] ?? 1000;
    final form = (data['form_rating'] as num?)?.toDouble() ?? 50.0;
    final style = data['play_style'] ?? 'Unclassified';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF333333), Color(0xFFFF6D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6D00).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$skill ELO',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  style.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Form Rating: ${form.toStringAsFixed(1)} / 100',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
