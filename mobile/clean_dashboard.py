import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# Remove _buildH2hChallengeWidget call and Top Club Leaderboard section from DashboardScreen column
h2h_call_pattern = r"\s*// Instant H2H Challenge Launcher \(\"Call Out\"\)\n\s*_buildH2hChallengeWidget\(\),\n\s*const SizedBox\(height: 24\),"
content = re.sub(h2h_call_pattern, "", content)

leaderboard_section_pattern = r"\s*// Club Leaderboard Header\n\s*Row\(.*?\),\n\s*const SizedBox\(height: 12\),\n\s*// Leaderboard List \(Interactive Tap for H2H\)\n\s*leaderboardAsync\.when\(.*?\n\s*\),"
content = re.sub(leaderboard_section_pattern, "", content, flags=re.DOTALL)

# Also remove _buildH2hChallengeWidget implementation method if present
h2h_method_pattern = r"\s*Widget _buildH2hChallengeWidget\(\) \{.*?\n  \}"
content = re.sub(h2h_method_pattern, "", content, flags=re.DOTALL)

with open('lib/main.dart', 'w') as f:
    f.write(content)
print('Cleaned DashboardScreen in main.dart!')
