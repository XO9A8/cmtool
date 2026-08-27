import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/offline_sync_service.dart';

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
    _refreshPendingCount();
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
          _serverStatus = ok ? 'ONLINE (200 OK)' : 'UNREACHABLE';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverStatus = 'OFFLINE';
        });
      }
    } finally {
      if (mounted) setState(() => _isPinging = false);
    }
  }

  void _showUpdatePasswordDialog() {
    final passwordController = TextEditingController();
    bool isUpdating = false;
    final colors = context.themeColors;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder),
          ),
          title: Text(
            'UPDATE PASSWORD',
            style: GoogleFonts.rajdhani(
              color: colors.isLight ? colors.navy : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                style: TextStyle(color: colors.isLight ? colors.navy : Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: TextStyle(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.isLight
                      ? colors.surfaceLight
                      : Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isUpdating ? null : () => Navigator.pop(ctx),
              child: Text('CANCEL', style: TextStyle(color: colors.textMuted)),
            ),
            ElevatedButton(
              onPressed: isUpdating
                  ? null
                  : () async {
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
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.buttonTextColor,
              ),
              child: isUpdating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: colors.buttonTextColor,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'UPDATE',
                      style: GoogleFonts.rajdhani(
                        color: colors.buttonTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
    final colors = context.themeColors;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.cardBorder),
          ),
          title: Text(
            'UPDATE PROFILE',
            style: GoogleFonts.rajdhani(
              color: colors.isLight ? colors.navy : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: displayNameController,
                style: TextStyle(color: colors.isLight ? colors.navy : Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: colors.textMuted),
                  filled: true,
                  fillColor: colors.isLight
                      ? colors.surfaceLight
                      : Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select your primary tactical play style preference:',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: validStyles.contains(selectedStyle) ? selectedStyle : validStyles.first,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.isLight ? colors.navy : Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colors.isLight
                      ? colors.surfaceLight
                      : Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.cardBorder),
                  ),
                ),
                items: validStyles.map((style) {
                  return DropdownMenuItem(
                    value: style,
                    child: Text(
                      style,
                      style: TextStyle(color: colors.isLight ? colors.navy : Colors.white),
                    ),
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
              child: Text('CANCEL', style: TextStyle(color: colors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.buttonTextColor,
              ),
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
                      backgroundColor: colors.winGreen,
                    ),
                  );
                }
              },
              child: Text(
                'SAVE CHANGES',
                style: GoogleFonts.rajdhani(
                  color: colors.buttonTextColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    final colors = context.themeColors;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.lossRed),
        ),
        title: Text(
          'TERMINATE SESSION',
          style: GoogleFonts.rajdhani(
            color: colors.isLight ? colors.navy : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of the Player Dashboard?',
          style: TextStyle(color: colors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: TextStyle(color: colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.lossRed),
            onPressed: () async {
              Navigator.pop(ctx);
              final client = ref.read(apiClientProvider);
              await ref.read(authStateProvider.notifier).logout(client);
            },
            child: Text(
              'LOGOUT',
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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

    final currentTheme = ref.watch(themeProvider);
    final profilePrefs = ref.watch(profilePreferencesProvider);
    final colors = context.themeColors;
    final titleColor = colors.isLight ? colors.navy : Colors.white;

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
            color: colors.isLight ? colors.navy : colors.cyan,
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
            _buildSectionHeader('ACCOUNT SECURITY', colors),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: colors.cardBorder,
              child: ListTile(
                leading: Icon(Icons.lock_outline, color: colors.cyan),
                title: Text(
                  'Update Password',
                  style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Change your account password',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right, color: colors.textMuted),
                onTap: _showUpdatePasswordDialog,
              ),
            ),
            const SizedBox(height: 24),

            // Operative Profile Header
            _buildSectionHeader('OPERATIVE PROFILE', colors),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: colors.cardBorder,
              padding: const EdgeInsets.all(20),
              child: profileAsync?.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: colors.cyan),
                    ),
                    error: (_, __) => _buildProfileHeaderContent(
                      username: 'Player',
                      userId: userId ?? 'Unknown',
                      skillRating: 1500,
                      playStyle: 'Possession Game',
                      colors: colors,
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
                        colors: colors,
                      );
                    },
                  ) ??
                  _buildProfileHeaderContent(
                    username: profilePrefs.displayName,
                    userId: userId ?? 'Unknown',
                    skillRating: 1500,
                    playStyle: profilePrefs.playStyle,
                    colors: colors,
                  ),
            ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

            const SizedBox(height: 28),

            // Appearance & Theme
            _buildSectionHeader('THEME & APPEARANCE', colors),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: colors.cardBorder,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildThemeOptionCard(
                    themeType: AppThemeType.classic,
                    isSelected: currentTheme == AppThemeType.classic,
                    previewColors: const [
                      Color(0xFFFF6D00), // Electric Orange
                      Color(0xFF00E5FF), // Cyber Cyan
                      Color(0xFF090A0F), // Void Dark
                    ],
                    onTap: () => ref.read(themeProvider.notifier).setTheme(AppThemeType.classic),
                    colors: colors,
                  ),
                  const SizedBox(height: 10),
                  _buildThemeOptionCard(
                    themeType: AppThemeType.daylight,
                    isSelected: currentTheme == AppThemeType.daylight,
                    previewColors: const [
                      Color(0xFFD90429), // Championship Scarlet
                      Color(0xFFC9A84C), // Trophy Gold
                      Color(0xFFF5F3EE), // Programme Paper
                    ],
                    onTap: () => ref.read(themeProvider.notifier).setTheme(AppThemeType.daylight),
                    colors: colors,
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms),
            const SizedBox(height: 12),
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
                activeThumbColor: colors.cyan,
              ),
              colors: colors,
            ).animate().fade(delay: 320.ms),

            const SizedBox(height: 28),

            // Offline Sync & Engine Status
            _buildSectionHeader('OFFLINE SYNC & DATA ENGINE', colors),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.cloud_sync_outlined,
              title: 'Offline Match Queue',
              subtitle: _pendingCount > 0
                  ? '$_pendingCount matches waiting to sync'
                  : 'All local match data is synchronized',
              trailing: _isSyncing
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.cyan),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.buttonTextColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: Icon(Icons.sync, size: 16, color: colors.buttonTextColor),
                      label: Text(
                        'FORCE SYNC',
                        style: GoogleFonts.rajdhani(
                          color: colors.buttonTextColor,
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
                                backgroundColor: colors.winGreen,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sync error: $e'),
                                backgroundColor: colors.lossRed,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSyncing = false);
                        }
                      },
                    ),
              colors: colors,
            ).animate().fade(delay: 350.ms),

            const SizedBox(height: 28),

            // Server & Network Status
            _buildSectionHeader('API BACKEND HEALTH', colors),
            const SizedBox(height: 12),
            GlassCard(
              borderColor: colors.cardBorder,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.dns, color: colors.cyan, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server Status: $_serverStatus',
                          style: GoogleFonts.rajdhani(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Backend API v1',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.cyan),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _isPinging ? null : _pingServer,
                    child: _isPinging
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.cyan),
                          )
                        : Text(
                            'PING',
                            style: GoogleFonts.rajdhani(
                              color: colors.cyan,
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
                  backgroundColor: colors.lossRed.withValues(alpha: 0.15),
                  foregroundColor: colors.lossRed,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: colors.lossRed.withValues(alpha: 0.6)),
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
    required AppThemeExtension colors,
  }) {
    final titleColor = colors.isLight ? colors.navy : Colors.white;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.primary, colors.cyan],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.cyan.withValues(alpha: 0.4),
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
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Skill Rating: $skillRating PTS • $playStyle',
                style: TextStyle(color: colors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'ID: ${userId.length > 8 ? userId.substring(0, 8) : userId}...',
                style: TextStyle(color: colors.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit, color: colors.cyan, size: 20),
          tooltip: 'Update Play Style',
          onPressed: () => _showEditProfileDialog(ProfilePreferences(
            displayName: username,
            playStyle: playStyle,
          )),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, AppThemeExtension colors) {
    return Text(
      title,
      style: GoogleFonts.rajdhani(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: colors.cyan,
        letterSpacing: 1.8,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required AppThemeExtension colors,
  }) {
    final titleColor = colors.isLight ? colors.navy : Colors.white;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderColor: colors.cardBorder,
      child: Row(
        children: [
          Icon(icon, color: colors.cyan, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildThemeOptionCard({
    required AppThemeType themeType,
    required bool isSelected,
    required VoidCallback onTap,
    required List<Color> previewColors,
    required AppThemeExtension colors,
  }) {
    final titleColor = colors.isLight ? colors.navy : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? previewColors.first.withValues(alpha: colors.isLight ? 0.12 : 0.15)
              : (colors.isLight ? colors.surfaceLight : Colors.white.withValues(alpha: 0.03)),
          border: Border.all(
            color: isSelected ? previewColors.first : colors.cardBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: previewColors.first.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Row(
              children: previewColors
                  .map(
                    (c) => Container(
                      width: 13,
                      height: 13,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.isLight ? const Color(0xFF0A1628).withValues(alpha: 0.2) : Colors.white24,
                          width: 1,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    themeType.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? titleColor : colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    themeType.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? previewColors.first : colors.textMuted.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
