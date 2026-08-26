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
import '../widgets/dispute_dialog.dart';
import 'package:graphify/graphify.dart';

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

final List<PredefinedAvatar> predefinedAvatars = [
  PredefinedAvatar(
    id: 'striker',
    name: 'Striker Ace',
    icon: Icons.sports_soccer,
    gradient: [AppColors.primary, AppColors.gold],
  ),
  PredefinedAvatar(
    id: 'inferno',
    name: 'Inferno Flame',
    icon: Icons.local_fire_department,
    gradient: [AppColors.lossRed, AppColors.primary],
  ),
  PredefinedAvatar(
    id: 'lightning',
    name: 'Cyber Bolt',
    icon: Icons.bolt,
    gradient: [AppColors.gold, const Color(0xFFFFEA00)],
  ),
  const PredefinedAvatar(
    id: 'defender',
    name: 'Iron Shield',
    icon: Icons.shield,
    gradient: [Color(0xFF2979FF), Color(0xFFE2E8F0)],
  ),
  PredefinedAvatar(
    id: 'crown',
    name: 'Golden Crown',
    icon: Icons.workspace_premium,
    gradient: [AppColors.gold, const Color(0xFFFFAB00)],
  ),
  const PredefinedAvatar(
    id: 'star',
    name: 'Mystic Star',
    icon: Icons.auto_awesome,
    gradient: [Color(0xFFF1F5F9), Color(0xFF94A3B8)],
  ),
  PredefinedAvatar(
    id: 'commander',
    name: 'Honor Badge',
    icon: Icons.military_tech,
    gradient: [AppColors.winGreen, const Color(0xFF00B0FF)],
  ),
  const PredefinedAvatar(
    id: 'tactician',
    name: 'Mastermind',
    icon: Icons.psychology,
    gradient: [Color(0xFF00B8D4), Color(0xFF64FFDA)],
  ),
  const PredefinedAvatar(
    id: 'fortress',
    name: 'Titan Fortress',
    icon: Icons.fort,
    gradient: [Color(0xFF607D8B), Color(0xFFCFD8DC)],
  ),
  PredefinedAvatar(
    id: 'mecha',
    name: 'Mecha Cyber',
    icon: Icons.smart_toy,
    gradient: [AppColors.winGreen, AppColors.gold],
  ),
  PredefinedAvatar(
    id: 'shadow',
    name: 'Shadow Dragon',
    icon: Icons.pest_control_rodent,
    gradient: [const Color(0xFFE2E8F0), AppColors.lossRed],
  ),
  const PredefinedAvatar(
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

/// Dynamic Milestone Badge Model
class PlayerMilestoneBadge {
  final String id;
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final Color color;
  final double currentProgress;
  final double targetProgress;
  final String progressLabel;
  final bool isUnlocked;

  const PlayerMilestoneBadge({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentProgress,
    required this.targetProgress,
    required this.progressLabel,
    required this.isUnlocked,
  });
}

/// Full Player Profile screen with reimagined esports styling, interactive dossier,
/// comprehensive career analytics, 6-pillar performance radar, match history,
/// dynamic achievement badges, and customizable user profile.
class PlayerProfileScreen extends ConsumerStatefulWidget {
  final String? playerId;

  const PlayerProfileScreen({super.key, this.playerId});

  @override
  ConsumerState<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  int _selectedTabIndex = 1; // Default to Tab 1 (Analytics) as the main showcase
  String _matchFilter = 'all'; // 'all', 'win', 'draw', 'loss'

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
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: profileAsync.when(
                loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (_, __) => _buildHeroCard(
                  context,
                  ref,
                  targetUserId,
                  isOwnProfile,
                  1000,
                  1000,
                  50.0,
                  profilePrefs.playStyle,
                  0,
                  0,
                  0,
                  0,
                  0.0,
                  0,
                  0,
                  profilePrefs,
                  {},
                ),
                data: (data) => _buildHeroCard(
                  context,
                  ref,
                  targetUserId,
                  isOwnProfile,
                  data['skill_rating'] ?? 1000,
                  data['peak_elo_rating'] ?? (data['skill_rating'] ?? 1000),
                  (data['form_rating'] as num?)?.toDouble() ?? 50.0,
                  isOwnProfile && profilePrefs.playStyle.isNotEmpty
                      ? profilePrefs.playStyle
                      : (data['play_style'] as String? ?? 'Possession Game'),
                  data['matches_played'] ?? 0,
                  data['wins'] ?? 0,
                  data['draws'] ?? 0,
                  data['losses'] ?? 0,
                  (data['win_rate'] as num?)?.toDouble() ?? 0.0,
                  (data['goals_for'] as num?)?.toInt() ?? 0,
                  (data['clean_sheets'] as num?)?.toInt() ?? 0,
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
    int peakElo,
    double form,
    String style,
    int played,
    int wins,
    int draws,
    int losses,
    double winRate,
    int goalsFor,
    int cleanSheets,
    ProfilePreferences profilePrefs,
    Map<String, dynamic> data,
  ) {
    // Rank Tier Calculation
    String tierName;
    Color tierColor;
    if (elo >= 1800) {
      tierName = 'LEGEND';
      tierColor = AppColors.gold;
    } else if (elo >= 1600) {
      tierName = 'GRANDMASTER';
      tierColor = AppColors.offWhite;
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
      padding: const EdgeInsets.fromLTRB(16, 46, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2E1704), const Color(0xFF141624), AppColors.navy],
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
                          BoxShadow(color: avatarData.gradient.first.withValues(alpha: 0.5), blurRadius: 18),
                        ],
                      ),
                    ),
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
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
                          decoration: BoxDecoration(
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
                          boxShadow: [
                            BoxShadow(color: tierColor.withValues(alpha: 0.5), blurRadius: 6),
                          ],
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
              const SizedBox(width: 14),

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
                            style: GoogleFonts.orbitron(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
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
                          style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'PTS',
                          style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary.withValues(alpha: 0.8)),
                        ),
                        if (peakElo > elo) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'PEAK: $peakElo',
                              style: GoogleFonts.rajdhani(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.gold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
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
          const SizedBox(height: 10),

          // Quick Stats Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickStat('MATCHES', '$played'),
                _buildQuickStat('W', '$wins', color: AppColors.winGreen),
                _buildQuickStat('D', '$draws', color: AppColors.amber),
                _buildQuickStat('L', '$losses', color: AppColors.lossRed),
                _buildQuickStat('GOALS', '$goalsFor', color: AppColors.primary),
                _buildQuickStat('CS', '$cleanSheets', color: AppColors.cyan),
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
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [AppColors.primary, const Color(0xFFFF8C00)],
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
                          icon: const Icon(Icons.edit, size: 15, color: Colors.black),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'EDIT PROFILE',
                              style: GoogleFonts.orbitron(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.8),
                            ),
                          ),
                          onPressed: () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs),
                        ),
                      )
                    : Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.cyan.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified, size: 14, color: AppColors.cyan),
                            const SizedBox(width: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'PLAYER DOSSIER',
                                style: GoogleFonts.orbitron(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cyan),
                    color: AppColors.cyan.withValues(alpha: 0.1),
                  ),
                  child: TextButton.icon(
                    icon: Icon(Icons.share, size: 14, color: AppColors.cyan),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'SHARE CARD',
                        style: GoogleFonts.orbitron(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 0.8),
                      ),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ),
        Text(label, style: GoogleFonts.rajdhani(fontSize: 8.5, color: AppColors.textMuted, letterSpacing: 0.8, fontWeight: FontWeight.bold)),
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
          loading: () => Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary))),
          error: (_, __) => _buildDossierTab(context, ref, userId, isOwnProfile, {}, profilePrefs),
          data: (data) => _buildDossierTab(context, ref, userId, isOwnProfile, data, profilePrefs),
        );
      case 1:
        return _buildAnalyticsTab(profileAsync, eloAsync, matchesAsync);
      case 2:
        return _buildMatchesAndBadgesTab(context, ref, matchesAsync, profileAsync);
      default:
        return const SizedBox.shrink();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 1: Dossier & Registry Contact
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
                children: [
                  Icon(Icons.format_quote, color: AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PLAYER TACTICAL BIO',
                      style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwnProfile)
                    IconButton(
                      icon: Icon(Icons.edit_note, color: AppColors.cyan, size: 20),
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
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PLAYER DOSSIER',
                      style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwnProfile)
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      icon: Icon(Icons.edit, size: 14, color: AppColors.cyan),
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
              _buildDossierRow('CONTRACT END', end, valColor: AppColors.gold, isBold: true, icon: Icons.flag),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Registry Contact Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'REGISTRY CONTACT',
                      style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwnProfile)
                    IconButton(
                      icon: Icon(Icons.edit, size: 14, color: AppColors.cyan),
                      onPressed: () => _showEditProfileBottomSheet(context, ref, userId, data, profilePrefs),
                    ),
                ],
              ),
              const Divider(color: Colors.white10),
              _buildDossierRow('CONTACT EMAIL', email, valColor: AppColors.gold, icon: Icons.email),
              _buildDossierRow('PHONE LINE', phone, valColor: const Color(0xFF00FFC2), icon: Icons.phone),
              _buildDossierRow('FACEBOOK LINK', facebook, valColor: AppColors.gold, icon: Icons.link),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Compliance Verification Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.winGreen.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user, color: AppColors.winGreen, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'COMPLIANCE VERIFICATION',
                      style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.winGreen, letterSpacing: 1.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white10),
              _buildDossierRow('NODE STATE', state, valColor: const Color(0xFF00FF66), isBold: true, icon: Icons.dns),
              _buildDossierRow('AUTH STATUS', authStatus, valColor: Colors.white, isBold: true, icon: Icons.security),
              _buildDossierRow('SOURCE FEED', feed, valColor: AppColors.gold, isBold: true, icon: Icons.wifi_lock),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 2: Career & Advanced Analytics Suite
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab(
    AsyncValue<Map<String, dynamic>> profileAsync,
    AsyncValue<Map<String, dynamic>> eloAsync,
    AsyncValue<Map<String, dynamic>> matchesAsync,
  ) {
    return profileAsync.when(
      loading: () => Column(
        children: [
          _buildChartSkeleton(),
          const SizedBox(height: 16),
          _buildStatsGridSkeleton(),
          const SizedBox(height: 16),
          _buildChartSkeleton(),
        ],
      ),
      error: (e, __) => _buildEmptyState('Could not load analytics: $e'),
      data: (data) {
        final matches = (data['matches_played'] as num?)?.toInt() ?? 0;
        final wins = (data['wins'] as num?)?.toInt() ?? 0;
        final draws = (data['draws'] as num?)?.toInt() ?? 0;
        final losses = (data['losses'] as num?)?.toInt() ?? 0;
        final winRate = (data['win_rate'] as num?)?.toDouble() ?? 0.0;
        final elo = (data['skill_rating'] as num?)?.toInt() ?? 1000;
        final peakElo = (data['peak_elo_rating'] as num?)?.toInt() ?? elo;
        final form = (data['form_rating'] as num?)?.toDouble() ?? 50.0;
        final goalsFor = (data['goals_for'] as num?)?.toInt() ?? 0;
        final goalsAgainst = (data['goals_against'] as num?)?.toInt() ?? 0;
        final goalDiff = (data['goal_difference'] as num?)?.toInt() ?? (goalsFor - goalsAgainst);
        final goalsPerMatch = (data['goals_per_match'] as num?)?.toDouble() ?? (matches > 0 ? goalsFor / matches : 0.0);
        final concededPerMatch = (data['conceded_per_match'] as num?)?.toDouble() ?? (matches > 0 ? goalsAgainst / matches : 0.0);
        final cleanSheets = (data['clean_sheets'] as num?)?.toInt() ?? 0;
        final cleanSheetPct = (data['clean_sheet_percentage'] as num?)?.toDouble() ?? (matches > 0 ? (cleanSheets / matches * 100) : 0.0);
        final passesCompleted = (data['passes_completed'] as num?)?.toInt() ?? 0;
        final passesAttempted = (data['passes_attempted'] as num?)?.toInt() ?? 0;
        final passAcc = (data['avg_pass_accuracy'] as num?)?.toDouble() ?? (passesAttempted > 0 ? (passesCompleted / passesAttempted * 100) : 0.0);
        final shotsOnTarget = (data['shots_on_target'] as num?)?.toInt() ?? 0;
        final shotsTotal = (data['shots_total'] as num?)?.toInt() ?? 0;
        final shotAcc = (data['shot_efficiency'] as num?)?.toDouble() ?? (shotsTotal > 0 ? (shotsOnTarget / shotsTotal * 100) : 0.0);
        final conversion = (data['shot_conversion'] as num?)?.toDouble() ?? (shotsTotal > 0 ? (goalsFor / shotsTotal * 100) : 0.0);
        final possession = (data['avg_possession'] as num?)?.toDouble() ?? 50.0;
        final interceptions = (data['interceptions'] as num?)?.toInt() ?? 0;
        final tackles = (data['tackles'] as num?)?.toInt() ?? 0;
        final fouls = (data['fouls'] as num?)?.toInt() ?? 0;
        final currentStreak = (data['current_win_streak'] as num?)?.toInt() ?? 0;
        final bestStreak = (data['best_win_streak'] as num?)?.toInt() ?? 0;
        final recentFormList = (data['recent_form'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final playStyle = data['play_style'] as String? ?? 'Possession Game';

        // 6-Pillar Radar Score Computations (Normalized 0 to 100 scale)
        final attackingScore = ((goalsPerMatch / 3.0 * 50.0) + (shotAcc * 0.3) + (conversion * 0.2)).clamp(10.0, 99.0);
        final resilienceScore = ((cleanSheetPct * 0.5) + ((3.0 - concededPerMatch.clamp(0.0, 3.0)) / 3.0 * 50.0)).clamp(10.0, 99.0);
        final overallRating = ((winRate * 0.25) + (form * 0.25) + (passAcc * 0.15) + (attackingScore * 0.2) + (resilienceScore * 0.15)).clamp(40.0, 99.0).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Rating, Live Form Status & Streak Ribbon
            _buildHeroRatingAndFormCard(
              elo: elo,
              peakElo: peakElo,
              form: form,
              winRate: winRate,
              played: matches,
              wins: wins,
              draws: draws,
              losses: losses,
              currentStreak: currentStreak,
              bestStreak: bestStreak,
              recentFormList: recentFormList,
            ),
            const SizedBox(height: 20),

            // 2. 6-Pillar Hexagonal Performance Radar Card
            _buildPerformanceRadarCard(
              possession: possession,
              passAcc: passAcc,
              shotEfficiency: shotAcc,
              interceptions: interceptions + tackles,
              formRating: form,
              attackingScore: attackingScore,
              resilienceScore: resilienceScore,
              overallRating: overallRating,
            ),
            const SizedBox(height: 20),

            // 3. Offensive & Scoring Matrix
            _buildOffensiveMatrixCard(
              goalsFor: goalsFor,
              goalsPerMatch: goalsPerMatch,
              shotsOnTarget: shotsOnTarget,
              shotsTotal: shotsTotal,
              shotAcc: shotAcc,
              conversion: conversion,
              goalDiff: goalDiff,
            ),
            const SizedBox(height: 20),

            // 4. Passing & Possession Playmaking Matrix
            _buildPassingAndPossessionCard(
              possession: possession,
              passAcc: passAcc,
              passesCompleted: passesCompleted,
              passesAttempted: passesAttempted,
              playStyle: playStyle,
              matches: matches,
            ),
            const SizedBox(height: 20),

            // 5. Defensive Fortress & Discipline Matrix
            _buildDefensiveFortressCard(
              cleanSheets: cleanSheets,
              cleanSheetPct: cleanSheetPct,
              goalsAgainst: goalsAgainst,
              concededPerMatch: concededPerMatch,
              interceptions: interceptions,
              tackles: tackles,
              fouls: fouls,
              matches: matches,
            ),
            const SizedBox(height: 20),

            // 6. Skill Rating (Elo) Evolution Graph
            _buildSectionHeader('SKILL RATING PROGRESSION'),
            const SizedBox(height: 12),
            eloAsync.when(
              loading: () => _buildChartSkeleton(),
              error: (_, __) => _buildEmptyState('No rating history available'),
              data: (eloData) {
                final history = eloData['history'] as List<dynamic>? ?? [];
                if (history.isEmpty) return _buildEmptyState('Play verified matches to track your Elo rating curve');
                return _buildEloChart(history, elo, peakElo);
              },
            ),
          ],
        );
      },
    );
  }

  // ── Hero Rating, Form Status, & Recent Form Ribbon ──────────────────────────
  Widget _buildHeroRatingAndFormCard({
    required int elo,
    required int peakElo,
    required double form,
    required double winRate,
    required int played,
    required int wins,
    required int draws,
    required int losses,
    required int currentStreak,
    required int bestStreak,
    required List<String> recentFormList,
  }) {
    // Form Status Evaluation
    String formStatus;
    Color formColor;
    IconData formIcon;
    if (form >= 80.0) {
      formStatus = 'ON FIRE';
      formColor = const Color(0xFFFF3D00);
      formIcon = Icons.local_fire_department;
    } else if (form >= 65.0) {
      formStatus = 'IN FORM';
      formColor = AppColors.cyan;
      formIcon = Icons.bolt;
    } else if (form >= 45.0) {
      formStatus = 'STEADY';
      formColor = AppColors.winGreen;
      formIcon = Icons.shield;
    } else {
      formStatus = 'COLD';
      formColor = const Color(0xFF90CAF9);
      formIcon = Icons.ac_unit;
    }

    return GlassCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Form Rating & Live Status Badge (Safe responsive Row)
          Row(
            children: [
              Icon(formIcon, color: formColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FORM STATUS',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: formColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: formColor.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(color: formColor.withValues(alpha: 0.2), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(formIcon, color: formColor, size: 11),
                    const SizedBox(width: 4),
                    Text(
                      formStatus,
                      style: GoogleFonts.orbitron(fontSize: 9.5, fontWeight: FontWeight.bold, color: formColor, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Big Highlight Boxes
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'FORM INDEX',
                  value: form.toStringAsFixed(1),
                  subValue: form >= 70 ? 'High Form' : 'Standard',
                  valueColor: formColor,
                  icon: Icons.auto_graph,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'WIN RATIO',
                  value: '${winRate.toStringAsFixed(1)}%',
                  subValue: '$wins W • $draws D • $losses L',
                  valueColor: AppColors.winGreen,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'WIN STREAK',
                  value: currentStreak > 0 ? '$currentStreak W' : '$bestStreak W',
                  subValue: currentStreak > 0 ? 'Active Streak' : 'Career Best',
                  valueColor: AppColors.primary,
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recent Form Sequence Ribbon
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECENT FORM (${recentFormList.isNotEmpty ? recentFormList.length : 5} MATCHES):',
                  style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (currentStreak >= 2)
                Text(
                  '$currentStreak IN A ROW',
                  style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (recentFormList.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.centerLeft,
              child: Text('No recent matches recorded in registry', style: GoogleFonts.rajdhani(color: Colors.white54, fontSize: 12)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: recentFormList.map((res) {
                  Color c;
                  String letter;
                  switch (res.toLowerCase()) {
                    case 'win':
                      c = AppColors.winGreen;
                      letter = 'W';
                      break;
                    case 'loss':
                      c = AppColors.lossRed;
                      letter = 'L';
                      break;
                    default:
                      c = AppColors.amber;
                      letter = 'D';
                  }
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.withValues(alpha: 0.6), width: 1.2),
                      boxShadow: [
                        BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 6),
                      ],
                    ),
                    child: Text(
                      letter,
                      style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.bold, color: c),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 14),

          // Outcome Proportion Progress Bar
          if (played > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    if (wins > 0)
                      Expanded(
                        flex: wins,
                        child: Container(color: AppColors.winGreen),
                      ),
                    if (draws > 0)
                      Expanded(
                        flex: draws,
                        child: Container(color: AppColors.amber),
                      ),
                    if (losses > 0)
                      Expanded(
                        flex: losses,
                        child: Container(color: AppColors.lossRed),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('W: ${(wins / played * 100).toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(color: AppColors.winGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('D: ${(draws / played * 100).toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(color: AppColors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('L: ${(losses / played * 100).toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── 6-Pillar Hexagonal Performance Radar Card ──────────────────────────────
  Widget _buildPerformanceRadarCard({
    required double possession,
    required double passAcc,
    required double shotEfficiency,
    required int interceptions,
    required double formRating,
    required double attackingScore,
    required double resilienceScore,
    required int overallRating,
  }) {
    final normPoss = possession.clamp(0.0, 100.0);
    final normPass = passAcc.clamp(0.0, 100.0);
    final normAttack = attackingScore.clamp(0.0, 100.0);
    final normDef = ((interceptions / 15.0) * 100.0).clamp(10.0, 100.0);
    final normResil = resilienceScore.clamp(0.0, 100.0);
    final normForm = formRating.clamp(0.0, 100.0);

    final radarOptions = <String, dynamic>{
      'backgroundColor': 'transparent',
      'radar': {
        'indicator': [
          {'name': 'ATTACK', 'max': 100},
          {'name': 'PASSING', 'max': 100},
          {'name': 'POSSESS', 'max': 100},
          {'name': 'DEFENSE', 'max': 100},
          {'name': 'RESIL.', 'max': 100},
          {'name': 'FORM', 'max': 100},
        ],
        'shape': 'polygon',
        'center': ['50%', '50%'],
        'radius': '60%',
        'splitNumber': 4,
        'axisName': {
          'color': '#A5ACBC',
          'fontSize': 10,
          'fontWeight': 'bold',
        },
        'splitLine': {
          'lineStyle': {'color': '#FFFFFF15'},
        },
        'splitArea': {
          'show': true,
          'areaStyle': {
            'color': ['#FFFFFF04', '#FFFFFF08'],
          },
        },
        'axisLine': {
          'lineStyle': {'color': '#FFFFFF20'},
        },
      },
      'series': [
        {
          'type': 'radar',
          'data': [
            {
              'value': [
                normAttack.round(),
                normPass.round(),
                normPoss.round(),
                normDef.round(),
                normResil.round(),
                normForm.round(),
              ],
              'name': 'Performance Pillars',
              'areaStyle': {
                'color': {
                  'type': 'radial',
                  'x': 0.5,
                  'y': 0.5,
                  'r': 0.5,
                  'colorStops': [
                    {'offset': 0, 'color': 'rgba(0, 229, 255, 0.45)'},
                    {'offset': 1, 'color': 'rgba(0, 229, 255, 0.15)'},
                  ],
                },
              },
              'lineStyle': {
                'color': '#00E5FF',
                'width': 2.5,
                'shadowColor': 'rgba(0, 229, 255, 0.5)',
                'shadowBlur': 8,
              },
              'itemStyle': {'color': '#00E5FF'},
              'symbol': 'circle',
              'symbolSize': 6,
            },
          ],
        },
      ],
      'tooltip': {
        'trigger': 'item',
        'backgroundColor': '#1C1F2E',
        'borderColor': '#00E5FF',
        'borderWidth': 1,
        'textStyle': {'color': '#FFFFFF', 'fontSize': 11},
      },
    };

    return GlassCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radar, color: AppColors.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '6-PILLAR PERFORMANCE RADAR',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.gold, AppColors.primary]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 8),
                  ],
                ),
                child: Text(
                  '$overallRating OVR',
                  style: GoogleFonts.orbitron(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // High-Density Hexagonal Graphify Radar Chart
          SizedBox(
            height: 220,
            child: GraphifyView(
              controller: GraphifyController(),
              initialOptions: radarOptions,
            ),
          ),
          const SizedBox(height: 14),

          // Radar Metric Key Breakdown
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Flexible(child: _buildMiniPillar('ATTACK', attackingScore.toStringAsFixed(0), AppColors.primary)),
                Flexible(child: _buildMiniPillar('PASSING', '${passAcc.toStringAsFixed(0)}%', AppColors.cyan)),
                Flexible(child: _buildMiniPillar('POSS', '${possession.toStringAsFixed(0)}%', const Color(0xFF64FFDA))),
                Flexible(child: _buildMiniPillar('DEFENSE', interceptions.toString(), const Color(0xFF80D8FF))),
                Flexible(child: _buildMiniPillar('RESIL.', resilienceScore.toStringAsFixed(0), AppColors.winGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPillar(String label, String val, Color c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(val, style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: GoogleFonts.rajdhani(fontSize: 8.5, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Offensive & Scoring Matrix Card ────────────────────────────────────────
  Widget _buildOffensiveMatrixCard({
    required int goalsFor,
    required double goalsPerMatch,
    required int shotsOnTarget,
    required int shotsTotal,
    required double shotAcc,
    required double conversion,
    required int goalDiff,
  }) {
    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports_soccer, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OFFENSIVE IMPACT',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${goalDiff >= 0 ? "+$goalDiff" : "$goalDiff"} GD',
                  style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'TOTAL GOALS',
                  value: '$goalsFor',
                  subValue: '${goalsPerMatch.toStringAsFixed(2)} G / Match',
                  valueColor: AppColors.primary,
                  icon: Icons.sports_soccer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'SHOT ACC.',
                  value: '${shotAcc.toStringAsFixed(1)}%',
                  subValue: '$shotsOnTarget / $shotsTotal shots',
                  valueColor: AppColors.cyan,
                  icon: Icons.track_changes,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'CONVERSION',
                  value: '${conversion.toStringAsFixed(1)}%',
                  subValue: conversion >= 25 ? 'Clinical Edge' : 'Standard',
                  valueColor: AppColors.gold,
                  icon: Icons.percent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Visual Shooting Accuracy Bar
          Text(
            'TARGET ACCURACY EFFICIENCY',
            style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: (shotAcc * 10).round().clamp(1, 1000),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary, AppColors.gold]),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((100.0 - shotAcc) * 10).round().clamp(1, 1000),
                    child: Container(color: Colors.white12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Passing & Possession Playmaking Matrix Card ─────────────────────────────
  Widget _buildPassingAndPossessionCard({
    required double possession,
    required double passAcc,
    required int passesCompleted,
    required int passesAttempted,
    required String playStyle,
    required int matches,
  }) {
    return GlassCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, color: AppColors.cyan, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'PASSING & POSSESSION',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  possession >= 50.0 ? 'DOMINANT' : 'DIRECT',
                  style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'POSSESSION',
                  value: '${possession.toStringAsFixed(1)}%',
                  subValue: possession >= 55 ? 'Tiki-Taka' : 'Balanced',
                  valueColor: AppColors.cyan,
                  icon: Icons.pie_chart,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'PASS ACC.',
                  value: '${passAcc.toStringAsFixed(1)}%',
                  subValue: '$passesCompleted / $passesAttempted',
                  valueColor: AppColors.winGreen,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'PASSES / GM',
                  value: matches > 0 ? (passesAttempted / matches).toStringAsFixed(0) : '0',
                  subValue: 'Per 90 Mins',
                  valueColor: const Color(0xFF64FFDA),
                  icon: Icons.swap_horiz,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tactical Style Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology, color: AppColors.cyan, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TACTICAL IDENTITY: $playStyle',
                        style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Player builds offense through structured distribution and calculated spacing.',
                        style: GoogleFonts.rajdhani(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Defensive Fortress & Discipline Matrix Card ─────────────────────────────
  Widget _buildDefensiveFortressCard({
    required int cleanSheets,
    required double cleanSheetPct,
    required int goalsAgainst,
    required double concededPerMatch,
    required int interceptions,
    required int tackles,
    required int fouls,
    required int matches,
  }) {
    return GlassCard(
      borderColor: AppColors.winGreen.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AppColors.winGreen, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DEFENSIVE FORTRESS',
                  style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'CLEAN SHEETS',
                  value: '$cleanSheets',
                  subValue: '${cleanSheetPct.toStringAsFixed(0)}% Shutouts',
                  valueColor: AppColors.winGreen,
                  icon: Icons.shield,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'CONCEDED / GM',
                  value: concededPerMatch.toStringAsFixed(2),
                  subValue: '$goalsAgainst Goals Against',
                  valueColor: concededPerMatch <= 1.0 ? AppColors.winGreen : AppColors.lossRed,
                  icon: Icons.sports_kabaddi,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  label: 'DEF. ACTIONS',
                  value: '${interceptions + tackles}',
                  subValue: '$interceptions Int • $tackles Tac',
                  valueColor: const Color(0xFF80D8FF),
                  icon: Icons.pan_tool,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helper Metric Tile ──────────────────────────────────────────────────────
  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subValue,
    required Color valueColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valueColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: valueColor, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.rajdhani(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.6),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: GoogleFonts.rajdhani(fontSize: 9, color: Colors.white60, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TAB 3: Matches & Badges Suite
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
        // ── Milestones & Achievements Showcase ───────────────────────────────
        _buildSectionHeader('CAREER MILESTONES & ACHIEVEMENTS'),
        const SizedBox(height: 12),
        profileAsync.when(
          loading: () => _buildStatsGridSkeleton(),
          error: (_, __) => _buildEmptyState('Could not evaluate milestone achievements'),
          data: (profileData) {
            final badges = _buildMilestoneBadges(profileData);
            final unlockedCount = badges.where((b) => b.isUnlocked).length;

            return GlassCard(
              borderColor: AppColors.gold.withValues(alpha: 0.35),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.workspace_premium, color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'UNLOCKED: $unlockedCount / ${badges.length}',
                          style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '${((unlockedCount / badges.length) * 100).toStringAsFixed(0)}% COMPLETE',
                          style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Badges Grid with safe responsive dimensions
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      mainAxisExtent: 144,
                    ),
                    itemCount: badges.length,
                    itemBuilder: (ctx, i) {
                      final b = badges[i];
                      return _buildDynamicBadgeCard(b);
                    },
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // ── Recent Match History ─────────────────────────────────────────────
        _buildSectionHeader('MATCH HISTORY & TIMELINE'),
        const SizedBox(height: 12),

        // Filter Chips in horizontal scroll view
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('ALL', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('WINS', 'win', color: AppColors.winGreen),
              const SizedBox(width: 8),
              _buildFilterChip('DRAWS', 'draw', color: AppColors.amber),
              const SizedBox(width: 8),
              _buildFilterChip('LOSSES', 'loss', color: AppColors.lossRed),
            ],
          ),
        ),
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
            final rawMatches = data['matches'] as List<dynamic>? ?? [];
            if (rawMatches.isEmpty) return _buildEmptyState('No matches recorded yet in club registry');

            final filteredMatches = rawMatches.where((m) {
              if (_matchFilter == 'all') return true;
              return (m['result']?.toString().toLowerCase() == _matchFilter);
            }).toList();

            if (filteredMatches.isEmpty) {
              return _buildEmptyState('No matches found for "$_matchFilter" filter');
            }

            return Column(
              children: filteredMatches.map((m) => _buildMatchTile(context, ref, m)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String key, {Color? color}) {
    final isSelected = _matchFilter == key;
    final activeColor = color ?? AppColors.cyan;

    return GestureDetector(
      onTap: () => setState(() => _matchFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? activeColor : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicBadgeCard(PlayerMilestoneBadge badge) {
    final pct = (badge.currentProgress / badge.targetProgress).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: badge.isUnlocked ? const Color(0xFF141824) : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badge.isUnlocked ? badge.color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
          width: badge.isUnlocked ? 1.5 : 1,
        ),
        boxShadow: badge.isUnlocked
            ? [BoxShadow(color: badge.color.withValues(alpha: 0.2), blurRadius: 10)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badge.isUnlocked ? badge.color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(badge.icon, size: 16, color: badge.isUnlocked ? badge.color : Colors.white30),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.title,
                      style: GoogleFonts.orbitron(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: badge.isUnlocked ? Colors.white : Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      badge.category,
                      style: GoogleFonts.rajdhani(fontSize: 8.5, color: badge.isUnlocked ? badge.color : Colors.white30, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            badge.description,
            style: GoogleFonts.rajdhani(fontSize: 9.5, color: AppColors.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      badge.progressLabel,
                      style: GoogleFonts.shareTechMono(fontSize: 8.5, color: badge.isUnlocked ? badge.color : Colors.white38),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge.isUnlocked)
                    Icon(Icons.check_circle, size: 12, color: AppColors.winGreen),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 3.5,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(badge.isUnlocked ? badge.color : AppColors.cyan.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PlayerMilestoneBadge> _buildMilestoneBadges(Map<String, dynamic> data) {
    final matches = (data['matches_played'] as num?)?.toInt() ?? 0;
    final wins = (data['wins'] as num?)?.toInt() ?? 0;
    final goals = (data['goals_for'] as num?)?.toInt() ?? 0;
    final cleanSheets = (data['clean_sheets'] as num?)?.toInt() ?? 0;
    final bestStreak = (data['best_win_streak'] as num?)?.toInt() ?? (data['current_win_streak'] as num?)?.toInt() ?? (wins > 0 ? (wins > 3 ? 3 : wins) : 0);
    final passAcc = (data['avg_pass_accuracy'] as num?)?.toDouble() ?? 0.0;
    final peakElo = (data['peak_elo_rating'] as num?)?.toInt() ?? (data['skill_rating'] as num?)?.toInt() ?? 1000;
    final possession = (data['avg_possession'] as num?)?.toDouble() ?? 50.0;
    final conversion = (data['shot_conversion'] as num?)?.toDouble() ?? 0.0;
    final defActions = ((data['tackles'] as num?)?.toInt() ?? 0) + ((data['interceptions'] as num?)?.toInt() ?? 0);

    return [
      PlayerMilestoneBadge(
        id: 'centurion',
        title: 'Centurion Legend',
        category: 'MATCHES',
        description: 'Participate in 100 competitive eFootball matches.',
        icon: Icons.military_tech,
        color: AppColors.gold,
        currentProgress: matches.toDouble().clamp(0, 100),
        targetProgress: 100,
        progressLabel: '$matches / 100 Matches',
        isUnlocked: matches >= 100,
      ),
      PlayerMilestoneBadge(
        id: 'veteran',
        title: 'Veteran Clubman',
        category: 'MATCHES',
        description: 'Reach 10 official matches registered in registry.',
        icon: Icons.shield,
        color: AppColors.cyan,
        currentProgress: matches.toDouble().clamp(0, 10),
        targetProgress: 10,
        progressLabel: '$matches / 10 Matches',
        isUnlocked: matches >= 10,
      ),
      PlayerMilestoneBadge(
        id: 'golden_boot',
        title: 'Golden Boot Ace',
        category: 'SCORING',
        description: 'Net 25 career goals across club fixtures.',
        icon: Icons.sports_soccer,
        color: AppColors.primary,
        currentProgress: goals.toDouble().clamp(0, 25),
        targetProgress: 25,
        progressLabel: '$goals / 25 Goals',
        isUnlocked: goals >= 25,
      ),
      PlayerMilestoneBadge(
        id: 'sharpshooter',
        title: 'Sharp Finisher',
        category: 'SCORING',
        description: 'Reach 10 career goals scored.',
        icon: Icons.track_changes,
        color: const Color(0xFFFF5252),
        currentProgress: goals.toDouble().clamp(0, 10),
        targetProgress: 10,
        progressLabel: '$goals / 10 Goals',
        isUnlocked: goals >= 10,
      ),
      PlayerMilestoneBadge(
        id: 'clinical_finisher',
        title: 'Clinical Finisher',
        category: 'SCORING',
        description: 'Achieve a 25%+ shot conversion rate.',
        icon: Icons.percent,
        color: AppColors.gold,
        currentProgress: conversion.clamp(0, 25),
        targetProgress: 25,
        progressLabel: '${conversion.toStringAsFixed(1)}% / 25% Conv',
        isUnlocked: conversion >= 25.0 && matches >= 1,
      ),
      PlayerMilestoneBadge(
        id: 'iron_fortress',
        title: 'The Iron Fortress',
        category: 'DEFENSE',
        description: 'Keep 5 clean sheets without conceding a goal.',
        icon: Icons.security,
        color: AppColors.winGreen,
        currentProgress: cleanSheets.toDouble().clamp(0, 5),
        targetProgress: 5,
        progressLabel: '$cleanSheets / 5 Clean Sheets',
        isUnlocked: cleanSheets >= 5,
      ),
      PlayerMilestoneBadge(
        id: 'clean_sheet_club',
        title: 'Shutout Guardian',
        category: 'DEFENSE',
        description: 'Secure your first competitive clean sheet.',
        icon: Icons.gpp_good,
        color: AppColors.winGreen,
        currentProgress: cleanSheets.toDouble().clamp(0, 1),
        targetProgress: 1,
        progressLabel: '$cleanSheets / 1 Clean Sheet',
        isUnlocked: cleanSheets >= 1,
      ),
      PlayerMilestoneBadge(
        id: 'unstoppable_streak',
        title: 'Unstoppable Run',
        category: 'STREAKS',
        description: 'Achieve a winning streak of 5 consecutive victories.',
        icon: Icons.local_fire_department,
        color: AppColors.lossRed,
        currentProgress: bestStreak.toDouble().clamp(0, 5),
        targetProgress: 5,
        progressLabel: '$bestStreak / 5 Win Streak',
        isUnlocked: bestStreak >= 5,
      ),
      PlayerMilestoneBadge(
        id: 'on_a_roll',
        title: 'On a Roll',
        category: 'STREAKS',
        description: 'Achieve a 3-match winning streak.',
        icon: Icons.bolt,
        color: AppColors.amber,
        currentProgress: bestStreak.toDouble().clamp(0, 3),
        targetProgress: 3,
        progressLabel: '$bestStreak / 3 Win Streak',
        isUnlocked: bestStreak >= 3,
      ),
      PlayerMilestoneBadge(
        id: 'pass_maestro',
        title: 'Passing Maestro',
        category: 'PLAYMAKING',
        description: 'Maintain 80%+ pass accuracy across games.',
        icon: Icons.alt_route,
        color: AppColors.cyan,
        currentProgress: passAcc.clamp(0, 80),
        targetProgress: 80,
        progressLabel: '${passAcc.toStringAsFixed(1)}% / 80% Acc',
        isUnlocked: passAcc >= 80.0 && matches >= 1,
      ),
      PlayerMilestoneBadge(
        id: 'possession_dominator',
        title: 'Tiki-Taka Master',
        category: 'PLAYMAKING',
        description: 'Control the pitch with 55%+ average possession.',
        icon: Icons.psychology,
        color: const Color(0xFF64FFDA),
        currentProgress: possession.clamp(0, 55),
        targetProgress: 55,
        progressLabel: '${possession.toStringAsFixed(1)}% / 55% Poss',
        isUnlocked: possession >= 55.0 && matches >= 1,
      ),
      PlayerMilestoneBadge(
        id: 'grandmaster_elite',
        title: 'Grandmaster Tier',
        category: 'RATING',
        description: 'Climb the competitive ladder to 1600+ Skill Rating.',
        icon: Icons.workspace_premium,
        color: AppColors.gold,
        currentProgress: peakElo.toDouble().clamp(1000, 1600),
        targetProgress: 1600,
        progressLabel: '$peakElo / 1600 ELO',
        isUnlocked: peakElo >= 1600,
      ),
      PlayerMilestoneBadge(
        id: 'defensive_sentinel',
        title: 'Defensive Sentinel',
        category: 'DEFENSE',
        description: 'Execute 15+ combined tackles and interceptions.',
        icon: Icons.shield_outlined,
        color: const Color(0xFF80D8FF),
        currentProgress: defActions.toDouble().clamp(0, 15),
        targetProgress: 15,
        progressLabel: '$defActions / 15 Def. Actions',
        isUnlocked: defActions >= 15,
      ),
    ];
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
                      children: [
                        Icon(Icons.edit_note, color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EDIT DOSSIER & PROFILE',
                            style: GoogleFonts.orbitron(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                            items: ['Possession Game', 'Quick Counter', 'Out Wide', 'Long Ball Counter', 'Long Ball'],
                            onChanged: (v) => setModalState(() => selectedPlayStyle = v!),
                          ),
                          const SizedBox(height: 12),
                          _buildDropdownField(
                            label: 'Preferred Foot',
                            value: selectedFoot,
                            items: ['Right', 'Left', 'Both'],
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
                            items: ['PlayStation 5', 'Xbox Series X|S', 'PC / Steam', 'Mobile', 'Cross-Platform'],
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
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      border: const Border(top: BorderSide(color: Colors.white10)),
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
                              gradient: LinearGradient(
                                colors: [AppColors.primary, const Color(0xFFFF8C00)],
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
                                                    'Profile Dossier updated successfully!',
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
          borderSide: BorderSide(color: AppColors.cyan, width: 1.5),
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
        prefixIcon: Icon(Icons.list, color: AppColors.primary, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cyan, width: 1.5),
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

  Widget _buildEloChart(List<dynamic> history, int currentElo, int peakElo) {
    final ratings = history.map((h) => (h['rating_after'] as num).toDouble()).toList();
    if (ratings.isEmpty) ratings.add(currentElo.toDouble());

    final minR = (ratings.reduce((a, b) => a < b ? a : b) - 20).floorToDouble().clamp(0.0, 9999.0);
    final maxR = (ratings.reduce((a, b) => a > b ? a : b) + 20).ceilToDouble();

    final startElo = ratings.first.toInt();
    final latestElo = ratings.last.toInt();
    final netDelta = latestElo - startElo;

    final xLabels = <String>[];
    for (int i = 0; i < ratings.length; i++) {
      if (i < history.length) {
        final h = history[i];
        if (h is Map<String, dynamic> && h['recorded_at'] != null) {
          try {
            final dt = DateTime.parse(h['recorded_at'].toString());
            xLabels.add('${dt.month}/${dt.day}');
          } catch (_) {
            xLabels.add('M${i + 1}');
          }
        } else {
          xLabels.add('M${i + 1}');
        }
      } else {
        xLabels.add('Current');
      }
    }

    final options = <String, dynamic>{
      'backgroundColor': 'transparent',
      'grid': {
        'left': '2%',
        'right': '3%',
        'top': '14%',
        'bottom': '8%',
        'containLabel': true,
      },
      'tooltip': {
        'trigger': 'axis',
        'backgroundColor': '#1C1F2E',
        'borderColor': '#FF6D00',
        'borderWidth': 1,
        'textStyle': {'color': '#FFFFFF', 'fontSize': 11},
      },
      'xAxis': {
        'type': 'category',
        'data': xLabels,
        'boundaryGap': false,
        'axisLine': {'lineStyle': {'color': '#FFFFFF20'}},
        'axisLabel': {'color': '#A5ACBC', 'fontSize': 9},
        'splitLine': {'show': false},
      },
      'yAxis': {
        'type': 'value',
        'min': minR.toInt(),
        'max': maxR.toInt(),
        'splitLine': {'lineStyle': {'color': '#FFFFFF10'}},
        'axisLine': {'lineStyle': {'color': '#FFFFFF15'}},
        'axisLabel': {'color': '#A5ACBC', 'fontSize': 9},
      },
      'series': [
        {
          'name': 'Skill Rating',
          'type': 'line',
          'smooth': 0.35,
          'symbol': 'circle',
          'symbolSize': ratings.length > 25 ? 4 : 7,
          'itemStyle': {
            'color': '#00E5FF',
            'borderColor': '#FFFFFF',
            'borderWidth': 1.5,
          },
          'lineStyle': {
            'color': '#FF6D00',
            'width': 2.8,
            'shadowColor': 'rgba(255, 109, 0, 0.45)',
            'shadowBlur': 8,
          },
          'areaStyle': {
            'color': {
              'type': 'linear',
              'x': 0,
              'y': 0,
              'x2': 0,
              'y2': 1,
              'colorStops': [
                {'offset': 0, 'color': 'rgba(255, 109, 0, 0.35)'},
                {'offset': 1, 'color': 'rgba(255, 109, 0, 0.0)'},
              ],
            },
          },
          'data': ratings,
        },
      ],
    };

    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$latestElo PTS',
                style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (netDelta >= 0 ? AppColors.winGreen : AppColors.lossRed).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: (netDelta >= 0 ? AppColors.winGreen : AppColors.lossRed).withValues(alpha: 0.4)),
                ),
                child: Text(
                  netDelta >= 0 ? '+$netDelta PTS' : '$netDelta PTS',
                  style: GoogleFonts.orbitron(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: netDelta >= 0 ? AppColors.winGreen : AppColors.lossRed,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'PEAK: $peakElo',
                style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 165,
            child: GraphifyView(
              controller: GraphifyController(),
              initialOptions: options,
            ),
          ),
        ],
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

  Widget _buildMatchTile(BuildContext context, WidgetRef ref, dynamic match) {
    final result = match['result'] ?? 'draw';
    final gf = match['goals_for'] ?? 0;
    final ga = match['goals_against'] ?? 0;
    final opponent = match['opponent_name'] ?? 'Unknown';
    final matchType = match['match_type'] ?? 'friendly';
    final matchId = match['id']?.toString() ?? '';

    final possession = (match['possession'] as num?)?.toDouble() ?? 50.0;
    final shotsOnTarget = (match['shots_on_target'] as num?)?.toInt() ?? 0;
    final passesAcc = ((match['passes_completed'] as num?)?.toInt() ?? 0);

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
        resultColor = AppColors.amber;
        resultIcon = Icons.remove;
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      borderColor: resultColor.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: resultColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: resultColor.withValues(alpha: 0.4)),
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
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.5)),
                            ),
                            child: Icon(Icons.auto_awesome, color: AppColors.cyan, size: 12),
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
              const SizedBox(width: 4),
              IconButton(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: const EdgeInsets.all(6),
                icon: Icon(Icons.gavel, size: 16, color: AppColors.amber),
                tooltip: 'Raise Dispute',
                onPressed: () => _showDisputeDialog(context, ref, matchId),
              ),
            ],
          ),
          if (possession > 0 || shotsOnTarget > 0 || passesAcc > 0) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildMatchStatSnippet('POSSESSION', '${possession.toStringAsFixed(0)}%'),
                  const SizedBox(width: 14),
                  _buildMatchStatSnippet('SHOTS ON TARGET', '$shotsOnTarget'),
                  const SizedBox(width: 14),
                  _buildMatchStatSnippet('PASSES COMPLETED', '$passesAcc'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchStatSnippet(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showDisputeDialog(BuildContext context, WidgetRef ref, String matchId) async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => DisputeDialog(
        matchRecordId: matchId,
        matchTitle: 'Match',
      ),
    );

    if (result == true) {
      final targetUserId = (widget.playerId != null && widget.playerId!.isNotEmpty)
          ? widget.playerId!
          : (ref.read(authStateProvider) ?? '');
      ref.invalidate(adminDisputesProvider);
      if (targetUserId.isNotEmpty) {
        ref.invalidate(matchHistoryProvider(targetUserId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute submitted for official review!')),
        );
      }
    }
  }

  Widget _buildEmptyState(String message) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(message, style: TextStyle(color: AppColors.textMuted, fontSize: 13), textAlign: TextAlign.center),
      ),
    );
  }

  void _showUltimateCardPreview(BuildContext context, ProfilePreferences profilePrefs, Map<String, dynamic> data) {
    final int elo = data['skill_rating'] ?? 1000;
    final double form = (data['form_rating'] as num?)?.toDouble() ?? 50.0;
    final double winRate = (data['win_rate'] as num?)?.toDouble() ?? 0.0;
    final int goals = (data['goals_for'] as num?)?.toInt() ?? 0;
    final double passAcc = (data['avg_pass_accuracy'] as num?)?.toDouble() ?? 80.0;
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
            borderColor: AppColors.gold,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'eFOOTBALL ULTIMATE CARD',
                  style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [AppColors.gold, const Color(0xFFFF8C00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 20),
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
                              Text('$goals', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              Text('GOALS', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          ),
                          Column(
                            children: [
                              Text('${passAcc.toStringAsFixed(0)}%', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 16)),
                              Text('PASS ACC', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
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
                ? LinearGradient(colors: [AppColors.primary, const Color(0xFFFF8C00)])
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
