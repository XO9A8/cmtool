import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';

import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

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
      
      // Perform API call to persist the verification result
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
        title: Text('TOURNAMENT LOBBY', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tournament Rules Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text('Squad Strength Limit', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Maximum allowed Team Strength: $_maxTeamStrengthLimit',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Both players must upload and verify their squad before the match can officially begin.',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Opponent Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: AppColors.cyan),
                  const SizedBox(width: 12),
                  const Text('Waiting for opponent check-in...', style: TextStyle(color: AppColors.cyan, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Inputs
            TextField(
              controller: _matchIdCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tournament Match ID (UUID)',
                labelStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.tag, color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _teamStrengthCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Extracted Team Strength',
                labelStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.fitness_center, color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _screenshotUrlCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Screenshot Evidence URL',
                labelStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.image, color: Colors.white38),
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.verified_user),
                label: Text(
                  _isSubmitting ? 'VERIFYING...' : 'UPLOAD SQUAD & CHECK-IN',
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16),
                ),
                onPressed: _isSubmitting ? null : _verifySquad,
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            ],

            // Result Alert
            if (_hasSubmitted && _errorMessage == null) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isValid
                      ? AppColors.winGreen.withOpacity(0.15)
                      : AppColors.lossRed.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isValid ? AppColors.winGreen : AppColors.lossRed),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle : Icons.cancel,
                      color: _isValid ? AppColors.winGreen : AppColors.lossRed,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isValid ? 'CHECK-IN COMPLETE' : 'SQUAD REJECTED',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _isValid ? AppColors.winGreen : AppColors.lossRed,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isValid
                                ? 'Your squad is compliant. Waiting for opponent...'
                                : 'Team Strength exceeds the $_maxTeamStrengthLimit limit.',
                            style: TextStyle(
                              color: _isValid ? AppColors.winGreen : AppColors.lossRed,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
