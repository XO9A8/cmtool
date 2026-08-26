import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final Color navy;
  final Color surface;
  final Color surfaceLight;
  final Color primary;
  final Color cyan;
  final Color gold;
  final Color offWhite;
  final Color paper;
  final Color paperDark;
  final Color winGreen;
  final Color lossRed;
  final Color amber;
  final Color background;
  final Color textMuted;

  const AppThemeExtension({
    required this.navy,
    required this.surface,
    required this.surfaceLight,
    required this.primary,
    required this.cyan,
    required this.gold,
    required this.offWhite,
    required this.paper,
    required this.paperDark,
    required this.winGreen,
    required this.lossRed,
    required this.amber,
    required this.background,
    required this.textMuted,
  });

  factory AppThemeExtension.premium() {
    return const AppThemeExtension(
      navy: Color(0xFF0A1628),
      surface: Color(0xFF0F1B33),
      surfaceLight: Color(0xFF162040),
      primary: Color(0xFFD90429), // Scarlet
      cyan: Color(0xFFC9A84C), // Gold accent
      gold: Color(0xFFC9A84C),
      offWhite: Color(0xFFF5F3EE),
      paper: Color(0xFFF5F3EE),
      paperDark: Color(0xFFD9D4C8),
      winGreen: Color(0xFF1B7A3E),
      lossRed: Color(0xFFFF1744),
      amber: Color(0xFFB45309),
      background: Color(0xFF0A1628),
      textMuted: Color(0xFF888888),
    );
  }

  factory AppThemeExtension.legacy() {
    return const AppThemeExtension(
      navy: Color(0xFF090A0F),
      surface: Color(0xFF12141F),
      surfaceLight: Color(0xFF1C1F2E),
      primary: Color(0xFFFF6D00), // Orange
      cyan: Color(0xFF00E5FF), // Cyan
      gold: Color(0xFF00E5FF),
      offWhite: Color(0xFFF5F3EE),
      paper: Color(0xFFF5F3EE),
      paperDark: Color(0xFFD9D4C8),
      winGreen: Color(0xFF1B7A3E),
      lossRed: Color(0xFFFF1744),
      amber: Color(0xFFB45309),
      background: Color(0xFF090A0F),
      textMuted: Color(0xFFA5ACBC),
    );
  }

  @override
  ThemeExtension<AppThemeExtension> copyWith() {
    return this;
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      navy: Color.lerp(navy, other.navy, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      offWhite: Color.lerp(offWhite, other.offWhite, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      paperDark: Color.lerp(paperDark, other.paperDark, t)!,
      winGreen: Color.lerp(winGreen, other.winGreen, t)!,
      lossRed: Color.lerp(lossRed, other.lossRed, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      background: Color.lerp(background, other.background, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

extension ThemeColorsExt on BuildContext {
  AppThemeExtension get themeColors => Theme.of(this).extension<AppThemeExtension>() ?? AppThemeExtension.premium();
}

class AppTheme {
  static ThemeData get premiumTheme {
    final colors = AppThemeExtension.premium();
    return _buildTheme(colors);
  }

  static ThemeData get legacyTheme {
    final colors = AppThemeExtension.legacy();
    return _buildTheme(colors);
  }

  static ThemeData _buildTheme(AppThemeExtension colors) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: colors.navy,
      colorScheme: ColorScheme.dark(
        primary: colors.primary,
        secondary: colors.gold,
        surface: colors.surface,
        onPrimary: Colors.white,
        onSecondary: colors.navy,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: colors.surfaceLight,
        iconColor: Colors.white,
        textColor: Colors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.navy,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      extensions: [colors],
    );
  }

  static AppThemeExtension currentColors = AppThemeExtension.premium();
}

class AppColors {
  static Color get navy => AppTheme.currentColors.navy;
  static Color get surface => AppTheme.currentColors.surface;
  static Color get surfaceLight => AppTheme.currentColors.surfaceLight;
  static Color get primary => AppTheme.currentColors.primary;
  static Color get cyan => AppTheme.currentColors.cyan;
  static Color get gold => AppTheme.currentColors.gold;
  static Color get offWhite => AppTheme.currentColors.offWhite;
  static Color get paper => AppTheme.currentColors.paper;
  static Color get paperDark => AppTheme.currentColors.paperDark;
  static Color get winGreen => AppTheme.currentColors.winGreen;
  static Color get lossRed => AppTheme.currentColors.lossRed;
  static Color get amber => AppTheme.currentColors.amber;
  static Color get background => AppTheme.currentColors.background;
  static Color get textMuted => AppTheme.currentColors.textMuted;
}

/// A sleek modern Glassmorphic container with optional neon border and blur
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.borderRadius = 16.0,
    this.onTap,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    Widget container = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: gradientColors ?? [
            colors.gold.withValues(alpha: 0.15),
            colors.gold.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: container,
        ),
      );
    }

    return container;
  }
}

/// Custom Gradient Button with loading indicator
class EsportsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color>? gradient;
  final Color textColor;
  final double height;

  const EsportsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.textColor = Colors.white,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final effectiveGradient = gradient ?? [colors.primary, colors.gold];

    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: effectiveGradient),
          boxShadow: [
            BoxShadow(
              color: effectiveGradient.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: textColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Glowing tag for status, playstyle, roles, ratings
class GlowBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const GlowBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.themeColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.1),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: effectiveColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small metric pill for stats like Elo, Form, Win %
class StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatPill({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.themeColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.themeColors.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
