import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/theme_provider.dart';

enum AppThemeType {
  classic,
  daylight;

  String get displayName {
    switch (this) {
      case AppThemeType.classic:
        return 'Cyber Esports (Dark)';
      case AppThemeType.daylight:
        return 'Matchday Editorial (Light)';
    }
  }

  String get description {
    switch (this) {
      case AppThemeType.classic:
        return 'Retro-futuristic neon arena with Electric Orange & Cyan cyber-matrix';
      case AppThemeType.daylight:
        return 'Sports programme aesthetic with Warm Paper, Velvet Navy, Scarlet & Trophy Gold';
    }
  }
}

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  final AppThemeType themeType;
  final String name;
  final Color navy;
  final Color surface;
  final Color surfaceLight;
  final Color primary;
  final Color cyan;
  final Color purple;
  final Color gold;
  final Color offWhite;
  final Color paper;
  final Color paperDark;
  final Color winGreen;
  final Color lossRed;
  final Color amber;
  final Color background;
  final Color textMuted;

  // Text contrast & structural tokens
  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;
  final Color divider;
  final Color cardBackground;

  // Custom visual language design tokens
  final double cardRadius;
  final double buttonRadius;
  final Color cardBorder;
  final List<Color> cardGradient;
  final List<Color> buttonGradient;
  final Color buttonTextColor;
  final Color activeGlow;

  const AppThemeExtension({
    required this.themeType,
    required this.name,
    required this.navy,
    required this.surface,
    required this.surfaceLight,
    required this.primary,
    required this.cyan,
    required this.purple,
    required this.gold,
    required this.offWhite,
    required this.paper,
    required this.paperDark,
    required this.winGreen,
    required this.lossRed,
    required this.amber,
    required this.background,
    required this.textMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
    required this.divider,
    required this.cardBackground,
    required this.cardRadius,
    required this.buttonRadius,
    required this.cardBorder,
    required this.cardGradient,
    required this.buttonGradient,
    required this.buttonTextColor,
    required this.activeGlow,
  });

  bool get isClassic => themeType == AppThemeType.classic;
  bool get isLight => themeType == AppThemeType.daylight;
  bool get isDaylight => themeType == AppThemeType.daylight;
  // Backward compatibility helpers
  bool get isPremium => false;
  bool get isPitchDominance => false;

  /// 1. Classic Cyber Esports (Dark)
  factory AppThemeExtension.classic() {
    return const AppThemeExtension(
      themeType: AppThemeType.classic,
      name: 'Cyber Esports',
      navy: Color(0xFF090A0F),
      surface: Color(0xFF12141F),
      surfaceLight: Color(0xFF1C1F2E),
      primary: Color(0xFFFF6D00), // Electric Orange
      cyan: Color(0xFF00E5FF),    // Cyber Neon Cyan
      purple: Color(0xFFB000FF),  // Vivid Purple Accent
      gold: Color(0xFFFFD600),    // Vibrant Gold
      offWhite: Color(0xFFF5F3EE),
      paper: Color(0xFFF5F3EE),
      paperDark: Color(0xFFD9D4C8),
      winGreen: Color(0xFF00E676), // Neon Green
      lossRed: Color(0xFFFF1744),  // Neon Red
      amber: Color(0xFFFFAB00),
      background: Color(0xFF090A0F),
      textMuted: Color(0xFFA5ACBC),
      textPrimary: Colors.white,
      textSecondary: Color(0xFFA5ACBC),
      textDim: Color(0xFF6B7280),
      divider: Color(0x1FFFFFFF),
      cardBackground: Color(0xFF12141F),
      cardRadius: 10.0,
      buttonRadius: 10.0,
      cardBorder: Color(0x3300E5FF),
      cardGradient: [
        Color(0x1AFFFFFF),
        Color(0x05FFFFFF),
      ],
      buttonGradient: [
        Color(0xFFFF6D00),
        Color(0xFFFF9E00),
      ],
      buttonTextColor: Colors.black,
      activeGlow: Color(0xFF00E5FF),
    );
  }

  /// 2. Matchday Editorial (High-End Sports Programme Light Mode)
  /// Inspired by the Matchday Export Fixtures editorial graphics, colors, and geometric motifs.
  factory AppThemeExtension.daylight() {
    return const AppThemeExtension(
      themeType: AppThemeType.daylight,
      name: 'Matchday Editorial',
      navy: Color(0xFF0A1628),        // Deep Velvet Navy (Headlines, Authority)
      surface: Color(0xFFFFFFFF),     // Crisp White Magazine Paper
      surfaceLight: Color(0xFFF5F3EE),// Heavyweight Warm Linen Tone
      primary: Color(0xFFD90429),     // Championship Scarlet Red
      cyan: Color(0xFFC9A84C),        // Trophy Champagne Gold Accent
      purple: Color(0xFF1E293B),      // Slate Navy Secondary
      gold: Color(0xFFC9A84C),        // Trophy Champagne Gold
      offWhite: Color(0xFF0A1628),    // Deep Navy for text contrast
      paper: Color(0xFFF5F3EE),       // Warm Editorial Paper
      paperDark: Color(0xFFD9D4C8),   // Divider & Border hairline tone
      winGreen: Color(0xFF1B7A3E),    // Editorial Forest Green
      lossRed: Color(0xFFD90429),     // Matchday Scarlet Red
      amber: Color(0xFFB45309),       // Reschedule Warm Amber
      background: Color(0xFFF5F3EE),  // Warm Canvas Base
      textMuted: Color(0xFF5A6678),   // Slate Muted Editorial
      textPrimary: Color(0xFF0A1628), // Deep Velvet Navy Primary Text
      textSecondary: Color(0xFF475569), // Crisp Slate Secondary Text
      textDim: Color(0xFF718096),     // Dim Editorial Annotation Text
      divider: Color(0xFFD9D4C8),     // Paper Dark Divider Line
      cardBackground: Color(0xFFFFFFFF),
      cardRadius: 12.0,
      buttonRadius: 8.0,
      cardBorder: Color(0x40C9A84C),  // Champagne Gold Accent Border
      cardGradient: [
        Color(0xFFFFFFFF),
        Color(0xFFF8F6F0),
      ],
      buttonGradient: [
        Color(0xFFD90429),
        Color(0xFFB80322),
      ],
      buttonTextColor: Colors.white,
      activeGlow: Color(0xFFC9A84C),
    );
  }

  /// Alias for backward compatibility
  factory AppThemeExtension.legacy() => AppThemeExtension.classic();
  factory AppThemeExtension.premium() => AppThemeExtension.classic();
  factory AppThemeExtension.midnightGold() => AppThemeExtension.classic();

  @override
  ThemeExtension<AppThemeExtension> copyWith() {
    return this;
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      themeType: t < 0.5 ? themeType : other.themeType,
      name: other.name,
      navy: Color.lerp(navy, other.navy, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceLight: Color.lerp(surfaceLight, other.surfaceLight, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      offWhite: Color.lerp(offWhite, other.offWhite, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      paperDark: Color.lerp(paperDark, other.paperDark, t)!,
      winGreen: Color.lerp(winGreen, other.winGreen, t)!,
      lossRed: Color.lerp(lossRed, other.lossRed, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      background: Color.lerp(background, other.background, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardGradient: [
        Color.lerp(cardGradient.first, other.cardGradient.first, t)!,
        Color.lerp(cardGradient.last, other.cardGradient.last, t)!,
      ],
      buttonGradient: [
        Color.lerp(buttonGradient.first, other.buttonGradient.first, t)!,
        Color.lerp(buttonGradient.last, other.buttonGradient.last, t)!,
      ],
      buttonTextColor: Color.lerp(buttonTextColor, other.buttonTextColor, t)!,
      activeGlow: Color.lerp(activeGlow, other.activeGlow, t)!,
    );
  }
}

extension ThemeColorsExt on BuildContext {
  AppThemeExtension get themeColors =>
      Theme.of(this).extension<AppThemeExtension>() ?? AppTheme.currentColors;
}

class AppTheme {
  static ThemeData get classicTheme => _buildTheme(AppThemeExtension.classic());
  static ThemeData get daylightTheme => _buildTheme(AppThemeExtension.daylight());
  static ThemeData get legacyTheme => classicTheme;
  static ThemeData get darkTheme => classicTheme;
  static ThemeData get lightTheme => daylightTheme;

  // Backward compatibility getters
  static ThemeData get premiumTheme => classicTheme;
  static ThemeData get midnightGoldTheme => classicTheme;

  static ThemeData getTheme(AppThemeType type) {
    currentColors = getColors(type);
    switch (type) {
      case AppThemeType.classic:
        return classicTheme;
      case AppThemeType.daylight:
        return daylightTheme;
    }
  }

  static AppThemeExtension getColors(AppThemeType type) {
    switch (type) {
      case AppThemeType.classic:
        return AppThemeExtension.classic();
      case AppThemeType.daylight:
        return AppThemeExtension.daylight();
    }
  }

  static ThemeData _buildTheme(AppThemeExtension colors) {
    final baseTheme = colors.isLight ? ThemeData.light() : ThemeData.dark();
    final textColor = colors.textPrimary;
    final textSecondary = colors.textSecondary;
    final textDim = colors.textDim;

    final baseTextTheme = GoogleFonts.rajdhaniTextTheme(baseTheme.textTheme);
    final textTheme = baseTextTheme.copyWith(
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textColor),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textColor),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: textSecondary),
      titleLarge: baseTextTheme.titleLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      titleMedium: baseTextTheme.titleMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      titleSmall: baseTextTheme.titleSmall?.copyWith(color: textColor),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      displayLarge: baseTextTheme.displayLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      displayMedium: baseTextTheme.displayMedium?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      displaySmall: baseTextTheme.displaySmall?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      labelLarge: baseTextTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold),
      labelMedium: baseTextTheme.labelMedium?.copyWith(color: textSecondary),
      labelSmall: baseTextTheme.labelSmall?.copyWith(color: textDim),
    );

    return baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: colors.surface,
      dividerColor: colors.divider,
      colorScheme: colors.isLight
          ? ColorScheme.light(
              primary: colors.primary,
              secondary: colors.cyan,
              surface: colors.surface,
              onPrimary: colors.buttonTextColor,
              onSecondary: colors.navy,
              onSurface: textColor,
            )
          : ColorScheme.dark(
              primary: colors.primary,
              secondary: colors.cyan,
              surface: colors.surface,
              onPrimary: colors.buttonTextColor,
              onSecondary: Colors.black,
              onSurface: textColor,
            ),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: textColor),
      primaryIconTheme: IconThemeData(color: textColor),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textColor),
        titleTextStyle: GoogleFonts.rajdhani(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: colors.isLight ? 2 : 0,
        shadowColor: colors.isLight ? const Color(0xFF0A1628).withValues(alpha: 0.08) : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(colors.cardRadius),
          side: BorderSide(color: colors.cardBorder, width: 1.1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: colors.surfaceLight,
        iconColor: textColor,
        textColor: textColor,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(colors.cardRadius),
          side: BorderSide(color: colors.cardBorder, width: 1.2),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(colors.cardRadius + 4)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 0.8,
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colors.isLight ? colors.surfaceLight : Colors.white.withValues(alpha: 0.05),
        filled: true,
        labelStyle: TextStyle(color: textSecondary),
        hintStyle: TextStyle(color: textDim),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(colors.buttonRadius),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(colors.buttonRadius),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(colors.buttonRadius),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
      ),
      extensions: [colors],
    );
  }

  static AppThemeExtension currentColors = AppThemeExtension.classic();
}

class AppColors {
  static Color get navy => AppTheme.currentColors.navy;
  static Color get surface => AppTheme.currentColors.surface;
  static Color get surfaceLight => AppTheme.currentColors.surfaceLight;
  static Color get primary => AppTheme.currentColors.primary;
  static Color get cyan => AppTheme.currentColors.cyan;
  static Color get purple => AppTheme.currentColors.purple;
  static Color get gold => AppTheme.currentColors.gold;
  static Color get offWhite => AppTheme.currentColors.offWhite;
  static Color get paper => AppTheme.currentColors.paper;
  static Color get paperDark => AppTheme.currentColors.paperDark;
  static Color get winGreen => AppTheme.currentColors.winGreen;
  static Color get lossRed => AppTheme.currentColors.lossRed;
  static Color get amber => AppTheme.currentColors.amber;
  static Color get background => AppTheme.currentColors.background;
  static Color get textMuted => AppTheme.currentColors.textMuted;
  static Color get textPrimary => AppTheme.currentColors.textPrimary;
  static Color get textSecondary => AppTheme.currentColors.textSecondary;
  static Color get textDim => AppTheme.currentColors.textDim;
  static Color get divider => AppTheme.currentColors.divider;
  static Color get cardBorder => AppTheme.currentColors.cardBorder;
  static bool get isLight => AppTheme.currentColors.isLight;
}

// ─────────────────────────────────────────────────────────────────────────────
// ThemedBackground — Distinct atmospheric visual canvas for each theme
// ─────────────────────────────────────────────────────────────────────────────

class ThemedBackground extends ConsumerWidget {
  final Widget child;

  const ThemedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(themeProvider);
    final themeData = AppTheme.getTheme(themeType);
    final colors = AppTheme.getColors(themeType);

    return Theme(
      data: themeData,
      child: DefaultTextStyle(
        style: GoogleFonts.rajdhani(
          color: colors.textPrimary,
          fontSize: 14,
        ),
        child: IconTheme(
          data: IconThemeData(color: colors.textPrimary),
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _getPainter(themeType),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  CustomPainter _getPainter(AppThemeType type) {
    switch (type) {
      case AppThemeType.classic:
        return const _CyberBackgroundPainter();
      case AppThemeType.daylight:
        return const _MatchdayEditorialBackgroundPainter();
    }
  }
}

class _CyberBackgroundPainter extends CustomPainter {
  const _CyberBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid void base
    final bgPaint = Paint()..color = const Color(0xFF08090E);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Top-left Orange Cyber Glow
    final orangeGlow = RadialGradient(
      center: const Alignment(-0.8, -0.9),
      radius: 0.9,
      colors: [
        const Color(0xFFFF6D00).withValues(alpha: 0.12),
        const Color(0xFFFF6D00).withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = orangeGlow.createShader(Offset.zero & size),
    );

    // 3. Bottom-right Cyan Matrix Glow
    final cyanGlow = RadialGradient(
      center: const Alignment(0.9, 0.9),
      radius: 1.1,
      colors: [
        const Color(0xFF00E5FF).withValues(alpha: 0.14),
        const Color(0xFF00E5FF).withValues(alpha: 0.0),
      ],
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = cyanGlow.createShader(Offset.zero & size),
    );

    // 4. Tech Isometric Horizon Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const hSpacing = 36.0;
    for (double y = size.height * 0.45; y < size.height; y += hSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const vCount = 8;
    for (int i = 0; i <= vCount; i++) {
      final xTop = size.width * 0.5 + (i - vCount / 2) * (size.width / vCount) * 0.3;
      final xBottom = size.width * 0.5 + (i - vCount / 2) * (size.width / vCount) * 1.4;
      canvas.drawLine(
        Offset(xTop, size.height * 0.45),
        Offset(xBottom, size.height),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _CyberBackgroundPainter;
}

/// Creative Sports Programme / Editorial Light Background Painter
/// Directly inspired by the exported matchday fixtures visual graphics:
/// - Tactile warm paper base (#F5F3EE)
/// - Subtle angled diagonal background stripes (#EAE7DF)
/// - Top-left and bottom-right Deep Navy (#0A1628) geometric polygon accents with Scarlet Red (#D90429) slash cuts
/// - Championship Gold (#C9A84C) precision L-bracket corner marks
/// - Centre faint geometric watermark rings (#D9D4C8)
/// - Top Navy and bottom Scarlet hairline framing rules
class _MatchdayEditorialBackgroundPainter extends CustomPainter {
  const _MatchdayEditorialBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Warm Heavyweight Editorial Paper Base (#F5F3EE)
    final bgPaint = Paint()..color = const Color(0xFFF5F3EE);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Subtle Repeating Diagonal Stripe Texture (#EAE7DF)
    final stripePaint = Paint()
      ..color = const Color(0xFFEAE7DF).withValues(alpha: 0.65)
      ..strokeWidth = 16.0
      ..style = PaintingStyle.stroke;

    const stripeSpacing = 72.0;
    final totalSpan = size.width + size.height;
    for (double offset = -size.height; offset < totalSpan; offset += stripeSpacing) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset + size.height * 0.9, size.height),
        stripePaint,
      );
    }

    // 3. Top-Left Deep Navy Polygon Block with Scarlet Slash Accent
    final navyTopLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.34, 0)
      ..lineTo(0, size.height * 0.11)
      ..close();
    canvas.drawPath(
      navyTopLeft,
      Paint()..color = const Color(0xFF0A1628).withValues(alpha: 0.95),
    );

    final scarletTopLeft = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.12, 0)
      ..lineTo(0, size.height * 0.04)
      ..close();
    canvas.drawPath(
      scarletTopLeft,
      Paint()..color = const Color(0xFFD90429).withValues(alpha: 0.90),
    );

    // 4. Bottom-Right Deep Navy Polygon Block with Scarlet Slash Accent
    final navyBottomRight = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width - size.width * 0.34, size.height)
      ..lineTo(size.width, size.height - size.height * 0.11)
      ..close();
    canvas.drawPath(
      navyBottomRight,
      Paint()..color = const Color(0xFF0A1628).withValues(alpha: 0.95),
    );

    final scarletBottomRight = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width - size.width * 0.12, size.height)
      ..lineTo(size.width, size.height - size.height * 0.04)
      ..close();
    canvas.drawPath(
      scarletBottomRight,
      Paint()..color = const Color(0xFFD90429).withValues(alpha: 0.90),
    );

    // 5. Mid-page Faint Geometric Watermark Ring (Sports Programme Trophy Aura)
    final watermarkPaint = Paint()
      ..color = const Color(0xFFD9D4C8).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.5, size.height * 0.52);
    canvas.drawCircle(center, size.width * 0.38, watermarkPaint);
    canvas.drawCircle(center, size.width * 0.26, watermarkPaint..strokeWidth = 0.7);
    canvas.drawLine(
      Offset(size.width * 0.12, center.dy),
      Offset(size.width * 0.88, center.dy),
      watermarkPaint..strokeWidth = 0.7,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.width * 0.38),
      Offset(center.dx, center.dy + size.width * 0.38),
      watermarkPaint..strokeWidth = 0.7,
    );

    // 6. Top & Bottom Framing Rules
    // Top Navy rule
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 3.5),
      Paint()..color = const Color(0xFF0A1628),
    );
    // Bottom Scarlet rule
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 3.5, size.width, 3.5),
      Paint()..color = const Color(0xFFD90429),
    );

    // 7. Four Precision Championship Gold (0xFFC9A84C) L-Bracket Corner Marks
    final goldBracketPaint = Paint()
      ..color = const Color(0xFFC9A84C)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const cornerInset = 16.0;
    const bracketLen = 16.0;

    // Top-Left
    canvas.drawLine(
      const Offset(cornerInset, cornerInset),
      const Offset(cornerInset + bracketLen, cornerInset),
      goldBracketPaint,
    );
    canvas.drawLine(
      const Offset(cornerInset, cornerInset),
      const Offset(cornerInset, cornerInset + bracketLen),
      goldBracketPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - cornerInset, cornerInset),
      Offset(size.width - cornerInset - bracketLen, cornerInset),
      goldBracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - cornerInset, cornerInset),
      Offset(size.width - cornerInset, cornerInset + bracketLen),
      goldBracketPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(cornerInset, size.height - cornerInset),
      Offset(cornerInset + bracketLen, size.height - cornerInset),
      goldBracketPaint,
    );
    canvas.drawLine(
      Offset(cornerInset, size.height - cornerInset),
      Offset(cornerInset, size.height - cornerInset - bracketLen),
      goldBracketPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - cornerInset, size.height - cornerInset),
      Offset(size.width - cornerInset - bracketLen, size.height - cornerInset),
      goldBracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - cornerInset, size.height - cornerInset),
      Offset(size.width - cornerInset, size.height - cornerInset - bracketLen),
      goldBracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      oldDelegate is! _MatchdayEditorialBackgroundPainter;
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme-Aware Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Sleek card container adapted to the active theme (Cyber Glass vs Matchday Editorial Paper)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? borderColor;
  final double? borderRadius;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.borderColor,
    this.borderRadius,
    this.onTap,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final radius = borderRadius ?? colors.cardRadius;

    Widget container = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: gradientColors ?? colors.cardGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: borderColor ?? colors.cardBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.isLight
                ? const Color(0xFF0A1628).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.25),
            blurRadius: colors.isLight ? 12 : 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: colors.isLight ? 6 : 12,
            sigmaY: colors.isLight ? 6 : 12,
          ),
          child: DefaultTextStyle(
            style: GoogleFonts.rajdhani(
              color: colors.textPrimary,
              fontSize: 14,
            ),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: container,
        ),
      );
    }

    return container;
  }
}

/// Custom Button adapted to the active theme (Cyber Glow vs Matchday Editorial Action)
class EsportsButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final List<Color>? gradient;
  final Color? textColor;
  final double height;

  const EsportsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.textColor,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.themeColors;
    final effectiveGradient = gradient ?? colors.buttonGradient;
    final effectiveTextColor = textColor ?? colors.buttonTextColor;

    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(colors.buttonRadius),
          gradient: LinearGradient(colors: effectiveGradient),
          border: colors.isLight
              ? Border.all(color: const Color(0xFFC9A84C).withValues(alpha: 0.75), width: 1.0)
              : null,
          boxShadow: [
            BoxShadow(
              color: effectiveGradient.first.withValues(alpha: colors.isLight ? 0.35 : 0.4),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(colors.buttonRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: effectiveTextColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: effectiveTextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Tag badge for status, playstyle, roles, ratings
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
    final colors = context.themeColors;
    final effectiveColor = color ?? colors.cyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: colors.isLight ? 0.12 : 0.15),
        borderRadius: BorderRadius.circular(colors.isLight ? 6 : 20),
        border: Border.all(
          color: effectiveColor.withValues(alpha: colors.isLight ? 0.7 : 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.15),
            blurRadius: 6,
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
    final colors = context.themeColors;
    final effectiveColor = color ?? (colors.isLight ? colors.navy : colors.cyan);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.isLight
            ? colors.surfaceLight
            : colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(colors.isLight ? 8 : 10),
        border: Border.all(
          color: colors.isLight
              ? colors.paperDark
              : effectiveColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
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
