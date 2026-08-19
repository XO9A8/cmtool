import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/api_client.dart';
import 'tournament_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Crosshatch background painter
// ─────────────────────────────────────────────────────────────────────────────

class _TournamentGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double step = 32.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// TournamentScreen — Hub landing page
// ─────────────────────────────────────────────────────────────────────────────

class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> {
  String? _selectedClubId;
  String? _selectedClubName;

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _buildError(e.toString()),
        data: (data) {
          final clubs = (data['clubs'] as List<dynamic>? ?? []);
          if (clubs.isNotEmpty && _selectedClubId == null) {
            // Auto-select first club
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedClubId = clubs.first['id']?.toString();
                  _selectedClubName = clubs.first['name']?.toString() ?? 'Club';
                });
              }
            });
          }
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Club selector bar
              if (clubs.length > 1)
                SliverToBoxAdapter(child: _buildClubSelectorBar(clubs)),

              // Hero banner
              SliverToBoxAdapter(
                child: _buildHeroBanner(clubs).animate().fade(duration: 400.ms).slideY(begin: -0.08, duration: 400.ms),
              ),

              // Tournament sections
              SliverToBoxAdapter(
                child: _selectedClubId != null
                    ? _TournamentListSection(
                        clubId: _selectedClubId!,
                        selectedClubId: _selectedClubId!,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          borderColor: AppColors.lossRed.withValues(alpha: 0.4),
          child: Text(
            'Error loading clubs:\n$message',
            style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildClubSelectorBar(List<dynamic> clubs) {
    return Container(
      height: 52,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: clubs.length,
        itemBuilder: (context, i) {
          final club = clubs[i];
          final id = club['id']?.toString() ?? '';
          final name = club['name']?.toString() ?? 'Club';
          final isSelected = id == _selectedClubId;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedClubId = id;
              _selectedClubName = name;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surfaceLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Text(
                name,
                style: GoogleFonts.rajdhani(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fade(duration: 300.ms);
  }

  Widget _buildHeroBanner(List<dynamic> clubs) {
    final clubName = _selectedClubName ?? (clubs.isNotEmpty ? clubs.first['name']?.toString() : null) ?? 'YOUR CLUB';

    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.purple.withValues(alpha: 0.15),
            AppColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Crosshatch grid
            Positioned.fill(
              child: CustomPaint(painter: _TournamentGridPainter()),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Shimmer gradient title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.primary, AppColors.cyan],
                          ).createShader(bounds),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'TOURNAMENT\nHUB',
                              style: GoogleFonts.orbitron(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.1,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          clubName.toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // New Tournament button
                  if (_selectedClubId != null)
                    EsportsButton(
                      label: 'NEW TOURNAMENT',
                      icon: Icons.add,
                      height: 44,
                      onPressed: () => _showCreateSheet(context, _selectedClubId!),
                    ),
                ],
              ),
            ),
            // Trophy watermark
            Positioned(
              right: -16,
              bottom: -16,
              child: Icon(
                Icons.emoji_events,
                size: 140,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, String clubId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateTournamentSheet(
        clubId: clubId,
        onCreated: () => ref.invalidate(clubTournamentsProvider(clubId)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Tournament Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTournamentSheet extends ConsumerStatefulWidget {
  final String clubId;
  final VoidCallback onCreated;

  const _CreateTournamentSheet({required this.clubId, required this.onCreated});

  @override
  ConsumerState<_CreateTournamentSheet> createState() => _CreateTournamentSheetState();
}

class _CreateTournamentSheetState extends ConsumerState<_CreateTournamentSheet> {
  final _nameCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _formatType = 'round_robin';
  int _legs = 1; // 1 = single round-robin, 2 = double round-robin
  int _groupsCount = 2; // 2, 4, or 8 groups
  int _advancingPerGroup = 2; // Top 1 or Top 2 advance
  int _knockoutLegs = 1; // 1 = Single leg, 2 = Two legs (home & away)
  bool _hasThirdPlaceMatch = true; // 3rd place playoff
  String _seedingType = 'elo'; // 'elo' or 'random'
  bool _singleFinalMatch = true; // Single match for Final even if earlier rounds are 2 legs
  final Set<String> _selectedPlayerIds = {};
  bool _initializedMembers = false;
  bool _isLoading = false;
  String? _errorMsg;
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _createTournament() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Please enter a tournament name');
      return;
    }
    if (_selectedPlayerIds.length < 2) {
      setState(() => _errorMsg = 'Please select at least 2 participating players');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      await client.createTournament(
        clubId: widget.clubId,
        name: name,
        formatType: _formatType,
        startDate: _startDate,
        endDate: _endDate,
        rulesConfig: {
          'legs': _legs,
          'groups_count': _groupsCount,
          'advancing_per_group': _advancingPerGroup,
          'knockout_legs': _knockoutLegs,
          'has_third_place_match': _hasThirdPlaceMatch,
          'seeding_type': _seedingType,
          'single_final_match': _singleFinalMatch,
          'participant_ids': _selectedPlayerIds.toList(),
        },
      );
      final authUserId = ref.read(authStateProvider);
      if (authUserId != null) {
        ref.invalidate(playerScheduledMatchesProvider(authUserId));
      }
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = ApiClient.formatErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(clubMembersProvider(widget.clubId), (prev, next) {
      if (!_initializedMembers && next.hasValue) {
        final data = next.value ?? {};
        final members = (data['members'] as List<dynamic>? ?? []);
        setState(() {
          _selectedPlayerIds.addAll(members.map((m) => m['user_id']?.toString() ?? '').where((id) => id.isNotEmpty));
          _initializedMembers = true;
        });
      }
    });

    final membersAsync = ref.watch(clubMembersProvider(widget.clubId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassCard(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          borderRadius: 24,
          borderColor: AppColors.primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.emoji_events, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'CREATE TOURNAMENT',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Name field
                TextField(
                  controller: _nameCtrl,
                  focusNode: _focusNode,
                  style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Tournament Name',
                    labelStyle: GoogleFonts.rajdhani(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight.withValues(alpha: 0.6),
                    prefixIcon: Icon(
                      Icons.emoji_events,
                      color: _isFocused ? AppColors.primary : AppColors.textMuted,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Date Pickers
                Row(
                  children: [
                    Expanded(
                      child: _buildDatePicker(
                        label: 'Start Date',
                        date: _startDate,
                        onChanged: (d) => setState(() => _startDate = d),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDatePicker(
                        label: 'End Date',
                        date: _endDate,
                        onChanged: (d) => setState(() => _endDate = d),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Format type
                Text(
                  'FORMAT TYPE',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _FormatChip(
                        label: 'LEAGUE (ROUND ROBIN)',
                        icon: Icons.swap_horiz,
                        selected: _formatType == 'round_robin',
                        onTap: () => setState(() => _formatType = 'round_robin'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FormatChip(
                        label: 'KNOCKOUT TOURNAMENT',
                        icon: Icons.account_tree,
                        selected: _formatType == 'knockout' || _formatType == 'group_knockout',
                        onTap: () => setState(() {
                          if (_formatType == 'round_robin') {
                            _formatType = 'knockout'; // default to direct knockout
                          }
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Knockout Sub-options
                if (_formatType == 'knockout' || _formatType == 'group_knockout') ...[
                  Text(
                    'KNOCKOUT STAGE STRUCTURE',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatChip(
                          label: 'DIRECT KNOCKOUT',
                          icon: Icons.flash_on,
                          selected: _formatType == 'knockout',
                          onTap: () => setState(() => _formatType = 'knockout'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormatChip(
                          label: 'GROUP FIRST + KNOCKOUT',
                          icon: Icons.grid_view,
                          selected: _formatType == 'group_knockout',
                          onTap: () => setState(() => _formatType = 'group_knockout'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Group stage settings if group_knockout is selected
                  if (_formatType == 'group_knockout') ...[
                    Text(
                      'NUMBER OF GROUPS',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _FormatChip(
                            label: '2 GROUPS',
                            icon: Icons.filter_2,
                            selected: _groupsCount == 2,
                            onTap: () => setState(() => _groupsCount = 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FormatChip(
                            label: '4 GROUPS',
                            icon: Icons.filter_4,
                            selected: _groupsCount == 4,
                            onTap: () => setState(() => _groupsCount = 4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FormatChip(
                            label: '8 GROUPS',
                            icon: Icons.filter_8,
                            selected: _groupsCount == 8,
                            onTap: () => setState(() => _groupsCount = 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    Text(
                      'ADVANCING PER GROUP',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _FormatChip(
                            label: 'TOP 1 (WINNER ONLY)',
                            icon: Icons.looks_one,
                            selected: _advancingPerGroup == 1,
                            onTap: () => setState(() => _advancingPerGroup = 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormatChip(
                            label: 'TOP 2 ADVANCE',
                            icon: Icons.looks_two,
                            selected: _advancingPerGroup == 2,
                            onTap: () => setState(() => _advancingPerGroup = 2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Knockout legs / round format
                  Text(
                    'KNOCKOUT MATCH LEGS',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatChip(
                          label: 'SINGLE MATCH (1x)',
                          icon: Icons.filter_1,
                          selected: _knockoutLegs == 1,
                          onTap: () => setState(() => _knockoutLegs = 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormatChip(
                          label: 'TWO LEGS (HOME & AWAY)',
                          icon: Icons.repeat,
                          selected: _knockoutLegs == 2,
                          onTap: () => setState(() => _knockoutLegs = 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Seeding Strategy Selection
                  Text(
                    'BRACKET SEEDING STRATEGY',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatChip(
                          label: 'ELO SEEDED (1 vs N)',
                          icon: Icons.military_tech,
                          selected: _seedingType == 'elo',
                          onTap: () => setState(() => _seedingType = 'elo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormatChip(
                          label: 'RANDOM DRAW',
                          icon: Icons.shuffle,
                          selected: _seedingType == 'random',
                          onTap: () => setState(() => _seedingType = 'random'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3rd Place Match Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3RD PLACE PLAYOFF MATCH',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Match between semi-final losers for bronze',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textMuted.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: _hasThirdPlaceMatch,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _hasThirdPlaceMatch = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Single Match Final Toggle (if 2 legs selected)
                  if (_knockoutLegs == 2) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SINGLE MATCH FINAL',
                              style: GoogleFonts.rajdhani(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              'Neutral venue single match for the final',
                              style: GoogleFonts.rajdhani(
                                color: AppColors.textMuted.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Switch.adaptive(
                          value: _singleFinalMatch,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _singleFinalMatch = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  const SizedBox(height: 4),
                ],

                // Encounters (Legs) selection for League
                if (_formatType == 'round_robin') ...[
                  Text(
                    'MATCH ENCOUNTERS',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _FormatChip(
                          label: 'SINGLE (1x)',
                          icon: Icons.filter_1,
                          selected: _legs == 1,
                          onTap: () => setState(() => _legs = 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FormatChip(
                          label: 'DOUBLE (2x)',
                          icon: Icons.repeat,
                          selected: _legs == 2,
                          onTap: () => setState(() => _legs = 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],

                // Participants selection section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PARTICIPATING PLAYERS',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    membersAsync.maybeWhen(
                      data: (d) {
                        final members = (d['members'] as List<dynamic>? ?? []);
                        final allSelected = _selectedPlayerIds.length == members.length;
                        return TextButton(
                          onPressed: () {
                            setState(() {
                              if (allSelected) {
                                _selectedPlayerIds.clear();
                              } else {
                                _selectedPlayerIds.addAll(members.map((m) => m['user_id']?.toString() ?? '').where((id) => id.isNotEmpty));
                              }
                            });
                          },
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 20)),
                          child: Text(
                            allSelected ? 'DESELECT ALL' : 'SELECT ALL',
                            style: GoogleFonts.rajdhani(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                membersAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                  error: (e, _) => Text('Failed to load members: $e', style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 13)),
                  data: (d) {
                    final members = (d['members'] as List<dynamic>? ?? []);
                    if (members.isEmpty) {
                      return Text('No members found in this club', style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13));
                    }
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: members.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                        itemBuilder: (ctx, i) {
                          final m = members[i];
                          final id = m['user_id']?.toString() ?? '';
                          final name = m['username']?.toString() ?? 'Player';
                          final role = m['role']?.toString() ?? 'player';
                          final isChecked = _selectedPlayerIds.contains(id);

                          return CheckboxListTile(
                            dense: true,
                            value: isChecked,
                            activeColor: AppColors.primary,
                            checkColor: Colors.black,
                            title: Text(
                              name,
                              style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              role.toUpperCase(),
                              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 11),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPlayerIds.add(id);
                                } else {
                                  _selectedPlayerIds.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    );
                  },
                ),

                if (_errorMsg != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lossRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.lossRed.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 14),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: EsportsButton(
                    label: 'CREATE TOURNAMENT',
                    icon: Icons.add_circle_outline,
                    isLoading: _isLoading,
                    onPressed: _createTournament,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker({required String label, required DateTime? date, required ValueChanged<DateTime?> onChanged}) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.primary,
                onPrimary: Colors.black,
                surface: AppColors.surface,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary, size: 14),
                const SizedBox(width: 8),
                Text(
                  date != null ? '${date.day}/${date.month}/${date.year}' : 'Not set',
                  style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: selected ? AppColors.primary : AppColors.textMuted,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tournament List Section — consumes provider and partitions by status
// ─────────────────────────────────────────────────────────────────────────────

class _TournamentListSection extends ConsumerWidget {
  final String clubId;
  final String selectedClubId;

  const _TournamentListSection({required this.clubId, required this.selectedClubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourneysAsync = ref.watch(clubTournamentsProvider(clubId));

    return tourneysAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(e.toString()),
      data: (data) {
        final list = (data['tournaments'] as List<dynamic>? ?? []);
        if (list.isEmpty) return _buildEmpty(context, ref, selectedClubId);

        final live = list.where((t) => t['status'] == 'active').toList();
        final scheduled = list
            .where((t) => t['status'] == 'draft' || t['status'] == 'scheduled')
            .toList();
        final completed = list.where((t) => t['status'] == 'completed').toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LIVE NOW
              if (live.isNotEmpty) ...[
                _sectionHeader('LIVE NOW', AppColors.winGreen, Icons.circle, pulse: true),
                ...live.asMap().entries.map((e) => _TournamentHeroCard(
                      tournament: e.value,
                      delay: e.key * 80,
                    )),
              ],

              // SCHEDULED
              if (scheduled.isNotEmpty) ...[
                _sectionHeader('SCHEDULED', AppColors.cyan, Icons.schedule),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: scheduled.length,
                    itemBuilder: (context, i) => _TournamentScheduledCard(
                      tournament: scheduled[i],
                      selectedClubId: selectedClubId,
                      delay: i * 80,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // COMPLETED
              if (completed.isNotEmpty) ...[
                _sectionHeader('COMPLETED', AppColors.textMuted, Icons.archive_outlined),
                ...completed.asMap().entries.map((e) => _TournamentCompletedRow(
                      tournament: e.value,
                      delay: e.key * 60,
                    )),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title, Color color, IconData icon, {bool pulse = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          if (pulse)
            _PulseDot(color: color)
          else
            Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: List.generate(
          3,
          (i) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                duration: 1200.ms,
                color: Colors.white.withValues(alpha: 0.05),
              ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        borderColor: AppColors.lossRed.withValues(alpha: 0.4),
        child: Text(
          'Failed to load tournaments:\n$msg',
          style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref, String clubId) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, color: AppColors.textMuted.withValues(alpha: 0.4), size: 80),
          const SizedBox(height: 20),
          Text(
            'No tournaments yet',
            style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Get started by creating your first tournament',
            style: GoogleFonts.rajdhani(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          EsportsButton(
            label: 'CREATE YOUR FIRST',
            icon: Icons.add,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => _CreateTournamentSheet(
                  clubId: clubId,
                  onCreated: () => ref.invalidate(clubTournamentsProvider(clubId)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Now Hero Card
// ─────────────────────────────────────────────────────────────────────────────

class _TournamentHeroCard extends StatelessWidget {
  final dynamic tournament;
  final int delay;

  const _TournamentHeroCard({required this.tournament, required this.delay});

  @override
  Widget build(BuildContext context) {
    final id = tournament['id']?.toString() ?? '';
    final name = tournament['name']?.toString() ?? 'Tournament';
    final format = tournament['format_type']?.toString() ?? 'round_robin';
    final count = tournament['participant_count'] ?? 0;
    final isKnockout = format == 'knockout';

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: EdgeInsets.zero,
      borderColor: AppColors.winGreen.withValues(alpha: 0.35),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(
            tournamentId: id,
            tournamentName: name,
            formatType: format,
            status: 'active',
          ),
        ),
      ),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Trophy watermark
            Positioned(
              right: -12,
              bottom: -12,
              child: Icon(
                Icons.emoji_events,
                size: 120,
                color: AppColors.winGreen.withValues(alpha: 0.08),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _PulseDot(color: AppColors.winGreen),
                      SizedBox(width: 6),
                      GlowBadge(label: 'LIVE', color: AppColors.winGreen),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name.toUpperCase(),
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      GlowBadge(
                        label: isKnockout ? 'KNOCKOUT' : 'LEAGUE',
                        color: AppColors.cyan,
                        icon: isKnockout ? Icons.account_tree : Icons.swap_horiz,
                      ),
                      const SizedBox(width: 8),
                      GlowBadge(
                        label: '$count PLAYERS',
                        color: AppColors.purple,
                        icon: Icons.group,
                      ),
                      const Spacer(),
                      EsportsButton(
                        label: 'ENTER →',
                        height: 36,
                        gradient: const [AppColors.winGreen, AppColors.cyan],
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TournamentDetailScreen(
                              tournamentId: id,
                              tournamentName: name,
                              formatType: format,
                              status: 'active',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 350.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.08, duration: 350.ms, delay: Duration(milliseconds: delay));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scheduled Card (horizontal scroll)
// ─────────────────────────────────────────────────────────────────────────────

class _TournamentScheduledCard extends ConsumerStatefulWidget {
  final dynamic tournament;
  final String selectedClubId;
  final int delay;

  const _TournamentScheduledCard({
    required this.tournament,
    required this.selectedClubId,
    required this.delay,
  });

  @override
  ConsumerState<_TournamentScheduledCard> createState() => _TournamentScheduledCardState();
}

class _TournamentScheduledCardState extends ConsumerState<_TournamentScheduledCard> {
  bool _isStarting = false;

  Future<void> _showStartDialog(BuildContext context) async {
    final id = widget.tournament['id']?.toString() ?? '';
    final name = widget.tournament['name']?.toString() ?? 'Tournament';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        title: Text(
          'START TOURNAMENT?',
          style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Start "$name"? This will generate all fixtures and set the tournament to LIVE. This cannot be undone.',
          style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
          ),
          EsportsButton(
            label: 'START',
            icon: Icons.play_arrow,
            height: 40,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isStarting = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.startTournament(id, []);
      ref.invalidate(clubTournamentsProvider(widget.selectedClubId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start: ${ApiClient.formatErrorMessage(e)}', style: GoogleFonts.rajdhani()),
            backgroundColor: AppColors.lossRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.tournament['id']?.toString() ?? '';
    final name = widget.tournament['name']?.toString() ?? 'Tournament';
    final format = widget.tournament['format_type']?.toString() ?? 'round_robin';
    final count = widget.tournament['participant_count'] ?? 0;
    final status = widget.tournament['status']?.toString() ?? 'draft';
    final isDraft = status == 'draft';
    final isKnockout = format == 'knockout';

    return GlassCard(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.cyan.withValues(alpha: 0.25),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(
            tournamentId: id,
            tournamentName: name,
            formatType: format,
            status: status,
          ),
        ),
      ),
      child: SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: AppColors.cyan, size: 18),
                const SizedBox(width: 6),
                GlowBadge(
                  label: isDraft ? 'DRAFT' : 'SCHEDULED',
                  color: isDraft ? AppColors.textMuted : AppColors.cyan,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              isKnockout ? '⚡ KNOCKOUT' : '↔ LEAGUE',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12),
            ),
            Text(
              '$count players',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 12),
            ),
            const Spacer(),
            if (isDraft)
              SizedBox(
                width: double.infinity,
                child: EsportsButton(
                  label: 'START',
                  icon: Icons.play_arrow,
                  height: 36,
                  isLoading: _isStarting,
                  gradient: const [AppColors.cyan, AppColors.winGreen],
                  textColor: Colors.black,
                  onPressed: () => _showStartDialog(context),
                ),
              ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms, delay: Duration(milliseconds: widget.delay)).slideX(begin: 0.08, duration: 300.ms, delay: Duration(milliseconds: widget.delay));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed Row
// ─────────────────────────────────────────────────────────────────────────────

class _TournamentCompletedRow extends StatelessWidget {
  final dynamic tournament;
  final int delay;

  const _TournamentCompletedRow({required this.tournament, required this.delay});

  @override
  Widget build(BuildContext context) {
    final id = tournament['id']?.toString() ?? '';
    final name = tournament['name']?.toString() ?? 'Tournament';
    final format = tournament['format_type']?.toString() ?? 'round_robin';

    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(
            tournamentId: id,
            tournamentName: name,
            formatType: format,
            status: 'completed',
          ),
        ),
      ),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              format == 'knockout' ? 'KNOCKOUT' : 'LEAGUE',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(width: 8),
            const GlowBadge(label: 'ARCHIVED', color: AppColors.textMuted),
          ],
        ),
      ),
    ).animate().fade(duration: 280.ms, delay: Duration(milliseconds: delay)).slideY(begin: 0.05, duration: 280.ms, delay: Duration(milliseconds: delay));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot widget
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatelessWidget {
  final Color color;

  const _PulseDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6, spreadRadius: 1)],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 1.0, end: 1.5, duration: 800.ms, curve: Curves.easeInOut);
  }
}
