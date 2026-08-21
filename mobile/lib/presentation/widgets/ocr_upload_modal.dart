import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import '../../domain/models/match_record.dart';
import '../../domain/services/ocr_parser_service.dart';
import '../../presentation/providers/match_provider.dart';
import '../theme/app_theme.dart';

class OcrUploadModal extends ConsumerStatefulWidget {
  final String? tMatchId;
  final String? defaultPlayerId;
  final String? defaultOpponentId;
  final String? defaultPlayerName;
  final String? defaultOpponentName;
  final bool isKnockout;
  /// Club UUID — required for matches to show in the club's Resolved tab.
  final String? clubId;

  const OcrUploadModal({
    super.key,
    this.tMatchId,
    this.defaultPlayerId,
    this.defaultOpponentId,
    this.defaultPlayerName,
    this.defaultOpponentName,
    this.isKnockout = false,
    this.clubId,
  });

  @override
  ConsumerState<OcrUploadModal> createState() => _OcrUploadModalState();
}

class _OcrUploadModalState extends ConsumerState<OcrUploadModal> {
  bool _is2v2Mode = false;
  final String _selectedMatchType = 'league';
  int _uploadStep = 0; // 0: upload, 1: scanning, 2: results
  Set<String> _assumedFields = {};

  late final TextEditingController _opponentIdCtrl;
  final _partnerIdCtrl         = TextEditingController();
  final _opponentPartnerIdCtrl = TextEditingController();

  final _goalsForCtrl      = TextEditingController(text: '');
  final _goalsAgainstCtrl  = TextEditingController(text: '');
  final _possessionCtrl    = TextEditingController(text: '');
  final _possessionAwayCtrl= TextEditingController(text: '');
  final _passesCompCtrl    = TextEditingController(text: '');
  final _passesCompAwayCtrl= TextEditingController(text: '');
  final _passesAttCtrl     = TextEditingController(text: '');
  final _passesAttAwayCtrl = TextEditingController(text: '');
  final _shotsTargetCtrl   = TextEditingController(text: '');
  final _shotsTargetAwayCtrl=TextEditingController(text: '');
  final _shotsTotalCtrl    = TextEditingController(text: '');
  final _shotsTotalAwayCtrl= TextEditingController(text: '');
  final _interceptionsCtrl = TextEditingController(text: '');
  final _interceptionsAwayCtrl = TextEditingController(text: '');
  
  // New eFootball Fields
  final _foulsCtrl         = TextEditingController(text: '');
  final _foulsAwayCtrl     = TextEditingController(text: '');
  final _offsidesCtrl      = TextEditingController(text: '');
  final _offsidesAwayCtrl  = TextEditingController(text: '');
  final _cornersCtrl       = TextEditingController(text: '');
  final _cornersAwayCtrl   = TextEditingController(text: '');
  final _freeKicksCtrl     = TextEditingController(text: '');
  final _freeKicksAwayCtrl = TextEditingController(text: '');
  final _crossesCtrl       = TextEditingController(text: '');
  final _crossesAwayCtrl   = TextEditingController(text: '');
  final _tacklesCtrl       = TextEditingController(text: '');
  final _tacklesAwayCtrl   = TextEditingController(text: '');
  final _savesCtrl         = TextEditingController(text: '');
  final _savesAwayCtrl     = TextEditingController(text: '');

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _opponentIdCtrl = TextEditingController(
      text: widget.defaultOpponentId ?? '00000000-0000-0000-0000-000000000001',
    );
    _goalsForCtrl.addListener(_onFieldChanged);
    _goalsAgainstCtrl.addListener(_onFieldChanged);
    _shotsTotalCtrl.addListener(_onFieldChanged);
    _shotsTotalAwayCtrl.addListener(_onFieldChanged);
    _passesCompCtrl.addListener(_onFieldChanged);
    _passesAttCtrl.addListener(_onFieldChanged);
    _passesCompAwayCtrl.addListener(_onFieldChanged);
    _passesAttAwayCtrl.addListener(_onFieldChanged);
    _possessionCtrl.addListener(_onFieldChanged);
    _possessionAwayCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _goalsForCtrl.removeListener(_onFieldChanged);
    _goalsAgainstCtrl.removeListener(_onFieldChanged);
    _shotsTotalCtrl.removeListener(_onFieldChanged);
    _shotsTotalAwayCtrl.removeListener(_onFieldChanged);
    _passesCompCtrl.removeListener(_onFieldChanged);
    _passesAttCtrl.removeListener(_onFieldChanged);
    _passesCompAwayCtrl.removeListener(_onFieldChanged);
    _passesAttAwayCtrl.removeListener(_onFieldChanged);
    _possessionCtrl.removeListener(_onFieldChanged);
    _possessionAwayCtrl.removeListener(_onFieldChanged);
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

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _uploadStep = 1;
      _errorMessage = null;
    });

    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        throw UnsupportedError('Google ML Kit OCR is only supported on Android and iOS devices. Please run on a mobile device or emulator.');
      }

      final parsed = await OcrParserService.parseFile(pickedFile.path);

      if (mounted) {
        setState(() {
          if (parsed.goalsHome != null) _goalsForCtrl.text = parsed.goalsHome.toString();
          if (parsed.goalsAway != null) _goalsAgainstCtrl.text = parsed.goalsAway.toString();
          if (parsed.possessionHome != null) _possessionCtrl.text = parsed.possessionHome.toString();
          if (parsed.possessionAway != null) _possessionAwayCtrl.text = parsed.possessionAway.toString();
          if (parsed.shotsTotalHome != null) _shotsTotalCtrl.text = parsed.shotsTotalHome.toString();
          if (parsed.shotsTotalAway != null) _shotsTotalAwayCtrl.text = parsed.shotsTotalAway.toString();
          if (parsed.shotsTargetHome != null) _shotsTargetCtrl.text = parsed.shotsTargetHome.toString();
          if (parsed.shotsTargetAway != null) _shotsTargetAwayCtrl.text = parsed.shotsTargetAway.toString();
          if (parsed.foulsHome != null) _foulsCtrl.text = parsed.foulsHome.toString();
          if (parsed.foulsAway != null) _foulsAwayCtrl.text = parsed.foulsAway.toString();
          if (parsed.offsidesHome != null) _offsidesCtrl.text = parsed.offsidesHome.toString();
          if (parsed.offsidesAway != null) _offsidesAwayCtrl.text = parsed.offsidesAway.toString();
          if (parsed.cornersHome != null) _cornersCtrl.text = parsed.cornersHome.toString();
          if (parsed.cornersAway != null) _cornersAwayCtrl.text = parsed.cornersAway.toString();
          if (parsed.freeKicksHome != null) _freeKicksCtrl.text = parsed.freeKicksHome.toString();
          if (parsed.freeKicksAway != null) _freeKicksAwayCtrl.text = parsed.freeKicksAway.toString();
          if (parsed.passesAttHome != null) _passesAttCtrl.text = parsed.passesAttHome.toString();
          if (parsed.passesAttAway != null) _passesAttAwayCtrl.text = parsed.passesAttAway.toString();
          if (parsed.passesCompHome != null) _passesCompCtrl.text = parsed.passesCompHome.toString();
          if (parsed.passesCompAway != null) _passesCompAwayCtrl.text = parsed.passesCompAway.toString();
          if (parsed.crossesHome != null) _crossesCtrl.text = parsed.crossesHome.toString();
          if (parsed.crossesAway != null) _crossesAwayCtrl.text = parsed.crossesAway.toString();
          if (parsed.interceptionsHome != null) _interceptionsCtrl.text = parsed.interceptionsHome.toString();
          if (parsed.interceptionsAway != null) _interceptionsAwayCtrl.text = parsed.interceptionsAway.toString();
          if (parsed.tacklesHome != null) _tacklesCtrl.text = parsed.tacklesHome.toString();
          if (parsed.tacklesAway != null) _tacklesAwayCtrl.text = parsed.tacklesAway.toString();
          if (parsed.savesHome != null) _savesCtrl.text = parsed.savesHome.toString();
          if (parsed.savesAway != null) _savesAwayCtrl.text = parsed.savesAway.toString();
          
          _assumedFields = parsed.assumedFields;
          _uploadStep = 2;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to process image: $e';
          _uploadStep = 0;
        });
      }
    }
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
    if (goalsFor == goalsAgainst && (widget.isKnockout || _selectedMatchType == 'knockout' || _selectedMatchType == 'tournament_final' || _selectedMatchType == 'tournament_knockout')) {
      setState(() => _errorMessage = 'Knockout matches cannot end in a draw. Please resolve via extra time/penalties.');
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
      clubId:            widget.clubId,
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
      error: (e, _) {
        final errorMsg = e.toString();
        String displayMsg = 'Submission failed: $errorMsg';
        if (errorMsg.contains('INVALID_OPPONENT')) {
          displayMsg = 'Invalid Opponent. Please select the correct opponent for this tournament match.';
        } else if (errorMsg.contains('INVALID_KNOCKOUT_DRAW')) {
          displayMsg = 'Knockout matches cannot end in a draw. Please resolve via extra time/penalties.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMsg),
            backgroundColor: AppColors.lossRed,
          ),
        );
      },
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
                  if (res.ratingDelta == 0)
                    _buildResultStat('SKILL RATING', 'PENDING')
                  else
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        borderColor: AppColors.cyan.withValues(alpha: 0.5),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'OCR MATCH TERMINAL',
                    style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
            
            Flexible(
              child: _buildBodyContent(isSubmitting),
            ),

            // Footer
            if (_uploadStep == 2) Container(
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

  Widget _buildBodyContent(bool isSubmitting) {
    if (_uploadStep == 0) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.cyan.withValues(alpha: 0.8)),
            const SizedBox(height: 24),
            Text(
              'UPLOAD MATCH RESULT',
              style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a screenshot of the match statistics to automatically extract the data.',
              textAlign: TextAlign.center,
              style: GoogleFonts.rajdhani(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.photo_library, color: Colors.black),
                label: const Text('CHOOSE FROM GALLERY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _pickImage(ImageSource.gallery),
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
      );
    } else if (_uploadStep == 1) {
      return Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.cyan).animate().scale(),
            const SizedBox(height: 24),
            Text(
              'ANALYZING IMAGE...',
              style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
            const SizedBox(height: 8),
            Text(
              'Extracting match statistics',
              style: GoogleFonts.rajdhani(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
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
                          _buildEfootballRow('Possession', 'possession', _possessionCtrl, _possessionAwayCtrl, isPercent: true),
                          _buildEfootballRow('Total Shots', 'shotsTotal', _shotsTotalCtrl, _shotsTotalAwayCtrl),
                          _buildEfootballRow('Shots on Target', 'shotsTarget', _shotsTargetCtrl, _shotsTargetAwayCtrl),
                          _buildEfootballRow('Fouls', 'fouls', _foulsCtrl, _foulsAwayCtrl),
                          _buildEfootballRow('Offsides', 'offsides', _offsidesCtrl, _offsidesAwayCtrl),
                          _buildEfootballRow('Corner Kicks', 'corners', _cornersCtrl, _cornersAwayCtrl),
                          _buildEfootballRow('Free Kicks', 'freeKicks', _freeKicksCtrl, _freeKicksAwayCtrl),
                          _buildEfootballRow('Passes', 'passesAtt', _passesAttCtrl, _passesAttAwayCtrl),
                          _buildEfootballRow('Successful Passes', 'passesComp', _passesCompCtrl, _passesCompAwayCtrl),
                          _buildEfootballRow('Crosses', 'crosses', _crossesCtrl, _crossesAwayCtrl),
                          _buildEfootballRow('Interceptions', 'interceptions', _interceptionsCtrl, _interceptionsAwayCtrl),
                          _buildEfootballRow('Tackles', 'tackles', _tacklesCtrl, _tacklesAwayCtrl),
                          _buildEfootballRow('Saves', 'saves', _savesCtrl, _savesAwayCtrl),
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
    );
  }

  Widget _buildEfootballRow(String label, String statId, TextEditingController leftCtrl, TextEditingController rightCtrl, {bool isPercent = false}) {
    bool hasWarning = false;
    
    if (label == 'Possession') {
      final h = double.tryParse(leftCtrl.text) ?? 0;
      final a = double.tryParse(rightCtrl.text) ?? 0;
      if (h > 0 && a > 0 && h + a != 100.0) hasWarning = true;
    } else if (label == 'Successful Passes') {
      final compH = int.tryParse(leftCtrl.text) ?? 0;
      final attH = int.tryParse(_passesAttCtrl.text) ?? 0;
      final compA = int.tryParse(rightCtrl.text) ?? 0;
      final attA = int.tryParse(_passesAttAwayCtrl.text) ?? 0;
      if ((attH > 0 && compH > attH) || (attA > 0 && compA > attA)) hasWarning = true;
    } else if (label == 'Total Shots') {
      final goalsH = int.tryParse(_goalsForCtrl.text) ?? 0;
      final goalsA = int.tryParse(_goalsAgainstCtrl.text) ?? 0;
      final shotsH = int.tryParse(leftCtrl.text) ?? 0;
      final shotsA = int.tryParse(rightCtrl.text) ?? 0;
      if (goalsH > shotsH || goalsA > shotsA) hasWarning = true;
    }

    final textColor = hasWarning ? Colors.amber : Colors.white;
    final leftAssumed = _assumedFields.contains('${statId}Home');
    final rightAssumed = _assumedFields.contains('${statId}Away');

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            child: TextField(
              controller: leftCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              decoration: InputDecoration(
                filled: true, 
                fillColor: leftAssumed ? Colors.amber.shade200 : Colors.white, 
                isDense: true, 
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.rajdhani(color: textColor, fontWeight: FontWeight.bold, fontSize: 13))),
          const SizedBox(width: 12),
          SizedBox(
            width: 36,
            child: TextField(
              controller: rightCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              decoration: InputDecoration(
                filled: true, 
                fillColor: rightAssumed ? Colors.amber.shade200 : Colors.white, 
                isDense: true, 
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
