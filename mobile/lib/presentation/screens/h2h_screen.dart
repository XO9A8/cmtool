import 'package:flutter/material.dart';

class H2hScreen extends StatelessWidget {
  const H2hScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Head-to-Head Rivalry Tracker'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Head-to-Head Card Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF161925),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4)),
              ),
              child: Column(
                children: [
                  const Text(
                    'HEAD-TO-HEAD HISTORY',
                    style: TextStyle(
                        fontSize: 12, letterSpacing: 1.2, color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Column(
                        children: [
                          Text('ApexStriker',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('7 Wins',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00CEC9))),
                        ],
                      ),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          children: [
                            Text('12 Matches',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70)),
                            Text('2 Draws',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      ),
                      const Column(
                        children: [
                          Text('TikiTakaKing',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('3 Wins',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6C5CE7))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Progress Bar Representation
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Expanded(
                              flex: 7,
                              child: Container(color: const Color(0xFF00CEC9))),
                          Expanded(
                              flex: 2,
                              child: Container(color: Colors.white24)),
                          Expanded(
                              flex: 3,
                              child: Container(color: const Color(0xFF6C5CE7))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Avg Goal Difference: +1.25 goals for ApexStriker',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent H2H Match Logs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            _buildMatchLogTile('3 - 1', 'ApexStriker', 'League Match', 'Jul 28, 2026'),
            _buildMatchLogTile('2 - 2', 'Draw', 'Tournament Group Stage', 'Jul 20, 2026'),
            _buildMatchLogTile('1 - 2', 'TikiTakaKing', 'Friendly', 'Jul 15, 2026'),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchLogTile(
      String score, String winner, String competition, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161925),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(competition,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Winner: $winner • $date',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00CEC9),
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
