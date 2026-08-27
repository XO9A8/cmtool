import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../screens/player_profile_screen.dart';

/// Searchable Player Picker Bottom Sheet for selecting contenders in H2H Duel.
class PlayerPickerBottomSheet extends StatefulWidget {
  final String title;
  final Color themeColor;
  final List<dynamic> members;
  final String? selectedId;
  final String? otherSelectedId;
  final ValueChanged<String> onSelect;

  const PlayerPickerBottomSheet({
    super.key,
    required this.title,
    required this.themeColor,
    required this.members,
    required this.selectedId,
    required this.otherSelectedId,
    required this.onSelect,
  });

  @override
  State<PlayerPickerBottomSheet> createState() => _PlayerPickerBottomSheetState();
}

class _PlayerPickerBottomSheetState extends State<PlayerPickerBottomSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.members.where((m) {
      final username = (m['username'] ?? '').toString().toLowerCase();
      final playStyle = (m['play_style'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return username.contains(query) || playStyle.contains(query);
    }).toList();

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + (bottomInset > 0 ? bottomInset * 0.5 : 0),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
            color: widget.themeColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.themeColor,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${filteredMembers.length} PLAYERS',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.rajdhani(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search player name or play style...',
                hintStyle: TextStyle(color: AppColors.textDim, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                filled: true,
                fillColor: AppColors.isLight ? AppColors.surfaceLight : Colors.white.withValues(alpha: 0.04),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.themeColor),
                ),
              ),
            ),
          ),

          // Members List
          Expanded(
            child: filteredMembers.isEmpty
                ? Center(
                    child: Text(
                      'No matching players found.',
                      style: GoogleFonts.rajdhani(
                          color: AppColors.textMuted, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final m = filteredMembers[i] as Map<String, dynamic>;
                      final id = m['user_id']?.toString() ?? '';
                      final username = m['username']?.toString() ?? 'Player';
                      final elo = (m['skill_rating'] as num?)?.toInt() ?? 1000;
                      final form = (m['form_rating'] as num?)?.toInt() ?? 50;
                      final playStyle =
                          m['play_style']?.toString() ?? 'Balanced';
                      final avatarId = m['avatar_graphic']?.toString();
                      final isSelected = id == widget.selectedId;
                      final isOtherSelected = id == widget.otherSelectedId;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelect(id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? widget.themeColor.withValues(alpha: 0.15)
                                  : (isOtherSelected
                                      ? Colors.white.withValues(alpha: 0.02)
                                      : Colors.white.withValues(alpha: 0.04)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? widget.themeColor
                                    : (isOtherSelected
                                        ? Colors.white12
                                        : Colors.white.withValues(alpha: 0.06)),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isSelected
                                      ? widget.themeColor.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.08),
                                  child: Icon(
                                    getAvatarById(avatarId).icon,
                                    color: isSelected
                                        ? widget.themeColor
                                        : Colors.white70,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              username,
                                              style: GoogleFonts.rajdhani(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isOtherSelected) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: AppColors.amber
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'OTHER SLOT',
                                                style: GoogleFonts.rajdhani(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        playStyle,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: widget.themeColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '$elo ELO',
                                        style: GoogleFonts.orbitron(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: widget.themeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Form $form%',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white38),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
