import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final int _h2h1 = 3;
  final int _h2h2 = 1;

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
          Text(
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
              child: Text('Prediction API error: ${ApiClient.formatErrorMessage(err)}', style: TextStyle(color: AppColors.lossRed)),
            ),
            data: (res) {
              final double p1Raw = ((res['player_1_win_prob'] ?? res['player_1_win_probability'] ?? res['p1_win_probability'] ?? 0.39) as num).toDouble();
              final double drawRaw = ((res['draw_prob'] ?? res['draw_probability'] ?? 0.22) as num).toDouble();
              final double p2Raw = ((res['player_2_win_prob'] ?? res['player_2_win_probability'] ?? res['p2_win_probability'] ?? 0.39) as num).toDouble();

              final double p1Win = (p1Raw * 100).clamp(1.0, 98.0);
              final double draw = (drawRaw * 100).clamp(1.0, 98.0);
              final double p2Win = (p2Raw * 100).clamp(1.0, 98.0);

              return GlassCard(
                gradientColors: [AppColors.surfaceLight, AppColors.surface],
                borderColor: AppColors.primary.withValues(alpha: 0.5),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'AI PREDICTED MATCH OUTCOME',
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
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Player 1 Win', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${draw.toStringAsFixed(1)}%',
                              style: GoogleFonts.rajdhani(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.amber,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Draw', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, color: AppColors.textDim, fontSize: 13)),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${p2Win.toStringAsFixed(1)}%',
                              style: GoogleFonts.rajdhani(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: AppColors.cyan,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Player 2 Win', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            Expanded(
                              flex: (p1Win * 10).toInt(),
                              child: Container(color: AppColors.primary),
                            ),
                            Expanded(
                              flex: (draw * 10).toInt(),
                              child: Container(color: AppColors.amber.withValues(alpha: 0.8)),
                            ),
                            Expanded(
                              flex: (p2Win * 10).toInt(),
                              child: Container(color: AppColors.cyan),
                            ),
                          ],
                        ),
                      ),
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
