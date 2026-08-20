import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

/// Modal dialog for claiming a 3-0 forfeit victory on a scheduled tournament match.
class ForfeitClaimModal extends ConsumerStatefulWidget {
  final String tournamentId;
  final String matchId;
  final String player1Id;
  final String player2Id;
  final String player1Name;
  final String player2Name;
  final VoidCallback? onSuccess;

  const ForfeitClaimModal({
    super.key,
    required this.tournamentId,
    required this.matchId,
    required this.player1Id,
    required this.player2Id,
    required this.player1Name,
    required this.player2Name,
    this.onSuccess,
  });

  @override
  ConsumerState<ForfeitClaimModal> createState() => _ForfeitClaimModalState();
}

class _ForfeitClaimModalState extends ConsumerState<ForfeitClaimModal> {
  bool _submitting = false;
  String? _forfeitingPlayerId;

  Future<void> _submitForfeit() async {
    if (_forfeitingPlayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select which player is forfeiting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.claimTournamentForfeit(widget.tournamentId, widget.matchId, _forfeitingPlayerId!);

      // Invalidate relevant providers to refresh UI
      await client.clearAllCache();
      ref.invalidate(tournamentBracketProvider(widget.tournamentId));
      ref.invalidate(leagueStandingsProvider(widget.tournamentId));

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Forfeit victory successfully claimed (3-0 default).'),
            backgroundColor: AppColors.winGreen,
          ),
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim forfeit: $e'),
            backgroundColor: AppColors.lossRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: GlassCard(
        borderColor: AppColors.lossRed.withValues(alpha: 0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lossRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel, color: AppColors.lossRed, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLAIM FORFEIT VICTORY',
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Match Forfeit / No-Show Resolution',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Match Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Text(
                      widget.player1Name,
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lossRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'VS',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.lossRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.player2Name,
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rules explanation
            Text(
              'Select the player who forfeited (did not show up or surrendered). The other player will receive a default 3-0 victory.',
              style: GoogleFonts.rajdhani(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Selection
            Theme(
              data: Theme.of(context).copyWith(
                unselectedWidgetColor: AppColors.textMuted,
              ),
              child: RadioGroup<String>(
                groupValue: _forfeitingPlayerId,
                onChanged: (val) => setState(() => _forfeitingPlayerId = val),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(widget.player1Name, style: const TextStyle(color: Colors.white)),
                      value: widget.player1Id,
                      activeColor: AppColors.lossRed,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text(widget.player2Name, style: const TextStyle(color: Colors.white)),
                      value: widget.player2Id,
                      activeColor: AppColors.lossRed,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EsportsButton(
                    label: _submitting ? 'CLAIMING...' : 'CONFIRM',
                    icon: Icons.gavel,
                    gradient: const [AppColors.lossRed, Colors.orangeAccent],
                    onPressed: _submitting ? null : _submitForfeit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
