import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../providers/match_provider.dart';
import '../widgets/league_table_widget.dart';
import '../widgets/ocr_upload_modal.dart';

/// Tournament Control screen with CRUD, bracket view, league standings,
/// squad compliance warning banner, and direct fixture score reporting.
class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> with SingleTickerProviderStateMixin {
  String? _selectedTournamentId;
  String? _selectedClubId;
  bool _squadVerified = false; // Simulated squad check state for active tournament
  bool _isBracketListView = true; // Responsive bracket layout switcher (List View vs Tree View)
  
  // Tier 2 Active Details
  dynamic _activeTournamentDetails;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showCreateTournamentDialog() {
    final nameCtrl = TextEditingController();
    String formatType = 'round_robin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'CREATE TOURNAMENT',
                style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Tournament Name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.title, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: formatType,
                dropdownColor: AppColors.surface,
                style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'Format Type',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.category, color: AppColors.cyan),
                ),
                items: const [
                  DropdownMenuItem(value: 'round_robin', child: Text('Round-Robin League')),
                  DropdownMenuItem(value: 'knockout', child: Text('Knockout Bracket Tree')),
                ],
                onChanged: (v) => setDialogState(() => formatType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('CANCEL', style: GoogleFonts.rajdhani(color: Colors.white54, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('CREATE', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                if (_selectedClubId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join or create a club first')),
                  );
                  return;
                }
                try {
                  final client = ref.read(apiClientProvider);
                  final result = await client.createTournament(
                    clubId: _selectedClubId!,
                    name: nameCtrl.text.isEmpty ? 'Club Cup' : nameCtrl.text,
                    formatType: formatType,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ Tournament "${result['name']}" created!')),
                    );
                    if (_selectedClubId != null) {
                      ref.invalidate(clubTournamentsProvider(_selectedClubId!));
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to create tournament: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _activeTournamentDetails == null ? 'TOURNAMENT HUB' : (_activeTournamentDetails['name'] ?? 'EVENT DETAILS').toString().toUpperCase(), 
          style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, letterSpacing: 1.5)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _activeTournamentDetails != null 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => setState(() => _activeTournamentDetails = null),
              )
            : null,
        actions: [
          if (_activeTournamentDetails == null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
              onPressed: _showCreateTournamentDialog,
            ),
        ],
      ),
      floatingActionButton: _activeTournamentDetails == null ? FloatingActionButton.extended(
        onPressed: _showCreateTournamentDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.emoji_events),
        label: Text('NEW TOURNAMENT', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 400.ms) : null,
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => _buildNoClubState(),
        data: (data) {
          final clubs = data['clubs'] as List<dynamic>? ?? [];
          if (clubs.isEmpty) return _buildNoClubState();

          if (_selectedClubId == null && clubs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _selectedClubId = clubs.first['id']);
            });
          }

          return Column(
            children: [
              Expanded(
                child: _activeTournamentDetails == null
                    ? _buildHubDashboard()
                    : _buildTournamentDetailsView(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoClubState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text(
            'JOIN A CLUB TO PARTICIPATE IN TOURNAMENTS',
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHubDashboard() {
    if (_selectedClubId == null) return _buildNoClubState();

    final tournamentsAsync = ref.watch(clubTournamentsProvider(_selectedClubId!));

    return tournamentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (_, __) => _buildEmptyTournaments(),
      data: (data) {
        final tournaments = data['tournaments'] as List<dynamic>? ?? [];
        if (tournaments.isEmpty) return _buildEmptyTournaments();

        final active = tournaments.where((t) => t['status'] == 'active').toList();
        final upcoming = tournaments.where((t) => t['status'] == 'scheduled' || t['status'] == 'draft').toList();
        final completed = tournaments.where((t) => t['status'] == 'completed').toList();

        final heroTournament = active.isNotEmpty ? active.first : (upcoming.isNotEmpty ? upcoming.first : tournaments.first);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FEATURED EVENT', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _buildHeroCard(heroTournament),
              
              if (active.length > 1 || upcoming.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text('LIVE & UPCOMING', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                _buildHorizontalList([...active.where((t) => t['id'] != heroTournament['id']), ...upcoming.where((t) => t['id'] != heroTournament['id'])]),
              ],

              if (completed.isNotEmpty) ...[
                const SizedBox(height: 32),
                Text('PAST CHAMPIONS', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                _buildHorizontalList(completed),
              ],
              
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(dynamic tournament) {
    final format = (tournament['format_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase();
    final status = (tournament['status'] ?? 'draft').toString().toUpperCase();
    
    return GlassCard(
      borderColor: AppColors.primary.withValues(alpha: 0.5),
      padding: EdgeInsets.zero,
      onTap: () => setState(() => _activeTournamentDetails = tournament),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(Icons.emoji_events, size: 120, color: AppColors.primary.withValues(alpha: 0.1)),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GlowBadge(label: status, color: AppColors.winGreen, icon: Icons.play_circle),
                      const SizedBox(height: 8),
                      Text(
                        tournament['name'] ?? 'Tournament',
                        style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              border: Border(top: BorderSide(color: AppColors.primary.withValues(alpha: 0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FORMAT', style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    Text(format, style: GoogleFonts.rajdhani(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('MATCHES', style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                    Text('${tournament['participant_count'] ?? 0}', style: GoogleFonts.rajdhani(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildHorizontalList(List<dynamic> tournaments) {
    if (tournaments.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tournaments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) => _buildEventCard(tournaments[i]),
      ),
    );
  }

  Widget _buildEventCard(dynamic tournament) {
    final status = tournament['status'] ?? 'draft';
    final format = (tournament['format_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase();
    Color statusColor = status == 'completed' ? Colors.amber : (status == 'active' ? AppColors.winGreen : AppColors.textMuted);

    return SizedBox(
      width: 220,
      child: GlassCard(
        borderColor: statusColor.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      onTap: () => setState(() => _activeTournamentDetails = tournament),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.emoji_events, color: statusColor, size: 20),
              ),
              GlowBadge(label: status.toString().toUpperCase(), color: statusColor),
            ],
          ),
          const Spacer(),
          Text(
            tournament['name'] ?? 'Tournament',
            style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$format • ${tournament['participant_count'] ?? 0} FIXTURES',
            style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    )).animate().fade().slideX(begin: 0.05);
  }

  Widget _buildTournamentDetailsView() {
    if (_activeTournamentDetails == null) return const SizedBox.shrink();
    
    final tId = _activeTournamentDetails!['id']?.toString() ?? '';
    final formatType = _activeTournamentDetails!['format_type']?.toString();
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTournamentHeader(_activeTournamentDetails!),
          const SizedBox(height: 24),
          
          if (formatType == 'knockout') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'BRACKET VIEW MODE',
                  style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.2),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('List'), icon: Icon(Icons.list, size: 14)),
                    ButtonSegment(value: false, label: Text('Tree'), icon: Icon(Icons.account_tree, size: 14)),
                  ],
                  selected: {_isBracketListView},
                  onSelectionChanged: (set) => setState(() => _isBracketListView = set.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    selectedBackgroundColor: AppColors.primary,
                    selectedForegroundColor: Colors.black,
                    foregroundColor: Colors.white70,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ref.watch(tournamentBracketProvider(tId)).when(
              loading: () => Container(height: 100, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12))),
              error: (_, __) => const Text('Error loading bracket', style: TextStyle(color: Colors.redAccent)),
              data: (bData) {
                final fixtures = bData['fixtures'] as List<dynamic>? ?? [];
                if (fixtures.isEmpty) return const GlassCard(child: Padding(padding: EdgeInsets.all(16), child: Text('No bracket fixtures generated yet', style: TextStyle(color: AppColors.textMuted))));
                return _isBracketListView ? _buildBracketListView(fixtures) : _buildBracketTreeView(fixtures);
              },
            ),
          ] else ...[
            Text(
              'LEAGUE STANDINGS & GOAL DIFF',
              style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            LeagueTableWidget(tournamentId: tId),
            _buildLeagueFixturesSection(tId),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildTournamentHeader(dynamic tournament) {
    final status = tournament['status'] ?? 'draft';
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.winGreen;
        break;
      case 'completed':
        statusColor = Colors.amber;
        break;
      default:
        statusColor = AppColors.textMuted;
    }

    return GlassCard(
      borderColor: statusColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament['name'] ?? 'Tournament',
                  style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
                Text(
                  '${(tournament['format_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase()} • ${tournament['participant_count'] ?? 0} FIXTURES',
                  style: GoogleFonts.rajdhani(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          GlowBadge(label: status.toString(), color: statusColor),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildLeagueFixturesSection(String tournamentId) {
    final bracketAsync = ref.watch(tournamentBracketProvider(tournamentId));

    return bracketAsync.when(
      loading: () => Container(
        height: 80,
        margin: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (bData) {
        final fixtures = bData['fixtures'] as List<dynamic>? ?? [];
        if (fixtures.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MATCH FIXTURES & SCHEDULE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                    letterSpacing: 1.5,
                  ),
                ),
                GlowBadge(
                  label: '${fixtures.length} MATCHES',
                  color: AppColors.cyan,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBracketListView(fixtures),
          ],
        );
      },
    );
  }

  Widget _buildBracketMatchTile(String matchId, String p1, String p2, String label, String opponentUuid) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      borderColor: AppColors.primary.withValues(alpha: 0.2),
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => OcrUploadModal(
            tMatchId: matchId,
            defaultOpponentId: opponentUuid,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.1))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.rajdhani(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.psychology, size: 14, color: AppColors.purple),
                      label: Text('PREDICT', style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.purple, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        _showPredictionModal(context, p1, p2);
                      },
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.upload_file, size: 14, color: AppColors.cyan),
                    const SizedBox(width: 4),
                    Text('REPORT', style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.cyan, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          
          // Matchup
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(p1.isNotEmpty ? p1[0].toUpperCase() : '?', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Text(p1, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlowBadge(
                    label: 'VS',
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.cyan.withValues(alpha: 0.1),
                        child: Text(p2.isNotEmpty ? p2[0].toUpperCase() : '?', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Text(p2, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), textAlign: TextAlign.left, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildBracketListView(List<dynamic> fixtures) {
    return Column(
      children: fixtures.map((f) {
        final p1Id = f['player_1_id']?.toString() ?? '';
        final p2Id = f['player_2_id']?.toString() ?? '';
        final p1 = f['player_1_name']?.toString() ?? (p1Id.length > 8 ? p1Id.substring(0, 8) : (p1Id.isNotEmpty ? p1Id : 'TBD'));
        final p2 = f['player_2_name']?.toString() ?? (p2Id.length > 8 ? p2Id.substring(0, 8) : (p2Id.isNotEmpty ? p2Id : 'TBD'));
        final matchId = f['id']?.toString() ?? '';
        final round = f['round_number'] ?? 1;
        return _buildBracketMatchTile(matchId, p1, p2, 'ROUND $round MATCH', p2Id);
      }).toList(),
    );
  }

  Widget _buildBracketTreeView(List<dynamic> fixtures) {
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
      // Recursively find midpoint of feeder matches
      double topY = getNodeY(roundIdx - 1, matchIdx * 2);
      double bottomY = getNodeY(roundIdx - 1, matchIdx * 2 + 1);
      return (topY + bottomY) / 2;
    }

    double getNodeX(int roundIdx) {
      return roundIdx * (nodeWidth + hSpace);
    }

    List<Widget> stackChildren = [];

    // 1. Draw Connecting Lines via CustomPainter
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

    // 2. Draw Match Nodes
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
            child: _buildVersusPill(match),
          ),
        );
      }
    }

    return Container(
      height: 400, // Fixed height for interactive viewer
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

  Widget _buildVersusPill(dynamic f) {
    final matchId = f['id']?.toString() ?? '';
    final p1Id = f['player_1_id']?.toString() ?? '';
    final p2Id = f['player_2_id']?.toString() ?? '';
    final p1Name = f['player_1_name']?.toString() ?? (p1Id.length > 8 ? p1Id.substring(0, 8) : (p1Id.isNotEmpty ? p1Id : 'TBD'));
    final p2Name = f['player_2_name']?.toString() ?? (p2Id.length > 8 ? p2Id.substring(0, 8) : (p2Id.isNotEmpty ? p2Id : 'TBD'));
    final status = (f['status'] ?? 'scheduled').toString().toLowerCase();
    final winnerId = f['winner_player_id']?.toString();

    bool isComplete = status == 'completed';
    // Determine W/L based on the actual winner from the API
    String p1Score = '-';
    String p2Score = '-';
    if (isComplete && winnerId != null && winnerId.isNotEmpty) {
      p1Score = (winnerId == p1Id) ? 'W' : 'L';
      p2Score = (winnerId == p2Id) ? 'W' : 'L';
    } else if (isComplete) {
      // Fallback if winner_player_id is not available (e.g., seeded data without link)
      p1Score = 'W';
      p2Score = 'L';
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => OcrUploadModal(tMatchId: matchId, defaultOpponentId: p2Id),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isComplete ? AppColors.winGreen : AppColors.primary.withValues(alpha: 0.3)),
          boxShadow: [
            if (isComplete) BoxShadow(color: AppColors.winGreen.withValues(alpha: 0.2), blurRadius: 8),
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
              style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            score,
            style: GoogleFonts.rajdhani(color: score == 'W' ? AppColors.winGreen : (score == 'L' ? AppColors.lossRed : Colors.white70), fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTournaments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text('NO TOURNAMENTS CREATED YET', style: GoogleFonts.rajdhani(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          EsportsButton(
            label: 'CREATE FIRST TOURNAMENT',
            icon: Icons.add,
            onPressed: _showCreateTournamentDialog,
          ),
        ],
      ),
    );
  }

  void _showPredictionModal(BuildContext context, String p1Id, String p2Id) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.purple, width: 2)),
        ),
        padding: const EdgeInsets.all(24),
        child: Consumer(
          builder: (context, ref, child) {
            // Using placeholder baseline ratings of 1200 as we don't have the player ratings directly in the bracket node
            final predictionAsync = ref.watch(matchPredictionProvider(const PredictParams(p1Rating: 1200, p2Rating: 1200)));
            return predictionAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.purple)),
              error: (e, _) => Text('Prediction Engine Offline: $e', style: const TextStyle(color: Colors.red)),
              data: (data) {
                final p1Win = (data['player_1_win_probability'] ?? 0.0) as double;
                final draw = (data['draw_probability'] ?? 0.0) as double;
                final p2Win = (data['player_2_win_probability'] ?? 0.0) as double;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.psychology, color: AppColors.purple),
                        const SizedBox(width: 8),
                        Text('AI MATCH PREDICTION', style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildProbabilityBar(p1Id, 'WIN', p1Win, AppColors.winGreen)),
                        Expanded(child: _buildProbabilityBar('DRAW', '-', draw, Colors.amber)),
                        Expanded(child: _buildProbabilityBar(p2Id, 'WIN', p2Win, AppColors.lossRed)),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              }
            );
          }
        )
      )
    );
  }

  Widget _buildProbabilityBar(String label, String sub, double prob, Color color) {
    return Column(
      children: [
        Text('${(prob * 100).toStringAsFixed(1)}%', style: GoogleFonts.rajdhani(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }
}

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
        // Only draw if there's a pair to merge
        if (mIdx + 1 >= matchesInThisRound) continue;

        double topY = getNodeY(rIdx, mIdx) + (nodeHeight / 2);
        double bottomY = getNodeY(rIdx, mIdx + 1) + (nodeHeight / 2);
        double startX = getNodeX(rIdx) + nodeWidth;
        
        double midX = startX + (hSpace / 2);
        double nextX = getNodeX(rIdx + 1);
        double nextY = getNodeY(rIdx + 1, mIdx ~/ 2) + (nodeHeight / 2);

        // Path: Right from top node to mid, down to nextY, right to next node
        final path = Path();
        
        // Top node line
        path.moveTo(startX, topY);
        path.lineTo(midX, topY);
        path.lineTo(midX, nextY);
        path.lineTo(nextX, nextY);

        // Bottom node line
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
