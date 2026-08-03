import 'package:crypto/crypto.dart';
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
  final String? defaultPlayerId;
  final String? defaultOpponentId;
  final String? defaultPlayerName;
  final String? defaultOpponentName;

  const OcrUploadModal({
    super.key,
    this.tMatchId,
    this.defaultPlayerId,
    this.defaultOpponentId,
    this.defaultPlayerName,
    this.defaultOpponentName,
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
  final _possessionAwayCtrl= TextEditingController(text: '37.5');
  final _passesCompCtrl    = TextEditingController(text: '120');
  final _passesCompAwayCtrl= TextEditingController(text: '70');
  final _passesAttCtrl     = TextEditingController(text: '140');
  final _passesAttAwayCtrl = TextEditingController(text: '95');
  final _shotsTargetCtrl   = TextEditingController(text: '5');
  final _shotsTargetAwayCtrl=TextEditingController(text: '1');
  final _shotsTotalCtrl    = TextEditingController(text: '8');
  final _shotsTotalAwayCtrl= TextEditingController(text: '3');
  final _interceptionsCtrl = TextEditingController(text: '7');
  final _interceptionsAwayCtrl = TextEditingController(text: '4');
  
  // New eFootball Fields
  final _foulsCtrl         = TextEditingController(text: '0');
  final _foulsAwayCtrl     = TextEditingController(text: '2');
  final _offsidesCtrl      = TextEditingController(text: '0');
  final _offsidesAwayCtrl  = TextEditingController(text: '1');
  final _cornersCtrl       = TextEditingController(text: '0');
  final _cornersAwayCtrl   = TextEditingController(text: '2');
  final _freeKicksCtrl     = TextEditingController(text: '0');
  final _freeKicksAwayCtrl = TextEditingController(text: '1');
  final _crossesCtrl       = TextEditingController(text: '1');
  final _crossesAwayCtrl   = TextEditingController(text: '2');
  final _tacklesCtrl       = TextEditingController(text: '5');
  final _tacklesAwayCtrl   = TextEditingController(text: '8');
  final _savesCtrl         = TextEditingController(text: '1');
  final _savesAwayCtrl     = TextEditingController(text: '3');

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
    _possessionAwayCtrl.dispose();
    _passesCompCtrl.dispose();
    _passesCompAwayCtrl.dispose();
    _passesAttCtrl.dispose();
    _passesAttAwayCtrl.dispose();
    _shotsTargetCtrl.dispose();
    _shotsTargetAwayCtrl.dispose();
    _shotsTotalCtrl.dispose();
    _shotsTotalAwayCtrl.dispose();
    _interceptionsCtrl.dispose();
    _interceptionsAwayCtrl.dispose();
    _foulsCtrl.dispose();
    _foulsAwayCtrl.dispose();
    _offsidesCtrl.dispose();
    _offsidesAwayCtrl.dispose();
    _cornersCtrl.dispose();
    _cornersAwayCtrl.dispose();
    _freeKicksCtrl.dispose();
    _freeKicksAwayCtrl.dispose();
    _crossesCtrl.dispose();
    _crossesAwayCtrl.dispose();
    _tacklesCtrl.dispose();
    _tacklesAwayCtrl.dispose();
    _savesCtrl.dispose();
    _savesAwayCtrl.dispose();
    super.dispose();
  }

  void _swapSides() {
    setState(() {
      void swap(TextEditingController a, TextEditingController b) {
        final tmp = a.text;
        a.text = b.text;
        b.text = tmp;
      }

      swap(_goalsForCtrl, _goalsAgainstCtrl);
      swap(_possessionCtrl, _possessionAwayCtrl);
      swap(_shotsTotalCtrl, _shotsTotalAwayCtrl);
      swap(_shotsTargetCtrl, _shotsTargetAwayCtrl);
      swap(_foulsCtrl, _foulsAwayCtrl);
      swap(_offsidesCtrl, _offsidesAwayCtrl);
      swap(_cornersCtrl, _cornersAwayCtrl);
      swap(_freeKicksCtrl, _freeKicksAwayCtrl);
      swap(_passesAttCtrl, _passesAttAwayCtrl);
      swap(_passesCompCtrl, _passesCompAwayCtrl);
      swap(_crossesCtrl, _crossesAwayCtrl);
      swap(_interceptionsCtrl, _interceptionsAwayCtrl);
      swap(_tacklesCtrl, _tacklesAwayCtrl);
      swap(_savesCtrl, _savesAwayCtrl);
    });
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

    final fouls      = int.tryParse(_foulsCtrl.text) ?? 0;
    final offsides   = int.tryParse(_offsidesCtrl.text) ?? 0;
    final corners    = int.tryParse(_cornersCtrl.text) ?? 0;
    final freeKicks  = int.tryParse(_freeKicksCtrl.text) ?? 0;
    final crosses    = int.tryParse(_crossesCtrl.text) ?? 0;
    final tackles    = int.tryParse(_tacklesCtrl.text) ?? 0;
    final saves      = int.tryParse(_savesCtrl.text) ?? 0;

    if (passesComp > passesAtt) {
      setState(() => _errorMessage = 'Passes completed cannot exceed passes attempted.');
      return;
    }
    if (shotsTarget > shotsTotal) {
      setState(() => _errorMessage = 'Shots on target cannot exceed total shots.');
      return;
    }

    setState(() => _errorMessage = null);

    final playerId = widget.defaultPlayerId ?? await ref.read(apiClientProvider).storedUserId ?? '00000000-0000-0000-0000-000000000000';

    final record = MatchRecord(
      playerId:          playerId,
      opponentId:        _opponentIdCtrl.text.trim(),
      partnerId:         _is2v2Mode ? _partnerIdCtrl.text.trim() : null,
      opponentPartnerId: _is2v2Mode ? _opponentPartnerIdCtrl.text.trim() : null,
      tMatchId:          widget.tMatchId,
      matchType:         _selectedMatchType,
      goalsFor:          goalsFor,
      goalsAgainst:      goalsAgainst,
      possession:        double.tryParse(_possessionCtrl.text) ?? 50.0,
      passesCompleted:   passesComp,
      passesAttempted:   passesAtt,
      shotsOnTarget:     shotsTarget,
      shotsTotal:        shotsTotal,
      interceptions:     int.tryParse(_interceptionsCtrl.text) ?? 0,
      fouls:             fouls,
      offsides:          offsides,
      corners:           corners,
      freeKicks:         freeKicks,
      crosses:           crosses,
      tackles:           tackles,
      saves:             saves,
      screenshotHash:    _generateHash(playerId),
    );

    await ref.read(ocrSubmitProvider.notifier).submit(record);

    if (!mounted) return;
    final result = ref.read(ocrSubmitProvider);
    ref.read(ocrSubmitProvider.notifier).reset();
    ref.invalidate(pendingMatchesProvider);
    ref.invalidate(matchHistoryProvider(playerId));
    if (widget.tMatchId != null) {
      ref.invalidate(tournamentBracketProvider);
    }

    final nav = Navigator.of(context);
    nav.pop();

    result.when(
      data: (res) {
        if (res == null) return;
        _showSuccessDialog(context, res);
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

  void _showSuccessDialog(BuildContext dialogContext, dynamic res) {
    showDialog(
      context: dialogContext,
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

                    // Match Participants Display (Usernames display & Swap sides)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('MATCH PARTICIPANTS', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                        InkWell(
                          onTap: _swapSides,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.swap_horiz, color: AppColors.cyan, size: 16),
                                const SizedBox(width: 4),
                                Text('SWAP SIDES', style: GoogleFonts.rajdhani(color: AppColors.cyan, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('HOME PLAYER', style: GoogleFonts.rajdhani(color: AppColors.winGreen, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 2),
                                Text(
                                  widget.defaultPlayerName ?? (widget.defaultPlayerId != null && widget.defaultPlayerId!.length > 8 ? widget.defaultPlayerId!.substring(0, 8) : 'Home Player'),
                                  style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _swapSides,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('VS', style: GoogleFonts.rajdhani(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.swap_horiz, color: AppColors.primary, size: 14),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('AWAY PLAYER', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                const SizedBox(height: 2),
                                Text(
                                  widget.defaultOpponentName ?? (widget.defaultOpponentId != null && widget.defaultOpponentId!.length > 8 ? widget.defaultOpponentId!.substring(0, 8) : 'Opponent'),
                                  style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // eFootball Style Stats Board
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF000080), // Deep blue background like eFootball
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.yellow, width: 2),
                      ),
                      child: Column(
                        children: [
                          // Header (Scores)
                          Container(
                            color: Colors.yellow,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.defaultPlayerName ?? 'HOME',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 36,
                                  child: TextField(controller: _goalsForCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black), decoration: const InputDecoration(filled: true, fillColor: Colors.white, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4))),
                                ),
                                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('=', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 22))),
                                SizedBox(
                                  width: 36,
                                  child: TextField(controller: _goalsAgainstCtrl, textAlign: TextAlign.center, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black), decoration: const InputDecoration(filled: true, fillColor: Colors.white, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.defaultOpponentName ?? 'AWAY',
                                    textAlign: TextAlign.left,
                                    style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            color: Colors.yellow,
                            width: double.infinity,
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Full Time', textAlign: TextAlign.center, style: GoogleFonts.rajdhani(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: _swapSides,
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.swap_horiz, color: Colors.yellow, size: 13),
                                        const SizedBox(width: 3),
                                        Text('SWAP SIDES', style: GoogleFonts.rajdhani(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildEfootballRow('Possession', _possessionCtrl, _possessionAwayCtrl, isPercent: true),
                          _buildEfootballRow('Total Shots', _shotsTotalCtrl, _shotsTotalAwayCtrl),
                          _buildEfootballRow('Shots on Target', _shotsTargetCtrl, _shotsTargetAwayCtrl),
                          _buildEfootballRow('Fouls', _foulsCtrl, _foulsAwayCtrl),
                          _buildEfootballRow('Offsides', _offsidesCtrl, _offsidesAwayCtrl),
                          _buildEfootballRow('Corner Kicks', _cornersCtrl, _cornersAwayCtrl),
                          _buildEfootballRow('Free Kicks', _freeKicksCtrl, _freeKicksAwayCtrl),
                          _buildEfootballRow('Passes', _passesAttCtrl, _passesAttAwayCtrl),
                          _buildEfootballRow('Successful Passes', _passesCompCtrl, _passesCompAwayCtrl),
                          _buildEfootballRow('Crosses', _crossesCtrl, _crossesAwayCtrl),
                          _buildEfootballRow('Interceptions', _interceptionsCtrl, _interceptionsAwayCtrl),
                          _buildEfootballRow('Tackles', _tacklesCtrl, _tacklesAwayCtrl),
                          _buildEfootballRow('Saves', _savesCtrl, _savesAwayCtrl),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

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

  Widget _buildEfootballRow(String label, TextEditingController leftCtrl, TextEditingController rightCtrl, {bool isPercent = false}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: leftCtrl,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    keyboardType: isPercent ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                if (isPercent) Text('%', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(color: Colors.yellow, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: rightCtrl,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    keyboardType: isPercent ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  ),
                ),
                if (isPercent) Text('%', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
