import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// App-wide constants — replace placeholder values with real credentials.
/// ---------------------------------------------------------------------------
class AppConstants {
  AppConstants._();

  // Supabase — replace with values from your Supabase project settings.
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // RevenueCat — replace with the API key from the RevenueCat dashboard.
  static const String revenueCatApiKey = 'YOUR_REVENUECAT_API_KEY';

  // RevenueCat entitlement identifier (set in RevenueCat dashboard).
  static const String premiumEntitlement = 'premium';

  // RevenueCat product identifiers (must match App Store / Play Store).
  static const String monthlyProductId = 'echoed_premium_monthly';
  static const String annualProductId = 'echoed_premium_annual';

  // Game configuration
  static const int toneCount = 5;
  static const double minFrequencyHz = 200.0;
  static const double maxFrequencyHz = 1800.0;
  static const int memorizeTimeLimitSeconds = 300;
  static const double toneDurationSeconds = 1.5;
  static const double toneFadeSeconds = 0.01; // linear fade in/out
  static const double toneAmplitude = 0.7;
  static const int audioSampleRate = 44100;
  static const double minCentsDistance = 50.0; // min spacing between tones

  // Free tier limits
  static const int freeGamesPerDay = 3;
  static const int freeMultiplayerSessionsPerDay = 3;

  // Session code length
  static const int sessionCodeLength = 6;

  // Score grades
  static const Map<String, List<double>> scoreGrades = {
    'Perfect': [95, 100],
    'Sharp': [80, 95],
    'Tuned': [60, 80],
    'Drifting': [40, 60],
    'Off-key': [0, 40],
  };

  // PostHog analytics (optional — set to empty strings to disable)
  static const String posthogApiKey = '';
  static const String posthogHost = 'https://app.posthog.com';
}

/// ---------------------------------------------------------------------------
/// Color palette — original, dark-first design system.
/// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF13131A);
  static const Color surfaceVariant = Color(0xFF1E1E2A);
  static const Color border = Color(0xFF2A2A3A);

  // Primary accent — electric indigo
  static const Color primary = Color(0xFF7B6EF6);
  static const Color primaryDim = Color(0xFF3D3580);
  static const Color primaryGlow = Color(0xFFB0A8FF);

  // Secondary accent — neon teal (waveform highlight)
  static const Color accent = Color(0xFF00E5CC);
  static const Color accentDim = Color(0xFF00726A);

  // Tone score colors
  static const Color scorePerfect = Color(0xFF7BF696);
  static const Color scoreGood = Color(0xFFB0F67B);
  static const Color scoreMid = Color(0xFFF6D46A);
  static const Color scorePoor = Color(0xFFF6926A);
  static const Color scoreBad = Color(0xFFF66A6A);

  static const Color textPrimary = Color(0xFFF0F0FF);
  static const Color textSecondary = Color(0xFF8888AA);
  static const Color textDisabled = Color(0xFF444455);

  // Slider track gradient stops
  static const Color sliderBottom = Color(0xFF3D3580);
  static const Color sliderTop = Color(0xFF7B6EF6);
  static const Color sliderThumb = Color(0xFFFFFFFF);
}

/// ---------------------------------------------------------------------------
/// Typography — SpaceMono gives a precise, technical feel.
/// ---------------------------------------------------------------------------
class AppTextStyles {
  AppTextStyles._();

  static const String _mono = 'SpaceMono';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: _mono,
    fontSize: 64,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -2,
  );

  static const TextStyle headingLarge = TextStyle(
    fontFamily: _mono,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: _mono,
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _mono,
    fontSize: 16,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _mono,
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: _mono,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.textSecondary,
    letterSpacing: 1.5,
  );

  static const TextStyle freqReadout = TextStyle(
    fontFamily: _mono,
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    letterSpacing: 1,
  );

  static const TextStyle scoreDisplay = TextStyle(
    fontFamily: _mono,
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -3,
  );
}

/// ---------------------------------------------------------------------------
/// Spacing constants
/// ---------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
