import 'package:flutter/material.dart';

class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Brackets & Fixtures'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Knockout Bracket (Round 1)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildBracketMatchTile('ApexStriker (1500 Elo)', 'RookiePlayer (1000 Elo)', 'Match 1'),
            _buildBracketMatchTile('TikiTakaKing (1350 Elo)', 'DefensiveWall (1280 Elo)', 'Match 2'),
            const SizedBox(height: 28),
            const Text(
              'League Round-Robin Fixtures',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildLeagueFixtureTile('Round 1', 'ApexStriker vs TikiTakaKing'),
            _buildLeagueFixtureTile('Round 1', 'DefensiveWall vs RookiePlayer'),
            _buildLeagueFixtureTile('Round 2', 'ApexStriker vs DefensiveWall'),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketMatchTile(String p1, String p2, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161925),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF00CEC9), fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p1, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('VS', style: TextStyle(color: Colors.white38, fontSize: 12)),
              Text(p2, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeagueFixtureTile(String round, String fixture) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161925),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(round, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(fixture, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
