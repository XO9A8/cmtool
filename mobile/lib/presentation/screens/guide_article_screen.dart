import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/guide_content.dart';
import '../providers/guide_provider.dart';
import '../theme/app_theme.dart';

class GuideArticleScreen extends ConsumerWidget {
  final GuideArticle article;

  const GuideArticleScreen({
    super.key,
    required this.article,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRead = ref.watch(readArticlesProvider).contains(article.id);
    final isBookmarked =
        ref.watch(bookmarkedArticlesProvider).contains(article.id);

    final category = GuideData.categories.firstWhere(
      (c) => c.id == article.categoryId,
      orElse: () => GuideData.categories.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          category.title.toUpperCase(),
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: category.accentColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: isBookmarked ? 'Remove Bookmark' : 'Bookmark Article',
            onPressed: () {
              ref
                  .read(bookmarkedArticlesProvider.notifier)
                  .toggleBookmark(article.id);
            },
          ),
          IconButton(
            icon: Icon(Icons.share_outlined, color: AppColors.textSecondary),
            tooltip: 'Share Guide',
            onPressed: () {
              SharePlus.instance.share(
                ShareParams(
                  text:
                      'eFootball Mobile Guide: ${article.title}\n\n${article.summary}',
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: category.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GlowBadge(
                        label: article.difficulty.label,
                        color: article.difficulty.color,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${article.readTimeMinutes} min read',
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.winGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.winGreen.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 12,
                                color: AppColors.winGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'COMPLETED',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.winGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: GoogleFonts.orbitron(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.summary,
                    style: GoogleFonts.rajdhani(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: article.tags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              '#$tag',
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                color: AppColors.cyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Key Takeaways if available
            if (article.keyTakeaways.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bolt,
                          color: AppColors.cyan,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'KEY PRO TAKEAWAYS',
                          style: GoogleFonts.rajdhani(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.cyan,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...article.keyTakeaways.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2, right: 4),
                              child: Icon(
                                Icons.arrow_right,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: GoogleFonts.rajdhani(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Markdown Content
            MarkdownBody(
              data: article.markdownContent,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                h2: GoogleFonts.orbitron(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyan,
                ),
                h3: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                p: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
                listBullet: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyan,
                ),
                tableHead: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                tableBody: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                tableBorder: TableBorder.all(
                  color: AppColors.cardBorder,
                  width: 1,
                  borderRadius: BorderRadius.circular(8),
                ),
                tableCellsPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                code: GoogleFonts.firaCode(
                  fontSize: 13,
                  color: AppColors.cyan,
                  backgroundColor: AppColors.surfaceLight,
                ),
                codeblockDecoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                blockquoteDecoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: AppColors.cyan, width: 4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Mark as Complete Action Button
            Center(
              child: EsportsButton(
                label: isRead ? 'MARK AS UNREAD' : 'COMPLETE LESSON',
                icon: isRead ? Icons.undo : Icons.check_circle,
                gradient: isRead
                    ? [Colors.grey.shade800, Colors.grey.shade700]
                    : [AppColors.winGreen, const Color(0xFF00B0FF)],
                textColor: isRead ? Colors.white70 : Colors.black,
                onPressed: () {
                  ref
                      .read(readArticlesProvider.notifier)
                      .toggleRead(article.id);
                },
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
