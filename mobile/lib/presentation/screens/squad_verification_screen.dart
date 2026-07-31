import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/match_provider.dart';

/// Pre-match squad verification screen to ensure team strength compliance.
class SquadVerificationScreen extends ConsumerStatefulWidget {
  const SquadVerificationScreen({super.key});

  @override
  ConsumerState<SquadVerificationScreen> createState() => _SquadVerificationScreenState();
}

class _SquadVerificationScreenState extends ConsumerState<SquadVerificationScreen> {
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
      appBar: AppBar(
        title: const Text('Pre-Match Squad Verification', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.gavel, color: Color(0xFFFF6D00), size: 20),
                      SizedBox(width: 8),
                      Text('Tournament Squad Rule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Maximum allowed Team Strength: $_maxTeamStrengthLimit',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('Submit your squad details before starting the match to avoid disqualification.',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
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
                  backgroundColor: const Color(0xFFFF6D00),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Icon(Icons.verified_user),
                label: Text(
                  _isSubmitting ? 'VERIFYING...' : 'VERIFY SQUAD RULES',
                  style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
                      ? const Color(0xFF4CAF50).withOpacity(0.15)
                      : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isValid ? const Color(0xFF4CAF50) : Colors.redAccent),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle : Icons.cancel,
                      color: _isValid ? const Color(0xFF4CAF50) : Colors.redAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isValid ? 'SQUAD APPROVED' : 'SQUAD REJECTED',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _isValid ? const Color(0xFF4CAF50) : Colors.redAccent,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isValid
                                ? 'Team Strength is compliant. Result recorded.'
                                : 'Team Strength exceeds the $_maxTeamStrengthLimit limit.',
                            style: TextStyle(
                              color: _isValid ? const Color(0xFF4CAF50) : Colors.redAccent,
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
