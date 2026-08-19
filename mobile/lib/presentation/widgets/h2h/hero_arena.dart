import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../screens/player_profile_screen.dart';

/// Hero Face-Off Duel Arena for H2H rivalry comparison.
class HeroArena extends StatelessWidget {
  final List<dynamic> members;
  final Map<String, dynamic>? p1Member;
  final Map<String, dynamic>? p2Member;
  final String? p1Id;
  final String? p2Id;
  final bool isReadyToDuel;
  final bool isAnalyzing;
  final VoidCallback onRandomDuel;
  final VoidCallback onPickPlayer1;
  final VoidCallback onPickPlayer2;
  final VoidCallback onClearPlayer1;
  final VoidCallback onClearPlayer2;
  final VoidCallback onSwapPlayers;
  final VoidCallback onAnalyze;

  const HeroArena({
    super.key,
    required this.members,
    required this.p1Member,
    required this.p2Member,
    required this.p1Id,
    required this.p2Id,
    required this.isReadyToDuel,
    required this.isAnalyzing,
    required this.onRandomDuel,
    required this.onPickPlayer1,
    required this.onPickPlayer2,
    required this.onClearPlayer1,
    required this.onClearPlayer2,
    required this.onSwapPlayers,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF161824).withValues(alpha: 0.95),
            const Color(0xFF0C0E17).withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isReadyToDuel
              ? AppColors.primary.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isReadyToDuel
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Top Stage Status Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReadyToDuel
                            ? AppColors.winGreen
                            : AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: (isReadyToDuel
                                    ? AppColors.winGreen
                                    : AppColors.primary)
                                .withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isReadyToDuel
                          ? 'DUEL READY'
                          : (p1Id != null || p2Id != null
                              ? 'SELECT OPPONENT'
                              : 'CHOOSE CONTENDERS'),
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color:
                            isReadyToDuel ? AppColors.winGreen : Colors.white70,
                      ),
                    ),
                  ],
                ),
                // Random Duel Button
                InkWell(
                  onTap: onRandomDuel,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.casino_outlined,
                            size: 14, color: AppColors.cyan),
                        const SizedBox(width: 4),
                        Text(
                          'RANDOM DUEL',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Face-off Row: Challenger 1 vs Challenger 2
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Challenger 1 Slot (Orange)
                Expanded(
                  child: _buildChallengerCard(
                    title: 'CHALLENGER 1',
                    member: p1Member,
                    themeColor: AppColors.primary,
                    onTap: onPickPlayer1,
                    onClear: onClearPlayer1,
                  ),
                ),

                // Center VS & Swap Action
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.25),
                              AppColors.cyan.withValues(alpha: 0.25),
                            ],
                          ),
                          border: Border.all(
                            color:
                                isReadyToDuel ? Colors.white30 : Colors.white12,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isReadyToDuel
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          'VS',
                          style: GoogleFonts.orbitron(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      IconButton(
                        onPressed: (p1Id != null || p2Id != null)
                            ? onSwapPlayers
                            : null,
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        color: (p1Id != null || p2Id != null)
                            ? Colors.white70
                            : Colors.white24,
                        tooltip: 'Swap Challengers',
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                ),

                // Challenger 2 Slot (Cyan)
                Expanded(
                  child: _buildChallengerCard(
                    title: 'CHALLENGER 2',
                    member: p2Member,
                    themeColor: AppColors.cyan,
                    onTap: onPickPlayer2,
                    onClear: onClearPlayer2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Analyze CTA Button
            SizedBox(
              width: double.infinity,
              child: EsportsButton(
                label: isAnalyzing ? 'UPDATE ANALYSIS' : 'ANALYZE RIVALRY',
                icon: Icons.flash_on,
                gradient: isReadyToDuel
                    ? const [AppColors.primary, AppColors.cyan]
                    : [Colors.white24, Colors.white12],
                textColor: isReadyToDuel ? Colors.black : Colors.white38,
                onPressed: isReadyToDuel ? onAnalyze : null,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  Widget _buildChallengerCard({
    required String title,
    required Map<String, dynamic>? member,
    required Color themeColor,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasPlayer = member != null;
    final username = member?['username']?.toString() ?? 'Select Player';
    final elo = (member?['skill_rating'] as num?)?.toInt() ?? 1000;
    final playStyle = member?['play_style']?.toString() ?? 'Balanced';
    final avatarId = member?['avatar_graphic']?.toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasPlayer
                ? themeColor.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasPlayer
                  ? themeColor.withValues(alpha: 0.5)
                  : Colors.white12,
              width: hasPlayer ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: themeColor,
                ),
              ),
              const SizedBox(height: 10),

              // Avatar Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPlayer
                          ? LinearGradient(
                              colors: [
                                themeColor.withValues(alpha: 0.4),
                                themeColor.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      color: hasPlayer
                          ? null
                          : Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                        color: hasPlayer ? themeColor : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      hasPlayer
                          ? getAvatarById(avatarId).icon
                          : Icons.person_add_alt_1,
                      color: hasPlayer ? themeColor : Colors.white38,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Username
              Text(
                username,
                style: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: hasPlayer ? Colors.white : Colors.white54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // Rating / Action prompt
              if (hasPlayer) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: themeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$elo ELO',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  playStyle,
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else ...[
                Text(
                  'Tap to pick',
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    color: Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
