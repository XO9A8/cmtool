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
            icon: Icon(Icons.refresh, color: AppColors.cyan),
            onPressed: () => ref.invalidate(adminDisputesProvider),
          ),
        ],
      ),
      body: disputesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load disputes: $e',
              style: TextStyle(color: AppColors.lossRed, fontSize: 13),
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
                  Icon(Icons.gavel_rounded, size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  Text(
                    'No Open Disputes',
                    style: GoogleFonts.rajdhani(fontSize: 20, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
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
                  borderColor: AppColors.lossRed.withValues(alpha: 0.5),
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
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Match: $matchId',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                                Text('Reported Image', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.isLight ? AppColors.surfaceLight : Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Center(child: Icon(Icons.image, color: AppColors.textDim)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Counter Evidence', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.isLight ? AppColors.surfaceLight : Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.cardBorder),
                                  ),
                                  child: Center(
                                    child: Text('No Evidence', style: TextStyle(color: AppColors.textDim, fontSize: 10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reason
                      Text('Reason:', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(reason, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.4)),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.winGreen),
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
                                side: BorderSide(color: AppColors.lossRed),
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

  void _resolve(BuildContext context, WidgetRef ref, String disputeId, {required bool dismiss}) async {
    bool isLoading = false;
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.cyan),
          ),
          title: Text(
            dismiss ? 'DISMISS DISPUTE' : 'UPHOLD DISPUTE',
            style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            dismiss
                ? 'Mark this dispute as dismissed? No rating changes will be applied.'
                : 'Uphold this dispute and VOID the match? This will reverse all Elo and Standings updates so players can resubmit.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(ctx).pop(false),
              child: Text('CANCEL', style: TextStyle(color: AppColors.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);
                      try {
                        final client = ref.read(apiClientProvider);
                        await client.resolveAdminDispute(
                          disputeId: disputeId,
                          dismiss: dismiss,
                          voidMatch: !dismiss,
                        );
                        await client.clearAllCache();
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop(true);
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setState(() => isLoading = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.lossRed),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      'CONFIRM',
                      style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ref.invalidate(adminDisputesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(dismiss ? 'Dispute dismissed.' : 'Dispute upheld and resolved.'),
            backgroundColor: dismiss ? AppColors.lossRed : AppColors.winGreen,
          ),
        );
      }
    }
  }
}
