import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/match_provider.dart';

/// Club Management screen with live data fetching, member management,
/// role controls, multi-club support, and club statistics.
class ClubsScreen extends ConsumerStatefulWidget {
  const ClubsScreen({super.key});

  @override
  ConsumerState<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends ConsumerState<ClubsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _clubNameCtrl   = TextEditingController();
  final _inviteCodeCtrl = TextEditingController();
  bool _creating = false;
  String? _createResult;
  bool _createError = false;

  final _joinCodeCtrl = TextEditingController();
  bool _joining = false;
  String? _joinResult;
  bool _joinError = false;

  String? _selectedClubId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clubNameCtrl.dispose();
    _inviteCodeCtrl.dispose();
    _joinCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (_clubNameCtrl.text.trim().isEmpty || _inviteCodeCtrl.text.trim().isEmpty) {
      setState(() { _createResult = 'Name & Invite Code required.'; _createError = true; });
      return;
    }
    setState(() { _creating = true; _createResult = null; });
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.createClub(_clubNameCtrl.text.trim(), _inviteCodeCtrl.text.trim());
      setState(() {
        _createResult = '✅ Club Created! ID: ${res['club_id']}';
        _createError = false;
      });
      // Refresh clubs list
      ref.invalidate(myClubsProvider);
    } catch (e) {
      setState(() { _createResult = 'Failed: $e'; _createError = true; });
    } finally {
      setState(() => _creating = false);
    }
  }

  Future<void> _joinClub() async {
    if (_joinCodeCtrl.text.trim().isEmpty) {
      setState(() { _joinResult = 'Invite code required.'; _joinError = true; });
      return;
    }
    setState(() { _joining = true; _joinResult = null; });
    try {
      final client = ref.read(apiClientProvider);
      await client.joinClub(_joinCodeCtrl.text.trim());
      setState(() {
        _joinResult = '✅ Successfully joined club!';
        _joinError = false;
      });
      // Refresh clubs list
      ref.invalidate(myClubsProvider);
    } catch (e) {
      setState(() { _joinResult = 'Failed: $e'; _joinError = true; });
    } finally {
      setState(() => _joining = false);
    }
  }

  void _showRoleDialog(String clubId, String playerId, String currentRole) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Role', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['admin', 'organizer', 'player'].map((role) {
            return ListTile(
              leading: Icon(
                role == 'admin' ? Icons.star : (role == 'organizer' ? Icons.engineering : Icons.person),
                color: currentRole == role ? const Color(0xFFFF6D00) : Colors.white54,
              ),
              title: Text(role.toUpperCase(), style: TextStyle(
                color: currentRole == role ? const Color(0xFFFF6D00) : Colors.white,
                fontWeight: currentRole == role ? FontWeight.bold : FontWeight.normal,
              )),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final client = ref.read(apiClientProvider);
                  await client.updateMemberRole(clubId, playerId, role);
                  ref.invalidate(clubMembersProvider(clubId));
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update role: $e')),
                    );
                  }
                }
              },
            );
          }).toList(),
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
        title: const Text('CLUB MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6D00),
          labelColor: const Color(0xFFFF6D00),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'My Clubs'),
            Tab(text: 'Create'),
            Tab(text: 'Join'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyClubsTab(clubsAsync),
          _buildCreateClubTab(),
          _buildJoinClubTab(),
        ],
      ),
    );
  }

  Widget _buildMyClubsTab(AsyncValue<Map<String, dynamic>> clubsAsync) {
    return clubsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFFF6D00))),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            const Text('No clubs yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), foregroundColor: Colors.black),
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Create Your First Club'),
            ),
          ],
        ),
      ),
      data: (data) {
        final clubs = data['clubs'] as List<dynamic>? ?? [];
        if (clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white24, size: 64),
                const SizedBox(height: 16),
                const Text('No clubs yet', style: TextStyle(color: Colors.white54, fontSize: 16)),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00), foregroundColor: Colors.black),
                  onPressed: () => _tabController.animateTo(1),
                  child: const Text('Create Your First Club'),
                ),
              ],
            ),
          );
        }

        // Auto-select first club if none selected
        if (_selectedClubId == null && clubs.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() => _selectedClubId = clubs.first['id']);
          });
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Club selector chips
              if (clubs.length > 1) ...[
                const Text('YOUR CLUBS', style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 2)),
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
                        onSelected: (_) => setState(() => _selectedClubId = club['id']),
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
                const SizedBox(height: 20),
              ],

              // Active club detail
              if (_selectedClubId != null) ...[
                _buildClubDetail(
                  clubs.firstWhere((c) => c['id'] == _selectedClubId, orElse: () => clubs.first),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildClubDetail(dynamic club) {
    final clubId = club['id'] as String;
    final membersAsync = ref.watch(clubMembersProvider(clubId));
    final isOwner = club['is_owner'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Club banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1A1A2E), const Color(0xFFFF6D00).withOpacity(0.12)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF6D00).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6D00).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Color(0xFFFF6D00), size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          club['name'] ?? 'Club',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.vpn_key, color: Color(0xFFFF6D00), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              club['invite_code'] ?? '',
                              style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOwner ? Colors.amber.withOpacity(0.2) : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isOwner ? Colors.amber.withOpacity(0.4) : Colors.white24),
                        ),
                        child: Text(
                          isOwner ? 'OWNER' : 'MEMBER',
                          style: TextStyle(color: isOwner ? Colors.amber : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${club['member_count'] ?? 0} members',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ).animate().fade().slideY(begin: 0.1),

        const SizedBox(height: 24),
        const Text('ROSTER & ROLES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 2)),
        const SizedBox(height: 12),

        // Members list
        membersAsync.when(
          loading: () => Column(
            children: List.generate(3, (_) => Container(
              height: 64,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            )),
          ),
          error: (e, _) => Text('Could not load members: $e', style: const TextStyle(color: Colors.redAccent)),
          data: (data) {
            final members = data['members'] as List<dynamic>? ?? [];
            if (members.isEmpty) return const Text('No members', style: TextStyle(color: Colors.white38));
            return Column(
              children: members.map((m) => _buildMemberTile(
                clubId: clubId,
                userId: m['user_id'] ?? '',
                name: m['username'] ?? 'Unknown',
                elo: '${m['skill_rating'] ?? 1000} Elo',
                role: m['role'] ?? 'player',
                playStyle: m['play_style'] ?? 'Unclassified',
                matchesPlayed: m['matches_played'] ?? 0,
                isAdmin: isOwner,
              )).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMemberTile({
    required String clubId,
    required String userId,
    required String name,
    required String elo,
    required String role,
    required String playStyle,
    required int matchesPlayed,
    required bool isAdmin,
  }) {
    Color roleColor;
    switch (role) {
      case 'admin':
        roleColor = Colors.amber;
        break;
      case 'organizer':
        roleColor = const Color(0xFFFF6D00);
        break;
      default:
        roleColor = Colors.white38;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: roleColor.withOpacity(0.15),
            child: Icon(Icons.person, size: 20, color: roleColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Row(
                  children: [
                    Text(elo, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('• $playStyle', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    const SizedBox(width: 8),
                    Text('• $matchesPlayed MP', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            GestureDetector(
              onTap: () => _showRoleDialog(clubId, userId, role),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: roleColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 12, color: roleColor),
                  ],
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: roleColor.withOpacity(0.4)),
              ),
              child: Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateClubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(0xFFFF6D00).withOpacity(0.3), const Color(0xFFFF6D00).withOpacity(0.1)],
              ),
            ),
            child: const Icon(Icons.add_business, color: Color(0xFFFF6D00), size: 40),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _clubNameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Club Name', Icons.shield_outlined),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inviteCodeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Invite Code (e.g. MYCLUB12)', Icons.vpn_key_outlined),
          ),
          if (_createResult != null) ...[
            const SizedBox(height: 16),
            Text(_createResult!, style: TextStyle(color: _createError ? Colors.redAccent : const Color(0xFFFF6D00))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _creating ? null : _createClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6D00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add),
              label: Text(_creating ? 'CREATING...' : 'CREATE CLUB', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinClubTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              ),
            ),
            child: const Icon(Icons.group_add, color: Colors.white70, size: 40),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _joinCodeCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('Enter Invite Code', Icons.group_add_outlined),
          ),
          if (_joinResult != null) ...[
            const SizedBox(height: 16),
            Text(_joinResult!, style: TextStyle(color: _joinError ? Colors.redAccent : const Color(0xFFFF6D00))),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _joining ? null : _joinClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.login),
              label: Text(_joining ? 'JOINING...' : 'JOIN CLUB', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: const Color(0xFFFF6D00)),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    );
  }
}
