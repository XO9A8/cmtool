import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/offline_sync_service.dart';
import 'admin_dispute_screen.dart';


// Settings state providers
final matchAlertsProvider = StateProvider<bool>((ref) => true);
final aiInsightsSettingsProvider = StateProvider<bool>((ref) => true);
final hapticFeedbackProvider = StateProvider<bool>((ref) => true);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _pendingCount = 0;
  bool _isSyncing = false;
  bool _isPinging = false;
  String _serverStatus = 'Connected';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _refreshPendingCount();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    ref.read(matchAlertsProvider.notifier).state = prefs.getBool('match_alerts') ?? true;
    ref.read(aiInsightsSettingsProvider.notifier).state = prefs.getBool('ai_insights') ?? true;
    ref.read(hapticFeedbackProvider.notifier).state = prefs.getBool('haptic_feedback') ?? true;
  }

  Future<void> _persistToggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _refreshPendingCount() async {
    final count = await ref.read(offlineSyncProvider).pendingCount;
    if (mounted) {
      setState(() {
        _pendingCount = count;
      });
    }
  }

  Future<void> _pingServer() async {
    setState(() => _isPinging = true);
    try {
      final client = ref.read(apiClientProvider);
      final ok = await client.healthCheck();
      if (mounted) {
        setState(() {
          _serverStatus = ok ? '🟢 ONLINE (200 OK)' : '🔴 UNREACHABLE';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverStatus = '🔴 OFFLINE';
        });
      }
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  void _showUpdatePasswordDialog() {
    final passwordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.cyan),
          ),
          title: Text(
            'UPDATE PASSWORD',
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: isUpdating ? null : () async {
                final pwd = passwordController.text;
                if (pwd.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password must be at least 6 characters')),
                  );
                  return;
                }
                setDialogState(() => isUpdating = true);
                try {
                  await ref.read(authStateProvider.notifier).updatePassword(pwd);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating password: $e')),
                    );
                  }
                } finally {
                  if (mounted) setDialogState(() => isUpdating = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
              child: isUpdating 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('UPDATE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(ProfilePreferences currentProfile) {
    String selectedStyle = currentProfile.playStyle;
    final displayNameController = TextEditingController(text: currentProfile.displayName);
    final validStyles = ['Possession Game', 'Quick Counter', 'Out-wide', 'Long Ball Counter', 'Park the Bus'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.cyan),
          ),
          title: Text(
            'UPDATE PROFILE',
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: displayNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select your primary tactical play style preference:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: validStyles.contains(selectedStyle) ? selectedStyle : validStyles.first,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: validStyles.map((style) {
                  return DropdownMenuItem(
                    value: style,
                    child: Text(style, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedStyle = val);
                  }
                },
              ),
            ],
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
                await ref.read(profilePreferencesProvider.notifier).update(
                  displayName: displayNameController.text.trim().isNotEmpty
                      ? displayNameController.text.trim()
                      : 'Player',
                  playStyle: selectedStyle,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile updated for $selectedStyle'),
                      backgroundColor: AppColors.winGreen,
                    ),
                  );
                }
              },
              child: Text(
                'SAVE CHANGES',
                style: GoogleFonts.rajdhani(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lossRed),
        ),
        title: Text(
          'TERMINATE SESSION',
          style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out of the Player Dashboard?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.lossRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final client = ref.read(apiClientProvider);
              await ref.read(authStateProvider.notifier).logout(client);
            },
            child: Text(
              'LOGOUT',
              style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authStateProvider);
    final profileAsync = userId != null ? ref.watch(playerProfileProvider(userId)) : null;

    final matchAlerts = ref.watch(matchAlertsProvider);
    final aiInsights = ref.watch(aiInsightsSettingsProvider);
    final haptic = ref.watch(hapticFeedbackProvider);
    final profilePrefs = ref.watch(profilePreferencesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'COMMAND CENTER',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            color: AppColors.cyan,
            fontSize: 18,
          ),
        ).animate().fade().slideX(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Security Header
            _buildSectionHeader('ACCOUNT SECURITY'),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: AppColors.primary.withValues(alpha: 0.4),
              child: ListTile(
                leading: const Icon(Icons.lock_outline, color: AppColors.cyan),
                title: const Text('Update Password', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Change your account password', style: TextStyle(color: Colors.white60, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                onTap: _showUpdatePasswordDialog,
              ),
            ),
            const SizedBox(height: 24),

            // Operative Profile Header
            _buildSectionHeader('OPERATIVE PROFILE'),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: AppColors.primary.withValues(alpha: 0.4),
              padding: const EdgeInsets.all(20),
              child: profileAsync?.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.cyan),
                    ),
                    error: (_, __) => _buildProfileHeaderContent(
                      username: 'Player',
                      userId: userId ?? 'Unknown',
                      skillRating: 1500,
                      playStyle: 'Possession Game',
                    ),
                    data: (data) {
                      final username = (data['username'] as String?)?.isNotEmpty == true
                          ? data['username']
                          : profilePrefs.displayName;
                      final rating = data['skill_rating'] ?? 1500;
                      final style = (data['play_style'] as String?)?.isNotEmpty == true
                          ? data['play_style']
                          : profilePrefs.playStyle;
                      return _buildProfileHeaderContent(
                        username: username,
                        userId: userId ?? 'Unknown',
                        skillRating: rating,
                        playStyle: style,
                      );
                    },
                  ) ??
                  _buildProfileHeaderContent(
                    username: profilePrefs.displayName,
                    userId: userId ?? 'Unknown',
                    skillRating: 1500,
                    playStyle: profilePrefs.playStyle,
                  ),
            ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 28),

            // System Preferences
            _buildSectionHeader('SYSTEM PREFERENCES'),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.notifications_active_outlined,
              title: 'Match Alerts',
              subtitle: 'Push notifications for tournament fixtures',
              trailing: Switch(
                value: matchAlerts,
                onChanged: (v) async {
                  ref.read(matchAlertsProvider.notifier).state = v;
                  await _persistToggle('match_alerts', v);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Match Alerts ${v ? 'Enabled' : 'Disabled'}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: AppColors.cyan,
              ),
            ).animate().fade(delay: 200.ms),
            _buildSettingsTile(
              icon: Icons.auto_awesome,
              title: 'AI Tactical Insights',
              subtitle: 'Enable post-match AI analysis engine',
              trailing: Switch(
                value: aiInsights,
                onChanged: (v) async {
                  ref.read(aiInsightsSettingsProvider.notifier).state = v;
                  await _persistToggle('ai_insights', v);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('AI Tactical Insights ${v ? 'Enabled' : 'Disabled'}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: AppColors.cyan,
              ),
            ).animate().fade(delay: 250.ms),
            _buildSettingsTile(
              icon: Icons.vibration,
              title: 'Haptic Feedback',
              subtitle: 'Vibrate on match submission and OCR detection',
              trailing: Switch(
                value: haptic,
                onChanged: (v) async {
                  ref.read(hapticFeedbackProvider.notifier).state = v;
                  await _persistToggle('haptic_feedback', v);
                },
                activeThumbColor: AppColors.cyan,
              ),
            ).animate().fade(delay: 300.ms),
            _buildSettingsTile(
              icon: Icons.visibility_outlined,
              title: 'Public Profile Visibility',
              subtitle: profilePrefs.isPublic
                  ? 'Your profile card is visible in shared club views'
                  : 'Your profile stays private until you switch it back on',
              trailing: Switch(
                value: profilePrefs.isPublic,
                onChanged: (v) async {
                  await ref.read(profilePreferencesProvider.notifier).update(isPublic: v);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(v ? 'Profile visibility enabled' : 'Profile visibility disabled'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                activeThumbColor: AppColors.cyan,
              ),
            ).animate().fade(delay: 320.ms),

            const SizedBox(height: 28),

            // Offline Sync & Engine Status
            _buildSectionHeader('OFFLINE SYNC & DATA ENGINE'),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.cloud_sync_outlined,
              title: 'Offline Match Queue',
              subtitle: _pendingCount > 0
                  ? '$_pendingCount matches waiting to sync'
                  : 'All local match data is synchronized',
              trailing: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.sync, size: 16, color: Colors.black),
                      label: Text(
                        'FORCE SYNC',
                        style: GoogleFonts.rajdhani(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      onPressed: () async {
                        setState(() => _isSyncing = true);
                        try {
                          final client = ref.read(apiClientProvider);
                          final res = await ref.read(offlineSyncProvider).syncPending(client);
                          await _refreshPendingCount();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sync complete: ${res.synced} synced, ${res.failed} failed.'),
                                backgroundColor: AppColors.winGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sync error: $e'),
                                backgroundColor: AppColors.lossRed,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSyncing = false);
                        }
                      },
                    ),
            ).animate().fade(delay: 350.ms),

            const SizedBox(height: 28),

            // Admin & Governance Hub
            _buildSectionHeader('ADMIN & GOVERNANCE HUB'),
            const SizedBox(height: 12),
            _buildActionTile(
              icon: Icons.gavel,
              title: 'Admin Dispute Center',
              subtitle: 'Review & resolve player match result disputes',
              color: Colors.amber,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDisputeScreen()),
                );
              },
            ).animate().fade(delay: 400.ms),
            const SizedBox(height: 28),

            // Server & Network Status
            _buildSectionHeader('API BACKEND HEALTH'),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: AppColors.cyan.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.dns, color: AppColors.cyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server Status: $_serverStatus',
                          style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'Backend API v1',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cyan),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _isPinging ? null : _pingServer,
                    child: _isPinging
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                          )
                        : Text(
                            'PING',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.cyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                  ),
                ],
              ),
            ).animate().fade(delay: 500.ms),

            const SizedBox(height: 40),

            // Terminate Session Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.power_settings_new, size: 20),
                label: Text(
                  'TERMINATE SESSION',
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lossRed.withValues(alpha: 0.2),
                  foregroundColor: AppColors.lossRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.6)),
                ),
                onPressed: _confirmLogout,
              ),
            ).animate().fade(delay: 550.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderContent({
    required String username,
    required String userId,
    required int skillRating,
    required String playStyle,
  }) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.4),
                blurRadius: 12,
              )
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: GoogleFonts.rajdhani(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Skill Rating: $skillRating PTS • $playStyle',
                style: const TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'ID: ${userId.length > 8 ? userId.substring(0, 8) : userId}...',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: AppColors.cyan, size: 20),
          tooltip: 'Update Play Style',
          onPressed: () => _showEditProfileDialog(ProfilePreferences(
            displayName: username,
            playStyle: playStyle,
          )),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.cyan,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.cyan, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      borderColor: color.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
