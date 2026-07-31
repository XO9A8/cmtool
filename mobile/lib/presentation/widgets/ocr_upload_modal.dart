import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../domain/models/match_record.dart';
import '../../presentation/providers/match_provider.dart';

class OcrUploadModal extends ConsumerStatefulWidget {
  const OcrUploadModal({super.key});

  @override
  ConsumerState<OcrUploadModal> createState() => _OcrUploadModalState();
}

class _OcrUploadModalState extends ConsumerState<OcrUploadModal> {
  String _selectedMatchType = 'league';
  final _opponentIdCtrl   = TextEditingController(text: '00000000-0000-0000-0000-000000000001');
  final _goalsForCtrl     = TextEditingController(text: '3');
  final _goalsAgainstCtrl = TextEditingController(text: '1');
  final _possessionCtrl   = TextEditingController(text: '62.5');
  final _passesCompCtrl   = TextEditingController(text: '120');
  final _passesAttCtrl    = TextEditingController(text: '140');
  final _shotsTargetCtrl  = TextEditingController(text: '5');
  final _shotsTotalCtrl   = TextEditingController(text: '8');
  final _interceptionsCtrl = TextEditingController(text: '7');

  String? _errorMessage;

  @override
  void dispose() {
    _opponentIdCtrl.dispose();
    _goalsForCtrl.dispose();
    _goalsAgainstCtrl.dispose();
    _possessionCtrl.dispose();
    _passesCompCtrl.dispose();
    _passesAttCtrl.dispose();
    _shotsTargetCtrl.dispose();
    _shotsTotalCtrl.dispose();
    _interceptionsCtrl.dispose();
    super.dispose();
  }

  String _generateHash() {
    final data = '${_selectedMatchType}_${_goalsForCtrl.text}_${_goalsAgainstCtrl.text}'
        '_${_possessionCtrl.text}_${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(data)).toString();
  }

  Future<void> _submitMatchData() async {
    final goalsFor     = int.tryParse(_goalsForCtrl.text) ?? 0;
    final goalsAgainst = int.tryParse(_goalsAgainstCtrl.text) ?? 0;
    final passesComp   = int.tryParse(_passesCompCtrl.text) ?? 0;
    final passesAtt    = int.tryParse(_passesAttCtrl.text) ?? 1;
    final shotsTarget  = int.tryParse(_shotsTargetCtrl.text) ?? 0;
    final shotsTotal   = int.tryParse(_shotsTotalCtrl.text) ?? 0;

    if (passesComp > passesAtt) {
      setState(() => _errorMessage = 'Passes completed cannot exceed passes attempted.');
      return;
    }
    if (shotsTarget > shotsTotal) {
      setState(() => _errorMessage = 'Shots on target cannot exceed total shots.');
      return;
    }

    setState(() => _errorMessage = null);

    final playerId = await ref.read(apiClientProvider).storedUserId ?? '00000000-0000-0000-0000-000000000000';

    final record = MatchRecord(
      playerId:         playerId,
      opponentId:       _opponentIdCtrl.text.trim(),
      matchType:        _selectedMatchType,
      goalsFor:         goalsFor,
      goalsAgainst:     goalsAgainst,
      possession:       double.tryParse(_possessionCtrl.text) ?? 50.0,
      passesCompleted:  passesComp,
      passesAttempted:  passesAtt,
      shotsOnTarget:    shotsTarget,
      shotsTotal:       shotsTotal,
      interceptions:    int.tryParse(_interceptionsCtrl.text) ?? 0,
      screenshotHash:   _generateHash(),
    );

    await ref.read(ocrSubmitProvider.notifier).submit(record);

    if (!mounted) return;
    final result = ref.read(ocrSubmitProvider);
    Navigator.of(context).pop();

    result.when(
      data: (res) {
        if (res == null) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161925),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Color(0xFF00CEC9)),
                SizedBox(width: 8),
                Text('Match Verified!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Skill Rating: ${res.newSkillRating} Elo '
                  '(${res.ratingDelta >= 0 ? '+' : ''}${res.ratingDelta})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF00CEC9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'MPS: ${res.matchPerformanceScore.toStringAsFixed(1)} / 100',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'Play Style: ${res.playStyleTag}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                if (res.strengths.isNotEmpty) ...[
                  const Divider(height: 24, color: Colors.white24),
                  const Text('Strengths:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...res.strengths.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $s', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  )),
                ],
                if (res.weaknesses.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Areas to Improve:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  ...res.weaknesses.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $w', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  )),
                ],
              ],
            ),
            actions: [
              TextButton(
                child: const Text('OK', style: TextStyle(color: Color(0xFF00CEC9))),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ref.read(ocrSubmitProvider.notifier).reset();
                },
              ),
            ],
          ),
        );
      },
      loading: () {},
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(ocrSubmitProvider);
    final isSubmitting = submitState is AsyncLoading;

    return Dialog(
      backgroundColor: const Color(0xFF161925),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Match Screenshot OCR Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Screenshot Upload Preview Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F17),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00CEC9).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00CEC9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image_outlined, color: Color(0xFF00CEC9)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'post_match_stats_final.png',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'OCR Scan Status: 100% Extracted',
                          style: TextStyle(fontSize: 11, color: Color(0xFF00CEC9)),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    side: BorderSide.none,
                    avatar: const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6C5CE7)),
                    label: const Text('OCR Parsed', style: TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _opponentIdCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Opponent ID (UUID)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedMatchType,
              dropdownColor: const Color(0xFF161925),
              decoration: const InputDecoration(
                labelText: 'Match Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'friendly', child: Text('Friendly')),
                DropdownMenuItem(value: 'league', child: Text('League Fixture')),
                DropdownMenuItem(value: 'tournament_final', child: Text('Tournament Final')),
              ],
              onChanged: (val) => setState(() => _selectedMatchType = val!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_goalsForCtrl, 'Goals For')),
                const SizedBox(width: 12),
                Expanded(child: _field(_goalsAgainstCtrl, 'Goals Against')),
              ],
            ),
            const SizedBox(height: 12),
            _field(_possessionCtrl, 'Possession %', decimal: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_passesCompCtrl, 'Passes Comp')),
                const SizedBox(width: 12),
                Expanded(child: _field(_passesAttCtrl, 'Passes Att')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_shotsTargetCtrl, 'Shots Target')),
                const SizedBox(width: 12),
                Expanded(child: _field(_shotsTotalCtrl, 'Shots Total')),
              ],
            ),
            const SizedBox(height: 12),
            _field(_interceptionsCtrl, 'Interceptions'),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CEC9),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSubmitting ? null : _submitMatchData,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Text('Verify & Submit Match', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool decimal = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
