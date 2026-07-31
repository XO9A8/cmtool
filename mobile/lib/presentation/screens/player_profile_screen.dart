import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';

/// Full Player Profile screen with career stats, Elo history chart,
/// match history timeline, badges, and shareable Ultimate Team card.
class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider) ?? '';
    final profileAsync = ref.watch(playerProfileProvider(userId));
    final eloAsync = ref.watch(eloHistoryProvider(userId));
    final matchesAsync = ref.watch(matchHistoryProvider(userId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Collapsing header with player card
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF090A0F),
            flexibleSpace: FlexibleSpaceBar(
              background: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
                error: (_, __) => _buildHeroCard(1000, 50.0, 'Unclassified', 0, 0, 0, 0, 0.0),
                data: (data) => _buildHeroCard(
                  data['skill_rating'] ?? 1000,
                  (data['form_rating'] as num?)?.toDouble() ?? 50.0,
                  data['play_style'] ?? 'Unclassified',
                  data['matches_played'] ?? 0,
                  data['wins'] ?? 0,
                  data['draws'] ?? 0,
                  data['losses'] ?? 0,
                  (data['win_rate'] as num?)?.toDouble() ?? 0.0,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ─── Elo Rating Chart ───
                  _buildSectionHeader('ELO RATING PROGRESSION'),
                  const SizedBox(height: 12),
                  eloAsync.when(
                    loading: () => _buildChartSkeleton(),
                    error: (_, __) => _buildEmptyState('No Elo history yet'),
                    data: (data) {
                      final history = data['history'] as List<dynamic>? ?? [];
                      if (history.isEmpty) return _buildEmptyState('Play matches to track your Elo progression');
                      return _buildEloChart(history);
                    },
                  ),

                  const SizedBox(height: 28),

                  // ─── Career Stats Grid ───
                  _buildSectionHeader('CAREER STATISTICS'),
                  const SizedBox(height: 12),
                  profileAsync.when(
                    loading: () => _buildStatsGridSkeleton(),
                    error: (_, __) => _buildStatsGrid(0, 0, 0, 0, 0.0, 50.0),
                    data: (data) => _buildStatsGrid(
                      data['matches_played'] ?? 0,
                      data['wins'] ?? 0,
                      data['draws'] ?? 0,
                      data['losses'] ?? 0,
                      (data['win_rate'] as num?)?.toDouble() ?? 0.0,
                      (data['form_rating'] as num?)?.toDouble() ?? 50.0,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Match History ───
                  _buildSectionHeader('RECENT MATCHES'),
                  const SizedBox(height: 12),
                  matchesAsync.when(
                    loading: () => Column(
                      children: List.generate(3, (_) => Container(
                        height: 70,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      )),
                    ),
                    error: (_, __) => _buildEmptyState('Could not load match history'),
                    data: (data) {
                      final matches = data['matches'] as List<dynamic>? ?? [];
                      if (matches.isEmpty) return _buildEmptyState('No matches played yet');
                      return Column(
                        children: matches.take(10).map((m) => _buildMatchTile(m)).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ─── Badges ───
                  _buildSectionHeader('EARNED BADGES'),
                  const SizedBox(height: 12),
                  profileAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => _buildEmptyState('No badges yet'),
                    data: (data) {
                      final badges = data['badges'] as List<dynamic>? ?? [];
                      if (badges.isEmpty) return _buildEmptyState('Play more matches to earn badges');
                      return Column(
                        children: badges.map((b) => _buildBadgeTile(
                          b['name'] ?? 'Badge',
                          b['description'] ?? '',
                        )).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(int elo, double form, String style, int played, int wins, int draws, int losses, double winRate) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6D00), Color(0xFFFF9E40)],
                  ),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF6D00).withOpacity(0.4), blurRadius: 20),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$elo ELO',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildMiniTag(style, const Color(0xFFFF6D00)),
                        const SizedBox(width: 8),
                        _buildMiniTag('${winRate.toStringAsFixed(0)}% WR', Colors.white38),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick stat row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('PLAYED', '$played'),
              _buildQuickStat('W', '$wins', color: const Color(0xFF4CAF50)),
              _buildQuickStat('D', '$draws', color: Colors.amber),
              _buildQuickStat('L', '$losses', color: Colors.redAccent),
              _buildQuickStat('FORM', form.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildQuickStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2),
    );
  }

  Widget _buildEloChart(List<dynamic> history) {
    final ratings = history.map((h) => (h['rating_after'] as num).toDouble()).toList();
    final minR = ratings.reduce((a, b) => a < b ? a : b) - 50;
    final maxR = ratings.reduce((a, b) => a > b ? a : b) + 50;
    final range = maxR - minR;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 128),
        painter: _EloChartPainter(ratings, minR, range),
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildChartSkeleton() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildStatsGrid(int played, int wins, int draws, int losses, double winRate, double form) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Matches', '$played', Icons.sports_soccer, const Color(0xFFFF6D00))),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Win Rate', '${winRate.toStringAsFixed(1)}%', Icons.trending_up, const Color(0xFF4CAF50))),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Form', form.toStringAsFixed(1), Icons.auto_graph, Colors.amber)),
      ],
    ).animate().fade(delay: 300.ms);
  }

  Widget _buildStatsGridSkeleton() {
    return Row(
      children: List.generate(3, (_) => Expanded(
        child: Container(
          height: 80,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      )),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildMatchTile(dynamic match) {
    final result = match['result'] ?? 'draw';
    final gf = match['goals_for'] ?? 0;
    final ga = match['goals_against'] ?? 0;
    final opponent = match['opponent_name'] ?? 'Unknown';
    final matchType = match['match_type'] ?? 'friendly';

    Color resultColor;
    IconData resultIcon;
    switch (result) {
      case 'win':
        resultColor = const Color(0xFF4CAF50);
        resultIcon = Icons.arrow_upward;
        break;
      case 'loss':
        resultColor = Colors.redAccent;
        resultIcon = Icons.arrow_downward;
        break;
      default:
        resultColor = Colors.amber;
        resultIcon = Icons.remove;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resultColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: resultColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(resultIcon, color: resultColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs $opponent', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(matchType.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1)),
              ],
            ),
          ),
          Text(
            '$gf - $ga',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: resultColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTile(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6D00).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.military_tech, color: Color(0xFFFF6D00)),
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

  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(message, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

/// Custom painter for the Elo rating line chart.
class _EloChartPainter extends CustomPainter {
  final List<double> ratings;
  final double minR;
  final double range;

  _EloChartPainter(this.ratings, this.minR, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    if (ratings.length < 2) return;

    final paint = Paint()
      ..color = const Color(0xFFFF6D00)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFFF6D00).withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final dotPaint = Paint()..color = const Color(0xFFFF6D00);

    for (int i = 0; i < ratings.length; i++) {
      final x = (i / (ratings.length - 1)) * size.width;
      final y = size.height - ((ratings[i] - minR) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      // Draw dot for last point
      if (i == ratings.length - 1) {
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, gradientPaint);
    canvas.drawPath(path, paint);

    // Draw baseline
    final baselinePaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), baselinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
