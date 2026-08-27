import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import 'player_profile_screen.dart';

/// Full per-club deep-dive screen.
/// Navigation param: clubId + clubName.
class ClubDetailScreen extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;

  const ClubDetailScreen({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  ConsumerState<ClubDetailScreen> createState() => _ClubDetailScreenState();
}

class _ClubDetailScreenState extends ConsumerState<ClubDetailScreen> {
  int _selectedIndex = 0;
  late String _currentClubName;

  @override
  void initState() {
    super.initState();
    _currentClubName = widget.clubName;
  }

  void _updateClubName(String newName) {
    if (mounted) {
      setState(() => _currentClubName = newName);
    }
  }

  // ── label / icon maps for the nav bar ────────────────────────────────────
  static const _navLabels = ['OVERVIEW', 'ROSTER', 'LEADERBOARD', 'ACTIVITY', 'RESOLVED'];
  static const _navIcons = [
    Icons.dashboard_outlined,
    Icons.group_outlined,
    Icons.leaderboard_outlined,
    Icons.timeline_outlined,
    Icons.verified_outlined,
  ];
  static const _navIconsFilled = [
    Icons.dashboard,
    Icons.group,
    Icons.leaderboard,
    Icons.timeline,
    Icons.verified,
  ];

  Future<void> _refresh() async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.clearAllCache();

    ref.invalidate(clubDetailsProvider(widget.clubId));
    ref.invalidate(clubMembersProvider(widget.clubId));
    ref.invalidate(leaderboardProvider(widget.clubId));
    ref.invalidate(clubActivityProvider(widget.clubId));
    ref.invalidate(clubResolvedActivityProvider(widget.clubId));
    ref.invalidate(clubSeasonsProvider(widget.clubId));
    ref.invalidate(clubTournamentsProvider(widget.clubId));
    ref.invalidate(myClubsProvider);
  }

  void _showEditClubModal(BuildContext context, String currentName, String currentCode) {
    final nameCtrl = TextEditingController(text: currentName);
    final codeCtrl = TextEditingController(text: currentCode == '—' ? '' : currentCode);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.edit_note, color: AppColors.cyan, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'EDIT CLUB DETAILS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Club Name *',
                        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.shield, color: AppColors.cyan, size: 20),
                        filled: true,
                        fillColor: AppColors.isLight ? AppColors.surfaceLight : Colors.white.withValues(alpha: 0.05),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.cyan),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 16),
                      decoration: InputDecoration(
                        labelText: 'Invite Code (Optional)',
                        hintText: 'Leave unchanged or type custom code',
                        hintStyle: GoogleFonts.rajdhani(color: AppColors.textDim, fontSize: 13),
                        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 14),
                        prefixIcon: Icon(Icons.vpn_key, color: AppColors.offWhite, size: 20),
                        filled: true,
                        fillColor: AppColors.isLight ? AppColors.surfaceLight : Colors.white.withValues(alpha: 0.05),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.offWhite),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: EsportsButton(
                        label: 'SAVE CHANGES',
                        icon: Icons.check,
                        isLoading: isSaving,
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newName = nameCtrl.text.trim();
                                if (newName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Club name cannot be empty.', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                                      backgroundColor: AppColors.lossRed,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSaving = true);
                                try {
                                  final client = ref.read(apiClientProvider);
                                  await client.updateClub(
                                    widget.clubId,
                                    newName,
                                    inviteCode: codeCtrl.text.trim(),
                                  );
                                  _updateClubName(newName);
                                  await _refresh();
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Club updated successfully!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                                        backgroundColor: AppColors.winGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error updating club: $e', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                                        backgroundColor: AppColors.lossRed,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmRegenerateInvite(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.offWhite.withValues(alpha: 0.3)),
        ),
        title: Text(
          'REGENERATE INVITE CODE',
          style: GoogleFonts.rajdhani(color: AppColors.offWhite, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'This will invalidate the existing invite code and generate a brand new one. Existing members will remain in the club.',
          style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.offWhite,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await ref.read(apiClientProvider).regenerateInviteCode(widget.clubId);
                await _refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('New Invite Code: ${res['invite_code']}', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.winGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to regenerate: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text('REGENERATE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmLeaveClub(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.4)),
        ),
        title: Text(
          'LEAVE CLUB',
          style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to leave $_currentClubName? You will need an invite code to rejoin.',
          style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).leaveClub(widget.clubId);
                ref.invalidate(myClubsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You have left the club.', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to leave club: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text('LEAVE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteClub(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.5)),
        ),
        title: Text(
          'DISBAND CLUB',
          style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to permanently disband and delete $_currentClubName? All members and club history will be removed. This cannot be undone.',
          style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).deleteClub(widget.clubId);
                ref.invalidate(myClubsProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Club disbanded successfully.', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.lossRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete club: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text('DISBAND CLUB', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        mini: true,
        onPressed: _refresh,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.cyan,
        child: const Icon(Icons.refresh, size: 20),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar()],
        body: Column(
          children: [
            // NavigationBar
            _buildNavBar(),
            // Body
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sliver App Bar
  // ─────────────────────────────────────────────────────────────────────────

  SliverAppBar _buildSliverAppBar() {
    final detailsAsync = ref.watch(clubDetailsProvider(widget.clubId));
    final inviteCode = detailsAsync.valueOrNull?['invite_code']?.toString() ?? '—';
    final isOfficial = detailsAsync.valueOrNull?['is_official'] == true;
    final isOwner = detailsAsync.valueOrNull?['is_owner'] == true;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.background,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.textPrimary),
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          onSelected: (val) {
            if (val == 'edit') {
              _showEditClubModal(context, _currentClubName, inviteCode);
            } else if (val == 'copy_invite') {
              if (inviteCode != '—') {
                Clipboard.setData(ClipboardData(text: inviteCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Invite code copied!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                    backgroundColor: AppColors.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } else if (val == 'regenerate') {
              _confirmRegenerateInvite(context);
            } else if (val == 'leave') {
              _confirmLeaveClub(context);
            } else if (val == 'delete') {
              _confirmDeleteClub(context);
            }
          },
          itemBuilder: (_) => [
            if (isOfficial || isOwner)
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: AppColors.cyan, size: 18),
                    const SizedBox(width: 10),
                    Text('Edit Club', style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'copy_invite',
              child: Row(
                children: [
                  Icon(Icons.copy, color: AppColors.offWhite, size: 18),
                  const SizedBox(width: 10),
                  Text('Copy Invite Code', style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (isOfficial || isOwner)
              PopupMenuItem(
                value: 'regenerate',
                child: Row(
                  children: [
                    Icon(Icons.autorenew, color: AppColors.offWhite, size: 18),
                    const SizedBox(width: 10),
                    Text('Regenerate Invite Code', style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            if (!isOwner)
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: AppColors.lossRed, size: 18),
                    const SizedBox(width: 10),
                    Text('Leave Club', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            if (isOwner || isOfficial)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: AppColors.lossRed, size: 18),
                    const SizedBox(width: 10),
                    Text('Disband Club', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Text(
          _currentClubName.toUpperCase(),
          style: GoogleFonts.rajdhani(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: _buildExpandedHeader(),
        collapseMode: CollapseMode.parallax,
      ),
    );
  }

  Widget _buildExpandedHeader() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1A0A00), const Color(0xFF0D0D1A), AppColors.background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        // Glow
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.07),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 60,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        // Content
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Shield hero
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [AppColors.primary, const Color(0xFFFF9E00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield, color: Colors.black, size: 38),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => LinearGradient(
                          colors: [AppColors.primary, const Color(0xFFFF9E00)],
                        ).createShader(b),
                        child: Text(
                          _currentClubName.toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.15),
                      const SizedBox(height: 4),
                      GlowBadge(label: 'CLUB', color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation Bar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: List.generate(_navLabels.length, (i) {
            final selected = _selectedIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(
                duration: 200.ms,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.primary.withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? _navIconsFilled[i] : _navIcons[i],
                      size: 16,
                      color: selected ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _navLabels[i],
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                        color: selected ? AppColors.primary : AppColors.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Body dispatcher
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return _OverviewTab(
        clubId: widget.clubId,
        clubName: _currentClubName,
        onClubNameChanged: _updateClubName,
        onOpenEditModal: (name, code) => _showEditClubModal(context, name, code),
        onRegenerateCode: () => _confirmRegenerateInvite(context),
        onLeaveClub: () => _confirmLeaveClub(context),
        onDeleteClub: () => _confirmDeleteClub(context),
      );
      case 1: return _RosterTab(clubId: widget.clubId);
      case 2: return _LeaderboardTab(clubId: widget.clubId);
      case 3: return _ActivityTab(clubId: widget.clubId);
      case 4: return _ResolvedTab(clubId: widget.clubId);
      default: return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — OVERVIEW
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends ConsumerStatefulWidget {
  final String clubId;
  final String clubName;
  final ValueChanged<String> onClubNameChanged;
  final void Function(String currentName, String currentCode) onOpenEditModal;
  final VoidCallback onRegenerateCode;
  final VoidCallback onLeaveClub;
  final VoidCallback onDeleteClub;

  const _OverviewTab({
    required this.clubId,
    required this.clubName,
    required this.onClubNameChanged,
    required this.onOpenEditModal,
    required this.onRegenerateCode,
    required this.onLeaveClub,
    required this.onDeleteClub,
  });

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  final _editNameCtrl = TextEditingController();
  final _editCodeCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _editNameCtrl.dispose();
    _editCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(String currentName, String currentCode) async {
    final name = _editNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Club name cannot be empty.', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.lossRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final code = _editCodeCtrl.text.trim();
      await ref.read(apiClientProvider).updateClub(
            widget.clubId,
            name,
            inviteCode: code.isNotEmpty ? code : null,
          );
      widget.onClubNameChanged(name);
      final apiClient = ref.read(apiClientProvider);
      await apiClient.clearAllCache();
      ref.invalidate(clubDetailsProvider(widget.clubId));
      ref.invalidate(clubMembersProvider(widget.clubId));
      ref.invalidate(myClubsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Club updated successfully!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.winGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating club: $e', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.lossRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invite code copied to clipboard!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(clubDetailsProvider(widget.clubId));
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));
    final leaderboardAsync = ref.watch(leaderboardProvider(widget.clubId));
    final tournamentsAsync = ref.watch(clubTournamentsProvider(widget.clubId));

    return membersAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load club: $e'),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        final clubMap = detailsAsync.valueOrNull ?? (data['club'] as Map<String, dynamic>? ?? {});

        final clubName = clubMap['name']?.toString() ?? data['name']?.toString() ?? widget.clubName;
        final inviteCode = clubMap['invite_code']?.toString() ?? data['invite_code']?.toString() ?? '—';
        final createdAt = clubMap['created_at']?.toString() ?? '—';
        final isOwner = clubMap['is_owner'] == true;

        // User role
        final myId = ref.read(authStateProvider) ?? '';
        final me = members.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id']?.toString() == myId,
              orElse: () => null,
            );
        final myRole = (clubMap['user_role'] ?? me?['role'] ?? 'player').toString().toLowerCase();
        final isOfficial = clubMap['is_official'] == true ||
            isOwner ||
            ['admin', 'president', 'organizer', 'captain', 'vice-captain'].contains(myRole);

        // Leaderboard top player
        String topPlayer = '—';
        leaderboardAsync.whenData((lb) {
          if (lb.isNotEmpty) {
            topPlayer = lb.first['player_name'] ?? lb.first['username'] ?? '—';
          }
        });

        // Tournaments count
        int tournamentCount = 0;
        tournamentsAsync.whenData((tData) {
          final list = tData['tournaments'] as List<dynamic>? ?? [];
          tournamentCount = list.length;
        });

        // Prefill
        if (_editNameCtrl.text.isEmpty && clubName.isNotEmpty) {
          _editNameCtrl.text = clubName;
        }
        if (_editCodeCtrl.text.isEmpty && inviteCode != '—') {
          _editCodeCtrl.text = inviteCode;
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Club Overview Hero Card ────────────────────────────────
            GlassCard(
              borderColor: AppColors.primary.withValues(alpha: 0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionLabel('CLUB OVERVIEW', AppColors.primary),
                      const Spacer(),
                      GlowBadge(
                        label: myRole.toUpperCase(),
                        color: _roleColor(myRole),
                        icon: _roleIcon(myRole),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          label: 'MEMBERS',
                          value: '${members.length}',
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          label: 'TOURNAMENTS',
                          value: '$tournamentCount',
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: StatPill(
                          label: 'TOP PLAYER',
                          value: topPlayer.length > 12 ? '${topPlayer.substring(0, 12)}…' : topPlayer,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatPill(
                          label: 'CREATED',
                          value: _formatDate(createdAt),
                          color: AppColors.offWhite,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.08),

            const SizedBox(height: 14),

            // ── Invite Code & Share Card ───────────────────────────────
            GlassCard(
              borderColor: AppColors.offWhite.withValues(alpha: 0.25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _sectionLabel('INVITE ACCESS', AppColors.offWhite),
                      const Spacer(),
                      if (isOfficial)
                        GestureDetector(
                          onTap: widget.onRegenerateCode,
                          child: Row(
                            children: [
                              Icon(Icons.autorenew, size: 14, color: AppColors.offWhite),
                              const SizedBox(width: 4),
                              Text(
                                'REGENERATE',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.offWhite,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.offWhite.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.vpn_key, color: AppColors.offWhite, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inviteCode,
                              style: GoogleFonts.rajdhani(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: 3,
                              ),
                            ),
                            Text(
                              'Share this code with players to join',
                              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.offWhite.withValues(alpha: 0.15),
                          foregroundColor: AppColors.offWhite,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: AppColors.offWhite.withValues(alpha: 0.3)),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () => _copyCode(inviteCode),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text('COPY', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate(delay: 60.ms).fadeIn().slideY(begin: 0.08),

            // ── Edit Club Section (Admin/Officials) ────────────────────
            if (isOfficial) ...[
              const SizedBox(height: 14),
              GlassCard(
                borderColor: AppColors.cyan.withValues(alpha: 0.25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _sectionLabel('EDIT CLUB SETTINGS', AppColors.cyan),
                        const Spacer(),
                        GlowBadge(label: 'OFFICIAL ACCESS', color: AppColors.cyan, icon: Icons.admin_panel_settings),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _input(_editNameCtrl, 'Club Name *', Icons.shield),
                    const SizedBox(height: 10),
                    _input(_editCodeCtrl, 'Invite Code (Optional)', Icons.vpn_key),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: EsportsButton(
                        label: 'SAVE CLUB CHANGES',
                        icon: Icons.save,
                        isLoading: _saving,
                        onPressed: _saving ? null : () => _save(clubName, inviteCode),
                        gradient: [AppColors.cyan, const Color(0xFF00B0FF)],
                        textColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 120.ms).fadeIn().slideY(begin: 0.08),
            ],

            // ── Club Management & Membership Actions ──────────────────
            const SizedBox(height: 14),
            GlassCard(
              borderColor: Colors.white10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('CLUB ACTIONS', AppColors.textMuted),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!isOwner)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.lossRed,
                              side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.exit_to_app, size: 18),
                            label: Text('LEAVE CLUB', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: widget.onLeaveClub,
                          ),
                        ),
                      if (isOwner || isOfficial) ...[
                        if (!isOwner) const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.lossRed,
                              side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: Text('DISBAND CLUB', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: widget.onDeleteClub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ).animate(delay: 180.ms).fadeIn().slideY(begin: 0.08),

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
        filled: true,
        fillColor: AppColors.isLight ? AppColors.surfaceLight : Colors.white.withValues(alpha: 0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cyan),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — ROSTER
// ─────────────────────────────────────────────────────────────────────────────

class _RosterTab extends ConsumerStatefulWidget {
  final String clubId;
  const _RosterTab({required this.clubId});

  @override
  ConsumerState<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends ConsumerState<_RosterTab> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _roleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showInviteDialog(String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.offWhite.withValues(alpha: 0.3)),
        ),
        title: Text(
          'INVITE CODE',
          style: GoogleFonts.rajdhani(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppColors.offWhite.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.offWhite.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.offWhite.withValues(alpha: 0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.vpn_key, color: AppColors.offWhite, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    code,
                    style: GoogleFonts.rajdhani(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: EsportsButton(
                label: 'COPY CODE',
                icon: Icons.copy,
                gradient: [AppColors.primary, const Color(0xFFFF9E00)],
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invite code copied!', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoleDialog(String clubId, String playerId, String currentRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        title: Text(
          'CHANGE ROLE',
          style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['admin', 'president', 'organizer', 'captain', 'vice-captain', 'player'].map((role) {
            final isCurrent = currentRole.toLowerCase() == role;
            final rColor = _roleColor(role);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isCurrent ? rColor.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent ? rColor.withValues(alpha: 0.4) : Colors.white12,
                ),
              ),
              child: ListTile(
                leading: Icon(_roleIcon(role), color: rColor, size: 18),
                title: Text(
                  role.toUpperCase(),
                  style: GoogleFonts.rajdhani(
                    color: isCurrent ? rColor : AppColors.textPrimary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                trailing: isCurrent ? Icon(Icons.check_circle, color: rColor, size: 18) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(apiClientProvider).updateMemberRole(clubId, playerId, role);
                    ref.invalidate(clubMembersProvider(clubId));
                    ref.invalidate(clubDetailsProvider(clubId));
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update role: $e'), backgroundColor: AppColors.lossRed),
                      );
                    }
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _confirmTransferOwnership(String clubId, String playerId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        title: Text(
          'TRANSFER OWNERSHIP',
          style: GoogleFonts.rajdhani(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to transfer full ownership of this club to $username? You will remain an admin member.',
          style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).transferOwnership(clubId, playerId);
                ref.invalidate(clubMembersProvider(clubId));
                ref.invalidate(clubDetailsProvider(clubId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Club ownership transferred to $username!'), backgroundColor: AppColors.winGreen),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to transfer ownership: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text('TRANSFER', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(String clubId, String playerId, String username) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.4)),
        ),
        title: Text(
          'REMOVE MEMBER',
          style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove $username from the club? This action cannot be undone.',
          style: GoogleFonts.rajdhani(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lossRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).removeMember(clubId, playerId);
                ref.invalidate(clubMembersProvider(clubId));
                ref.invalidate(clubDetailsProvider(clubId));
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove member: $e'), backgroundColor: AppColors.lossRed),
                  );
                }
              }
            },
            child: Text('REMOVE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(clubDetailsProvider(widget.clubId));
    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));

    return membersAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load roster: $e'),
      data: (data) {
        final allMembers = data['members'] as List<dynamic>? ?? [];
        final clubMap = detailsAsync.valueOrNull ?? (data['club'] as Map<String, dynamic>? ?? {});
        final inviteCode = clubMap['invite_code']?.toString() ?? data['invite_code']?.toString() ?? '—';
        final isOwner = clubMap['is_owner'] == true;

        // Current user role
        final myId = ref.read(authStateProvider) ?? '';
        final me = allMembers.cast<Map<String, dynamic>?>().firstWhere(
              (m) => m?['user_id']?.toString() == myId,
              orElse: () => null,
            );
        final myRole = (clubMap['user_role'] ?? me?['role'] ?? 'player').toString().toLowerCase();
        final isOfficial = clubMap['is_official'] == true ||
            isOwner ||
            ['admin', 'president', 'organizer', 'captain', 'vice-captain'].contains(myRole);

        // Filter members
        final filteredMembers = allMembers.where((m) {
          final username = (m['username'] ?? '').toString().toLowerCase();
          final role = (m['role'] ?? 'player').toString().toLowerCase();

          final matchesSearch = _searchQuery.isEmpty || username.contains(_searchQuery);
          if (!matchesSearch) return false;

          if (_roleFilter == 'OFFICIALS') {
            return ['admin', 'president', 'organizer', 'captain', 'vice-captain'].contains(role);
          } else if (_roleFilter == 'PLAYERS') {
            return role == 'player';
          }
          return true;
        }).toList();

        final officialCount = allMembers.where((m) {
          final role = (m['role'] ?? 'player').toString().toLowerCase();
          return ['admin', 'president', 'organizer', 'captain', 'vice-captain'].contains(role);
        }).length;
        final playerCount = allMembers.length - officialCount;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Invite button
                    Row(
                      children: [
                        _sectionLabel('SQUAD ROSTER', AppColors.cyan),
                        const Spacer(),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.offWhite,
                            side: BorderSide(color: AppColors.offWhite.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.link, size: 16),
                          label: Text('INVITE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13)),
                          onPressed: () => _showInviteDialog(inviteCode),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search input
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search members...',
                          hintStyle: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 14),
                          prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AppColors.textMuted, size: 16),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Filter chips row
                    Row(
                      children: [
                        _filterChip('ALL (${allMembers.length})', 'ALL'),
                        const SizedBox(width: 8),
                        _filterChip('OFFICIALS ($officialCount)', 'OFFICIALS'),
                        const SizedBox(width: 8),
                        _filterChip('PLAYERS ($playerCount)', 'PLAYERS'),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            if (filteredMembers.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.group_off, size: 40, color: AppColors.textDim),
                        const SizedBox(height: 10),
                        Text(
                          _searchQuery.isNotEmpty ? 'No members match "$_searchQuery"' : 'No members found in this filter.',
                          style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final m = filteredMembers[index] as Map<String, dynamic>;
                      final role = (m['role'] ?? 'player').toString().toLowerCase();
                      final username = m['username']?.toString() ?? 'Player';
                      final pid = m['user_id']?.toString() ?? '';
                      final rating = m['skill_rating'] ?? 0;
                      final wins = m['matches_played'] ?? m['wins'] ?? 0;
                      final rColor = _roleColor(role);
                      final rIcon = _roleIcon(role);
                      final isMe = pid == myId;

                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        borderColor: rColor.withValues(alpha: 0.18),
                        onTap: () {
                          if (pid.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerProfileScreen(playerId: pid),
                              ),
                            );
                          }
                        },
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: getAvatarById(m['avatar_graphic']?.toString()).gradient.first.withValues(alpha: 0.2),
                              child: Icon(
                                getAvatarById(m['avatar_graphic']?.toString()).icon,
                                color: getAvatarById(m['avatar_graphic']?.toString()).gradient.first,
                                size: 22,
                              ),
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
                                          username,
                                          style: GoogleFonts.rajdhani(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.textPrimary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isMe)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.cyan.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                                          ),
                                          child: Text('YOU', style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.cyan)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      GlowBadge(
                                        label: role.toUpperCase(),
                                        color: rColor,
                                        icon: rIcon,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Matches: $wins',
                                        style: GoogleFonts.rajdhani(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // ELO badge
                            GlowBadge(label: '$rating ELO', color: AppColors.primary),
                            const SizedBox(width: 4),
                            // Options popup menu
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.cardBorder),
                              ),
                              onSelected: (val) {
                                if (val == 'profile') {
                                  if (pid.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PlayerProfileScreen(playerId: pid),
                                      ),
                                    );
                                  }
                                } else if (val == 'role') {
                                  _showRoleDialog(widget.clubId, pid, role);
                                } else if (val == 'transfer_ownership') {
                                  _confirmTransferOwnership(widget.clubId, pid, username);
                                } else if (val == 'remove') {
                                  _confirmRemove(widget.clubId, pid, username);
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'profile',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person, color: AppColors.cyan, size: 16),
                                      const SizedBox(width: 8),
                                      Text('View Profile', style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 14)),
                                    ],
                                  ),
                                ),
                                if (isOfficial && !isMe)
                                  PopupMenuItem(
                                    value: 'role',
                                    child: Row(
                                      children: [
                                        Icon(Icons.manage_accounts, color: AppColors.cyan, size: 16),
                                        const SizedBox(width: 8),
                                        Text('Change Role', style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                if (isOwner && !isMe)
                                  PopupMenuItem(
                                    value: 'transfer_ownership',
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz, color: AppColors.primary, size: 16),
                                        const SizedBox(width: 8),
                                        Text('Transfer Ownership', style: GoogleFonts.rajdhani(color: AppColors.primary, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                if (isOfficial && !isMe)
                                  PopupMenuItem(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_remove, color: AppColors.lossRed, size: 16),
                                        const SizedBox(width: 8),
                                        Text('Remove Member', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      )
                          .animate(delay: Duration(milliseconds: (index % 10) * 45))
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.1);
                    },
                    childCount: filteredMembers.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _roleFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = value),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.cyan.withValues(alpha: 0.18) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.cyan : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            color: selected ? AppColors.cyan : AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — LEADERBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardTab extends ConsumerWidget {
  final String clubId;
  const _LeaderboardTab({required this.clubId});

  static final _gold = AppColors.gold;
  static const _silver = Color(0xFFD9D4C8);
  static const _bronze = Color(0xFFB45309);

  Color _rankColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return AppColors.textSecondary;
  }

  void _showPlayerSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> player) {
    final name = player['player_name'] ?? player['username'] ?? 'Player';
    final rating = player['skill_rating'] ?? 0;
    final pid = player['player_id']?.toString() ?? '';
    final wins = player['wins'] ?? 0;
    final losses = player['losses'] ?? 0;
    final total = (wins + losses) as int;
    final winRate = total > 0 ? (wins / total * 100) : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),

                // Player header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: getAvatarById(player['avatar_graphic']?.toString()).gradient.first.withValues(alpha: 0.2),
                      child: Icon(
                        getAvatarById(player['avatar_graphic']?.toString()).icon,
                        size: 28,
                        color: getAvatarById(player['avatar_graphic']?.toString()).gradient.first,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$rating ELO • W:$wins / L:$losses',
                            style: GoogleFonts.rajdhani(color: AppColors.cyan, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Win rate bar
                Text(
                  'WIN RATE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: winRate / 100,
                    minHeight: 8,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      winRate >= 50 ? AppColors.winGreen : AppColors.lossRed,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${winRate.toStringAsFixed(1)}%',
                    style: GoogleFonts.rajdhani(
                      color: winRate >= 50 ? AppColors.winGreen : AppColors.lossRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.cyan,
                          side: BorderSide(color: AppColors.cyan),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.compare_arrows, size: 16),
                        label: Text('H2H', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EsportsButton(
                        label: 'PROFILE',
                        icon: Icons.person,
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (pid.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerProfileScreen(playerId: pid),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider(clubId));

    return leaderboardAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.amber)),
      error: (e, _) => _errorCard('Failed to load leaderboard: $e'),
      data: (players) {
        if (players.isEmpty) {
          return Center(
            child: Text(
              'No ranked players yet.',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('ELO LEADERBOARD', AppColors.amber),
            const SizedBox(height: 4),
            Text(
              'Tap any player for details & H2H',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Top 3 podium
            if (players.length >= 3)
              _buildPodium(context, ref, players)
            else
              const SizedBox.shrink(),

            if (players.length >= 3) const SizedBox(height: 16),

            // Full ranked list
            ...players.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final p = entry.value as Map<String, dynamic>;
              final name = p['player_name'] ?? p['username'] ?? 'Player';
              final rating = p['skill_rating'] ?? 0;
              final wins = p['wins'] ?? 0;
              final losses = p['losses'] ?? 0;
              final total = (wins + losses) as int;
              final winRate = total > 0 ? (wins / total * 100) : 0.0;
              final rColor = _rankColor(rank);

              // Skip top 3 if we rendered podium
              if (players.length >= 3 && rank <= 3) return const SizedBox.shrink();

              return GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                onTap: () => _showPlayerSheet(context, ref, p),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rColor.withValues(alpha: 0.1),
                        border: Border.all(color: rColor.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '#$rank',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13, color: rColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: winRate / 100,
                              minHeight: 4,
                              backgroundColor: Colors.white10,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                winRate >= 50 ? AppColors.winGreen : AppColors.lossRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatPill(label: 'ELO', value: '$rating', color: AppColors.primary),
                  ],
                ),
              ).animate(delay: Duration(milliseconds: rank * 50)).fadeIn().slideY(begin: 0.1);
            }),

            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildPodium(BuildContext context, WidgetRef ref, List<dynamic> players) {
    final top3 = players.take(3).toList();
    final p1 = top3[0] as Map<String, dynamic>;
    final p2 = top3[1] as Map<String, dynamic>;
    final p3 = top3[2] as Map<String, dynamic>;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd
        Expanded(
          child: _podiumCard(context, ref, p2, 2, 102),
        ),
        const SizedBox(width: 8),
        // 1st
        Expanded(
          child: _podiumCard(context, ref, p1, 1, 120),
        ),
        const SizedBox(width: 8),
        // 3rd
        Expanded(
          child: _podiumCard(context, ref, p3, 3, 90),
        ),
      ],
    );
  }

  Widget _podiumCard(BuildContext context, WidgetRef ref, Map<String, dynamic> p, int rank, double height) {
    final name = p['player_name'] ?? p['username'] ?? 'Player';
    final rating = p['skill_rating'] ?? 0;
    final rColor = _rankColor(rank);

    return GestureDetector(
      onTap: () => _showPlayerSheet(context, ref, p),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [rColor.withValues(alpha: 0.15), rColor.withValues(alpha: 0.04)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(color: rColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: rColor.withValues(alpha: rank == 1 ? 0.25 : 0.1),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium, color: rColor, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name.length > 10 ? '${name.substring(0, 10)}…' : name,
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$rating',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: rColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: rank * 80)).slideY(begin: 0.15),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — ACTIVITY
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTab extends ConsumerWidget {
  final String clubId;
  const _ActivityTab({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(clubActivityProvider(clubId));

    return activityAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load activity: $e'),
      data: (matches) {
        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: 56, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No match activity yet.', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16)),
              ],
            ),
          );
        }

        // Group by date
        final Map<String, List<dynamic>> grouped = {};
        for (final m in matches) {
          final raw = m['played_at'] ?? m['created_at'] ?? '';
          final dateKey = raw.toString().length >= 10 ? raw.toString().substring(0, 10) : 'Unknown';
          grouped.putIfAbsent(dateKey, () => []).add(m);
        }

        final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('MATCH ACTIVITY', AppColors.primary),
            const SizedBox(height: 12),
            for (final date in sortedDates) ...[
              // Date separator
              Container(
                margin: const EdgeInsets.only(bottom: 10, top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _formatDate(date),
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              ...grouped[date]!.asMap().entries.map((entry) {
                final idx = entry.key;
                final match = entry.value as Map<String, dynamic>;
                final pName = match['player_name'] ?? 'Unknown';
                final oName = match['opponent_name'] ?? 'Unknown';
                final gf = (match['goals_for'] ?? match['score_for'] ?? 0) as int;
                final ga = (match['goals_against'] ?? match['score_against'] ?? 0) as int;
                final isP1Win = gf > ga;
                final isP2Win = ga > gf;
                final authUserId = ref.watch(authStateProvider);
                final isUserP1 = match['player_id']?.toString() == authUserId;
                final isUserP2 = match['opponent_id']?.toString() == authUserId;
                final matchType = match['match_type']?.toString() ?? 'MATCH';

                String resultLabel;
                Color resultColor;
                if (isUserP1) {
                  if (isP1Win) {
                    resultLabel = 'WON';
                    resultColor = AppColors.winGreen;
                  } else if (isP2Win) {
                    resultLabel = 'LOST';
                    resultColor = AppColors.lossRed;
                  } else {
                    resultLabel = 'DRAW';
                    resultColor = AppColors.amber;
                  }
                } else if (isUserP2) {
                  if (isP2Win) {
                    resultLabel = 'WON';
                    resultColor = AppColors.winGreen;
                  } else if (isP1Win) {
                    resultLabel = 'LOST';
                    resultColor = AppColors.lossRed;
                  } else {
                    resultLabel = 'DRAW';
                    resultColor = AppColors.amber;
                  }
                } else {
                  resultLabel = 'FT';
                  resultColor = AppColors.cyan;
                }

                return GlassCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  borderColor: resultColor.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      // Result color stripe
                      Container(
                        width: 4,
                        height: 56,
                        margin: const EdgeInsets.only(right: 14),
                        decoration: BoxDecoration(
                          color: resultColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(color: resultColor.withValues(alpha: 0.4), blurRadius: 6),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$pName vs $oName',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Text(
                                  '$gf – $ga',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: (isUserP1 || isUserP2) ? resultColor : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GlowBadge(label: matchType.toUpperCase(), color: AppColors.cyan),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GlowBadge(label: resultLabel, color: resultColor),
                    ],
                  ),
                )
                    .animate(delay: Duration(milliseconds: idx * 45))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.06);
              }),
            ],
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — RESOLVED MATCHES
// ─────────────────────────────────────────────────────────────────────────────

class _ResolvedTab extends ConsumerWidget {
  final String clubId;
  const _ResolvedTab({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedAsync = ref.watch(clubResolvedActivityProvider(clubId));

    return resolvedAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _errorCard('Failed to load resolved activity: $e'),
      data: (activity) {
        if (activity.isEmpty) {
          return Center(
            child: Text(
              'No resolved matches yet.',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activity.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _sectionLabel('RESOLVED MATCHES', AppColors.winGreen),
              );
            }
            final match = activity[index - 1] as Map<String, dynamic>;
            final matchType = match['match_type']?.toString().toUpperCase() ?? 'FRIENDLY';
            final pName = match['player_name'] ?? 'Player 1';
            final oName = match['opponent_name'] ?? 'Player 2';
            final gf = match['goals_for']?.toString() ?? '0';
            final ga = match['goals_against']?.toString() ?? '0';
            final date = _formatDate(match['created_at']?.toString() ?? '');
            final submitter = match['submitter_username'] ?? 'Player';
            final verifier = match['verifier_username'] ?? 'Unknown Admin';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                borderColor: Colors.white10,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GlowBadge(
                          label: matchType,
                          color: AppColors.cyan,
                          icon: Icons.sports_soccer,
                        ),
                        Text(date, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            pName,
                            textAlign: TextAlign.right,
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '$gf - $ga',
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            oName,
                            textAlign: TextAlign.left,
                            style: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.file_upload_outlined, color: AppColors.textMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Submitted by $submitter',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.verified, color: AppColors.winGreen, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Verified by $verifier',
                          style: TextStyle(color: AppColors.winGreen, fontSize: 11, fontStyle: FontStyle.italic),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _roleColor(String role) {
  final r = role.toLowerCase();
  if (r == 'admin') return AppColors.primary;
  if (r == 'president') return const Color(0xFFFFD700);
  if (r == 'organizer') return AppColors.offWhite;
  if (r == 'captain') return AppColors.amber;
  if (r == 'vice-captain') return const Color(0xFFFF9E00);
  return AppColors.cyan;
}

IconData _roleIcon(String role) {
  final r = role.toLowerCase();
  if (r == 'admin') return Icons.star;
  if (r == 'president') return Icons.account_balance;
  if (r == 'organizer') return Icons.engineering;
  if (r == 'captain') return Icons.local_police;
  if (r == 'vice-captain') return Icons.shield;
  return Icons.person;
}

Widget _sectionLabel(String label, Color color) {
  return Text(
    label,
    style: GoogleFonts.rajdhani(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
      color: color,
    ),
  );
}

Widget _errorCard(String msg) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        borderColor: AppColors.lossRed.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.lossRed),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: TextStyle(color: AppColors.lossRed))),
          ],
        ),
      ),
    ),
  );
}

String _formatDate(String raw) {
  if (raw.isEmpty || raw == '—') return raw;
  try {
    final dt = DateTime.parse(raw);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return raw.length >= 10 ? raw.substring(0, 10) : raw;
  }
}

