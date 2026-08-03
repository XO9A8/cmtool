import re

with open('lib/presentation/screens/tournament_screen.dart', 'r') as f:
    content = f.read()

tree_pattern = r"  Widget _buildBracketTreeView\(List<dynamic> fixtures\) \{.*?(?=  Widget _buildEmptyTournaments)"

new_tree = """  Widget _buildBracketTreeView(List<dynamic> fixtures) {
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

    bool isComplete = status == 'completed';

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
            _buildPillRow(p1Name, isComplete ? (f['player_1_score']?.toString() ?? 'W') : '-'),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
            _buildPillRow(p2Name, isComplete ? (f['player_2_score']?.toString() ?? 'L') : '-'),
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

"""

content = re.sub(tree_pattern, new_tree, content, flags=re.DOTALL)

with open('lib/presentation/screens/tournament_screen.dart', 'w') as f:
    f.write(content)
print('Redesigned Tree View for real this time!')
