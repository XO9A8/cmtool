import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(true) {
    _loadTheme();
  }

  // true = Premium, false = Legacy
  bool get isPremium => state;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool('is_premium_theme') ?? true;
    state = isPremium;
    AppTheme.currentColors = isPremium ? AppThemeExtension.premium() : AppThemeExtension.legacy();
  }

  Future<void> toggleTheme(bool isPremium) async {
    state = isPremium;
    AppTheme.currentColors = isPremium ? AppThemeExtension.premium() : AppThemeExtension.legacy();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium_theme', isPremium);
  }
}
