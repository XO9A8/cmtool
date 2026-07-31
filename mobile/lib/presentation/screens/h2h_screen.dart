import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';

/// Head-to-Head Rivalry Tracker screen showing live H2H stats between two players.
class H2hScreen extends ConsumerStatefulWidget {
  const H2hScreen({super.key});

  @override
  ConsumerState<H2hScreen> createState() => _H2hScreenState();
}

class _H2hScreenState extends ConsumerState<H2hScreen> {
  String? _selectedClubId;
  String? _p1Id;
  String? _p2Id;
  H2hParams? _currentParams;

  void _search() {
    if (_p1Id == null || _p2Id == null) return;
    setState(() {
      _currentParams = H2hParams(p1Id: _p1Id!, p2Id: _p2Id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final clubsAsync = ref.watch(myClubsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('H2H RIVALRY TRACKER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Club Selection
            clubsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
              error: (e, _) => Text('Error loading clubs: $e', style: const TextStyle(color: Colors.redAccent)),
              data: (data) {
                final clubs = data['clubs'] as List<dynamic>? ?? [];
                if (clubs.isEmpty) {
                  return const Text('Join a club first to track rivalries.', style: TextStyle(color: Colors.white54));
                }

                if (_selectedClubId == null && clubs.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() => _selectedClubId = clubs.first['id']);
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SELECT CLUB', style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: clubs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final club = clubs[i];
                          final isSelected = club['id'] == _selectedClubId;
                          return ChoiceChip(
                            label: Text(club['name'] ?? 'Club'),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedClubId = club['id'];
                                _p1Id = null;
                                _p2Id = null;
                                _currentParams = null;
                              });
                            },
                            backgroundColor: Colors.white10,
                            selectedColor: const Color(0xFFFF6D00),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Player Selection (dependent on selected club)
            if (_selectedClubId != null) ...[
              _buildPlayerSelectors(),
            ],

            const SizedBox(height: 20),
            if (_currentParams != null) _H2hResultWidget(params: _currentParams!),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSelectors() {
    final membersAsync = ref.watch(clubMembersProvider(_selectedClubId!));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
      error: (e, _) => Text('Error loading members: $e', style: const TextStyle(color: Colors.redAccent)),
      data: (data) {
        final members = data['members'] as List<dynamic>? ?? [];
        if (members.length < 2) {
          return const Text('Not enough members in this club to compare.', style: TextStyle(color: Colors.white54));
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _p1Id,
                dropdownColor: const Color(0xFF111111),
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Player 1',
                  labelStyle: const TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFFFF6D00)),
                ),
                items: members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['user_id'],
                    child: Text(m['username'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _p1Id = val),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _p2Id,
                dropdownColor: const Color(0xFF111111),
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Player 2',
                  labelStyle: const TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Colors.white),
                ),
                items: members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m['user_id'],
                    child: Text(m['username'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _p2Id = val),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_p1Id != null && _p2Id != null) ? _search : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('COMPARE STATS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ).animate().fade().slideY(begin: 0.05);
      },
    );
  }
}

class _H2hResultWidget extends ConsumerWidget {
  final H2hParams params;
  const _H2hResultWidget({required this.params});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncH2h = ref.watch(h2hProvider(params));

    return asyncH2h.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFFFF6D00)),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Failed to load H2H: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
      data: (data) {
        final total   = data['total_matches'] ?? 0;
        final p1Wins  = data['player_1_wins'] ?? 0;
        final draws   = data['draws'] ?? 0;
        final p2Wins  = data['player_2_wins'] ?? 0;
        final avgDiff = (data['avg_goal_diff'] as num?)?.toDouble() ?? 0.0;

        // Player names (fallback to UUID if not available in data)
        final p1Name = data['player_1_name'] ?? params.p1Id.substring(0, 8);
        final p2Name = data['player_2_name'] ?? params.p2Id.substring(0, 8);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1A1A2E), const Color(0xFF111111)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'HEAD-TO-HEAD HISTORY',
                    style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white60, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              p1Name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$p1Wins WINS',
                              style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFFF6D00),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$total MATCHES',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$draws DRAWS',
                              style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              p2Name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$p2Wins WINS',
                              style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (total > 0) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 12,
                        child: Row(
                          children: [
                            Expanded(
                              flex: p1Wins > 0 ? p1Wins : (total == 0 ? 1 : 0),
                              child: Container(color: p1Wins > 0 ? const Color(0xFFFF6D00) : Colors.transparent),
                            ),
                            Expanded(
                              flex: draws > 0 ? draws : (total == 0 ? 1 : 0),
                              child: Container(color: draws > 0 ? Colors.white24 : Colors.transparent),
                            ),
                            Expanded(
                              flex: p2Wins > 0 ? p2Wins : (total == 0 ? 1 : 0),
                              child: Container(color: p2Wins > 0 ? Colors.white : Colors.transparent),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sports_soccer, color: Colors.white38, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Avg Goal Difference: ${avgDiff > 0 ? '+' : ''}${avgDiff.toStringAsFixed(2)} goals',
                        style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: 0.1),
          ],
        );
      },
    );
  }
}
