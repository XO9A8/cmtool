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
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
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

                return Column(
                  children: pendingMatches.map((matchData) {
                    final match = matchData as Map<String, dynamic>;
                    final matchId = match['id']?.toString() ?? '';
                    final playerName = match['player_name']?.toString() ?? 'Player';
                    final goalsFor = match['goals_for']?.toString() ?? '0';
                    final goalsAgainst = match['goals_against']?.toString() ?? '0';
                    final possession = match['possession'] != null ? '${match['possession']}%' : '—';
                    final createdAt = match['created_at']?.toString() ?? '';
                    final matchType = match['match_type']?.toString() ?? 'Match';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Submitted by $playerName',
                                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                              ),
                              Text(
                                createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Score:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              const SizedBox(width: 6),
                              Text('$goalsFor - $goalsAgainst', style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              const Spacer(),
                              Text('Possession: $possession', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Type: $matchType', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.winGreen,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: Text('CONFIRM RESULT', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => _confirmMatch(context, ref, matchId, playerName),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.lossRed),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  icon: const Icon(Icons.flag_outlined, color: AppColors.lossRed, size: 16),
                                  label: Text('DISPUTE', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 12)),
                                  onPressed: () => _disputeMatch(context, ref, matchId, playerName),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Match result with $playerName confirmed!'),
            backgroundColor: AppColors.winGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm match: $e'),
            backgroundColor: AppColors.lossRed,
          ),
        );
      }
    }
  }

  void _disputeMatch(BuildContext context, WidgetRef ref, String matchId, String playerName) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lossRed),
        ),
        title: Text('FILE A DISPUTE', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are disputing the result submitted by $playerName.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: 'Reason for dispute',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lossRed),
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final client = ref.read(apiClientProvider);
                await client.submitDispute(
                  matchRecordId: matchId,
                  reason: reason,
                );
                ref.invalidate(pendingMatchesProvider);
                ref.invalidate(adminDisputesProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Match with $playerName disputed. Case logged for admin review.'),
                      backgroundColor: AppColors.lossRed,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit dispute: $e'),
                      backgroundColor: AppColors.lossRed,
                    ),
                  );
                }
              }
            },
            child: Text('SUBMIT DISPUTE', style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
