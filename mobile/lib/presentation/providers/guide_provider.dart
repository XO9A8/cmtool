import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/guide_content.dart';

// Keys for SharedPreferences
const _kReadArticlesKey = 'guide_read_articles';
const _kBookmarksKey = 'guide_bookmarked_articles';
const _kDismissedTipsKey = 'guide_dismissed_tips';

// ── Search & Filter State ───────────────────────────────────────────────────

final guideSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);
final selectedDifficultyFilterProvider = StateProvider<GuideDifficulty?>((ref) => null);

// ── Read Progress StateNotifier ─────────────────────────────────────────────

class ReadArticlesNotifier extends StateNotifier<Set<String>> {
  ReadArticlesNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kReadArticlesKey) ?? [];
    state = list.toSet();
  }

  Future<void> toggleRead(String articleId) async {
    final updated = Set<String>.from(state);
    if (updated.contains(articleId)) {
      updated.remove(articleId);
    } else {
      updated.add(articleId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kReadArticlesKey, updated.toList());
  }

  bool isRead(String articleId) => state.contains(articleId);
}

final readArticlesProvider =
    StateNotifierProvider<ReadArticlesNotifier, Set<String>>((ref) {
  return ReadArticlesNotifier();
});

// ── Bookmarks StateNotifier ─────────────────────────────────────────────────

class BookmarksNotifier extends StateNotifier<Set<String>> {
  BookmarksNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kBookmarksKey) ?? [];
    state = list.toSet();
  }

  Future<void> toggleBookmark(String articleId) async {
    final updated = Set<String>.from(state);
    if (updated.contains(articleId)) {
      updated.remove(articleId);
    } else {
      updated.add(articleId);
    }
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kBookmarksKey, updated.toList());
  }

  bool isBookmarked(String articleId) => state.contains(articleId);
}

final bookmarkedArticlesProvider =
    StateNotifierProvider<BookmarksNotifier, Set<String>>((ref) {
  return BookmarksNotifier();
});

// ── Dismissed Tips StateNotifier ────────────────────────────────────────────

class DismissedTipsNotifier extends StateNotifier<Set<String>> {
  DismissedTipsNotifier() : super({}) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kDismissedTipsKey) ?? [];
    state = list.toSet();
  }

  Future<void> dismissTip(String tipId) async {
    final updated = Set<String>.from(state);
    updated.add(tipId);
    state = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDismissedTipsKey, updated.toList());
  }

  Future<void> resetDismissed() async {
    state = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDismissedTipsKey);
  }
}

final dismissedTipsProvider =
    StateNotifierProvider<DismissedTipsNotifier, Set<String>>((ref) {
  return DismissedTipsNotifier();
});

// ── Derived Providers ───────────────────────────────────────────────────────

final totalArticlesCountProvider = Provider<int>((ref) {
  int count = 0;
  for (final cat in GuideData.categories) {
    count += cat.articles.length;
  }
  return count;
});

final readProgressRatioProvider = Provider<double>((ref) {
  final readSet = ref.watch(readArticlesProvider);
  final total = ref.watch(totalArticlesCountProvider);
  if (total == 0) return 0.0;
  return (readSet.length / total).clamp(0.0, 1.0);
});

final filteredArticlesProvider = Provider<List<GuideArticle>>((ref) {
  final query = ref.watch(guideSearchQueryProvider);
  final categoryId = ref.watch(selectedCategoryFilterProvider);
  final difficulty = ref.watch(selectedDifficultyFilterProvider);

  List<GuideArticle> list;
  if (query.trim().isNotEmpty) {
    list = GuideData.searchArticles(query);
  } else {
    list = GuideData.categories.expand((c) => c.articles).toList();
  }

  if (categoryId != null) {
    list = list.where((a) => a.categoryId == categoryId).toList();
  }

  if (difficulty != null) {
    list = list.where((a) => a.difficulty == difficulty).toList();
  }

  return list;
});

final bookmarkedArticlesListProvider = Provider<List<GuideArticle>>((ref) {
  final bookmarkedSet = ref.watch(bookmarkedArticlesProvider);
  final allArticles = GuideData.categories.expand((c) => c.articles).toList();
  return allArticles.where((a) => bookmarkedSet.contains(a.id)).toList();
});

final activeDailyTipProvider = Provider<GuideTip?>((ref) {
  final dismissed = ref.watch(dismissedTipsProvider);
  final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
  const tips = GuideData.dailyTips;

  if (tips.isEmpty) return null;

  // Cycle through tips based on day of year, skipping dismissed ones if possible
  for (int i = 0; i < tips.length; i++) {
    final idx = (dayOfYear + i) % tips.length;
    final tip = tips[idx];
    if (!dismissed.contains(tip.id)) {
      return tip;
    }
  }

  // If all dismissed, return the standard daily tip
  return tips[dayOfYear % tips.length];
});
