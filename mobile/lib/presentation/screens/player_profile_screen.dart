import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../widgets/mps_radar_chart.dart';

/// Predefined Avatar Graphic item
class PredefinedAvatar {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradient;

  const PredefinedAvatar({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
  });
}

const List<PredefinedAvatar> predefinedAvatars = [
  PredefinedAvatar(
    id: 'striker',
    name: 'Striker Ace',
    icon: Icons.sports_soccer,
    gradient: [Color(0xFFFF6D00), Color(0xFFFFD700)],
  ),
  PredefinedAvatar(
    id: 'inferno',
    name: 'Inferno Flame',
    icon: Icons.local_fire_department,
    gradient: [Color(0xFFFF1744), Color(0xFFFF9100)],
  ),
  PredefinedAvatar(
    id: 'lightning',
    name: 'Cyber Bolt',
    icon: Icons.bolt,
    gradient: [Color(0xFF00E5FF), Color(0xFFFFEA00)],
  ),
  PredefinedAvatar(
    id: 'defender',
    name: 'Iron Shield',
    icon: Icons.shield,
    gradient: [Color(0xFF2979FF), Color(0xFFB000FF)],
  ),
  PredefinedAvatar(
    id: 'crown',
    name: 'Golden Crown',
    icon: Icons.workspace_premium,
    gradient: [Color(0xFFFFD700), Color(0xFFFFAB00)],
  ),
  PredefinedAvatar(
    id: 'star',
    name: 'Mystic Star',
    icon: Icons.auto_awesome,
    gradient: [Color(0xFFE040FB), Color(0xFF7C4DFF)],
  ),
  PredefinedAvatar(
    id: 'commander',
    name: 'Honor Badge',
    icon: Icons.military_tech,
    gradient: [Color(0xFF00E676), Color(0xFF00B0FF)],
  ),
  PredefinedAvatar(
    id: 'tactician',
    name: 'Mastermind',
    icon: Icons.psychology,
    gradient: [Color(0xFF00B8D4), Color(0xFF64FFDA)],
  ),
  PredefinedAvatar(
    id: 'fortress',
    name: 'Titan Fortress',
    icon: Icons.fort,
    gradient: [Color(0xFF607D8B), Color(0xFFCFD8DC)],
  ),
  PredefinedAvatar(
    id: 'mecha',
    name: 'Mecha Cyber',
    icon: Icons.smart_toy,
    gradient: [Color(0xFF00E676), Color(0xFF00E5FF)],
  ),
  PredefinedAvatar(
    id: 'shadow',
    name: 'Shadow Dragon',
    icon: Icons.pest_control_rodent,
    gradient: [Color(0xFFB000FF), Color(0xFFFF1744)],
  ),
  PredefinedAvatar(
    id: 'apex',
    name: 'Apex Racer',
    icon: Icons.sports_motorsports,
    gradient: [Color(0xFFFF3D00), Color(0xFFFFC400)],
  ),
];

PredefinedAvatar getAvatarById(String? id) {
  return predefinedAvatars.firstWhere(
    (a) => a.id == id,
    orElse: () => predefinedAvatars.first,
  );
}

/// Full Player Profile screen with reimagined esports styling, interactive dossier,
/// career analytics, match history timeline, badges, and editable user profile.
class PlayerProfileScreen extends ConsumerStatefulWidget {
  final String? playerId;

  const PlayerProfileScreen({super.key, this.playerId});

  @override
  ConsumerState<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  int _selectedTabIndex = 0; // 0: Dossier & Contact, 1: Career & Analytics, 2: Matches & Badges

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authStateProvider) ?? '';
    final targetUserId = (widget.playerId != null && widget.playerId!.isNotEmpty)
        ? widget.playerId!
        : currentUserId;
    final isOwnProfile = (targetUserId == currentUserId);

    final profileAsync = ref.watch(playerProfileProvider(targetUserId));
    final eloAsync = ref.watch(eloHistoryProvider(targetUserId));
    final matchesAsync = ref.watch(matchHistoryProvider(targetUserId));
    final profilePrefs = ref.watch(profilePreferencesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // Collapsing Esports Header & Hero Card
          SliverAppBar(
            expandedHeight: 310,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => _buildHeroCard(
                  context,
                  ref,
                  targetUserId,
                  isOwnProfile,
                  0,
                  0.0,
                  profilePrefs.playStyle,
                  0,
                  0,
                  0,
                  0,
                  0.0,
                  profilePrefs,
                  {},
                ),
                data: (data) => _buildHeroCard(
                  context,
                  ref,
                  targetUserId,
                  isOwnProfile,
                  data['skill_rating'] ?? 0,
                  (data['form_rating'] as num?)?.toDouble() ?? 0.0,
                  isOwnProfile && profilePrefs.playStyle.isNotEmpty
                      ? profilePrefs.playStyle
                      : (data['play_style'] as String? ?? 'Possession Game'),
                  data['matches_played'] ?? 0,
                  data['wins'] ?? 0,
                  data['draws'] ?? 0,
                  data['losses'] ?? 0,
                  (data['win_rate'] as num?)?.toDouble() ?? 0.0,
                  profilePrefs,
                  data,
                ),
              ),
            ),
          ),

          // Sticky Segmented Tab Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _EsportsTabHeaderDelegate(
              selectedIndex: _selectedTabIndex,
              onTabSelected: (idx) {
                setState(() {
                  _selectedTabIndex = idx;
                });
              },
            ),
          ),

          // Main Tab Content Area
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildTabContent(
                  context,
                  ref,
                  targetUserId,
                  isOwnProfile,
                  _selectedTabIndex,
                  profileAsync,
                  eloAsync,
                  matchesAsync,
                  profilePrefs,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool isOwnProfile,
    int elo,
    double form,
    String style,
    int played,
    int wins,
    int draws,
    int losses,
    double winRate,
    ProfilePreferences profilePrefs,
    Map<String, dynamic> data,
  ) {
    // Rank Tier Calculation
    String tierName;
    Color tierColor;
    if (elo >= 1800) {
      tierName = 'LEGEND';
      tierColor = const Color(0xFFFFD700);
    } else if (elo >= 1600) {
      tierName = 'GRANDMASTER';
      tierColor = AppColors.purple;
    } else if (elo >= 1400) {
      tierName = 'MASTER';
      tierColor = AppColors.cyan;
    } else {
      tierName = 'PRO';
      tierColor = AppColors.winGreen;
    }

    final displayName = isOwnProfile && profilePrefs.safeDisplayName.isNotEmpty
        ? profilePrefs.safeDisplayName
        : (data['username'] as String? ?? data['display_name'] as String? ?? 'PLAYER');

    final avatarKey = isOwnProfile && profilePrefs.safeAvatarGraphic.isNotEmpty
        ? profilePrefs.safeAvatarGraphic
        : (data['avatar_graphic'] as String? ?? 'striker');
    final avatarData = getAvatarById(avatarKey);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E1704), Color(0xFF141624), Color(0xFF090A0F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              // Avatar with predefined graphic & glowing rank ring
              GestureDetector(
                onTap: isOwnProfile
                    ? () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs)
                    : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: avatarData.gradient,
                        ),
                        boxShadow: [
                          BoxShadow(color: avatarData.gradient.first.withValues(alpha: 0.5), blurRadius: 20),
                        ],
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                      ),
                      child: Icon(avatarData.icon, color: avatarData.gradient.first, size: 36),
                    ),
                    if (isOwnProfile)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 10, color: Colors.black),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tierColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tierName,
                          style: GoogleFonts.orbitron(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Player Name, Elo & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName.toUpperCase(),
                            style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$elo',
                          style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'PTS',
                          style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        GlowBadge(label: style, color: AppColors.cyan),
                        GlowBadge(label: '${winRate.toStringAsFixed(0)}% WR', color: Colors.white70),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('MATCHES', '$played'),
                _buildQuickStat('W', '$wins', color: AppColors.winGreen),
                _buildQuickStat('D', '$draws', color: Colors.amber),
                _buildQuickStat('L', '$losses', color: AppColors.lossRed),
                _buildQuickStat('FORM', form.toStringAsFixed(1), color: AppColors.cyan),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons Row (Edit Profile / Player Profile & Share Card)
          Row(
            children: [
              Expanded(
                child: isOwnProfile
                    ? Container(
                        height: 38,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFFFF8C00)],
                          ),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.edit, size: 16, color: Colors.black),
                          label: Text(
                            'EDIT PROFILE',
                            style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1),
                          ),
                          onPressed: () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs),
                        ),
                      )
                    : Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.cyan.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified, size: 15, color: AppColors.cyan),
                            const SizedBox(width: 6),
                            Text(
                              'PLAYER PROFILE',
                              style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cyan),
                    color: AppColors.cyan.withValues(alpha: 0.1),
                  ),
                  child: TextButton.icon(
                    icon: const Icon(Icons.share, size: 15, color: AppColors.cyan),
                    label: Text(
                      'SHARE CARD',
                      style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1),
                    ),
                    onPressed: () => _showUltimateCardPreview(context, profilePrefs, data),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05, duration: 400.ms);
  }

  Widget _buildQuickStat(String label, String value, {Color color = Colors.white}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.rajdhani(fontSize: 9, color: AppColors.textMuted, letterSpacing: 1, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool isOwnProfile,
    int tabIndex,
    AsyncValue<Map<String, dynamic>> profileAsync,
    AsyncValue<Map<String, dynamic>> eloAsync,
    AsyncValue<Map<String, dynamic>> matchesAsync,
    ProfilePreferences profilePrefs,
  ) {
    switch (tabIndex) {
      case 0:
        return profileAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary))),
          error: (_, __) => _buildDossierTab(context, ref, userId, isOwnProfile, {}, profilePrefs),
          data: (data) => _buildDossierTab(context, ref, userId, isOwnProfile, data, profilePrefs),
        );
      case 1:
        return _buildAnalyticsTab(profileAsync, eloAsync);
      case 2:
        return _buildMatchesAndBadgesTab(context, ref, matchesAsync, profileAsync);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: Dossier & Registry Contact (With Editing Triggers)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDossierTab(
    BuildContext context,
    WidgetRef ref,
    String userId,
    bool isOwnProfile,
    Map<String, dynamic> data,
    ProfilePreferences profilePrefs,
  ) {
    final gameId = isOwnProfile && profilePrefs.gameId.isNotEmpty
        ? profilePrefs.gameId
        : (data['efootball_game_id'] as String? ?? 'N/A');
    final foot = isOwnProfile && profilePrefs.preferredFoot.isNotEmpty
        ? profilePrefs.preferredFoot
        : (data['preferred_foot'] as String? ?? 'Right');
    final jersey = isOwnProfile && profilePrefs.jerseyNumber.isNotEmpty
        ? profilePrefs.jerseyNumber
        : (data['jersey_number']?.toString() ?? 'N/A');
    final device = isOwnProfile && profilePrefs.systemDevice.isNotEmpty
        ? profilePrefs.systemDevice
        : (data['system_device'] as String? ?? 'PlayStation 5');
    final facebook = isOwnProfile && profilePrefs.facebookLink.isNotEmpty
        ? profilePrefs.facebookLink
        : (data['contact_info']?['facebook_link'] as String? ?? 'N/A');
    final district = isOwnProfile && profilePrefs.district.isNotEmpty
        ? profilePrefs.district
        : (data['contact_info']?['district'] as String? ?? 'N/A');
    final dob = isOwnProfile && profilePrefs.dateOfBirth.isNotEmpty
        ? profilePrefs.dateOfBirth
        : (data['contact_info']?['date_of_birth'] as String? ?? 'N/A');
    final email = isOwnProfile && profilePrefs.contactEmail.isNotEmpty
        ? profilePrefs.contactEmail
        : (data['contact_info']?['email_node'] as String? ?? 'N/A');
    final phone = isOwnProfile && profilePrefs.phoneLine.isNotEmpty
        ? profilePrefs.phoneLine
        : (data['contact_info']?['phone_line'] as String? ?? 'N/A');
    final bio = isOwnProfile && profilePrefs.bio.isNotEmpty
        ? profilePrefs.bio
        : (data['bio'] as String? ?? 'No biometric bio profile submitted to registry.');

    final joined = data['compliance']?['registrar_joined'] as String? ?? '2026-01-01';
    final start = data['compliance']?['contract_start'] as String? ?? '2026-01-01';
    final end = data['compliance']?['contract_end'] as String? ?? '2026-12-31';
    final state = data['compliance']?['node_state'] as String? ?? 'ACTIVE NODE';
    final authStatus = data['compliance']?['auth_status'] as String? ?? 'VERIFIED';
    final feed = data['compliance']?['source_feed'] as String? ?? 'ENCRYPTED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bio Slogan Header Card
        GlassCard(
          borderColor: AppColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.format_quote, color: AppColors.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'PLAYER TACTICAL BIO',
                        style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  if (isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: AppColors.cyan, size: 20),
                      tooltip: 'Edit Bio',
                      onPressed: () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '"$bio"',
                style: GoogleFonts.shareTechMono(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Player Dossier Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium, size: 18, color: Color(0xFFFFD700)),
                      const SizedBox(width: 8),
                      Text(
                        'PLAYER DOSSIER',
                        style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                    ],
                  ),
                  if (isOwnProfile)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      icon: const Icon(Icons.edit, size: 14, color: AppColors.cyan),
                      label: Text('EDIT', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cyan)),
                      onPressed: () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white10),
              _buildDossierRow('EFOOTBALL GAME ID', gameId, valColor: Colors.white, icon: Icons.sports_esports),
              _buildDossierRow('PREFERRED FOOT', foot, valColor: AppColors.cyan, icon: Icons.straighten),
              _buildDossierRow('JERSEY NUMBER', jersey, valColor: Colors.white, icon: Icons.numbers),
              _buildDossierRow('SYSTEM DEVICE', device, valColor: Colors.white, icon: Icons.devices),
              _buildDossierRow(
                'PLAY STYLE',
                isOwnProfile && profilePrefs.playStyle.isNotEmpty
                    ? profilePrefs.playStyle
                    : (data['play_style'] as String? ?? 'Possession Game'),
                valColor: AppColors.primary,
                isBold: true,
                icon: Icons.auto_awesome,
              ),
              _buildDossierRow('DISTRICT / REGION', district, valColor: Colors.white70, icon: Icons.location_on),
              _buildDossierRow('DATE OF BIRTH', dob, valColor: Colors.white70, icon: Icons.cake),
              _buildDossierRow('REGISTRAR JOINED', joined, valColor: Colors.white54, icon: Icons.calendar_today),
              _buildDossierRow('CONTRACT START', start, valColor: Colors.white54, icon: Icons.play_arrow),
              _buildDossierRow('CONTRACT END', end, valColor: const Color(0xFFFFD700), isBold: true, icon: Icons.flag),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Registry Contact Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REGISTRY CONTACT',
                    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5),
                  ),
                  if (isOwnProfile)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 14, color: AppColors.cyan),
                      onPressed: () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs),
                    ),
                ],
              ),
              const Divider(color: Colors.white10),
              _buildDossierRow('CONTACT EMAIL', email, valColor: const Color(0xFFFFD700), icon: Icons.email),
              _buildDossierRow('PHONE LINE', phone, valColor: const Color(0xFF00FFC2), icon: Icons.phone),
              _buildDossierRow('FACEBOOK LINK', facebook, valColor: const Color(0xFF00E5FF), icon: Icons.link),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Compliance Verification Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.winGreen.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user, color: AppColors.winGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'COMPLIANCE VERIFICATION',
                    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.winGreen, letterSpacing: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white10),
              _buildDossierRow('NODE STATE', state, valColor: const Color(0xFF00FF66), isBold: true, icon: Icons.dns),
              _buildDossierRow('AUTH STATUS', authStatus, valColor: Colors.white, isBold: true, icon: Icons.security),
              _buildDossierRow('SOURCE FEED', feed, valColor: const Color(0xFFFFD700), isBold: true, icon: Icons.wifi_lock),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: Career & Analytics
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab(
    AsyncValue<Map<String, dynamic>> profileAsync,
    AsyncValue<Map<String, dynamic>> eloAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('SKILL RATING PROGRESSION'),
        const SizedBox(height: 12),
        eloAsync.when(
          loading: () => _buildChartSkeleton(),
          error: (_, __) => _buildEmptyState('No rating history available'),
          data: (data) {
            final history = data['history'] as List<dynamic>? ?? [];
            if (history.isEmpty) return _buildEmptyState('Play matches to track your rating progression');
            return _buildEloChart(history);
          },
        ),

        const SizedBox(height: 24),

        _buildSectionHeader('CAREER STATISTICS'),
        const SizedBox(height: 12),
        profileAsync.when(
          loading: () => _buildStatsGridSkeleton(),
          error: (_, __) => _buildStatsGrid(0, 0, 0, 0, 0.0, 0.0),
          data: (data) => _buildStatsGrid(
            data['matches_played'] ?? 0,
            data['wins'] ?? 0,
            data['draws'] ?? 0,
            data['losses'] ?? 0,
            (data['win_rate'] as num?)?.toDouble() ?? 0.0,
            (data['form_rating'] as num?)?.toDouble() ?? 0.0,
          ),
        ),

        const SizedBox(height: 24),

        _buildSectionHeader('MATCH PERFORMANCE BREAKDOWN'),
        const SizedBox(height: 12),
        profileAsync.when(
          loading: () => _buildChartSkeleton(),
          error: (_, __) => _buildEmptyState('Could not load performance radar'),
          data: (data) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
              ),
              child: MpsRadarChart(
                possession: (data['avg_possession'] as num?)?.toDouble() ?? 55.0,
                passAccuracy: (data['avg_pass_accuracy'] as num?)?.toDouble() ?? 82.0,
                shotEfficiency: (data['avg_shot_efficiency'] as num?)?.toDouble() ?? 42.0,
                interceptions: (data['avg_interceptions'] as num?)?.toDouble() ?? 6.5,
                formRating: (data['form_rating'] as num?)?.toDouble() ?? 7.5,
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: Matches & Badges
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMatchesAndBadgesTab(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>> matchesAsync,
    AsyncValue<Map<String, dynamic>> profileAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('RECENT MATCHES & DISPUTES'),
        const SizedBox(height: 12),
        matchesAsync.when(
          loading: () => Column(
            children: List.generate(
              3,
              (_) => Container(
                height: 70,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 0.6),
          error: (_, __) => _buildEmptyState('Could not load match history'),
          data: (data) {
            final matches = data['matches'] as List<dynamic>? ?? [];
            if (matches.isEmpty) return _buildEmptyState('No matches recorded yet');
            return Column(
              children: matches.take(10).map((m) => _buildMatchTile(context, ref, m)).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        _buildSectionHeader('EARNED BADGES'),
        const SizedBox(height: 12),
        profileAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => _buildEmptyState('No badges unlocked yet'),
          data: (data) {
            final badges = data['badges'] as List<dynamic>? ?? [];
            if (badges.isEmpty) return _buildEmptyState('Play more tournament matches to unlock badges');
            return Column(
              children: badges
                  .map((b) => _buildBadgeTile(
                        b['name'] ?? 'Badge',
                        b['description'] ?? '',
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT PROFILE MODAL BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showEditProfileBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String userId,
    Map<String, dynamic> data,
    ProfilePreferences profilePrefs,
  ) {
    final displayNameCtrl = TextEditingController(
      text: profilePrefs.safeDisplayName.isNotEmpty ? profilePrefs.safeDisplayName : (data['username'] as String? ?? ''),
    );
    final bioCtrl = TextEditingController(
      text: profilePrefs.safeBio.isNotEmpty ? profilePrefs.safeBio : (data['bio'] as String? ?? ''),
    );
    final gameIdCtrl = TextEditingController(
      text: profilePrefs.safeGameId.isNotEmpty ? profilePrefs.safeGameId : (data['efootball_game_id'] as String? ?? ''),
    );
    final jerseyCtrl = TextEditingController(
      text: profilePrefs.safeJerseyNumber.isNotEmpty ? profilePrefs.safeJerseyNumber : (data['jersey_number']?.toString() ?? ''),
    );
    final emailCtrl = TextEditingController(
      text: profilePrefs.safeContactEmail.isNotEmpty ? profilePrefs.safeContactEmail : (data['contact_info']?['email_node'] as String? ?? ''),
    );
    final phoneCtrl = TextEditingController(
      text: profilePrefs.safePhoneLine.isNotEmpty ? profilePrefs.safePhoneLine : (data['contact_info']?['phone_line'] as String? ?? ''),
    );
    final facebookCtrl = TextEditingController(
      text: profilePrefs.safeFacebookLink.isNotEmpty ? profilePrefs.safeFacebookLink : (data['contact_info']?['facebook_link'] as String? ?? ''),
    );
    final districtCtrl = TextEditingController(
      text: profilePrefs.safeDistrict.isNotEmpty ? profilePrefs.safeDistrict : (data['contact_info']?['district'] as String? ?? ''),
    );
    final dobCtrl = TextEditingController(
      text: profilePrefs.safeDateOfBirth.isNotEmpty ? profilePrefs.safeDateOfBirth : (data['contact_info']?['date_of_birth'] as String? ?? ''),
    );

    String selectedPlayStyle = profilePrefs.safePlayStyle.isNotEmpty
        ? profilePrefs.safePlayStyle
        : (data['play_style'] as String? ?? 'Possession Game');
    if (!['Possession Game', 'Quick Counter', 'Out Wide', 'Long Ball Counter', 'Long Ball'].contains(selectedPlayStyle)) {
      selectedPlayStyle = 'Possession Game';
    }

    String selectedFoot = profilePrefs.safePreferredFoot.isNotEmpty
        ? profilePrefs.safePreferredFoot
        : (data['preferred_foot'] as String? ?? 'Right');
    if (!['Right', 'Left', 'Both'].contains(selectedFoot)) {
      selectedFoot = 'Right';
    }

    String selectedDevice = profilePrefs.safeSystemDevice.isNotEmpty
        ? profilePrefs.safeSystemDevice
        : (data['system_device'] as String? ?? 'PlayStation 5');
    if (!['PlayStation 5', 'Xbox Series X|S', 'PC / Steam', 'Mobile', 'Cross-Platform'].contains(selectedDevice)) {
      selectedDevice = 'PlayStation 5';
    }

    String selectedAvatarGraphic = profilePrefs.safeAvatarGraphic.isNotEmpty
        ? profilePrefs.safeAvatarGraphic
        : (data['avatar_graphic'] as String? ?? 'striker');

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: BoxDecoration(
                color: const Color(0xFF10121D),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 30, offset: const Offset(0, -5)),
                ],
              ),
              child: Column(
                children: [
                  // Top Drag Handle & Title
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'EDIT DOSSIER & PROFILE',
                              style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // Form Fields List
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormSectionHeader('SELECT PREDEFINED AVATAR GRAPHIC'),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.85,
                            ),
                            itemCount: predefinedAvatars.length,
                            itemBuilder: (ctx, i) {
                              final avatar = predefinedAvatars[i];
                              final isSelected = selectedAvatarGraphic == avatar.id;
                              return GestureDetector(
                                onTap: () => setModalState(() => selectedAvatarGraphic = avatar.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(colors: avatar.gradient),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: avatar.gradient.first.withValues(alpha: 0.6), blurRadius: 12)]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(avatar.icon, color: Colors.white, size: 26),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          avatar.name,
                                          style: GoogleFonts.orbitron(
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 24),
                          _buildFormSectionHeader('BASIC PLAYER IDENTIFICATION'),
                          const SizedBox(height: 12),
                          _buildCustomTextField(displayNameCtrl, 'Display Name / Alias', Icons.person),
                          const SizedBox(height: 12),
                          _buildCustomTextField(bioCtrl, 'Tactical Bio / Motto', Icons.format_quote, maxLines: 2),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            label: 'Tactical Play Style',
                            value: selectedPlayStyle,
                            items: const ['Possession Game', 'Quick Counter', 'Out Wide', 'Long Ball Counter', 'Long Ball'],
                            onChanged: (v) => setModalState(() => selectedPlayStyle = v!),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            label: 'Preferred Foot',
                            value: selectedFoot,
                            items: const ['Right', 'Left', 'Both'],
                            onChanged: (v) => setModalState(() => selectedFoot = v!),
                          ),

                          const SizedBox(height: 24),
                          _buildFormSectionHeader('GAMING DOSSIER REGISTRATION'),
                          const SizedBox(height: 12),
                          _buildCustomTextField(gameIdCtrl, 'eFootball Game ID (Owner / Konami ID)', Icons.sports_esports),
                          const SizedBox(height: 12),
                          _buildCustomTextField(jerseyCtrl, 'Jersey Number', Icons.numbers, keyboardType: TextInputType.number),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            label: 'Primary Gaming Platform/Device',
                            value: selectedDevice,
                            items: const ['PlayStation 5', 'Xbox Series X|S', 'PC / Steam', 'Mobile', 'Cross-Platform'],
                            onChanged: (v) => setModalState(() => selectedDevice = v!),
                          ),

                          const SizedBox(height: 24),
                          _buildFormSectionHeader('REGISTRY CONTACT & LOCATION'),
                          const SizedBox(height: 12),
                          _buildCustomTextField(emailCtrl, 'Contact Email', Icons.email, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _buildCustomTextField(phoneCtrl, 'Phone Line', Icons.phone, keyboardType: TextInputType.phone),
                          const SizedBox(height: 12),
                          _buildCustomTextField(facebookCtrl, 'Facebook Link / Handle', Icons.link),
                          const SizedBox(height: 12),
                          _buildCustomTextField(districtCtrl, 'District / Region', Icons.location_on),
                          const SizedBox(height: 12),
                          _buildCustomTextField(dobCtrl, 'Date of Birth (YYYY-MM-DD)', Icons.cake),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Save Action Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF090A0F),
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('CANCEL', style: GoogleFonts.orbitron(color: Colors.white54, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFFFF8C00)],
                              ),
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12),
                              ],
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      setModalState(() => isSaving = true);
                                      try {
                                        // 1. Update Riverpod Local Preference State & SharedPreferences
                                        await ref.read(profilePreferencesProvider.notifier).update(
                                              displayName: displayNameCtrl.text.trim(),
                                              bio: bioCtrl.text.trim(),
                                              playStyle: selectedPlayStyle,
                                              preferredFoot: selectedFoot,
                                              gameId: gameIdCtrl.text.trim(),
                                              jerseyNumber: jerseyCtrl.text.trim(),
                                              systemDevice: selectedDevice,
                                              contactEmail: emailCtrl.text.trim(),
                                              phoneLine: phoneCtrl.text.trim(),
                                              facebookLink: facebookCtrl.text.trim(),
                                              district: districtCtrl.text.trim(),
                                              dateOfBirth: dobCtrl.text.trim(),
                                              avatarGraphic: selectedAvatarGraphic,
                                            );

                                        // 2. Call backend API to persist database profile
                                        final client = ref.read(apiClientProvider);
                                        await client.updatePlayerProfile(userId, {
                                          'display_name': displayNameCtrl.text.trim(),
                                          'bio': bioCtrl.text.trim(),
                                          'play_style': selectedPlayStyle,
                                          'preferred_foot': selectedFoot,
                                          'efootball_game_id': gameIdCtrl.text.trim(),
                                          'jersey_number': jerseyCtrl.text.trim(),
                                          'system_device': selectedDevice,
                                          'email_node': emailCtrl.text.trim(),
                                          'phone_line': phoneCtrl.text.trim(),
                                          'facebook_link': facebookCtrl.text.trim(),
                                          'district': districtCtrl.text.trim(),
                                          'date_of_birth': dobCtrl.text.trim(),
                                          'avatar_graphic': selectedAvatarGraphic,
                                        });

                                        // 3. Invalidate provider to trigger fresh state render
                                        ref.invalidate(playerProfileProvider(userId));

                                        if (context.mounted) {
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle, color: Colors.black),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '⚡ Profile Dossier updated successfully!',
                                                    style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor: AppColors.winGreen,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setModalState(() => isSaving = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to update profile: $e'),
                                              backgroundColor: AppColors.lossRed,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                                    )
                                  : Text(
                                      'SAVE DOSSIER',
                                      style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.2),
    );
  }

  Widget _buildCustomTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
      dropdownColor: const Color(0xFF161928),
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.list, color: AppColors.primary, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.8),
    );
  }

  Widget _buildDossierRow(String label, String value, {Color valColor = Colors.white, bool isBold = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white38),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.shareTechMono(fontSize: 11, color: Colors.white38, letterSpacing: 1),
              ),
            ],
          ),
          Flexible(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              textAlign: TextAlign.right,
              style: GoogleFonts.shareTechMono(
                fontSize: 11,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEloChart(List<dynamic> history) {
    final ratings = history.map((h) => (h['rating_after'] as num).toDouble()).toList();
    final minR = ratings.reduce((a, b) => a < b ? a : b) - 50;
    final maxR = ratings.reduce((a, b) => a > b ? a : b) + 50;
    final range = maxR - minR;

    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 140,
        child: CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _EloChartPainter(ratings, minR, range),
        ),
      ),
    ).animate().fade(delay: 200.ms);
  }

  Widget _buildChartSkeleton() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 0.6);
  }

  Widget _buildStatsGrid(int played, int wins, int draws, int losses, double winRate, double form) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Matches', '$played', Icons.sports_soccer, AppColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Win Rate', '${winRate.toStringAsFixed(1)}%', Icons.trending_up, AppColors.winGreen)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard('Form', form.toStringAsFixed(1), Icons.auto_graph, AppColors.cyan)),
      ],
    ).animate().fade(delay: 300.ms);
  }

  Widget _buildStatsGridSkeleton() {
    return Row(
      children: List.generate(
        3,
        (_) => Expanded(
          child: Container(
            height: 80,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.2, end: 0.6);
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return GlassCard(
      borderColor: color.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMatchTile(BuildContext context, WidgetRef ref, dynamic match) {
    final result = match['result'] ?? 'draw';
    final gf = match['goals_for'] ?? 0;
    final ga = match['goals_against'] ?? 0;
    final opponent = match['opponent_name'] ?? 'Unknown';
    final matchType = match['match_type'] ?? 'friendly';
    final matchId = match['id']?.toString() ?? '';

    Color resultColor;
    IconData resultIcon;
    switch (result) {
      case 'win':
        resultColor = AppColors.winGreen;
        resultIcon = Icons.arrow_upward;
        break;
      case 'loss':
        resultColor = AppColors.lossRed;
        resultIcon = Icons.arrow_downward;
        break;
      default:
        resultColor = Colors.amber;
        resultIcon = Icons.remove;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: resultColor.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(resultIcon, color: resultColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        match['is_coop'] == true
                            ? 'vs $opponent & ${match['opponent_partner'] ?? 'Unknown'}'
                            : 'vs $opponent',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (match['has_ai_insight'] == true)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.auto_awesome, color: AppColors.cyan, size: 12),
                      ),
                  ],
                ),
                if (match['is_coop'] == true)
                  Text('w/ ${match['partner_name'] ?? 'Unknown'}', style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.primary)),
                Text(matchType.toString().toUpperCase(), style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Text(
            '$gf - $ga',
            style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: resultColor),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(8),
            icon: const Icon(Icons.gavel, size: 18, color: Colors.amber),
            tooltip: 'Raise Dispute',
            onPressed: () => _showDisputeDialog(context, ref, matchId),
          ),
        ],
      ),
    );
  }

  void _showDisputeDialog(BuildContext context, WidgetRef ref, String matchId) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amber)),
        title: Text('RAISE MATCH DISPUTE', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: reasonCtrl,
          style: GoogleFonts.rajdhani(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Reason for Dispute',
            labelStyle: TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white10,
          ),
        ),
        actions: [
          TextButton(
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text('SUBMIT DISPUTE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final client = ref.read(apiClientProvider);
                await client.submitDispute(matchRecordId: matchId, reason: reasonCtrl.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ Dispute submitted for official review!')),
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
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTile(String title, String desc) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.military_tech, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.orbitron(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
    );
  }

  void _showUltimateCardPreview(BuildContext context, ProfilePreferences profilePrefs, Map<String, dynamic> data) {
    final int elo = data['skill_rating'] ?? 0;
    final double form = (data['form_rating'] as num?)?.toDouble() ?? 0.0;
    final double winRate = (data['win_rate'] as num?)?.toDouble() ?? 0.0;
    final String playStyle = profilePrefs.safePlayStyle.isNotEmpty
        ? profilePrefs.safePlayStyle
        : (data['play_style'] as String? ?? 'Possession Game');
    final String username = profilePrefs.safeDisplayName.isNotEmpty
        ? profilePrefs.safeDisplayName
        : (data['username'] as String? ?? 'PLAYER');

    final avatarKey = profilePrefs.safeAvatarGraphic.isNotEmpty
        ? profilePrefs.safeAvatarGraphic
        : (data['avatar_graphic'] as String? ?? 'striker');
    final avatarData = getAvatarById(avatarKey);

    final screenshotController = ScreenshotController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Screenshot(
          controller: screenshotController,
          child: GlassCard(
            gradientColors: const [Color(0xFF332005), Color(0xFF141624)],
            borderColor: const Color(0xFFFFD700),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'eFOOTBALL ULTIMATE CARD',
                  style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFFFD700), letterSpacing: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFFFD700).withValues(alpha: 0.4), blurRadius: 20),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$elo', style: GoogleFonts.orbitron(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black)),
                              Text('RATING', style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                            ],
                          ),
                          const Icon(Icons.sports_soccer, size: 36, color: Colors.black),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: avatarData.gradient),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10),
                          ],
                        ),
                        child: Icon(avatarData.icon, size: 36, color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      Text(username.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                      Text(playStyle, style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${winRate.toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              Text('WIN RATE', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(form.toStringAsFixed(1), style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              Text('FORM', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    EsportsButton(
                      label: 'CLOSE',
                      textColor: Colors.black,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    EsportsButton(
                      label: 'SHARE',
                      icon: Icons.share,
                      gradient: const [Color(0xFF25D366), Color(0xFF128C7E)],
                      onPressed: () async {
                        try {
                          final image = await screenshotController.capture();
                          if (image != null) {
                            final directory = await getTemporaryDirectory();
                            final imagePath = await File('${directory.path}/ultimate_card.png').create();
                            await imagePath.writeAsBytes(image);
                            await SharePlus.instance.share(
                              ShareParams(
                                text: 'Check out my eFootball Ultimate Team Card on Club Manager!',
                                files: [XFile(imagePath.path)],
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY ESPORTS TAB HEADER DELEGATE
// ─────────────────────────────────────────────────────────────────────────────
class _EsportsTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  _EsportsTabHeaderDelegate({
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141624),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            _buildTabItem(0, 'DOSSIER', Icons.badge),
            _buildTabItem(1, 'ANALYTICS', Icons.analytics),
            _buildTabItem(2, 'MATCHES', Icons.sports_soccer),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isSelected
                ? const LinearGradient(colors: [AppColors.primary, Color(0xFFFF8C00)])
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.black : Colors.white60),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _EsportsTabHeaderDelegate oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}

class _EloChartPainter extends CustomPainter {
  final List<double> ratings;
  final double minR;
  final double range;

  _EloChartPainter(this.ratings, this.minR, this.range);

  @override
  void paint(Canvas canvas, Size size) {
    if (ratings.isEmpty) return;

    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = AppColors.cyan;

    if (ratings.length == 1) {
      final y = size.height / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      canvas.drawCircle(Offset(size.width / 2, y), 6, dotPaint);
      return;
    }

    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary.withValues(alpha: 0.3), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < ratings.length; i++) {
      final x = (i / (ratings.length - 1)) * size.width;
      final y = size.height - ((ratings[i] - minR) / (range == 0 ? 1 : range)) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }

      if (i == ratings.length - 1) {
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, gradientPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
