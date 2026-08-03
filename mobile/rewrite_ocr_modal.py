import re

with open('lib/presentation/widgets/ocr_upload_modal.dart', 'r') as f:
    content = f.read()

new_content = """import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';

import '../../domain/models/match_record.dart';
import '../../presentation/providers/match_provider.dart';
import '../theme/app_theme.dart';

class OcrUploadModal extends ConsumerStatefulWidget {
  final String? tMatchId;
  final String? defaultOpponentId;

  const OcrUploadModal({
    super.key,
    this.tMatchId,
    this.defaultOpponentId,
  });

  @override
  ConsumerState<OcrUploadModal> createState() => _OcrUploadModalState();
}

class _OcrUploadModalState extends ConsumerState<OcrUploadModal> {
  bool _is2v2Mode = false;
  String _selectedMatchType = 'league';
  double _ocrConfidence = 82.5;

  late final TextEditingController _opponentIdCtrl;
  final _partnerIdCtrl         = TextEditingController();
  final _opponentPartnerIdCtrl = TextEditingController();

  final _goalsForCtrl      = TextEditingController(text: '3');
  final _goalsAgainstCtrl  = TextEditingController(text: '1');
  final _possessionCtrl    = TextEditingController(text: '62.5');
  final _passesCompCtrl    = TextEditingController(text: '120');
  final _passesAttCtrl     = TextEditingController(text: '140');
  final _shotsTargetCtrl   = TextEditingController(text: '5');
  final _shotsTotalCtrl    = TextEditingController(text: '8');
  final _interceptionsCtrl = TextEditingController(text: '7');

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _opponentIdCtrl = TextEditingController(
      text: widget.defaultOpponentId ?? '00000000-0000-0000-0000-000000000001',
    );
  }

  @override
  void dispose() {
    _opponentIdCtrl.dispose();
    _partnerIdCtrl.dispose();
    _opponentPartnerIdCtrl.dispose();
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

  String _generateHash(String playerId) {
    final opponent = _opponentIdCtrl.text.trim();
    final data = 'hash_${playerId}_${opponent}_${_selectedMatchType}_${_goalsForCtrl.text}_${_goalsAgainstCtrl.text}'
        '_${_possessionCtrl.text}_${widget.tMatchId ?? ''}_${DateTime.now().millisecondsSinceEpoch}';
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
      playerId:          playerId,
      opponentId:        _opponentIdCtrl.text.trim(),
      partnerId:         _is2v2Mode ? _partnerIdCtrl.text.trim() : null,
      opponentPartnerId: _is2v2Mode ? _opponentPartnerIdCtrl.text.trim() : null,
      matchType:         _selectedMatchType,
      goalsFor:          goalsFor,
      goalsAgainst:      goalsAgainst,
      possession:        double.tryParse(_possessionCtrl.text) ?? 50.0,
      passesCompleted:   passesComp,
      passesAttempted:   passesAtt,
      shotsOnTarget:     shotsTarget,
      shotsTotal:        shotsTotal,
      interceptions:     int.tryParse(_interceptionsCtrl.text) ?? 0,
      screenshotHash:    _generateHash(playerId),
    );

    await ref.read(ocrSubmitProvider.notifier).submit(record);

    if (!mounted) return;
    final result = ref.read(ocrSubmitProvider);
    Navigator.of(context).pop();

    result.when(
      data: (res) {
        if (res == null) return;
        _showSuccessDialog(res);
      },
      loading: () {},
      error: (e, _) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.toString()}'),
          backgroundColor: AppColors.lossRed,
        ),
      ),
    );
  }
  
  void _showSuccessDialog(dynamic res) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          borderColor: AppColors.cyan,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppColors.cyan, size: 64).animate().scale(delay: 200.ms, curve: Curves.elasticOut),
              const SizedBox(height: 16),
              Text('MATCH RECORDED!', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Status: Pending confirmation by opponent or club official (President/Captain)',
                        style: GoogleFonts.rajdhani(fontSize: 13, color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResultStat('SKILL RATING', '${res.newSkillRating}', delta: res.ratingDelta),
                  _buildResultStat('MPS SCORE', res.matchPerformanceScore.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ref.read(ocrSubmitProvider.notifier).reset();
                  },
                  child: Text('DONE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultStat(String label, String value, {int? delta}) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            if (delta != null) ...[
              const SizedBox(width: 4),
              Text('${delta >= 0 ? '+' : ''}$delta', style: GoogleFonts.rajdhani(color: delta >= 0 ? AppColors.winGreen : AppColors.lossRed, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(ocrSubmitProvider);
    final isSubmitting = submitState is AsyncLoading;
    final isLowConfidence = _ocrConfidence < 85.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        borderColor: isLowConfidence ? Colors.amber.withValues(alpha: 0.6) : AppColors.cyan.withValues(alpha: 0.5),
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                border: Border(bottom: BorderSide(color: AppColors.cyan.withValues(alpha: 0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OCR MATCH TERMINAL',
                    style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  ),
                  GlowBadge(
                    label: '${_ocrConfidence.toStringAsFixed(1)}% SCAN',
                    color: isLowConfidence ? Colors.amber : AppColors.cyan,
                    icon: isLowConfidence ? Icons.warning_amber_rounded : Icons.document_scanner,
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLowConfidence) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note, color: Colors.amber, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'OCR Confidence < 85%. Bounding-box review active: Please verify extracted statistics before submitting.',
                                style: TextStyle(fontSize: 12, color: Colors.amber.shade200, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ).animate().pulse(duration: 2.seconds),
                      const SizedBox(height: 20),
                    ],

                    // Format Toggle
                    Center(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('1v1 Solo')),
                          ButtonSegment(value: true, label: Text('2v2 Co-op')),
                        ],
                        selected: {_is2v2Mode},
                        onSelectionChanged: (set) => setState(() => _is2v2Mode = set.first),
                        style: SegmentedButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.04),
                          selectedBackgroundColor: AppColors.primary,
                          selectedForegroundColor: Colors.black,
                          foregroundColor: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Versus Profile Grid
                    Text('MATCH PARTICIPANTS', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    _buildParticipantField(_opponentIdCtrl, 'Opponent UUID', Icons.person_search, AppColors.lossRed),
                    if (_is2v2Mode) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildParticipantField(_partnerIdCtrl, 'Your Partner UUID', Icons.group, AppColors.winGreen)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildParticipantField(_opponentPartnerIdCtrl, 'Opponent Partner UUID', Icons.group_outlined, AppColors.lossRed)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text('MATCH STATISTICS', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(child: _buildStatField(_goalsForCtrl, 'GOALS FOR', isLowConfidence)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatField(_goalsAgainstCtrl, 'GOALS AGAINST', isLowConfidence)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatField(_possessionCtrl, 'POSSESSION %', isLowConfidence, decimal: true),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatField(_passesCompCtrl, 'PASSES COMP')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatField(_passesAttCtrl, 'PASSES ATT')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatField(_shotsTargetCtrl, 'SHOTS ON TARGET')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatField(_shotsTotalCtrl, 'TOTAL SHOTS')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatField(_interceptionsCtrl, 'INTERCEPTIONS'),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.lossRed.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.lossRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.lossRed, fontSize: 13, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ).animate().shake(),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                border: Border(top: BorderSide(color: AppColors.cyan.withValues(alpha: 0.2))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: EsportsButton(
                  label: 'VERIFY & SUBMIT MATCH',
                  icon: Icons.upload_file,
                  gradient: const [AppColors.cyan, Color(0xFF00B0FF)],
                  isLoading: isSubmitting,
                  onPressed: _submitMatchData,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantField(TextEditingController ctrl, String label, IconData icon, Color color) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: color.withValues(alpha: 0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: color)),
        prefixIcon: Icon(icon, color: color),
      ),
    );
  }

  Widget _buildStatField(TextEditingController ctrl, String label, [bool highlight = false, bool decimal = false]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? Colors.amber.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.rajdhani(color: highlight ? Colors.amber : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          TextField(
            controller: ctrl,
            keyboardType: decimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
            style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
"""

with open('lib/presentation/widgets/ocr_upload_modal.dart', 'w') as f:
    f.write(new_content)
print('Redesigned OCR Upload Modal!')
