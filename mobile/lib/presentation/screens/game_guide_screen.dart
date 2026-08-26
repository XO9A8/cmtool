import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/guide_content.dart';
import '../providers/guide_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/guide_tip_card.dart';
import '../widgets/guide_onboarding_modal.dart';
import 'guide_article_screen.dart';

class GameGuideScreen extends ConsumerStatefulWidget {
  const GameGuideScreen({super.key});

  @override
  ConsumerState<GameGuideScreen> createState() => _GameGuideScreenState();
}

class _GameGuideScreenState extends ConsumerState<GameGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _onlyBookmarks = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final selectedDifficulty = ref.watch(selectedDifficultyFilterProvider);
    final readSet = ref.watch(readArticlesProvider);
    final bookmarkSet = ref.watch(bookmarkedArticlesProvider);
    final progressRatio = ref.watch(readProgressRatioProvider);
    final totalArticles = ref.watch(totalArticlesCountProvider);

    List<GuideArticle> articles = ref.watch(filteredArticlesProvider);
    if (_onlyBookmarks) {
      articles = articles.where((a) => bookmarkSet.contains(a.id)).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── 1. Hero & Search Header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.surface, AppColors.navy],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KNOWLEDGE HUB',
                            style: GoogleFonts.rajdhani(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cyan,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                AppColors.primary,
                                Colors.white,
                                AppColors.cyan,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds),
                            child: Text(
                              'GAME GUIDE',
                              style: GoogleFonts.orbitron(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.school_outlined,
                              color: AppColors.cyan,
                              size: 22,
                            ),
                            tooltip: 'Skill Level & Tour',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const GuideOnboardingModal(),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          // Progress badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.cyan.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(progressRatio * 100).toInt()}% READ',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.cyan,
                                  ),
                                ),
                                Text(
                                  '${readSet.length} / $totalArticles Lessons',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.cyan,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search input
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.rajdhani(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        ref.read(guideSearchQueryProvider.notifier).state = val;
                      },
                      decoration: InputDecoration(
                        hintText: 'Search skills, controls, formations, tactics...',
                        hintStyle: GoogleFonts.rajdhani(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.cyan,
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(guideSearchQueryProvider.notifier)
                                      .state = '';
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tip of the Day Card
                  const GuideTipCard(showDismiss: true),
                ],
              ),
            ),
          ),

          // ── 2. Category Selector (Horizontal Scroll) ──────────────────────
          SliverToBoxAdapter(
            child: Container(
              height: 44,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterPill(
                    label: 'All Categories',
                    isSelected: selectedCategory == null && !_onlyBookmarks,
                    onTap: () {
                      setState(() => _onlyBookmarks = false);
                      ref.read(selectedCategoryFilterProvider.notifier).state =
                          null;
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    label: '⭐ Bookmarked (${bookmarkSet.length})',
                    isSelected: _onlyBookmarks,
                    accentColor: AppColors.primary,
                    onTap: () {
                      setState(() => _onlyBookmarks = !_onlyBookmarks);
                    },
                  ),
                  const SizedBox(width: 8),
                  ...GuideData.categories.map((cat) {
                    final isSelected =
                        !_onlyBookmarks && selectedCategory == cat.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildFilterPill(
                        label: cat.title,
                        isSelected: isSelected,
                        accentColor: cat.accentColor,
                        onTap: () {
                          setState(() => _onlyBookmarks = false);
                          ref
                              .read(selectedCategoryFilterProvider.notifier)
                              .state = isSelected ? null : cat.id;
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── 3. Difficulty Filter Row ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'DIFFICULTY:',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildDifficultyChip(
                    label: 'All',
                    isSelected: selectedDifficulty == null,
                    onTap: () {
                      ref
                          .read(selectedDifficultyFilterProvider.notifier)
                          .state = null;
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDifficultyChip(
                    label: 'Beginner',
                    color: GuideDifficulty.beginner.color,
                    isSelected:
                        selectedDifficulty == GuideDifficulty.beginner,
                    onTap: () {
                      ref
                          .read(selectedDifficultyFilterProvider.notifier)
                          .state = selectedDifficulty ==
                              GuideDifficulty.beginner
                          ? null
                          : GuideDifficulty.beginner;
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDifficultyChip(
                    label: 'Intermediate',
                    color: GuideDifficulty.intermediate.color,
                    isSelected:
                        selectedDifficulty == GuideDifficulty.intermediate,
                    onTap: () {
                      ref
                          .read(selectedDifficultyFilterProvider.notifier)
                          .state = selectedDifficulty ==
                              GuideDifficulty.intermediate
                          ? null
                          : GuideDifficulty.intermediate;
                    },
                  ),
                  const SizedBox(width: 6),
                  _buildDifficultyChip(
                    label: 'Advanced',
                    color: GuideDifficulty.advanced.color,
                    isSelected:
                        selectedDifficulty == GuideDifficulty.advanced,
                    onTap: () {
                      ref
                          .read(selectedDifficultyFilterProvider.notifier)
                          .state = selectedDifficulty ==
                              GuideDifficulty.advanced
                          ? null
                          : GuideDifficulty.advanced;
                    },
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // ── 4. Articles List ──────────────────────────────────────────────
          if (articles.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No guide lessons match your search.',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final article = articles[index];
                    final isRead = readSet.contains(article.id);
                    final isBookmarked = bookmarkSet.contains(article.id);
                    final cat = GuideData.categories.firstWhere(
                      (c) => c.id == article.categoryId,
                      orElse: () => GuideData.categories.first,
                    );

                    return _buildArticleCard(
                      article: article,
                      category: cat,
                      isRead: isRead,
                      isBookmarked: isBookmarked,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                GuideArticleScreen(article: article),
                          ),
                        );
                      },
                      onBookmarkToggle: () {
                        ref
                            .read(bookmarkedArticlesProvider.notifier)
                            .toggleBookmark(article.id);
                      },
                    );
                  },
                  childCount: articles.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final color = accentColor ?? AppColors.cyan;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip({
    required String label,
    Color? color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final effectiveColor = color ?? Colors.white70;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? effectiveColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? effectiveColor : AppColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard({
    required GuideArticle article,
    required GuideCategory category,
    required bool isRead,
    required bool isBookmarked,
    required VoidCallback onTap,
    required VoidCallback onBookmarkToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? AppColors.winGreen.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  children: [
                    Icon(category.icon, size: 14, color: category.accentColor),
                    const SizedBox(width: 6),
                    Text(
                      category.title.toUpperCase(),
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: category.accentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    GlowBadge(
                      label: article.difficulty.label,
                      color: article.difficulty.color,
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onBookmarkToggle,
                      child: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                        color: isBookmarked ? AppColors.primary : Colors.white38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Article Title
                Text(
                  article.title,
                  style: GoogleFonts.orbitron(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),

                // Summary
                Text(
                  article.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),

                // Footer row
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${article.readTimeMinutes} min',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (isRead)
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 14,
                            color: AppColors.winGreen,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'COMPLETED',
                            style: GoogleFonts.rajdhani(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.winGreen,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Text(
                            'START LESSON',
                            style: GoogleFonts.rajdhani(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.cyan,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 10,
                            color: AppColors.cyan,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
