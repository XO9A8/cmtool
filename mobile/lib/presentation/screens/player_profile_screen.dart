import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../widgets/mps_radar_chart.dart';

/// Full Player Profile screen with career stats, Elo history chart,
/// match history timeline, badges, and shareable Ultimate Team card preview.
class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider) ?? '';
    final profileAsync = ref.watch(playerProfileProvider(userId));
    final eloAsync = ref.watch(eloHistoryProvider(userId));
    final matchesAsync = ref.watch(matchHistoryProvider(userId));
    final profilePrefs = ref.watch(profilePreferencesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Collapsing header with player card
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => _buildHeroCard(context, 0, 0.0, '—', 0, 0, 0, 0, 0.0),
                data: (data) => _buildHeroCard(
                  context,
                  data['skill_rating'] ?? 0,
                  (data['form_rating'] as num?)?.toDouble() ?? 0.0,
                  (data['play_style'] as String?)?.isNotEmpty == true
                      ? data['play_style']
                      : profilePrefs.playStyle,
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

                  // ─── Player Dossier, Contact & Compliance ───
                  profileAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPlayerDossierCard(data),
                        const SizedBox(height: 16),
                        _buildRegistryContactCard(data),
                        const SizedBox(height: 16),
                        _buildComplianceVerificationCard(data),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),

                  // ─── Shareable Ultimate Team Card Preview ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('SHAREABLE ULTIMATE TEAM CARD'),
                      TextButton.icon(
                        icon: const Icon(Icons.share, size: 16, color: AppColors.cyan),
                        label: Text('PREVIEW CARD', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _showUltimateCardPreview(context, profileAsync),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ─── Rating Chart ───
                  _buildSectionHeader('SKILL RATING PROGRESSION'),
                  const SizedBox(height: 12),
                  eloAsync.when(
                    loading: () => _buildChartSkeleton(),
                    error: (_, __) => _buildEmptyState('No rating history yet'),
                    data: (data) {
                      final history = data['history'] as List<dynamic>? ?? [];
                      if (history.isEmpty) return _buildEmptyState('Play matches to track your rating progression');
                      return _buildEloChart(history);
                    },
                  ),

                  const SizedBox(height: 28),

                  // ─── Career Stats Grid ───
                  _buildSectionHeader('CAREER STATISTICS'),
                  const SizedBox(height: 12),
                  profileAsync.when(
                    loading: () => _buildStatsGridSkeleton(),
                    error: (_, __) => _buildStatsGrid(0, 0, 0, 0, 0.0, 0.0),
                    data: (data) => _buildStatsGrid(
                      data['matches_played'] ?? 0,
                      data['wins'] ?? 0,
                      data['draws'] ?? 0,
                      data['losses'] ?? 0,
                      (data['win_rate'] as num?)?.toDouble() ?? 0.0,
                      (data['form_rating'] as num?)?.toDouble() ?? 0.0,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Visual MPS Breakdown (Radar Chart) ───
                  _buildSectionHeader('MATCH PERFORMANCE BREAKDOWN'),
                  const SizedBox(height: 12),
                  profileAsync.when(
                    loading: () => _buildChartSkeleton(),
                    error: (_, __) => _buildEmptyState('Could not load analytics'),
                    data: (data) {
                      final analytics = data;
                      // Fallback stats if actual aren't in profile endpoint yet
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: MpsRadarChart(
                          possession: (analytics['avg_possession'] as num?)?.toDouble() ?? 0.0,
                          passAccuracy: (analytics['avg_pass_accuracy'] as num?)?.toDouble() ?? 80.0,
                          shotEfficiency: (analytics['avg_shot_efficiency'] as num?)?.toDouble() ?? 30.0,
                          interceptions: (analytics['avg_interceptions'] as num?)?.toDouble() ?? 5.0,
                          formRating: (analytics['form_rating'] as num?)?.toDouble() ?? 0.0,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // ─── Match History ───
                  _buildSectionHeader('RECENT MATCHES & DISPUTES'),
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
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 0.6),
                    error: (_, __) => _buildEmptyState('Could not load match history'),
                    data: (data) {
                      final matches = data['matches'] as List<dynamic>? ?? [];
                      if (matches.isEmpty) return _buildEmptyState('No matches played yet');
                      return Column(
                        children: matches.take(10).map((m) => _buildMatchTile(context, ref, m)).toList(),
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

  void _showUltimateCardPreview(BuildContext context, AsyncValue<Map<String, dynamic>> profileAsync) {
    final data = profileAsync.asData?.value ?? {};
    final int elo = data['skill_rating'] ?? 0;
    final double form = (data['form_rating'] as num?)?.toDouble() ?? 0.0;
    final double winRate = (data['win_rate'] as num?)?.toDouble() ?? 0.0;
    final String playStyle = (data['play_style'] as String?)?.isNotEmpty == true
        ? data['play_style']
        : '—';
    final String username = (data['username'] as String?)?.isNotEmpty == true
        ? data['username']
        : 'PLAYER';
    final screenshotController = ScreenshotController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Screenshot(
          controller: screenshotController,
          child: GlassCard(
            gradientColors: const [Color(0xFF332005), Color(0xFF141624)],
            borderColor: const Color(0xFFFFD700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'eFOOTBALL ULTIMATE CARD',
                  style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700), letterSpacing: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.4), blurRadius: 20),
                    ],
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
                              Text('RATING', style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ],
                          ),
                          const Icon(Icons.sports_soccer, size: 36, color: Colors.black),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Icon(Icons.person, size: 64, color: Colors.black),
                      const SizedBox(height: 12),
                      Text(username.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text(playStyle, style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${winRate.toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              Text('WIN RATE', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(form.toStringAsFixed(1), style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              Text('FORM', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    EsportsButton(
                      label: 'CLOSE',
                      textColor: Colors.black,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    EsportsButton(
                      label: 'SHARE',
                      icon: Icons.share,
                      gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
                      onPressed: () async {
                        try {
                          final image = await screenshotController.capture();
                          if (image != null) {
                            final directory = await getTemporaryDirectory();
                            final imagePath = await File('${directory.path}/ultimate_card.png').create();
                            await imagePath.writeAsBytes(image);
                            await Share.shareXFiles([XFile(imagePath.path)], text: 'Check out my eFootball Ultimate Team Card on Club Manager!');
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, int elo, double form, String style, int played, int wins, int draws, int losses, double winRate) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF231408), Color(0xFF12141F), Color(0xFF090A0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20),
                  ],
                ),
                child: const Icon(Icons.person, color: Colors.black, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$elo PTS',
                      style: GoogleFonts.orbitron(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GlowBadge(label: style.toString(), color: AppColors.cyan),
                        const SizedBox(width: 8),
                        GlowBadge(label: '${winRate.toStringAsFixed(0)}% WR', color: Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickStat('PLAYED', '$played'),
              _buildQuickStat('W', '$wins', color: AppColors.winGreen),
              _buildQuickStat('D', '$draws', color: Colors.amber),
              _buildQuickStat('L', '$losses', color: AppColors.lossRed),
              _buildQuickStat('FORM', form.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _buildQuickStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, letterSpacing: 1, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.8),
    );
  }

  Widget _buildEloChart(List<dynamic> history) {
    final ratings = history.map((h) => (h['rating_after'] as num).toDouble()).toList();
    final minR = ratings.reduce((a, b) => a < b ? a : b) - 50;
    final maxR = ratings.reduce((a, b) => a > b ? a : b) + 50;
    final range = maxR - minR;

    return GlassCard(
      borderColor: AppColors.primary.withOpacity(0.4),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 140,
        child: CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _EloChartPainter(ratings, minR, range),
        ),
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildChartSkeleton() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 0.6);
  }

  Widget _buildStatsGrid(int played, int wins, int draws, int losses, double winRate, double form) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Matches', '$played', Icons.sports_soccer, AppColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Win Rate', '${winRate.toStringAsFixed(1)}%', Icons.trending_up, AppColors.winGreen)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Form', form.toStringAsFixed(1), Icons.auto_graph, AppColors.cyan)),
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
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 0.6);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      borderColor: color.withOpacity(0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMatchTile(BuildContext context, WidgetRef ref, dynamic match) {
    final result = match['result'] ?? 'draw';
    final gf = match['goals_for'] ?? 0;
    final ga = match['goals_against'] ?? 0;
    final opponent = match['opponent_name'] ?? 'Unknown';
    final matchType = match['match_type'] ?? 'friendly';
    final matchId = match['id']?.toString() ?? '';

    Color resultColor;
    IconData resultIcon;
    switch (result) {
      case 'win':
        resultColor = AppColors.winGreen;
        resultIcon = Icons.arrow_upward;
        break;
      case 'loss':
        resultColor = AppColors.lossRed;
        resultIcon = Icons.arrow_downward;
        break;
      default:
        resultColor = Colors.amber;
        resultIcon = Icons.remove;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: resultColor.withOpacity(0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match['is_coop'] == true 
                            ? 'vs ${opponent} & ${match['opponent_partner'] ?? 'Unknown'}'
                            : 'vs $opponent',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match['has_ai_insight'] == true)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.5)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppColors.cyan, size: 12),
                      ),
                  ],
                ),
                if (match['is_coop'] == true)
                  Text('w/ ${match['partner_name'] ?? 'Unknown'}', style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.primary)),
                Text(matchType.toString().toUpperCase(), style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(
            '$gf - $ga',
            style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.bold, color: resultColor),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.gavel, size: 18, color: Colors.amber),
            tooltip: 'Raise Dispute',
            onPressed: () => _showDisputeDialog(context, ref, matchId),
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog(BuildContext context, WidgetRef ref, String matchId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amber)),
        title: Text('RAISE MATCH DISPUTE', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          style: GoogleFonts.rajdhani(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Reason for Dispute',
            labelStyle: TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white10,
          ),
        ),
        actions: [
          TextButton(
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text('SUBMIT DISPUTE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final client = ref.read(apiClientProvider);
                await client.submitDispute(matchRecordId: matchId, reason: reasonCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ Dispute submitted for official review!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit dispute: $e'),
                      backgroundColor: AppColors.lossRed,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTile(String title, String desc) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: AppColors.primary.withOpacity(0.3),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.military_tech, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
    );
  }

  Widget _buildPlayerDossierCard(Map<String, dynamic> data) {
    final gameId = data['efootball_game_id'] ?? 'N/A';
    final foot = data['preferred_foot'] ?? 'N/A';
    final jersey = data['jersey_number']?.toString() ?? 'N/A';
    final device = data['system_device'] ?? 'N/A';
    final facebook = data['facebook'] ?? 'N/A';
    final blood = data['blood_group'] ?? 'N/A';
    final district = data['district'] ?? 'N/A';
    final dob = data['date_of_birth'] ?? 'N/A';
    final joined = data['registrar_joined'] ?? 'N/A';
    final start = data['contract_start'] ?? 'N/A';
    final end = data['contract_end'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090A0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, size: 16, color: Color(0xFFFFD700)),
              const SizedBox(width: 6),
              Text(
                'PLAYER DOSSIER',
                style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No biometric bio profile submitted to registry.',
            style: GoogleFonts.shareTechMono(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          _buildDossierRow('EFOOTBALL GAME ID', gameId, valColor: Colors.white),
          _buildDossierRow('PREFERRED FOOT', foot, valColor: Colors.white),
          _buildDossierRow('JERSEY NUMBER', jersey, valColor: Colors.white),
          _buildDossierRow('SYSTEM DEVICE', device, valColor: Colors.white),
          _buildDossierRow('FACEBOOK', facebook, valColor: Colors.white70),
          _buildDossierRow('BLOOD GROUP', blood, valColor: Colors.white),
          _buildDossierRow('DISTRICT', district, valColor: Colors.white),
          _buildDossierRow('DATE OF BIRTH', dob, valColor: Colors.white),
          _buildDossierRow('REGISTRAR JOINED', joined, valColor: Colors.white),
          _buildDossierRow('CONTRACT START', start, valColor: Colors.white),
          _buildDossierRow('CONTRACT END', end, valColor: const Color(0xFFFFD700), isBold: true),
        ],
      ),
    );
  }

  Widget _buildRegistryContactCard(Map<String, dynamic> data) {
    final fbLink = data['facebook_link'] ?? 'N/A';
    final email = data['email_node'] ?? 'N/A';
    final phone = data['phone_line'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090A0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REGISTRY CONTACT',
            style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          _buildDossierRow('FACEBOOK LINK', fbLink, valColor: const Color(0xFF00E5FF)),
          _buildDossierRow('EMAIL NODE', email, valColor: const Color(0xFFFFD700)),
          _buildDossierRow('PHONE LINE', phone, valColor: const Color(0xFF00FFC2)),
        ],
      ),
    );
  }

  Widget _buildComplianceVerificationCard(Map<String, dynamic> data) {
    final state = data['node_state'] ?? 'N/A';
    final authStatus = data['auth_status'] ?? 'N/A';
    final feed = data['source_feed'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090A0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMPLIANCE VERIFICATION',
            style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          _buildDossierRow('NODE STATE', state, valColor: const Color(0xFF00FF66), isBold: true),
          _buildDossierRow('AUTH STATUS', authStatus, valColor: Colors.white, isBold: true),
          _buildDossierRow('SOURCE FEED', feed, valColor: const Color(0xFFFFD700), isBold: true),
        ],
      ),
    );
  }

  Widget _buildDossierRow(String label, String value, {Color valColor = Colors.white, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.shareTechMono(fontSize: 11, color: Colors.white38, letterSpacing: 1),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.shareTechMono(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EloChartPainter extends CustomPainter {
  final List<double> ratings;
  final double minR;
  final double range;

  _EloChartPainter(this.ratings, this.minR, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    if (ratings.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = AppColors.cyan;

    if (ratings.length == 1) {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      canvas.drawCircle(Offset(size.width / 2, y), 6, dotPaint);
      return;
    }

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withOpacity(0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < ratings.length; i++) {
      final x = (i / (ratings.length - 1)) * size.width;
      final y = size.height - ((ratings[i] - minR) / (range == 0 ? 1 : range)) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == ratings.length - 1) {
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, gradientPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
