import 'package:flutter/material.dart';

class OcrUploadModal extends StatefulWidget {
  const OcrUploadModal({super.key});

  @override
  State<OcrUploadModal> createState() => _OcrUploadModalState();
}

class _OcrUploadModalState extends State<OcrUploadModal> {
  String _selectedMatchType = 'league';
  final _goalsForCtrl = TextEditingController(text: '3');
  final _goalsAgainstCtrl = TextEditingController(text: '1');
  final _possessionCtrl = TextEditingController(text: '62.5');
  final _passesCompCtrl = TextEditingController(text: '120');
  final _passesAttCtrl = TextEditingController(text: '140');
  final _shotsTargetCtrl = TextEditingController(text: '5');
  final _shotsTotalCtrl = TextEditingController(text: '8');
  final _interceptionsCtrl = TextEditingController(text: '7');

  bool _isSubmitting = false;

  void _submitMatchData() async {
    setState(() => _isSubmitting = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161925),
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
            const Text('New Skill Rating: 1,438 Elo (+18)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00CEC9))),
            const SizedBox(height: 6),
            const Text('Match Performance Score (MPS): 70.2 / 100',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            const Text('Play Style Tag: Possession Master',
                style: TextStyle(fontSize: 14, color: Colors.white70)),
            const Divider(height: 24, color: Colors.white24),
            const Text('AI Coaching Insights:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('• You won 3-1 with 62.5% possession.', style: TextStyle(fontSize: 12, color: Colors.white70)),
            const Text('• Passing accuracy (85.7%) exceeded season avg.', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Color(0xFF00CEC9))),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF161925),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Match Screenshot OCR Verification',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
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
                Expanded(
                  child: TextField(
                    controller: _goalsForCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Goals For', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _goalsAgainstCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Goals Against', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _possessionCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Possession %', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _passesCompCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Passes Comp', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _passesAttCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Passes Att', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _shotsTargetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Shots Target', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _shotsTotalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Shots Total', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _interceptionsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Interceptions', border: OutlineInputBorder()),
            ),
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
                onPressed: _isSubmitting ? null : _submitMatchData,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Verify & Submit Match', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
