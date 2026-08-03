import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/match_provider.dart';
import '../theme/app_theme.dart';

class AdminDisputeScreen extends ConsumerWidget {
  const AdminDisputeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputesAsync = ref.watch(adminDisputesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'ADMIN DISPUTE CENTER',
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.cyan),
            onPressed: () => ref.invalidate(adminDisputesProvider),
          ),
        ],
      ),
      body: disputesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load disputes: $e',
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (disputes) {
          if (disputes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel_rounded, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No Open Disputes',
                    style: GoogleFonts.rajdhani(fontSize: 20, color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'All club match records are verified and clean.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: disputes.length,
            itemBuilder: (context, index) {
              final disp = disputes[index] as Map<String, dynamic>;
              final id = disp['id']?.toString() ?? '—';
              final raisedBy = disp['raised_by_username'] ?? disp['raised_by'] ?? 'Unknown Player';
              final reason = disp['reason'] ?? 'No reason provided.';
              final createdAt = disp['created_at'] ?? '—';
              final matchId = disp['match_record_id'] ?? '—';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  borderColor: AppColors.lossRed.withOpacity(0.5),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GlowBadge(
                            label: 'DISPUTE',
                            color: AppColors.lossRed,
                            icon: Icons.warning_amber_rounded,
                          ),
                          Text(
                            createdAt.length > 10 ? createdAt.substring(0, 10) : createdAt,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Raised by
                      Text(
                        'Raised by: $raisedBy',
                        style: GoogleFonts.rajdhani(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Match: $matchId',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Screenshot placeholders (URLs come from backend when implemented)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Reported Image', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Center(child: Icon(Icons.image, color: Colors.white54)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Counter Evidence', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Center(
                                    child: Text('No Evidence', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reason
                      Text('Reason:', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(reason, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.winGreen),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _resolve(context, ref, id, dismiss: false),
                              child: Text(
                                'UPHOLD',
                                style: GoogleFonts.rajdhani(color: AppColors.winGreen, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.lossRed),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () => _resolve(context, ref, id, dismiss: true),
                              child: Text(
                                'DISMISS',
                                style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _resolve(BuildContext context, WidgetRef ref, String disputeId, {required bool dismiss}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cyan),
        ),
        title: Text(
          dismiss ? 'DISMISS DISPUTE' : 'UPHOLD DISPUTE',
          style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          dismiss
              ? 'Mark this dispute as dismissed? No rating changes will be applied.'
              : 'Uphold this dispute and apply the necessary rating correction?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final client = ref.read(apiClientProvider);
                await client.resolveAdminDispute(
                  disputeId: disputeId,
                  dismiss: dismiss,
                );
                ref.invalidate(adminDisputesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(dismiss ? 'Dispute dismissed.' : 'Dispute upheld and resolved.'),
                      backgroundColor: dismiss ? AppColors.lossRed : AppColors.winGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text(
              'CONFIRM',
              style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
