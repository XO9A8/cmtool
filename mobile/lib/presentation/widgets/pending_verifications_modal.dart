import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

class PendingVerificationsModal extends ConsumerWidget {
  const PendingVerificationsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingMatchesProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        borderColor: AppColors.cyan.withValues(alpha: 0.6),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PENDING MATCH APPROVALS',
                  style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                pendingAsync.when(
                  data: (matches) => GlowBadge(
                    label: '${matches.length} PENDING',
                    color: AppColors.cyan,
                    icon: Icons.hourglass_top,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            pendingAsync.when(
              loading: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Failed to load pending matches.', style: TextStyle(color: AppColors.lossRed, fontSize: 13)),
                ),
              ),
              data: (pendingMatches) {
                if (pendingMatches.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No pending match approvals.', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    ),
                  );
                }

                return Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: pendingMatches.map((matchData) {
                        final match = matchData as Map<String, dynamic>;
                        final matchId = match['id']?.toString() ?? '';
                        final playerName = match['player_name']?.toString() ?? 'Player';
                        final opponentName = match['opponent_name']?.toString() ?? 'Opponent';
                        final goalsFor = match['goals_for']?.toString() ?? '0';
                        final goalsAgainst = match['goals_against']?.toString() ?? '0';
                        final possessionVal = match['possession'];
                        final possession = possessionVal != null ? '$possessionVal%' : '—';
                        final matchType = match['match_type']?.toString() ?? 'Match';

                        final tournamentName = match['tournament_name']?.toString();
                        final roundNumber = match['round_number'];
                        final groupName = match['group_name']?.toString();

                        String headerContext = '';
                        if (tournamentName != null && tournamentName.isNotEmpty) {
                          headerContext = tournamentName.toUpperCase();
                          if (groupName != null && groupName.isNotEmpty) {
                            headerContext += ' • $groupName';
                          }
                          if (roundNumber != null) {
                            headerContext += ' • ROUND $roundNumber';
                          }
                        } else {
                          headerContext = '${matchType.toUpperCase()} MATCH';
                        }

                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tournament & Stage Banner
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      headerContext,
                                      style: GoogleFonts.rajdhani(
                                        color: AppColors.cyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 1.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      matchType.toUpperCase(),
                                      style: GoogleFonts.rajdhani(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Versus Matchup Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            playerName,
                                            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const Text('Submitter', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.winGreen.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$goalsFor – $goalsAgainst',
                                        style: GoogleFonts.orbitron(color: AppColors.winGreen, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            opponentName,
                                            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const Text('Opponent', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Text(
                                    'POSSESSION: $possession',
                                    style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.winGreen,
                                        side: BorderSide(color: AppColors.winGreen),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.check, size: 14),
                                      label: Text('CONFIRM', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () => _confirmMatch(context, ref, matchId, '$playerName vs $opponentName'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.lossRed,
                                        side: BorderSide(color: AppColors.lossRed),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      icon: const Icon(Icons.close, size: 14),
                                      label: Text('DISMISS', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 12)),
                                      onPressed: () => _dismissMatch(context, ref, matchId, '$playerName vs $opponentName'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmMatch(BuildContext context, WidgetRef ref, String matchId, String playerName) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.confirmMatch(matchId);
      ref.invalidate(pendingMatchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Match result with $playerName confirmed!'),
            backgroundColor: AppColors.winGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('already been confirmed')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.5)),
              ),
              title: Text('MATCH ALREADY CONFIRMED', style: GoogleFonts.orbitron(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 18)),
              content: Text(
                'This match result has already been confirmed by another submitter/admin.\n\nYou must dispute the previous result first to bring it back to pending state.',
                style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('UNDERSTOOD', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to confirm match: $e', style: GoogleFonts.rajdhani()),
              backgroundColor: AppColors.lossRed,
            ),
          );
        }
      }
    }
  }

  void _dismissMatch(BuildContext context, WidgetRef ref, String matchId, String playerName) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.dismissPendingMatch(matchId);
      ref.invalidate(pendingMatchesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Duplicate/Invalid request dismissed safely.'),
            backgroundColor: AppColors.textMuted,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss request: $e', style: GoogleFonts.rajdhani()),
            backgroundColor: AppColors.lossRed,
          ),
        );
      }
    }
  }
}
