import re

with open('lib/presentation/screens/squad_verification_screen.dart', 'r') as f:
    content = f.read()

new_content = """import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/match_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mps_radar_chart.dart';

/// Pre-match tournament lobby to ensure team strength compliance before playing.
class TournamentLobbyScreen extends ConsumerStatefulWidget {
  const TournamentLobbyScreen({super.key});

  @override
  ConsumerState<TournamentLobbyScreen> createState() => _TournamentLobbyScreenState();
}

class _TournamentLobbyScreenState extends ConsumerState<TournamentLobbyScreen> {
  final _matchIdCtrl = TextEditingController();
  final _teamStrengthCtrl = TextEditingController(text: '2850');
  final _screenshotUrlCtrl = TextEditingController(text: 'https://example.com/squad.png');
  final int _maxTeamStrengthLimit = 2900;
  
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  bool _isValid = false;
  String? _errorMessage;

  @override
  void dispose() {
    _matchIdCtrl.dispose();
    _teamStrengthCtrl.dispose();
    _screenshotUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifySquad() async {
    final matchId = _matchIdCtrl.text.trim();
    final strength = int.tryParse(_teamStrengthCtrl.text) ?? 0;
    final screenshotUrl = _screenshotUrlCtrl.text.trim();

    if (matchId.isEmpty) {
      setState(() {
        _errorMessage = 'Tournament Match ID is required.';
        _hasSubmitted = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _hasSubmitted = false;
    });

    try {
      final client = ref.read(apiClientProvider);
      
      final result = await client.submitSquadCheck(
        tMatchId: matchId,
        teamStrength: strength,
        screenshotUrl: screenshotUrl,
        maxStrength: _maxTeamStrengthLimit,
      );

      setState(() {
        _isValid = result['is_valid'] ?? false;
        _hasSubmitted = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to submit verification: $e';
      });
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('MATCH ROOM LOBBY', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Radar Chart visualization for "Squad Analysis"
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const MpsRadarChart(
                    dataScores: [85, 90, 78, 88, 92, 80],
                    size: 200,
                  ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Text('SQUAD ANALYSIS ACTIVE', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tournament Rules Header
            GlassCard(
              borderColor: AppColors.primary.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('SQUAD STRENGTH COMPLIANCE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, letterSpacing: 1.2)),
                      ),
                      GlowBadge(label: 'MAX $_maxTeamStrengthLimit', color: AppColors.primary),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Both players must upload and verify their squad before the match can officially begin.',
                      style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ).animate().fade().slideY(begin: 0.1),
            const SizedBox(height: 20),
            
            // Opponent Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: AppColors.cyan).animate().rotate(duration: 2.seconds).repeat(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('WAITING FOR OPPONENT CHECK-IN...', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: 0.1, delay: 100.ms),
            const SizedBox(height: 24),

            // Form Inputs
            Text('VERIFICATION DATA', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12)),
            const SizedBox(height: 12),
            _buildInputField(_matchIdCtrl, 'Tournament Match ID (UUID)', Icons.tag),
            const SizedBox(height: 12),
            _buildInputField(_teamStrengthCtrl, 'Extracted Team Strength', Icons.fitness_center, isNumber: true),
            const SizedBox(height: 12),
            _buildInputField(_screenshotUrlCtrl, 'Screenshot Evidence URL', Icons.image),
            const SizedBox(height: 32),

            // Submit Button
            EsportsButton(
              label: _isSubmitting ? 'VERIFYING SQUAD...' : 'READY UP',
              icon: Icons.sports_esports,
              isLoading: _isSubmitting,
              gradient: const [AppColors.primary, Color(0xFFFF6D00)],
              onPressed: _isSubmitting ? () {} : _verifySquad,
            ).animate().scale(delay: 300.ms),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.lossRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(_errorMessage!, style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold)),
              ).animate().shake(),
            ],

            // Result Alert
            if (_hasSubmitted && _errorMessage == null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _isValid ? AppColors.winGreen.withValues(alpha: 0.15) : AppColors.lossRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _isValid ? AppColors.winGreen : AppColors.lossRed, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle : Icons.cancel,
                      color: _isValid ? AppColors.winGreen : AppColors.lossRed,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isValid ? 'SQUAD VERIFIED & READY' : 'SQUAD REJECTED',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _isValid ? AppColors.winGreen : AppColors.lossRed,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isValid
                                ? 'Your squad is compliant. Waiting for opponent...'
                                : 'Team Strength exceeds the $_maxTeamStrengthLimit limit.',
                            style: GoogleFonts.rajdhani(
                              color: _isValid ? AppColors.winGreen : AppColors.lossRed,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().scale(curve: Curves.elasticOut),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: Colors.white38),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
      ),
    ).animate().fade().slideX(begin: 0.05);
  }
}
"""

with open('lib/presentation/screens/squad_verification_screen.dart', 'w') as f:
    f.write(new_content)
print('Redesigned Lobby!')
