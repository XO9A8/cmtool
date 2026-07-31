import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';
import '../widgets/league_table_widget.dart';

/// Tournament Control screen with CRUD, bracket view, league standings,
/// enrollment, and status management.
class TournamentScreen extends ConsumerStatefulWidget {
  const TournamentScreen({super.key});

  @override
  ConsumerState<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends ConsumerState<TournamentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedTournamentId;
  String? _selectedClubId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateTournamentDialog() {
    final nameCtrl = TextEditingController();
    String formatType = 'round_robin';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D0D12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: const Color(0xFFFF6D00).withOpacity(0.3)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6D00).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events, color: Color(0xFFFF6D00), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Create Tournament', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Tournament Name',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.title, color: Color(0xFFFF6D00)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: formatType,
                dropdownColor: const Color(0xFF111111),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Format',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.category, color: Color(0xFFFF6D00)),
                ),
                items: const [
                  DropdownMenuItem(value: 'round_robin', child: Text('Round-Robin League')),
                  DropdownMenuItem(value: 'knockout', child: Text('Knockout Bracket')),
                ],
                onChanged: (v) => setDialogState(() => formatType = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.bold)),
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
        title: const Text('TOURNAMENTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF6D00), size: 28),
            onPressed: _showCreateTournamentDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6D00),
          labelColor: const Color(0xFFFF6D00),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'League Table'),
            Tab(text: 'Brackets'),
            Tab(text: 'All Events'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTournamentDialog,
        backgroundColor: const Color(0xFFFF6D00),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.emoji_events),
        label: const Text('New Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 500.ms),
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
        error: (_, __) => _buildNoClubState(),
        data: (data) {
          final clubs = data['clubs'] as List<dynamic>? ?? [];
          if (clubs.isEmpty) return _buildNoClubState();

          // Auto-select club
          if (_selectedClubId == null && clubs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() => _selectedClubId = clubs.first['id']);
            });
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLeagueTableTab(),
              _buildBracketsTab(),
              _buildEventsTab(),
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
          const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('Join a club to manage tournaments', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildLeagueTableTab() {
    if (_selectedClubId == null) return _buildNoClubState();

    final tournamentsAsync = ref.watch(clubTournamentsProvider(_selectedClubId!));

    return tournamentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
      error: (_, __) => _buildEmptyTournaments(),
      data: (data) {
        final tournaments = data['tournaments'] as List<dynamic>? ?? [];
        final leagueTournaments = tournaments.where((t) =>
          t['format_type'] == 'round_robin' || t['format_type'] == 'league'
        ).toList();

        if (leagueTournaments.isEmpty) return _buildEmptyTournaments();

        // Auto-select first league tournament
        if (_selectedTournamentId == null && leagueTournaments.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedTournamentId = leagueTournaments.first['id']);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tournament selector
              if (leagueTournaments.length > 1) ...[
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: leagueTournaments.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final t = leagueTournaments[i];
                      final isSelected = t['id'] == _selectedTournamentId;
                      return ChoiceChip(
                        label: Text(t['name'] ?? 'Tournament'),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _selectedTournamentId = t['id']),
                        backgroundColor: Colors.white10,
                        selectedColor: const Color(0xFFFF6D00),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Tournament info header
              if (_selectedTournamentId != null) ...[
                _buildTournamentHeader(
                  leagueTournaments.firstWhere(
                    (t) => t['id'] == _selectedTournamentId,
                    orElse: () => leagueTournaments.first,
                  ),
                ),
                const SizedBox(height: 20),

                // The Premier League-style table
                const Text('LEAGUE STANDINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
                const SizedBox(height: 12),
                LeagueTableWidget(tournamentId: _selectedTournamentId!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTournamentHeader(dynamic tournament) {
    final status = tournament['status'] ?? 'draft';
    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = const Color(0xFF4CAF50);
        break;
      case 'completed':
        statusColor = Colors.amber;
        break;
      default:
        statusColor = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1A1A2E), statusColor.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: Color(0xFFFF6D00)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament['name'] ?? 'Tournament', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text(
                  '${(tournament['format_type'] ?? '').toString().replaceAll('_', ' ').toUpperCase()} • ${tournament['participant_count'] ?? 0} fixtures',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.4)),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    ).animate().fade();
  }

  Widget _buildBracketsTab() {
    if (_selectedClubId == null) return _buildNoClubState();

    final tournamentsAsync = ref.watch(clubTournamentsProvider(_selectedClubId!));

    return tournamentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
      error: (_, __) => _buildEmptyTournaments(),
      data: (data) {
        final tournaments = data['tournaments'] as List<dynamic>? ?? [];
        final knockoutTournaments = tournaments.where((t) => t['format_type'] == 'knockout').toList();

        if (knockoutTournaments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_tree_outlined, color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                const Text('No knockout tournaments yet', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), foregroundColor: Colors.black),
                  onPressed: _showCreateTournamentDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Knockout'),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: knockoutTournaments.map((t) {
              final tId = t['id'] as String;
              final bracketAsync = ref.watch(tournamentBracketProvider(tId));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTournamentHeader(t),
                  const SizedBox(height: 12),
                  bracketAsync.when(
                    loading: () => Container(
                      height: 100,
                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    ),
                    error: (_, __) => const Text('Could not load bracket', style: TextStyle(color: Colors.redAccent)),
                    data: (bData) {
                      final fixtures = bData['fixtures'] as List<dynamic>? ?? [];
                      if (fixtures.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No fixtures generated yet', style: TextStyle(color: Colors.white38)),
                        );
                      }
                      return Column(
                        children: fixtures.map((f) {
                          final p1 = f['player_1_id']?.toString().substring(0, 8) ?? 'TBD';
                          final p2 = f['player_2_id']?.toString().substring(0, 8) ?? 'TBD';
                          final round = f['round_number'] ?? 1;
                          return _buildBracketMatchTile(p1, p2, 'Round $round');
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEventsTab() {
    if (_selectedClubId == null) return _buildNoClubState();

    final tournamentsAsync = ref.watch(clubTournamentsProvider(_selectedClubId!));

    return tournamentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
      error: (_, __) => _buildEmptyTournaments(),
      data: (data) {
        final tournaments = data['tournaments'] as List<dynamic>? ?? [];
        if (tournaments.isEmpty) return _buildEmptyTournaments();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tournaments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final t = tournaments[i];
            return _buildTournamentCard(t);
          },
        );
      },
    );
  }

  Widget _buildTournamentCard(dynamic tournament) {
    final status = tournament['status'] ?? 'draft';
    final format = (tournament['format_type'] ?? '').toString().replaceAll('_', ' ');
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'active':
        statusColor = const Color(0xFF4CAF50);
        statusIcon = Icons.play_circle;
        break;
      case 'completed':
        statusColor = Colors.amber;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.white54;
        statusIcon = Icons.edit;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.emoji_events, color: statusColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament['name'] ?? 'Tournament', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(format.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white54, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    Text('${tournament['participant_count'] ?? 0} fixtures', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideX(begin: 0.05);
  }

  Widget _buildBracketMatchTile(String p1, String p2, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              const Text('VS', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(p2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            ],
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.1);
  }

  Widget _buildEmptyTournaments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          const Text('No tournaments yet', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), foregroundColor: Colors.black),
            onPressed: _showCreateTournamentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Tournament'),
          ),
        ],
      ),
    );
  }
}
