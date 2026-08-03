import re

with open('lib/presentation/screens/tournament_screen.dart', 'r') as f:
    content = f.read()

old_tile = r"  Widget _buildBracketMatchTile\(String matchId, String p1, String p2, String label, String opponentUuid\) \{.*?\)\.animate\(\)\.fade\(\)\.slideY\(begin: 0\.1\);\n  \}"

new_tile = """  Widget _buildBracketMatchTile(String matchId, String p1, String p2, String label, String opponentUuid) {
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
  }"""

content = re.sub(old_tile, new_tile, content, flags=re.DOTALL)

with open('lib/presentation/screens/tournament_screen.dart', 'w') as f:
    f.write(content)
print('Redesigned Match Tile!')
