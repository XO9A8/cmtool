import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/guide_content.dart';
import '../providers/guide_provider.dart';
import '../screens/game_guide_screen.dart';
import '../theme/app_theme.dart';

class GuideOnboardingModal extends ConsumerStatefulWidget {
  const GuideOnboardingModal({super.key});

  @override
  ConsumerState<GuideOnboardingModal> createState() =>
      _GuideOnboardingModalState();
}

class _GuideOnboardingModalState extends ConsumerState<GuideOnboardingModal> {
  GuideDifficulty _selectedDifficulty = GuideDifficulty.beginner;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.cyan.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.cyan),
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      color: AppColors.cyan,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MASTER THE PITCH',
                          style: GoogleFonts.rajdhani(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Select Your Level',
                          style: GoogleFonts.orbitron(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Text(
                'Customize your learning experience. We will curate the best tips and tactical breakdowns for your skill level.',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Level Cards
              _buildLevelCard(
                difficulty: GuideDifficulty.beginner,
                title: 'Rookie / Beginner',
                subtitle:
                    'Master classic touch controls, passing, Match-up defending, and team playstyles.',
                icon: Icons.shield_outlined,
              ),
              const SizedBox(height: 10),
              _buildLevelCard(
                difficulty: GuideDifficulty.intermediate,
                title: 'Competitor / Intermediate',
                subtitle:
                    'Learn Double Touch, Finesse Dribble, 4-2-2-2 meta formations, and weak foot synergy.',
                icon: Icons.flash_on_outlined,
              ),
              const SizedBox(height: 10),
              _buildLevelCard(
                difficulty: GuideDifficulty.advanced,
                title: 'Division Master / Advanced',
                subtitle:
                    'Fluid Formations, Overload tactics, booster stat thresholds, and high-press traps.',
                icon: Icons.military_tech_outlined,
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'DISMISS',
                        style: GoogleFonts.rajdhani(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: EsportsButton(
                      label: 'OPEN GUIDE',
                      icon: Icons.menu_book,
                      gradient: [
                        _selectedDifficulty.color,
                        AppColors.primary,
                      ],
                      textColor: Colors.black,
                      onPressed: () {
                        ref
                            .read(selectedDifficultyFilterProvider.notifier)
                            .state = _selectedDifficulty;
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GameGuideScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard({
    required GuideDifficulty difficulty,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = difficulty.color;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDifficulty = difficulty);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
