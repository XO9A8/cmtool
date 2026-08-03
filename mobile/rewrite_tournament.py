import re

with open('lib/presentation/screens/tournament_screen.dart', 'r') as f:
    content = f.read()

# 1. Replace State variables, initState, dispose
state_vars_pattern = r"class _TournamentScreenState extends ConsumerState<TournamentScreen> with SingleTickerProviderStateMixin \{.*?\n\s+void _showCreateTournamentDialog\(\)"
new_state_vars = """class _TournamentScreenState extends ConsumerState<TournamentScreen> with SingleTickerProviderStateMixin {
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

  void _showCreateTournamentDialog()"""
content = re.sub(state_vars_pattern, new_state_vars, content, flags=re.DOTALL)

# 2. Replace build method
build_pattern = r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  Widget _buildNoClubState\(\)"
new_build = """  @override
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
              if (!_squadVerified)
                Container(
                  width: double.infinity,
                  color: Colors.amber.withValues(alpha: 0.18),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pre-Match Squad Strength Verification Pending (Max 2900). You can proceed, but results may be reviewed by admins.',
                          style: GoogleFonts.rajdhani(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        child: Text('VERIFY', style: GoogleFonts.rajdhani(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TournamentLobbyScreen()),
                          );
                          if (mounted) setState(() => _squadVerified = true);
                        },
                      ),
                    ],
                  ),
                ),
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

  Widget _buildNoClubState()"""
content = re.sub(build_pattern, new_build, content, flags=re.DOTALL)

# 3. Replace old Tabs with Hub methods
tabs_pattern = r"  Widget _buildLeagueTableTab\(\) \{.*?\n  Widget _buildBracketMatchTile\("
new_hub_methods = """  Widget _buildHubDashboard() {
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

    return GlassCard(
      width: 220,
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
    ).animate().fade().slideX(begin: 0.05);
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

  Widget _buildBracketMatchTile("""
content = re.sub(tabs_pattern, new_hub_methods, content, flags=re.DOTALL)

with open('lib/presentation/screens/tournament_screen.dart', 'w') as f:
    f.write(content)
print('Rewrite successful!')
