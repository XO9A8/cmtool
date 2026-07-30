import 'package:flutter/material.dart';

class SquadVerificationScreen extends StatefulWidget {
  const SquadVerificationScreen({super.key});

  @override
  State<SquadVerificationScreen> createState() => _SquadVerificationScreenState();
}

class _SquadVerificationScreenState extends State<SquadVerificationScreen> {
  final _teamStrengthCtrl = TextEditingController(text: '2850');
  final int _maxTeamStrengthLimit = 2900;
  bool _isValid = true;
  bool _hasSubmitted = false;

  void _verifySquad() {
    final strength = int.tryParse(_teamStrengthCtrl.text) ?? 0;
    setState(() {
      _hasSubmitted = true;
      _isValid = strength <= _maxTeamStrengthLimit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-Match Squad Verification'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161925),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tournament Squad Rule',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Maximum allowed Team Strength: $_maxTeamStrengthLimit',
                      style: const TextStyle(color: Color(0xFF00CEC9), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _teamStrengthCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Extracted Team Strength',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Verify Squad Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _verifySquad,
              ),
            ),
            if (_hasSubmitted) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isValid
                      ? const Color(0xFF00CEC9).withOpacity(0.15)
                      : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _isValid ? const Color(0xFF00CEC9) : Colors.redAccent),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isValid ? Icons.check_circle : Icons.cancel,
                      color: _isValid ? const Color(0xFF00CEC9) : Colors.redAccent,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isValid
                            ? 'Squad Approved! Team Strength is compliant with tournament rules.'
                            : 'Squad Rejected! Team Strength exceeds the $_maxTeamStrengthLimit limit.',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isValid ? const Color(0xFF00CEC9) : Colors.redAccent),
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
