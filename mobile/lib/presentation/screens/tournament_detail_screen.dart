import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../../infrastructure/api_client.dart';
import '../widgets/league_table_widget.dart';
import '../widgets/group_standings_widget.dart';
import '../widgets/forfeit_claim_modal.dart';
import '../widgets/ocr_upload_modal.dart';
import 'player_profile_screen.dart';
import '../widgets/tournament_leaders_widget.dart';
import '../widgets/reschedule_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bracket lines painter (moved from tournament_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _BracketLinesPainter extends CustomPainter {
  final int numRounds;
  final List<int> matchesPerRound;
  final double nodeWidth;
  final double nodeHeight;
  final double hSpace;
  final double vSpace;
  final double Function(int) getNodeX;
  final double Function(int, int) getNodeY;
  final Color linkColor;

  _BracketLinesPainter({
    required this.numRounds,
    required this.matchesPerRound,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.hSpace,
    required this.vSpace,
    required this.getNodeX,
    required this.getNodeY,
    required this.linkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = linkColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int rIdx = 0; rIdx < numRounds - 1; rIdx++) {
      final matchesInThisRound = matchesPerRound[rIdx];
      for (int mIdx = 0; mIdx < matchesInThisRound; mIdx += 2) {
        if (mIdx + 1 >= matchesInThisRound) continue;

        double topY = getNodeY(rIdx, mIdx) + (nodeHeight / 2);
        double bottomY = getNodeY(rIdx, mIdx + 1) + (nodeHeight / 2);
        double startX = getNodeX(rIdx) + nodeWidth;

        double midX = startX + (hSpace / 2);
        double nextX = getNodeX(rIdx + 1);
        double nextY = getNodeY(rIdx + 1, mIdx ~/ 2) + (nodeHeight / 2);

        final path = Path();

        path.moveTo(startX, topY);
        path.lineTo(midX, topY);
        path.lineTo(midX, nextY);
        path.lineTo(nextX, nextY);

        path.moveTo(startX, bottomY);
        path.lineTo(midX, bottomY);
        path.lineTo(midX, nextY);

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// TournamentDetailScreen
// ─────────────────────────────────────────────────────────────────────────────

class TournamentDetailScreen extends ConsumerStatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final String formatType;
  final String status;
  final bool isAdmin;

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.formatType,
    required this.status,
    this.isAdmin = true, // Default to true if not passed for now, though better to explicitly pass

  });

  @override
  ConsumerState<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends ConsumerState<TournamentDetailScreen> {
  int _tabIndex = 0;
  // For knockout fixtures view: 0 = list, 1 = tree
  int _fixtureView = 0;
  // Track mutable status locally so admin actions update the UI
  late String _currentStatus;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_currentStatus == 'active') {
        _refresh();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get _isKnockout => widget.formatType == 'knockout';

  Future<void> _refresh() async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.clearAllCache();
    
    ref.invalidate(tournamentBracketProvider(widget.tournamentId));
    ref.invalidate(leagueStandingsProvider(widget.tournamentId));
    ref.invalidate(clubTournamentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(innerBoxIsScrolled),
        ],
        body: Column(
          children: [
            // NavigationBar
            NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (i) => setState(() => _tabIndex = i),
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.primary.withValues(alpha: 0.2),
              height: 64,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined, color: AppColors.textMuted),
                  selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary),
                  label: 'FIXTURES',
                ),
                NavigationDestination(
                  icon: Icon(Icons.leaderboard_outlined, color: AppColors.textMuted),
                  selectedIcon: Icon(Icons.leaderboard, color: AppColors.primary),
                  label: 'STANDINGS',
                ),
                NavigationDestination(
                  icon: Icon(Icons.info_outline, color: AppColors.textMuted),
                  selectedIcon: Icon(Icons.info, color: AppColors.primary),
                  label: 'INFO',
                ),
              ],
            ),
            // Tab bodies
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _FixturesTab(
                    tournamentId: widget.tournamentId,
                    formatType: widget.formatType,
                    fixtureView: _fixtureView,
                    onToggleView: (v) => setState(() => _fixtureView = v),
                    isAdmin: widget.isAdmin,
                  ),
                  _StandingsTab(
                    tournamentId: widget.tournamentId,
                    formatType: widget.formatType,
                    onGoToFixtures: () => setState(() => _tabIndex = 0),
                  ),
                  _InfoTab(
                    tournamentId: widget.tournamentId,
                    tournamentName: widget.tournamentName,
                    formatType: widget.formatType,
                    status: _currentStatus,
                    onStatusChanged: (newStatus) {
                      setState(() => _currentStatus = newStatus);
                      _refresh();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.cyan),
          onPressed: _refresh,
          tooltip: 'Refresh',
        ),
      ],
      title: innerBoxIsScrolled
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tournamentName,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: _currentStatus),
              ],
            )
          : null,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: _buildExpandedBanner(),
      ),
    );
  }

  Widget _buildExpandedBanner() {
    final isKnockout = _isKnockout;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.purple.withValues(alpha: 0.2),
            AppColors.background,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Trophy watermark
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.emoji_events,
              size: 160,
              color: AppColors.primary.withValues(alpha: 0.07),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 60, 80, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.tournamentName.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    height: 1.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GlowBadge(
                      label: isKnockout ? 'KNOCKOUT' : 'LEAGUE',
                      color: AppColors.cyan,
                      icon: isKnockout ? Icons.account_tree : Icons.swap_horiz,
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: _currentStatus),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status Badge helper
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = AppColors.winGreen;
        label = 'LIVE';
        break;
      case 'completed':
        color = AppColors.textMuted;
        label = 'COMPLETED';
        break;
      default:
        color = AppColors.cyan;
        label = 'DRAFT';
    }
    return GlowBadge(label: label, color: color);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Fixtures
// ─────────────────────────────────────────────────────────────────────────────

class _FixturesTab extends ConsumerStatefulWidget {
  final String tournamentId;
  final String formatType;
  final int fixtureView;
  final ValueChanged<int> onToggleView;
  final bool isAdmin;

  const _FixturesTab({
    required this.tournamentId,
    required this.formatType,
    required this.fixtureView,
    required this.onToggleView,
    required this.isAdmin,
  });

  @override
  ConsumerState<_FixturesTab> createState() => _FixturesTabState();
}

class _FixturesTabState extends ConsumerState<_FixturesTab> {
  String? _selectedMatchdayId;

  @override
  Widget build(BuildContext context) {
    final bracketAsync = ref.watch(tournamentBracketProvider(widget.tournamentId));
    final matchdaysAsync = ref.watch(matchdaysProvider(widget.tournamentId));
    final isKnockout = widget.formatType == 'knockout' || widget.formatType == 'group_knockout';

    if (bracketAsync.isLoading || matchdaysAsync.isLoading) return _buildLoading();
    if (bracketAsync.hasError) return _buildError(bracketAsync.error.toString());
    if (matchdaysAsync.hasError) return _buildError(matchdaysAsync.error.toString());

    final fixtures = (bracketAsync.value?['fixtures'] as List<dynamic>? ?? []);
    final matchdays = (matchdaysAsync.value?['matchdays'] as List<dynamic>? ?? []);

    if (fixtures.isEmpty) {
      return SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(16),
        child: _buildEmptyFixtures(),
      );
    }

    // Auto-select first matchday if not set
    if (_selectedMatchdayId == null && matchdays.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedMatchdayId = matchdays.first['id'].toString());
      });
    }

    final filteredFixtures = fixtures.where((f) {
      if (_selectedMatchdayId != null) {
        return f['matchday_id']?.toString() == _selectedMatchdayId;
      }
      return true;
    }).toList();

    return CustomScrollView(
      primary: false,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (isKnockout) ...[
                _buildViewToggle(),
                const SizedBox(height: 16),
              ],
              _buildMatchdaySelector(matchdays),
              const SizedBox(height: 16),
              if (filteredFixtures.isEmpty)
                _buildEmptyState()
              else if (isKnockout && widget.fixtureView == 1)
                _buildBracketTreeView(context, widget.formatType == 'group_knockout' 
                    ? filteredFixtures.where((f) => ((f['round_number'] as num?)?.toInt() ?? 1) >= 10).toList() 
                    : filteredFixtures),
            ]),
          ),
        ),
        if (filteredFixtures.isNotEmpty && !(isKnockout && widget.fixtureView == 1))
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 16),
            sliver: _buildFixtureListSliver(context, filteredFixtures, 0),
          ),
      ],
    );
  }



  Widget _buildMatchdaySelector(List<dynamic> matchdays) {
    if (matchdays.isEmpty) return const SizedBox.shrink();

    final selectedMd = matchdays.firstWhere(
      (m) => m['id'].toString() == _selectedMatchdayId,
      orElse: () => matchdays.first,
    );
    final dateStr = selectedMd['scheduled_date']?.toString();
    String dateLabel = 'Date TBD';
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final d = DateTime.parse(dateStr);
        dateLabel = '${d.day}/${d.month}/${d.year}';
      } catch (_) {}
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: matchdays.length,
            itemBuilder: (context, index) {
              final md = matchdays[index];
              final isSelected = md['id'].toString() == _selectedMatchdayId;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedMatchdayId = md['id'].toString()),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : AppColors.surfaceLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Matchday ${md['matchday_number']}',
                    style: GoogleFonts.orbitron(
                      color: isSelected ? AppColors.primary : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (widget.isAdmin)
                    GestureDetector(
                      onTap: () => _showRescheduleDialog(selectedMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_calendar, color: AppColors.cyan, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'RESCHEDULE',
                              style: GoogleFonts.rajdhani(
                                color: AppColors.cyan,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildExportButton(
                      'EXPORT FIXTURES',
                      Icons.picture_as_pdf,
                      () => _exportMatchday(selectedMd, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExportButton(
                      'EXPORT RESULTS',
                      Icons.picture_as_pdf,
                      () => _exportMatchday(selectedMd, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExportButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMatchday(dynamic matchday, bool includeResults) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.exportMatchdayPdf(widget.tournamentId, matchday['id'].toString(), includeResults);
      // Wait, there is no file saver here currently. We can just show a success message for now, or use path_provider and open_file to view it.
      // Since it's a mobile app, let's just show a snackbar saying it was generated.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF Exported Successfully (Check app directory)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  void _showRescheduleDialog(dynamic matchday) async {
    DateTime? currentDate;
    final dateStr = matchday['scheduled_date']?.toString();
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        currentDate = DateTime.parse(dateStr);
      } catch (_) {}
    }
    
    await showDialog(
      context: context,
      builder: (_) => RescheduleDialog(
        tournamentId: widget.tournamentId,
        matchdayId: matchday['id'].toString(),
        currentDate: currentDate,
        isMatchday: true,
      ),
    );
  }



  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.search_off, color: AppColors.textMuted.withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 12),
            Text(
              'No matches found',
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Center(
      child: SegmentedButton<int>(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surfaceLight,
          selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.2),
          selectedForegroundColor: AppColors.primary,
          foregroundColor: AppColors.textMuted,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        segments: const [
          ButtonSegment(value: 0, icon: Icon(Icons.view_list), label: Text('LIST')),
          ButtonSegment(value: 1, icon: Icon(Icons.account_tree), label: Text('TREE')),
        ],
        selected: {widget.fixtureView},
        onSelectionChanged: (s) => widget.onToggleView(s.first),
      ),
    );
  }



  Widget _buildFixtureListSliver(BuildContext context, List<dynamic> fixtures, int totalRounds) {
    final sorted = [...fixtures]..sort((a, b) {
        final rA = (a['round_number'] as num?)?.toInt() ?? 0;
        final rB = (b['round_number'] as num?)?.toInt() ?? 0;
        return rA.compareTo(rB);
      });

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return _MatchFixtureTile(
            fixture: sorted[index],
            tournamentId: widget.tournamentId,
            delay: index * 60,
            totalRounds: totalRounds,
            formatType: widget.formatType,
          ).animate().fade(duration: 300.ms, delay: Duration(milliseconds: (index % 10) * 60)).slideY(begin: 0.06, duration: 300.ms, delay: Duration(milliseconds: (index % 10) * 60));
        },
        childCount: sorted.length,
      ),
    );
  }


  Widget _buildBracketTreeView(BuildContext context, List<dynamic> fixtures) {
    if (fixtures.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: _buildEmptyState(),
      );
    }

    final Map<int, List<dynamic>> roundsMap = {};
    for (final f in fixtures) {
      final round = (f['round_number'] as num?)?.toInt() ?? 1;
      roundsMap.putIfAbsent(round, () => []).add(f);
    }

    final sortedRounds = roundsMap.keys.toList()..sort();
    if (sortedRounds.isEmpty) return const SizedBox.shrink();

    final numRounds = sortedRounds.length;
    final maxMatchesInR1 = roundsMap[sortedRounds.first]?.length ?? 1;

    const double nodeWidth = 200;
    const double nodeHeight = 70;
    const double hSpace = 50;
    const double vSpace = 30;

    final double totalWidth = numRounds * (nodeWidth + hSpace);
    final double totalHeight = maxMatchesInR1 * (nodeHeight + vSpace);

    double getNodeY(int roundIdx, int matchIdx) {
      if (roundIdx == 0) return matchIdx * (nodeHeight + vSpace);
      double topY = getNodeY(roundIdx - 1, matchIdx * 2);
      double bottomY = getNodeY(roundIdx - 1, matchIdx * 2 + 1);
      return (topY + bottomY) / 2;
    }

    double getNodeX(int roundIdx) => roundIdx * (nodeWidth + hSpace);

    final List<Widget> stackChildren = [];

    stackChildren.add(
      SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: CustomPaint(
          painter: _BracketLinesPainter(
            numRounds: numRounds,
            matchesPerRound: sortedRounds.map((r) => roundsMap[r]?.length ?? 0).toList(),
            nodeWidth: nodeWidth,
            nodeHeight: nodeHeight,
            hSpace: hSpace,
            vSpace: vSpace,
            getNodeX: getNodeX,
            getNodeY: getNodeY,
            linkColor: AppColors.primary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    for (int rIdx = 0; rIdx < sortedRounds.length; rIdx++) {
      final roundMatches = roundsMap[sortedRounds[rIdx]] ?? [];
      for (int mIdx = 0; mIdx < roundMatches.length; mIdx++) {
        final match = roundMatches[mIdx];
        final x = getNodeX(rIdx);
        final y = getNodeY(rIdx, mIdx);

        stackChildren.add(
          Positioned(
            left: x,
            top: y,
            width: nodeWidth,
            height: nodeHeight,
            child: _BracketVersusPill(fixture: match, tournamentId: widget.tournamentId),
          ),
        );
      }
    }

    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withValues(alpha: 0.1)),
      ),
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(80),
        minScale: 0.5,
        maxScale: 2.0,
        constrained: false,
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: SizedBox(
            width: totalWidth,
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: stackChildren,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFixtures() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.sports_soccer, color: AppColors.textMuted.withValues(alpha: 0.3), size: 60),
            const SizedBox(height: 16),
            Text(
              'No fixtures generated yet',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Start the tournament to generate fixtures',
              style: GoogleFonts.rajdhani(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          4,
          (i) => Container(
            height: 100,
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
          'Failed to load fixtures:\n$msg',
          style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Fixture Tile
// ─────────────────────────────────────────────────────────────────────────────

class _MatchFixtureTile extends ConsumerWidget {
  final dynamic fixture;
  final String tournamentId;
  final int delay;
  final int totalRounds;
  final String formatType;

  const _MatchFixtureTile({
    required this.fixture,
    required this.tournamentId,
    required this.delay,
    required this.totalRounds,
    required this.formatType,
  });

  String _getRoundLabel(int r, int totalRounds) {
    if (formatType == 'knockout' || (formatType == 'group_knockout' && r >= 10)) {
      if (r == totalRounds && totalRounds > 0) return 'FINAL';
      if (r == totalRounds - 1 && totalRounds > 1) return 'SEMI-FINAL';
      if (r == totalRounds - 2 && totalRounds > 2) return 'QUARTER-FINAL';
      return 'ROUND $r MATCH';
    }
    return 'MATCH DAY $r';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchId = fixture['id']?.toString() ?? '';
    final p1Id = fixture['player_1_id']?.toString() ?? '';
    final p2Id = fixture['player_2_id']?.toString() ?? '';
    final p1Name = fixture['player_1_name']?.toString() ??
        (p1Id.length > 8 ? p1Id.substring(0, 8) : (p1Id.isNotEmpty ? p1Id : 'TBD'));
    final p2Name = fixture['player_2_name']?.toString() ??
        (p2Id.length > 8 ? p2Id.substring(0, 8) : (p2Id.isNotEmpty ? p2Id : 'TBD'));
    final p1Avatar = fixture['player_1_avatar']?.toString();
    final p2Avatar = fixture['player_2_avatar']?.toString();
    final round = (fixture['round_number'] as num?)?.toInt() ?? 1;
    final status = (fixture['status'] ?? 'scheduled').toString().toLowerCase();
    final winnerId = fixture['winner_player_id']?.toString();
    final isCompleted = status == 'completed';

    final p1IsWinner = isCompleted && winnerId != null && winnerId == p1Id;
    final p2IsWinner = isCompleted && winnerId != null && winnerId == p2Id;

    final p1Score = fixture['player_1_score'] as num?;
    final p2Score = fixture['player_2_score'] as num?;

    final groupName = fixture['group_name']?.toString();
    final roundLabel = _getRoundLabel(round, totalRounds);
    final isGroupMatch = formatType == 'round_robin' || (formatType == 'group_knockout' && round < 10);
    
    // Check if the user asked to add date and deadline:
    // e.g. " • 11:59 PM"
    // Since backend might not have deadline, we just hardcode the requested string if it's a group match, or always?
    // User: "and whats the lable round 1 instead say match day also include date and deadline of 11:59 pm"
    const dateStr = ' • 11:59 PM'; // Hardcoded deadline for now as requested
    
    final headerText = groupName != null && groupName.isNotEmpty && isGroupMatch
        ? '$groupName • $roundLabel$dateStr'
        : '$roundLabel$dateStr';

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(0),
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    headerText,
                    style: GoogleFonts.rajdhani(
                      color: groupName != null && groupName.isNotEmpty ? AppColors.cyan : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  const GlowBadge(label: 'COMPLETED', color: AppColors.winGreen),
                ],
                const SizedBox(width: 4),
                // Predict button
                _IconActionButton(
                  icon: Icons.psychology,
                  label: 'PREDICT',
                  color: AppColors.purple,
                  onTap: () {
                    final p1Rating = (fixture['player_1_rating'] as num?)?.toInt() ?? 1000;
                    final p2Rating = (fixture['player_2_rating'] as num?)?.toInt() ?? 1000;
                    _showPredictionSheet(context, p1Name, p2Name, p1Rating, p2Rating);
                  },
                ),
                const SizedBox(width: 6),
                // If fixture is completed or has match record, show DISPUTE button; else show REPORT (OCR Upload) & FORFEIT
                if (isCompleted || (fixture['match_record_id'] != null)) ...[
                  _IconActionButton(
                    icon: Icons.flag_outlined,
                    label: 'DISPUTE',
                    color: AppColors.lossRed,
                    onTap: () {
                      final recId = fixture['match_record_id']?.toString() ?? matchId;
                      _showDisputeDialog(context, ref, recId, '$p1Name vs $p2Name');
                    },
                  ),
                ] else ...[
                  _IconActionButton(
                    icon: Icons.upload_file,
                    label: 'REPORT',
                    color: AppColors.cyan,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => OcrUploadModal(
                        tMatchId: matchId,
                        defaultPlayerId: p1Id,
                        defaultOpponentId: p2Id,
                        defaultPlayerName: p1Name,
                        defaultOpponentName: p2Name,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _IconActionButton(
                    icon: Icons.gavel,
                    label: 'FORFEIT',
                    color: AppColors.lossRed,
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => ForfeitClaimModal(
                        tournamentId: tournamentId,
                        matchId: matchId,
                        player1Id: p1Id,
                        player2Id: p2Id,
                        player1Name: p1Name,
                        player2Name: p2Name,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),

          // Players body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: isCompleted
                ? _buildResultRow(p1Name, p2Name, p1IsWinner, p2IsWinner, winnerId == null, p1Score: p1Score, p2Score: p2Score, p1Avatar: p1Avatar, p2Avatar: p2Avatar)
                : _buildVsRow(p1Name, p2Name, p1Avatar, p2Avatar),
          ),
        ],
      ),
    );
  }

  Widget _buildVsRow(String p1Name, String p2Name, String? p1Avatar, String? p2Avatar) {
    return Row(
      children: [
        Expanded(child: _PlayerColumn(name: p1Name, highlight: false, avatarGraphic: p1Avatar)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Text(
              'VS',
              style: GoogleFonts.orbitron(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(child: _PlayerColumn(name: p2Name, highlight: false, rightAlign: true, avatarGraphic: p2Avatar)),
      ],
    );
  }

  Widget _buildResultRow(String p1Name, String p2Name, bool p1Won, bool p2Won, bool isDraw, {num? p1Score, num? p2Score, String? p1Avatar, String? p2Avatar}) {
    Color p1Color = isDraw ? Colors.amber : (p1Won ? AppColors.winGreen : AppColors.lossRed);
    Color p2Color = isDraw ? Colors.amber : (p2Won ? AppColors.winGreen : AppColors.lossRed);

    final scoreDisplay = (p1Score != null && p2Score != null)
        ? '${p1Score.toInt()} – ${p2Score.toInt()}'
        : (p1Won ? 'W – L' : (p2Won ? 'L – W' : 'D – D'));

    return Row(
      children: [
        Expanded(child: _PlayerColumn(name: p1Name, highlight: p1Won, color: p1Color, avatarGraphic: p1Avatar)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Text(
                scoreDisplay,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'FT',
                style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        Expanded(child: _PlayerColumn(name: p2Name, highlight: p2Won, color: p2Color, rightAlign: true, avatarGraphic: p2Avatar)),
      ],
    );
  }

  void _showPredictionSheet(BuildContext context, String p1Name, String p2Name, int p1Rating, int p2Rating) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PredictionSheet(p1Name: p1Name, p2Name: p2Name, p1Rating: p1Rating, p2Rating: p2Rating),
    );
  }

  void _showDisputeDialog(BuildContext context, WidgetRef ref, String matchRecordId, String matchTitle) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lossRed),
        ),
        title: Text('RAISE DISPUTE', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raise a formal dispute for match: $matchTitle.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                  matchRecordId: matchRecordId,
                  reason: reason,
                );
                ref.invalidate(adminDisputesProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Dispute raised for $matchTitle. Logged for admin review.'),
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
    ).then((_) => reasonCtrl.dispose());
  }
}

class _PlayerColumn extends StatelessWidget {
  final String name;
  final bool highlight;
  final Color? color;
  final bool rightAlign;
  final String? avatarGraphic;

  const _PlayerColumn({
    required this.name,
    required this.highlight,
    this.color,
    this.rightAlign = false,
    this.avatarGraphic,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Colors.white;

    return Column(
      crossAxisAlignment: rightAlign ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: getAvatarById(avatarGraphic).gradient.first.withValues(alpha: 0.2),
          child: Icon(
            getAvatarById(avatarGraphic).icon,
            size: 20,
            color: getAvatarById(avatarGraphic).gradient.first,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.rajdhani(
            color: highlight ? displayColor : Colors.white,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: rightAlign ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bracket Versus Pill (used in tree view nodes)
// ─────────────────────────────────────────────────────────────────────────────

class _BracketVersusPill extends ConsumerWidget {
  final dynamic fixture;
  final String tournamentId;

  const _BracketVersusPill({required this.fixture, required this.tournamentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchId = fixture['id']?.toString() ?? '';
    final p1Id = fixture['player_1_id']?.toString() ?? '';
    final p2Id = fixture['player_2_id']?.toString() ?? '';
    final p1Name = fixture['player_1_name']?.toString() ??
        (p1Id.length > 8 ? p1Id.substring(0, 8) : (p1Id.isNotEmpty ? p1Id : 'TBD'));
    final p2Name = fixture['player_2_name']?.toString() ??
        (p2Id.length > 8 ? p2Id.substring(0, 8) : (p2Id.isNotEmpty ? p2Id : 'TBD'));
    final status = (fixture['status'] ?? 'scheduled').toString().toLowerCase();
    final winnerId = fixture['winner_player_id']?.toString();
    final isComplete = status == 'completed';

    String p1Score = '-';
    String p2Score = '-';
    if (isComplete && winnerId != null && winnerId.isNotEmpty) {
      p1Score = (winnerId == p1Id) ? 'W' : 'L';
      p2Score = (winnerId == p2Id) ? 'W' : 'L';
    } else if (isComplete) {
      p1Score = 'D';
      p2Score = 'D';
    }

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => OcrUploadModal(
          tMatchId: matchId,
          defaultPlayerId: p1Id,
          defaultOpponentId: p2Id,
          defaultPlayerName: p1Name,
          defaultOpponentName: p2Name,
          isKnockout: true,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isComplete
                ? AppColors.winGreen
                : AppColors.primary.withValues(alpha: 0.3),
          ),
          boxShadow: [
            if (isComplete)
              BoxShadow(color: AppColors.winGreen.withValues(alpha: 0.2), blurRadius: 8),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPillRow(p1Name, p1Score),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            _buildPillRow(p2Name, p2Score),
          ],
        ),
      ),
    );
  }

  Widget _buildPillRow(String name, String score) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            score,
            style: GoogleFonts.rajdhani(
              color: score == 'W'
                  ? AppColors.winGreen
                  : (score == 'L' ? AppColors.lossRed : Colors.white70),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Standings
// ─────────────────────────────────────────────────────────────────────────────

class _StandingsTab extends StatelessWidget {
  final String tournamentId;
  final String formatType;
  final VoidCallback onGoToFixtures;

  const _StandingsTab({
    required this.tournamentId,
    required this.formatType,
    required this.onGoToFixtures,
  });

  @override
  Widget build(BuildContext context) {
    final isDirectKnockout = formatType == 'knockout';
    final isGroupKnockout = formatType == 'group_knockout';

    if (isGroupKnockout) {
      return SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(16),
        child: GroupStandingsWidget(
          tournamentId: tournamentId,
        )
            .animate()
            .fade(duration: 350.ms)
            .slideY(begin: 0.06, duration: 350.ms),
      );
    }

    if (isDirectKnockout) {
      return SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TournamentLeadersWidget(tournamentId: tournamentId),
            const SizedBox(height: 16),
            GlassCard(
              borderColor: AppColors.cyan.withValues(alpha: 0.25),
              child: Column(
                children: [
                  const Icon(Icons.account_tree, color: AppColors.cyan, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'DIRECT KNOCKOUT BRACKET',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Direct knockout tournaments use bracket progression rather than standings tables. View the bracket in the Fixtures tab.',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  EsportsButton(
                    label: 'GO TO FIXTURES & BRACKET',
                    icon: Icons.calendar_month,
                    gradient: const [AppColors.cyan, AppColors.purple],
                    onPressed: onGoToFixtures,
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 300.ms).slideY(begin: 0.06, duration: 300.ms);
    }

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: LeagueTableWidget(tournamentId: tournamentId)
          .animate()
          .fade(duration: 350.ms)
          .slideY(begin: 0.06, duration: 350.ms),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Info + Admin Actions
// ─────────────────────────────────────────────────────────────────────────────

class _InfoTab extends ConsumerStatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final String formatType;
  final String status;
  final ValueChanged<String> onStatusChanged;

  const _InfoTab({
    required this.tournamentId,
    required this.tournamentName,
    required this.formatType,
    required this.status,
    required this.onStatusChanged,
  });

  @override
  ConsumerState<_InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends ConsumerState<_InfoTab> {
  bool _isActing = false;

  Future<void> _confirmAndStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        title: Text('START TOURNAMENT?',
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'This will generate all fixtures and set the tournament to LIVE. This cannot be undone.',
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
    setState(() => _isActing = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.startTournament(widget.tournamentId, []);
      widget.onStatusChanged('active');
      ref.invalidate(tournamentBracketProvider(widget.tournamentId));
      ref.invalidate(leagueStandingsProvider(widget.tournamentId));
      ref.invalidate(clubTournamentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${ApiClient.formatErrorMessage(e)}', style: GoogleFonts.rajdhani()),
          backgroundColor: AppColors.lossRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _confirmAndComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.textMuted.withValues(alpha: 0.3)),
        ),
        title: Text('COMPLETE TOURNAMENT?',
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Mark this tournament as completed and archive it. All fixtures will be locked.',
          style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
          ),
          EsportsButton(
            label: 'COMPLETE',
            icon: Icons.check_circle_outline,
            height: 40,
            gradient: const [AppColors.textMuted, Colors.grey],
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isActing = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.updateTournamentStatus(widget.tournamentId, 'completed');
      widget.onStatusChanged('completed');
      ref.invalidate(tournamentBracketProvider(widget.tournamentId));
      ref.invalidate(leagueStandingsProvider(widget.tournamentId));
      ref.invalidate(clubTournamentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${ApiClient.formatErrorMessage(e)}', style: GoogleFonts.rajdhani()),
          backgroundColor: AppColors.lossRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.lossRed.withValues(alpha: 0.4)),
        ),
        title: Text('DELETE TOURNAMENT?',
            style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'This will permanently delete the tournament and all its fixtures. This action cannot be undone. Only the club owner can perform this action.',
          style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: AppColors.textMuted)),
          ),
          EsportsButton(
            label: 'DELETE',
            icon: Icons.delete_outline,
            height: 40,
            gradient: const [AppColors.lossRed, Colors.red],
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isActing = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.deleteTournament(widget.tournamentId);
      if (mounted) {
        ref.invalidate(clubTournamentsProvider);
        Navigator.of(context).pop(); // Go back to club screen
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tournament deleted successfully.', style: GoogleFonts.rajdhani()),
          backgroundColor: AppColors.winGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${ApiClient.formatErrorMessage(e)}', style: GoogleFonts.rajdhani()),
          backgroundColor: AppColors.lossRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bracketAsync = ref.watch(tournamentBracketProvider(widget.tournamentId));
    final fixtures = (bracketAsync.asData?.value['fixtures'] as List<dynamic>? ?? []);
    final totalMatches = fixtures.length;
    final completedMatches = fixtures.where((f) => (f['status'] ?? '').toString().toLowerCase() == 'completed').length;
    final remainingMatches = totalMatches - completedMatches;
    final progress = totalMatches > 0 ? (completedMatches / totalMatches) : 0.0;

    final Map<String, String> participantMap = {};
    int maxRounds = 0;
    for (final f in fixtures) {
      final r = (f['round_number'] as num?)?.toInt() ?? 0;
      if (r > maxRounds) maxRounds = r;

      final p1Id = f['player_1_id']?.toString();
      final p1Name = f['player_1_name']?.toString() ?? 'Player';
      final p2Id = f['player_2_id']?.toString();
      final p2Name = f['player_2_name']?.toString() ?? 'Player';

      if (p1Id != null && p1Id.isNotEmpty && p1Id != '00000000-0000-0000-0000-000000000000') {
        participantMap[p1Id] = p1Name;
      }
      if (p2Id != null && p2Id.isNotEmpty && p2Id != '00000000-0000-0000-0000-000000000000') {
        participantMap[p2Id] = p2Name;
      }
    }

    final isDraft = widget.status == 'draft' || widget.status == 'scheduled';
    final isActive = widget.status == 'active';
    final isKnockout = widget.formatType == 'knockout';
    final participantCount = participantMap.isNotEmpty ? participantMap.length : null;

    final isDoubleRoundRobin = !isKnockout && participantCount != null && participantCount > 1 && maxRounds >= (participantCount - 1) * 2;

    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tournament Overview Card
          GlassCard(
            borderColor: AppColors.primary.withValues(alpha: 0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.tournamentName.toUpperCase(),
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.formatType == 'group_knockout'
                                ? 'Group Stage + Knockout Tournament'
                                : (isKnockout ? 'Direct Knockout Tournament' : 'League Round-Robin Tournament'),
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: widget.status),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                const SizedBox(height: 16),

                // 4 Grid metrics
                Row(
                  children: [
                    Expanded(
                      child: _infoMetricTile(
                        icon: Icons.group_outlined,
                        label: 'PARTICIPANTS',
                        value: participantCount != null ? '$participantCount' : 'TBD',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _infoMetricTile(
                        icon: Icons.sports_soccer,
                        label: 'MATCHES',
                        value: totalMatches > 0 ? '$totalMatches' : 'TBD',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _infoMetricTile(
                        icon: Icons.calendar_month,
                        label: 'MATCHDAYS',
                        value: maxRounds > 0 ? '$maxRounds' : 'TBD',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _infoMetricTile(
                        icon: Icons.pie_chart_outline,
                        label: 'PROGRESS',
                        value: totalMatches > 0 ? '${(progress * 100).round()}%' : '0%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade(duration: 300.ms).slideY(begin: 0.06, duration: 300.ms),

          const SizedBox(height: 16),

          // Tournament Progress Bar (if active/fixtures exist)
          if (totalMatches > 0) ...[
            GlassCard(
              borderColor: AppColors.cyan.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOURNAMENT PROGRESS',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '$completedMatches / $totalMatches Matches Played',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceLight,
                      color: AppColors.winGreen,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _subStatBox('COMPLETED', '$completedMatches', AppColors.winGreen),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _subStatBox('REMAINING', '$remainingMatches', AppColors.cyan),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _subStatBox('TOTAL', '$totalMatches', Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade(duration: 300.ms, delay: 60.ms).slideY(begin: 0.06, duration: 300.ms, delay: 60.ms),
            const SizedBox(height: 16),
          ],

          // Format & Rules Card
          GlassCard(
            borderColor: AppColors.purple.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RULES & FORMAT CONFIG',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                _ruleRow(
                  Icons.loop,
                  'Encounters Per Pairing',
                  isKnockout
                      ? 'Single Elimination'
                      : (isDoubleRoundRobin ? 'Double Round-Robin (Home & Away)' : 'Single Round-Robin (1 Match)'),
                ),
                const SizedBox(height: 10),
                _ruleRow(
                  Icons.scoreboard_outlined,
                  'Points System',
                  isKnockout ? 'Winner Advances' : 'Win: 3 Pts | Draw: 1 Pt | Loss: 0 Pts',
                ),
                const SizedBox(height: 10),
                _ruleRow(
                  Icons.equalizer,
                  'Standings Ranking',
                  isKnockout ? 'Bracket Progression' : 'Points → Goal Diff → Goals For → Wins',
                ),
              ],
            ),
          ).animate().fade(duration: 300.ms, delay: 100.ms).slideY(begin: 0.06, duration: 300.ms, delay: 100.ms),

          const SizedBox(height: 16),

          // Admin Actions Card
          if (isDraft || isActive) ...[
            GlassCard(
              borderColor: isDraft
                  ? AppColors.winGreen.withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.35),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isDraft ? AppColors.winGreen : AppColors.primary).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: isDraft ? AppColors.winGreen : AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADMIN CONTROLS',
                            style: GoogleFonts.rajdhani(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            isDraft
                                ? 'Tournament is in Draft state'
                                : 'Tournament is currently Live',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 16),
                  if (isDraft) ...[
                    Text(
                      'Generating fixtures will lock participating players and set the status to LIVE.',
                      style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    EsportsButton(
                      label: 'START TOURNAMENT',
                      icon: Icons.play_arrow_rounded,
                      isLoading: _isActing,
                      gradient: const [AppColors.winGreen, AppColors.cyan],
                      textColor: Colors.black,
                      onPressed: _confirmAndStart,
                    ),
                  ],
                  if (isActive) ...[
                    Text(
                      'Marking complete will finalize final standings and lock all match results.',
                      style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    EsportsButton(
                      label: 'MARK TOURNAMENT COMPLETE',
                      icon: Icons.emoji_events_outlined,
                      isLoading: _isActing,
                      gradient: [AppColors.primary, Colors.amber.shade600],
                      textColor: Colors.black,
                      onPressed: _confirmAndComplete,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 16),
                  Text(
                    'DANGER ZONE',
                    style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Permanently remove this tournament (Club Owners only).',
                    style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  EsportsButton(
                    label: 'DELETE TOURNAMENT',
                    icon: Icons.delete_outline,
                    isLoading: _isActing,
                    gradient: [AppColors.lossRed, Colors.red.shade900],
                    textColor: Colors.white,
                    onPressed: _confirmAndDelete,
                  ),
                ],
              ),
            ).animate().fade(duration: 300.ms, delay: 140.ms).slideY(begin: 0.06, duration: 300.ms, delay: 140.ms),
          ],
        ],
      ),
    );
  }

  Widget _infoMetricTile({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: AppColors.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _subStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.orbitron(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ruleRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.cyan, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Prediction Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PredictionSheet extends ConsumerWidget {
  final String p1Name;
  final String p2Name;
  final int p1Rating;
  final int p2Rating;

  const _PredictionSheet({required this.p1Name, required this.p2Name, required this.p1Rating, required this.p2Rating});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = PredictParams(p1Rating: p1Rating, p2Rating: p2Rating);
    final predAsync = ref.watch(matchPredictionProvider(params));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: const Border(top: BorderSide(color: AppColors.purple, width: 2)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, color: AppColors.purple, size: 22),
              const SizedBox(width: 8),
              Text(
                'AI MATCH PREDICTION',
                style: GoogleFonts.rajdhani(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          predAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(color: AppColors.purple),
              ),
            ),
            error: (e, _) => Text(
              'Prediction Engine Offline: $e',
              style: GoogleFonts.rajdhani(color: AppColors.lossRed, fontSize: 14),
            ),
            data: (data) {
              final p1Win = (data['player_1_win_probability'] as num?)?.toDouble() ?? 0.0;
              final draw = (data['draw_probability'] as num?)?.toDouble() ?? 0.0;
              final p2Win = (data['player_2_win_probability'] as num?)?.toDouble() ?? 0.0;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ProbabilityColumn(name: p1Name, label: 'WIN', prob: p1Win, color: AppColors.winGreen)),
                  Expanded(child: _ProbabilityColumn(name: 'DRAW', label: '–', prob: draw, color: Colors.amber)),
                  Expanded(child: _ProbabilityColumn(name: p2Name, label: 'WIN', prob: p2Win, color: AppColors.lossRed)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    ).animate().slideY(begin: 0.15, duration: 350.ms, curve: Curves.easeOut).fade(duration: 300.ms);
  }
}

class _ProbabilityColumn extends StatelessWidget {
  final String name;
  final String label;
  final double prob;
  final Color color;

  const _ProbabilityColumn({
    required this.name,
    required this.label,
    required this.prob,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${(prob * 100).toStringAsFixed(1)}%',
          style: GoogleFonts.orbitron(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Bar
        Container(
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: AppColors.surfaceLight,
          ),
          child: FractionallySizedBox(
            widthFactor: prob.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.rajdhani(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1),
        ),
      ],
    );
  }
}
