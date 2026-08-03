import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../widgets/league_table_widget.dart';
import '../widgets/ocr_upload_modal.dart';

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

  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.formatType,
    required this.status,
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

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
  }

  bool get _isKnockout => widget.formatType == 'knockout';

  void _refresh() {
    ref.invalidate(tournamentBracketProvider(widget.tournamentId));
    ref.invalidate(leagueStandingsProvider(widget.tournamentId));
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
              destinations: [
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
                      label: isKnockout ? 'KNOCKOUT' : 'ROUND ROBIN',
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

class _FixturesTab extends ConsumerWidget {
  final String tournamentId;
  final String formatType;
  final int fixtureView;
  final ValueChanged<int> onToggleView;

  const _FixturesTab({
    required this.tournamentId,
    required this.formatType,
    required this.fixtureView,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bracketAsync = ref.watch(tournamentBracketProvider(tournamentId));
    final isKnockout = formatType == 'knockout';

    return bracketAsync.when(
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(e.toString()),
      data: (data) {
        final fixtures = (data['fixtures'] as List<dynamic>? ?? []);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // For round_robin: league table at top
              if (!isKnockout) ...[
                LeagueTableWidget(tournamentId: tournamentId)
                    .animate()
                    .fade(duration: 350.ms)
                    .slideY(begin: 0.06, duration: 350.ms),
                const SizedBox(height: 20),
              ],

              // For knockout: view toggle
              if (isKnockout) ...[
                _buildViewToggle(),
                const SizedBox(height: 16),
              ],

              if (fixtures.isEmpty)
                _buildEmptyFixtures()
              else if (isKnockout && fixtureView == 1)
                _buildBracketTreeView(context, fixtures)
              else
                _buildFixtureList(context, fixtures),
            ],
          ),
        );
      },
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
        selected: {fixtureView},
        onSelectionChanged: (s) => onToggleView(s.first),
      ),
    );
  }

  Widget _buildFixtureList(BuildContext context, List<dynamic> fixtures) {
    final sorted = [...fixtures]..sort((a, b) {
        final rA = (a['round_number'] as num?)?.toInt() ?? 0;
        final rB = (b['round_number'] as num?)?.toInt() ?? 0;
        return rA.compareTo(rB);
      });

    return Column(
      children: sorted.asMap().entries.map((e) {
        return _MatchFixtureTile(
          fixture: e.value,
          tournamentId: tournamentId,
          delay: e.key * 60,
        ).animate().fade(duration: 300.ms, delay: Duration(milliseconds: e.key * 60)).slideY(begin: 0.06, duration: 300.ms, delay: Duration(milliseconds: e.key * 60));
      }).toList(),
    );
  }

  Widget _buildBracketTreeView(BuildContext context, List<dynamic> fixtures) {
    if (fixtures.isEmpty) return const SizedBox.shrink();

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
            child: _BracketVersusPill(fixture: match, tournamentId: tournamentId),
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

  const _MatchFixtureTile({
    required this.fixture,
    required this.tournamentId,
    required this.delay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchId = fixture['id']?.toString() ?? '';
    final p1Id = fixture['player_1_id']?.toString() ?? '';
    final p2Id = fixture['player_2_id']?.toString() ?? '';
    final p1Name = fixture['player_1_name']?.toString() ??
        (p1Id.length > 8 ? p1Id.substring(0, 8) : (p1Id.isNotEmpty ? p1Id : 'TBD'));
    final p2Name = fixture['player_2_name']?.toString() ??
        (p2Id.length > 8 ? p2Id.substring(0, 8) : (p2Id.isNotEmpty ? p2Id : 'TBD'));
    final round = (fixture['round_number'] as num?)?.toInt() ?? 1;
    final status = (fixture['status'] ?? 'scheduled').toString().toLowerCase();
    final winnerId = fixture['winner_player_id']?.toString();
    final isCompleted = status == 'completed';

    final p1IsWinner = isCompleted && winnerId != null && winnerId == p1Id;
    final p2IsWinner = isCompleted && winnerId != null && winnerId == p2Id;

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
                Text(
                  'ROUND $round MATCH',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.4,
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(width: 8),
                  GlowBadge(label: 'COMPLETED', color: AppColors.winGreen),
                ],
                const Spacer(),
                // Predict button
                _IconActionButton(
                  icon: Icons.psychology,
                  label: 'PREDICT',
                  color: AppColors.purple,
                  onTap: () => _showPredictionSheet(context, p1Name, p2Name),
                ),
                const SizedBox(width: 6),
                // Report button
                _IconActionButton(
                  icon: Icons.upload_file,
                  label: 'REPORT',
                  color: AppColors.cyan,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => OcrUploadModal(
                      tMatchId: matchId,
                      defaultOpponentId: p2Id,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),

          // Players body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: isCompleted
                ? _buildResultRow(p1Name, p2Name, p1IsWinner, p2IsWinner, winnerId == null)
                : _buildVsRow(p1Name, p2Name),
          ),
        ],
      ),
    );
  }

  Widget _buildVsRow(String p1Name, String p2Name) {
    return Row(
      children: [
        Expanded(child: _PlayerColumn(name: p1Name, highlight: false)),
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
        Expanded(child: _PlayerColumn(name: p2Name, highlight: false, rightAlign: true)),
      ],
    );
  }

  Widget _buildResultRow(String p1Name, String p2Name, bool p1Won, bool p2Won, bool isDraw) {
    Color p1Color = isDraw ? Colors.amber : (p1Won ? AppColors.winGreen : AppColors.lossRed);
    Color p2Color = isDraw ? Colors.amber : (p2Won ? AppColors.winGreen : AppColors.lossRed);
    String p1Result = isDraw ? 'D' : (p1Won ? 'W' : 'L');
    String p2Result = isDraw ? 'D' : (p2Won ? 'W' : 'L');

    return Row(
      children: [
        Expanded(child: _PlayerColumn(name: p1Name, highlight: p1Won, color: p1Color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              Text(
                '$p1Result – $p2Result',
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
        Expanded(child: _PlayerColumn(name: p2Name, highlight: p2Won, color: p2Color, rightAlign: true)),
      ],
    );
  }

  void _showPredictionSheet(BuildContext context, String p1Name, String p2Name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PredictionSheet(p1Name: p1Name, p2Name: p2Name),
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  final String name;
  final bool highlight;
  final Color? color;
  final bool rightAlign;

  const _PlayerColumn({
    required this.name,
    required this.highlight,
    this.color,
    this.rightAlign = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Colors.white;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return Column(
      crossAxisAlignment: rightAlign ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (!rightAlign) ...[
          CircleAvatar(
            radius: 18,
            backgroundColor: (highlight ? displayColor : AppColors.primary).withValues(alpha: 0.2),
            child: Text(
              initials,
              style: GoogleFonts.orbitron(
                color: highlight ? displayColor : AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
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
        if (rightAlign) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: (highlight ? displayColor : AppColors.purple).withValues(alpha: 0.2),
              child: Text(
                initials,
                style: GoogleFonts.orbitron(
                  color: highlight ? displayColor : AppColors.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
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
      p1Score = 'W';
      p2Score = 'L';
    }

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => OcrUploadModal(tMatchId: matchId, defaultOpponentId: p2Id),
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
    final isKnockout = formatType == 'knockout';

    if (isKnockout) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GlassCard(
              borderColor: AppColors.cyan.withValues(alpha: 0.25),
              child: Column(
                children: [
                  Icon(Icons.account_tree, color: AppColors.cyan, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'BRACKET FORMAT',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Knockout tournaments use bracket progression rather than standings. View the bracket in the Fixtures tab.',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textMuted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  EsportsButton(
                    label: 'GO TO FIXTURES',
                    icon: Icons.calendar_month,
                    gradient: [AppColors.cyan, AppColors.purple],
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.rajdhani()),
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
            gradient: [AppColors.textMuted, Colors.grey],
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
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e', style: GoogleFonts.rajdhani()),
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
    final participantCount = bracketAsync.asData?.value['fixtures'] != null
        ? _countParticipants(bracketAsync.asData!.value['fixtures'] as List<dynamic>)
        : null;
    final isDraft = widget.status == 'draft' || widget.status == 'scheduled';
    final isActive = widget.status == 'active';
    final isKnockout = widget.formatType == 'knockout';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metadata card
          GlassCard(
            borderColor: AppColors.primary.withValues(alpha: 0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaRow(Icons.emoji_events, 'Tournament', widget.tournamentName),
                const SizedBox(height: 12),
                _metaRow(
                  isKnockout ? Icons.account_tree : Icons.swap_horiz,
                  'Format',
                  isKnockout ? 'Knockout Bracket' : 'Round Robin League',
                ),
                const SizedBox(height: 12),
                _metaRow(Icons.flag, 'Status', widget.status.toUpperCase()),
                if (participantCount != null) ...[
                  const SizedBox(height: 12),
                  _metaRow(Icons.group, 'Participants', '$participantCount players'),
                ],
              ],
            ),
          ).animate().fade(duration: 300.ms).slideY(begin: 0.06, duration: 300.ms),

          const SizedBox(height: 20),

          // Admin actions
          if (isDraft || isActive) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'ADMIN ACTIONS',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            if (isDraft)
              EsportsButton(
                label: 'START TOURNAMENT',
                icon: Icons.play_arrow,
                isLoading: _isActing,
                gradient: [AppColors.winGreen, AppColors.cyan],
                textColor: Colors.black,
                onPressed: _confirmAndStart,
              ).animate().fade(duration: 300.ms, delay: 80.ms).slideY(begin: 0.06, duration: 300.ms, delay: 80.ms),
            if (isActive) ...[
              const SizedBox(height: 8),
              EsportsButton(
                label: 'COMPLETE TOURNAMENT',
                icon: Icons.check_circle_outline,
                isLoading: _isActing,
                gradient: [AppColors.textMuted, Colors.grey.shade700],
                textColor: Colors.white,
                onPressed: _confirmAndComplete,
              ).animate().fade(duration: 300.ms, delay: 160.ms).slideY(begin: 0.06, duration: 300.ms, delay: 160.ms),
            ],
          ],
        ],
      ),
    );
  }

  int _countParticipants(List<dynamic> fixtures) {
    final ids = <String>{};
    for (final f in fixtures) {
      final p1 = f['player_1_id']?.toString();
      final p2 = f['player_2_id']?.toString();
      if (p1 != null && p1.isNotEmpty) ids.add(p1);
      if (p2 != null && p2.isNotEmpty) ids.add(p2);
    }
    return ids.length;
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.rajdhani(
                color: AppColors.textMuted,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.rajdhani(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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

  const _PredictionSheet({required this.p1Name, required this.p2Name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const params = PredictParams(p1Rating: 1200, p2Rating: 1200);
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
