import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider) ?? '';
    final profileAsync = ref.watch(playerProfileProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text('BADGES & PLAYER CARD', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Failed to load player badges: $e', style: const TextStyle(color: Colors.redAccent))),
        data: (data) {
          final elo = data['skill_rating'] ?? 0;
          final form = (data['form_rating'] as num?)?.toDouble() ?? 0.0;
          final style = data['play_style'] ?? '—';
          final username = (data['username'] as String?)?.isNotEmpty == true ? data['username'] : 'Player';
          final winRate = (data['win_rate'] as num?)?.toDouble() ?? 0.0;
          final badges = data['badges'] as List<dynamic>? ?? [];

          return SingleChildScrollView(
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
                        colors: [AppColors.primary, Color(0xFFCC5500)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      border: Border.all(color: Colors.white70, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$elo', style: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
                                Text('ELO', style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                            ),
                            const Icon(Icons.sports_soccer, size: 40, color: Colors.black87),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.black12,
                          child: Icon(Icons.person, size: 50, color: Colors.black),
                        ),
                        const SizedBox(height: 12),
                        Text(username, style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                        Text(style, style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                        const Divider(color: Colors.black26, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('${winRate.toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                                Text('WIN RATE', style: GoogleFonts.rajdhani(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                Text('$elo', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                                Text('ELO', style: GoogleFonts.rajdhani(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                Text(form.toStringAsFixed(1), style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                                Text('FORM', style: GoogleFonts.rajdhani(fontSize: 9, color: Colors.black54, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('EARNED CLUB BADGES', style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                if (badges.isEmpty) ...[
                  _buildBadgeTile('Club Veteran', 'Recorded official club matches', Icons.military_tech),
                  _buildBadgeTile('Unstoppable Force', 'Achieved a winning streak', Icons.bolt),
                  _buildBadgeTile('Clean Sheet Master', 'Conceded 0 goals in matches', Icons.shield),
                ] else ...[
                  ...badges.map((b) => _buildBadgeTile(
                    b['name'] ?? 'Badge',
                    b['description'] ?? '',
                    Icons.military_tech,
                  )),
                ],
              ],
            ),
          );
        },
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
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
