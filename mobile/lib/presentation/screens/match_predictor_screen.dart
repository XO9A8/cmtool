import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/api_client.dart';

class MatchPredictorScreen extends ConsumerStatefulWidget {
  const MatchPredictorScreen({super.key});

  @override
  ConsumerState<MatchPredictorScreen> createState() => _MatchPredictorScreenState();
}

class _MatchPredictorScreenState extends ConsumerState<MatchPredictorScreen> {
  int _r1 = 1200;
  int _r2 = 1100;
  int _h2h1 = 3;
  int _h2h2 = 1;

  @override
  Widget build(BuildContext context) {
    final predictAsync = ref.watch(matchPredictionProvider(
      PredictParams(p1Rating: _r1, p2Rating: _r2, p1H2hWins: _h2h1, p2H2hWins: _h2h2),
    ));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MATCH OUTCOME PREDICTOR',
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.cyan,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Powered by Skill Rating & H2H Ratios',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Player 1 Control
          GlassCard(
            borderColor: AppColors.primary.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Player 1 Rating', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16)),
                    GlowBadge(label: '$_r1 PTS', color: AppColors.primary),
                  ],
                ),
                Slider(
                  value: _r1.toDouble(),
                  min: 800,
                  max: 2200,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _r1 = v.toInt()),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Player 2 Control
          GlassCard(
            borderColor: AppColors.cyan.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Player 2 Rating', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16)),
                    GlowBadge(label: '$_r2 PTS', color: AppColors.cyan),
                  ],
                ),
                Slider(
                  value: _r2.toDouble(),
                  min: 800,
                  max: 2200,
                  activeColor: AppColors.cyan,
                  onChanged: (v) => setState(() => _r2 = v.toInt()),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Prediction Output Card
          predictAsync.when(
            loading: () => Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            error: (err, _) => GlassCard(
              child: Text('Prediction API error: ${ApiClient.formatErrorMessage(err)}', style: const TextStyle(color: Colors.redAccent)),
            ),
            data: (res) {
              final double p1Win = ((res['p1_win_probability'] ?? 0.5) as num).toDouble() * 100;
              final double p2Win = ((res['p2_win_probability'] ?? 0.5) as num).toDouble() * 100;

              return GlassCard(
                gradientColors: const [Color(0xFF191C2B), Color(0xFF0F111A)],
                borderColor: AppColors.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'AI PREDICTED WIN PROBABILITY',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${p1Win.toStringAsFixed(1)}%',
                              style: GoogleFonts.rajdhani(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Player 1', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, color: Colors.white70)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('VS', style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, color: Colors.white54)),
                        ),
                        Column(
                          children: [
                            Text(
                              '${p2Win.toStringAsFixed(1)}%',
                              style: GoogleFonts.rajdhani(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: AppColors.cyan,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Player 2', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, color: Colors.white70)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
