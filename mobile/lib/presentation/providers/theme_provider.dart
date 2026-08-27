import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeType>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeType> {
  ThemeNotifier() : super(AppThemeType.classic) {
    _loadTheme();
  }

  bool get isClassic => state == AppThemeType.classic;
  bool get isDaylight => state == AppThemeType.daylight;
  bool get isLight => state == AppThemeType.daylight;

  // Backward compatibility getters
  bool get isPremium => false;
  bool get isPitchDominance => false;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('app_theme_type');
    if (savedTheme == 'daylight') {
      state = AppThemeType.daylight;
    } else {
      state = AppThemeType.classic;
    }
    AppTheme.currentColors = AppTheme.getColors(state);
  }

  Future<void> setTheme(AppThemeType themeType) async {
    state = themeType;
    AppTheme.currentColors = AppTheme.getColors(themeType);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme_type', themeType.name);
  }

  Future<void> toggleTheme(bool isLight) async {
    await setTheme(isLight ? AppThemeType.daylight : AppThemeType.classic);
  }
}
