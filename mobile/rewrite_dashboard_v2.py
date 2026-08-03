import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# Locate _DashboardScreenState class in main.dart
target = r"class _DashboardScreenState extends ConsumerState<DashboardScreen> \{"

new_state = """class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _activeAiTipIndex = 0;
  final List<Map<String, String>> _aiTips = [
    {
      'title': 'TACTICAL ADVANTAGE',
      'body': 'Possession efficiency is up +14%. Recommend counter-attacking against Possession style setups.',
      'tag': 'POSSESSION',
    },
    {
      'title': 'DEFENSIVE ALERT',
      'body': 'Interceptions dropped by 8% vs 4-3-3 wide setups. Tighten double-pivot pressing in mid-block.',
      'tag': 'DEFENSE',
    },
    {
      'title': 'FINISHING FORM',
      'body': 'Box conversion rate is a lethal 72%! Maintain low-driven finishes inside 18 yards.',
      'tag': 'ATTACK',
    },
  ];

  final Map<String, bool> _questClaimed = {
    'q1': false,
    'q2': true,
    'q3': false,
  };

  final Map<String, int> _loungeReactions = {
    'thumbs': 14,
    'shield': 9,
    'fire': 21,
  };

  @override
  Widget build(BuildContext context) {
    final authUserId = ref.watch(authStateProvider);
    final myClubsAsync = ref.watch(myClubsProvider);
    final clubsList = myClubsAsync.asData?.value['clubs'] as List<dynamic>? ?? [];
    final clubId = clubsList.isNotEmpty ? clubsList.first['id'].toString() : '00000000-0000-0000-0000-000000000001';
    final userId = authUserId ?? '00000000-0000-0000-0000-000000000001';
    final analyticsAsync = ref.watch(analyticsProvider(userId));
    final leaderboardAsync = ref.watch(leaderboardProvider(clubId));

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(analyticsProvider(userId));
        ref.invalidate(leaderboardProvider(clubId));
        ref.invalidate(myClubsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Score Marquee Ticker
            _buildLiveScoreTicker(),
            const SizedBox(height: 16),

            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMANDER DASHBOARD',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Season 1 Match Center',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const GlowBadge(label: 'LIVE ONLINE', color: AppColors.winGreen, icon: Icons.sensors),
              ],
            ).animate().fade().slideX(begin: -0.1, end: 0),

            const SizedBox(height: 20),

            // Hero Player Card
            analyticsAsync.when(
              loading: () => const _SkeletonCard(),
              error: (_, __) => const _PlayerCardStub(),
              data: (data) => _PlayerStatsCard(data: data),
            ).animate().fade(duration: 400.ms).scale(begin: const Offset(0.95, 0.95)),

            const SizedBox(height: 20),

            // Live "Next Match Up" Interactive Hero Card
            _buildLiveNextMatchCard(context),

            const SizedBox(height: 20),

            // Interactive ELO Sparkline & Form Tracker Card
            _buildEloTrajectoryCard(),

            const SizedBox(height: 20),

            // Squad Chemistry & Readiness Gauge Widget
            _buildSquadReadinessCard(),

            const SizedBox(height: 20),

            // Quick Interactive Command Grid (4 Action Tiles)
            _buildInteractiveCommandGrid(context),

            const SizedBox(height: 24),

            // Instant H2H Challenge Launcher ("Call Out")
            _buildH2hChallengeWidget(),

            const SizedBox(height: 24),

            // Dual-Player Pending Confirmations & Official Action Center
            _buildPendingConfirmationsCard(context, ref),

            const SizedBox(height: 24),

            // Interactive AI Coaching Advice Cycler
            _buildInteractiveAiCoach(),

            const SizedBox(height: 24),

            // Club Lounge & Captain's Announcement Board
            _buildClubLoungeWidget(),

            const SizedBox(height: 24),

            // Season 1 Daily Goals & Operations Tracker
            _buildSeasonQuestsTracker(),

            const SizedBox(height: 28),

            // Activity Feed Section
            Text(
              'CLUB ACTIVITY FEED',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.cyan,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildActivityFeed(),

            const SizedBox(height: 28),

            // Club Leaderboard Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOP CLUB LEADERBOARD',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Tap player for H2H',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Leaderboard List (Interactive Tap for H2H)
            leaderboardAsync.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => Container(
                    height: 54,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              error: (err, _) => GlassCard(
                child: Text(
                  'Could not load leaderboard: ${ApiClient.formatErrorMessage(err)}',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (players) {
                if (players.isEmpty) {
                  return const GlassCard(
                    child: Center(
                      child: Text(
                        'No ranked players in this club yet.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  );
                }
                return Column(
                  children: players.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final p = entry.value;
                    final String pid = p['player_id']?.toString() ?? 'Player';
                    final String displayId = pid.length > 8 ? pid.substring(0, 8) : pid;

                    Color rankColor;
                    if (rank == 1) {
                      rankColor = const Color(0xFFFFD700); // Gold
                    } else if (rank == 2) {
                      rankColor = const Color(0xFFC0C0C0); // Silver
                    } else if (rank == 3) {
                      rankColor = const Color(0xFFCD7F32); // Bronze
                    } else {
                      rankColor = Colors.white70;
                    }

                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderColor: rank == 1 ? rankColor.withValues(alpha: 0.4) : null,
                      onTap: () {
                        _showPlayerH2hBottomSheet(context, displayId, p['skill_rating'] ?? 1000);
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: rank <= 3 ? rankColor.withValues(alpha: 0.15) : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: rankColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '#$rank',
                              style: GoogleFonts.rajdhani(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: rankColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Commander $displayId',
                                  style: GoogleFonts.rajdhani(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Matches: ${p['matches_played'] ?? 0}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          StatPill(
                            label: 'RATING',
                            value: '${p['skill_rating'] ?? 1000}',
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveScoreTicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.winGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: AppColors.winGreen, shape: BoxShape.circle),
            child: const Icon(Icons.sensors, color: Colors.black, size: 12),
          ),
          const SizedBox(width: 8),
          Text('LIVE TICKER', style: GoogleFonts.rajdhani(color: AppColors.winGreen, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '🔴 Commander Alex 3 - 1 Rival #42 (78\') • 🏆 Champions Cup Finals starts in 15 mins!',
              style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: -0.2);
  }

  Widget _buildEloTrajectoryCard() {
    final form = [
      {'res': 'W', 'score': '3-1', 'elo': '+24'},
      {'res': 'W', 'score': '2-0', 'elo': '+18'},
      {'res': 'L', 'score': '1-2', 'elo': '-14'},
      {'res': 'D', 'score': '2-2', 'elo': '+2'},
      {'res': 'W', 'score': '4-1', 'elo': '+31'},
    ];

    return GlassCard(
      borderColor: AppColors.cyan.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ELO TRAJECTORY & RECENT FORM', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.2)),
              Text('+61 ELO THIS WEEK', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.winGreen)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: form.map((f) {
              final isW = f['res'] == 'W';
              final isL = f['res'] == 'L';
              final col = isW ? AppColors.winGreen : (isL ? AppColors.lossRed : Colors.grey);

              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Match Result: ${f['score']} (${f['elo']} ELO)')),
                  );
                },
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: col.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(f['res']!, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: col)),
                      Text(f['elo']!, style: GoogleFonts.rajdhani(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSquadReadinessCard() {
    return GlassCard(
      borderColor: AppColors.winGreen.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: 0.94,
                  strokeWidth: 6,
                  color: AppColors.winGreen,
                  backgroundColor: Colors.white10,
                ),
              ),
              Text('94%', style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SQUAD OPERATIONAL READINESS', style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('✓ Cap limit verified (2850 / 2900 max)', style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.winGreen)),
                Text('✓ Roster active & verified', style: GoogleFonts.rajdhani(fontSize: 11, color: AppColors.winGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildH2hChallengeWidget() {
    final rivals = [
      {'name': 'Commander David', 'elo': '1420', 'status': 'ONLINE'},
      {'name': 'Commander Chris', 'elo': '1380', 'status': 'IN LOBBY'},
      {'name': 'Commander Mark', 'elo': '1290', 'status': 'ONLINE'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CHALLENGE ONLINE COMMANDERS', style: GoogleFonts.rajdhani(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: rivals.length,
            itemBuilder: (context, idx) {
              final r = rivals[idx];
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderColor: AppColors.cyan.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(r['name']!, style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          GlowBadge(label: r['elo']!, color: AppColors.primary),
                        ],
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.5)),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 24),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Issued 1v1 H2H Challenge to ${r['name']}!')),
                            );
                          },
                          child: Text('CHALLENGE 1v1', style: GoogleFonts.rajdhani(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClubLoungeWidget() {
    return GlassCard(
      borderColor: AppColors.purple.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.campaign, color: AppColors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text('CAPTAIN\'S ANNOUNCEMENT BOARD', style: GoogleFonts.rajdhani(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.purple, letterSpacing: 1.2)),
                ],
              ),
              GlowBadge(label: 'PINNED', color: AppColors.purple),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'President: "All commanders please ensure squad limits are verified before 19:00 UTC for the Cup Qualifiers!"',
            style: GoogleFonts.rajdhani(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _reactionBadge('👍', 'thumbs'),
              const SizedBox(width: 8),
              _reactionBadge('🛡️', 'shield'),
              const SizedBox(width: 8),
              _reactionBadge('🔥', 'fire'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reactionBadge(String emoji, String key) {
    final count = _loungeReactions[key] ?? 0;
    return GestureDetector(
      onTap: () {
        setState(() {
          _loungeReactions[key] = count + 1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('$count', style: GoogleFonts.rajdhani(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          ],
        ),
      ),
    );
  }"""

content = re.sub(target, new_state, content)

with open('lib/main.dart', 'w') as f:
    f.write(content)
print('Added all 5 tier-1 esports dashboard features!')
