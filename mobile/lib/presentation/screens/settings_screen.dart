import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/offline_sync_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'COMMAND CENTER',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: Color(0xFF00E5FF),
          ),
        ).animate().fade().slideX(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            _buildSectionHeader('OPERATIVE PROFILE'),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFB000FF), Color(0xFF00E5FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.5),
                              blurRadius: 15,
                            )
                          ],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commander', // Dynamic username would go here
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(height: 4),
                            Text('ID: Authorized', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white54),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 40),

            // Settings List
            _buildSectionHeader('SYSTEM PREFERENCES'),
            const SizedBox(height: 16),
            _buildSettingsTile(
              icon: Icons.notifications_active_outlined,
              title: 'Match Alerts',
              subtitle: 'Push notifications for tournament fixtures',
              trailing: Switch(
                value: true,
                onChanged: (v) {},
                activeColor: const Color(0xFF00E5FF),
              ),
            ).animate().fade(delay: 200.ms),
            _buildSettingsTile(
              icon: Icons.sync_rounded,
              title: 'Offline Sync Queue',
              subtitle: 'Manually trigger local data sync to backend',
              trailing: IconButton(
                icon: const Icon(Icons.cloud_upload, color: Color(0xFFB000FF)),
                onPressed: () async {
                  final client = ref.read(apiClientProvider);
                  final res = await ref.read(offlineSyncProvider).syncPending(client);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sync complete: ${res.synced} synced, ${res.failed} failed.')),
                    );
                  }
                },
              ),
            ).animate().fade(delay: 300.ms),
            _buildSettingsTile(
              icon: Icons.auto_awesome,
              title: 'AI Tactical Insights',
              subtitle: 'Enable experimental AI analysis on match results',
              trailing: Switch(
                value: true,
                onChanged: (v) {},
                activeColor: const Color(0xFF00E5FF),
              ),
            ).animate().fade(delay: 400.ms),

            const SizedBox(height: 40),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.power_settings_new),
                label: const Text('TERMINATE SESSION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.15),
                  foregroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                ),
                onPressed: () async {
                  final client = ref.read(apiClientProvider);
                  await ref.read(authStateProvider.notifier).logout(client);
                },
              ),
            ).animate().fade(delay: 500.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white54,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: const Color(0xFF00E5FF), size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}
