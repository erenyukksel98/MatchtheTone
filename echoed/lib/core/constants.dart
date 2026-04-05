import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ---------------------------------------------------------------------------
/// App-wide constants — replace placeholder values with real credentials.
/// ---------------------------------------------------------------------------
class AppConstants {
  AppConstants._();

  static const String supabaseUrl = 'https://oxkntfwatwvwylpyevkk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94a250ZndhdHd2d3lscHlldmtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MzQzNDYsImV4cCI6MjA5MDExMDM0Nn0.EVpDoNdBYgH7HP9xUOanHfl401eyAFD0vJR0I0zck_g';
  static const String revenueCatApiKey = 'test_fbJjBjApVOAdVcekLSqFBDHmPAW';
  static const String premiumEntitlement = 'premium';
  static const String monthlyProductId = 'echoed_premium_monthly';
  static const String annualProductId = 'echoed_premium_annual';

  static const int toneCount = 5;
  static const double minFrequencyHz = 200.0;
  static const double maxFrequencyHz = 1800.0;
  static const int memorizeTimeLimitSeconds = 300;
  static const double toneDurationSeconds = 1.5;
  static const double toneFadeSeconds = 0.01;
  static const double toneAmplitude = 0.7;
  static const int audioSampleRate = 44100;
  static const double minCentsDistance = 50.0;

  static const int freeGamesPerDay = 3;
  static const int freeMultiplayerSessionsPerDay = 3;
  static const int sessionCodeLength = 6;

  static const Map<String, List<double>> scoreGrades = {
    'Perfect': [95, 100],
    'Sharp': [80, 95],
    'Tuned': [60, 80],
    'Drifting': [40, 60],
    'Off-key': [0, 40],
  };

  static const String posthogApiKey = '';
  static const String posthogHost = 'https://app.posthog.com';
}

/// ---------------------------------------------------------------------------
/// Color palette — neon cyan + magenta on near-black.
/// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color background    = Color(0xFF090909);
  static const Color surface       = Color(0xFF111111);
  static const Color surfaceHigh   = Color(0xFF1A1A1A);
  static const Color surfaceTop    = Color(0xFF222222);
  static const Color border        = Color(0xFF252525);
  static const Color borderBright  = Color(0xFF363636);

  // Primary — neon cyan
  static const Color cyan       = Color(0xFF00F5FF);
  static const Color cyanDim    = Color(0xFF003D40);
  static const Color cyanMid    = Color(0xFF007A80);

  // Secondary — neon magenta
  static const Color magenta    = Color(0xFFFF00FF);
  static const Color magentaDim = Color(0xFF3D003D);
  static const Color magentaMid = Color(0xFF7A007A);

  // Legacy aliases kept for widgets that reference them
  static const Color primary       = cyan;
  static const Color primaryDim    = cyanDim;
  static const Color primaryGlow   = Color(0xFF80FAFF);
  static const Color accent        = magenta;
  static const Color accentDim     = magentaDim;

  // Tone score colours
  static const Color scorePerfect = Color(0xFF00F5FF);
  static const Color scoreGood    = Color(0xFF7BF696);
  static const Color scoreMid     = Color(0xFFF6D46A);
  static const Color scorePoor    = Color(0xFFF6926A);
  static const Color scoreBad     = Color(0xFFFF4455);

  // Backward-compatible alias
  static const Color surfaceVariant = surfaceHigh;

  // Text
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textDisabled  = Color(0xFF3A3A3A);

  // Slider
  static const Color sliderBottom = cyanDim;
  static const Color sliderTop    = cyan;
  static const Color sliderThumb  = Color(0xFFFFFFFF);

  // Per-tone identity colours (cyan → magenta spectrum)
  static const List<Color> toneColors = [
    Color(0xFF00F5FF), // 1 – cyan
    Color(0xFF00CFFF), // 2 – sky
    Color(0xFFAA66FF), // 3 – violet
    Color(0xFFFF44CC), // 4 – pink
    Color(0xFFFF00FF), // 5 – magenta
  ];
}

/// ---------------------------------------------------------------------------
/// Typography — Inter (Google Fonts) for clean, modern feel.
/// ---------------------------------------------------------------------------
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 64,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -2,
    height: 1.0,
  );

  static TextStyle get headingLarge => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get headingMedium => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get headingSmall => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 1.8,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textDisabled,
    letterSpacing: 1.4,
  );

  // Monospace for Hz / numeric readouts
  static TextStyle get freqReadout => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.cyan,
    letterSpacing: 0.5,
  );

  static TextStyle get scoreDisplay => GoogleFonts.inter(
    fontSize: 80,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -4,
    height: 1.0,
  );

  static TextStyle get timerDisplay => GoogleFonts.spaceGrotesk(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 1,
  );
}

/// ---------------------------------------------------------------------------
/// Spacing constants
/// ---------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;
}

/// ---------------------------------------------------------------------------
/// Shared decorations & shadow helpers
/// ---------------------------------------------------------------------------
class AppDecorations {
  AppDecorations._();

  /// Glowing border card
  static BoxDecoration glowCard({
    Color glowColor = AppColors.cyan,
    double glowIntensity = 0.25,
    double radius = 20,
  }) =>
      BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glowColor.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(glowIntensity),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      );

  static BoxDecoration plainCard({double radius = 16}) => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border, width: 1),
      );

  static List<BoxShadow> neonShadow(Color color, {double opacity = 0.5}) => [
        BoxShadow(color: color.withOpacity(opacity), blurRadius: 20, spreadRadius: -6),
        BoxShadow(color: color.withOpacity(opacity * 0.3), blurRadius: 50, spreadRadius: -10),
      ];
}
