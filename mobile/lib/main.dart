import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/h2h_screen.dart';
import 'presentation/screens/tournament_screen.dart';
import 'presentation/widgets/ocr_upload_modal.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0D0F17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF00CEC9),
          surface: Color(0xFF161925),
        ),
      ),
      home: const NavigationRootScreen(),
    );
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
    MatchPredictorScreen(),
    H2hScreen(),
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
        backgroundColor: const Color(0xFF161925),
        selectedItemColor: const Color(0xFF00CEC9),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_tree_outlined),
            activeIcon: Icon(Icons.account_tree),
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
            label: 'H2H Rivalry',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sports_soccer, color: Color(0xFF00CEC9)),
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
            // Player Skill & Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFF341F97)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ApexStriker',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tag: Possession Master',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Color(0xFF00CEC9), size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Form Rating: 84.5',
                            style: TextStyle(
                                color: Color(0xFF00CEC9), fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'SKILL RATING',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: Colors.white60,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          '1,420 Elo',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00CEC9)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00CEC9),
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

            // Club Leaderboard Section
            const Text(
              'Club Leaderboard (Top Ratings)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                LeaderboardTile(
                    rank: 1, name: 'ApexStriker', elo: 1420, winRate: '78.5%', style: 'Possession'),
                LeaderboardTile(
                    rank: 2, name: 'TikiTakaKing', elo: 1350, winRate: '65.0%', style: 'Counter'),
                LeaderboardTile(
                    rank: 3, name: 'DefensiveWall', elo: 1280, winRate: '59.2%', style: 'Out Wide'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final int elo;
  final String winRate;
  final String style;

  const LeaderboardTile({
    super.key,
    required this.rank,
    required this.name,
    required this.elo,
    required this.winRate,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161925),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: rank == 1
                ? const Color(0xFFFFD700)
                : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32)),
            child: Text(
              '$rank',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text('Style: $style • Win Rate: $winRate',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '$elo Elo',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF00CEC9), fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class MatchPredictorScreen extends StatelessWidget {
  const MatchPredictorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Outcome Predictor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161925),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00CEC9).withOpacity(0.4)),
              ),
              child: const Column(
                children: [
                  Text('PREDICTED MATCH PROBABILITIES',
                      style: TextStyle(fontSize: 12, letterSpacing: 1.2, color: Colors.white60)),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('ApexStriker', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('66.0%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                          Text('Win Prob', style: TextStyle(fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('DRAW', style: TextStyle(color: Colors.white60)),
                          Text('22.0%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white70)),
                        ],
                      ),
                      Column(
                        children: [
                          Text('TikiTakaKing', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('12.0%', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                          Text('Win Prob', style: TextStyle(fontSize: 11, color: Colors.white54)),
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
}
