import 'package:flutter/material.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges & Player Card'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Shareable Ultimate Team Player Card
            Center(
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6D00), Color(0xFFCC5500)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6D00).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('94',
                                style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black)),
                            Text('ST',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                          ],
                        ),
                        Icon(Icons.sports_soccer, size: 40, color: Colors.black87),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.black12,
                      child: Icon(Icons.person, size: 50, color: Colors.black),
                    ),
                    const SizedBox(height: 12),
                    const Text('ApexStriker',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black)),
                    const Text('Possession Master',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const Divider(color: Colors.black26, height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('85.7%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.black)),
                            Text('PASS',
                                style: TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('1420',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.black)),
                            Text('ELO',
                                style: TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('84.5',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.black)),
                            Text('FORM',
                                style: TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Earned Club Badges',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildBadgeTile('Club Veteran', 'Recorded 50 official club matches', Icons.military_tech),
            _buildBadgeTile('Unstoppable Force', 'Achieved a 10-match winning streak', Icons.bolt),
            _buildBadgeTile('Clean Sheet Master', 'Conceded 0 goals in 5 consecutive matches', Icons.shield),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeTile(String title, String desc, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6D00).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFF6D00)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
