# Echoed — Flutter App

> **Five tones. One shot. How sharp is your ear?**

A cross-platform mobile game (iOS + Android) that tests pitch memory. Five pure sine-wave tones play; you recreate them on logarithmic frequency sliders. Scored in real time, centimetre-precise.

---

## Prerequisites

| Tool | Version |
|---|---|
| Flutter SDK | 3.24.0+ |
| Dart SDK | 3.3.0+ |
| Xcode (iOS) | 15+ |
| Android Studio | Hedgehog (2023.1.1)+ |
| CocoaPods | 1.14+ |
| pnpm / pub | (pub bundled with Flutter) |

---

## Environment Setup

### 1. Clone and install dependencies

```bash
git clone <your-repo-url>
cd echoed
flutter pub get
```

### 2. Configure credentials

Open `lib/core/constants.dart` and replace all placeholder values:

```dart
static const String supabaseUrl      = 'https://YOUR_PROJECT_ID.supabase.co';
static const String supabaseAnonKey  = 'YOUR_SUPABASE_ANON_KEY';
static const String revenueCatApiKey = 'YOUR_REVENUECAT_API_KEY';
```

### 3. Supabase — Database setup

Run the SQL in `supabase/schema.sql` against your Supabase project:

```bash
# Option A: Supabase CLI
supabase db push

# Option B: Supabase dashboard
# Paste supabase/schema.sql into the SQL editor and run it.
```

Then deploy the Edge Functions:

```bash
supabase functions deploy create-session
supabase functions deploy join-session
supabase functions deploy submit-result
supabase functions deploy daily-leaderboard
supabase functions deploy player-stats
supabase functions deploy offline-seeds
supabase functions deploy revenuecat-webhook
```

### 4. RevenueCat setup

1. Create a RevenueCat project at [app.revenuecat.com](https://app.revenuecat.com).
2. Add your iOS and Android apps.
3. Create an **Entitlement** named `premium`.
4. Add two **Products** in App Store Connect / Google Play Console:
   - `echoed_premium_monthly` — $3.99/month
   - `echoed_premium_annual` — $29.99/year
5. Attach both products to the `premium` entitlement.
6. Copy the RevenueCat API key into `constants.dart`.
7. Set up the RevenueCat webhook → your Supabase Edge Function URL (`/functions/v1/revenuecat-webhook`).

### 5. iOS setup

```bash
cd ios
pod install
cd ..
```

Add the following to `ios/Runner/Info.plist`:

```xml
<!-- Required for audio playback in silent mode -->
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>

<!-- Microphone not required, but audio session needs this on some iOS versions -->
<key>NSMicrophoneUsageDescription</key>
<string>Echoed uses the audio session for tone playback only.</string>
```

### 6. Android setup

Ensure `android/app/build.gradle` has:

```groovy
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

---

## Running the App

```bash
# iOS simulator
flutter run -d iPhone

# Android emulator
flutter run -d emulator-5554

# Physical device (connected via USB)
flutter run
```

---

## Project Structure

```
echoed/
├── lib/
│   ├── main.dart                  # App entry point
│   ├── app.dart                   # GoRouter + MaterialApp
│   ├── core/
│   │   ├── constants.dart         # Colors, text styles, app constants
│   │   └── theme.dart             # Material 3 dark theme
│   ├── models/
│   │   ├── tone_model.dart        # Single tone (target + guess + score)
│   │   ├── game_model.dart        # Full game state + phase enum
│   │   └── user_model.dart        # User, LeaderboardEntry, PlayerStats
│   ├── services/
│   │   ├── tone_generator.dart    # PCG32 PRNG + logarithmic freq generator
│   │   ├── audio_service.dart     # WAV synthesis + just_audio playback
│   │   ├── scoring_service.dart   # Cents-based per-tone scoring
│   │   ├── supabase_service.dart  # All Supabase calls (auth, DB, realtime)
│   │   └── revenuecat_service.dart# RevenueCat subscription management
│   ├── providers/
│   │   ├── auth_provider.dart     # Auth state, guest token, user profile
│   │   ├── game_provider.dart     # Game state machine + play limit guard
│   │   └── subscription_provider.dart # Offerings + purchase notifier
│   ├── screens/
│   │   ├── home_screen.dart       # Mode selector + daily banner
│   │   ├── daily_screen.dart      # Daily challenge entry
│   │   ├── game_memorize_screen.dart # Memorization phase
│   │   ├── game_recreate_screen.dart # Recall phase (sliders)
│   │   ├── results_screen.dart    # Score + waveform comparison
│   │   ├── leaderboard_screen.dart# Daily / session leaderboard
│   │   ├── multiplayer_lobby_screen.dart # Code entry + lobby
│   │   ├── profile_screen.dart    # Account + stats + settings
│   │   └── paywall_screen.dart    # Premium upgrade
│   └── widgets/
│       ├── waveform_painter.dart  # CustomPainter: sine wave overlays
│       └── frequency_slider.dart  # Vertical log slider + preview button
├── supabase/
│   └── schema.sql                 # Full database schema
├── assets/
│   └── fonts/                     # SpaceMono-Regular.ttf, SpaceMono-Bold.ttf
└── pubspec.yaml
```

---

## Key Technical Decisions

### Deterministic Tone Generation (PCG32)

All tones are generated from a 64-bit integer seed using PCG32, a portable pseudorandom number generator. The same seed always produces identical tones on every device and on the server.

**How the seed maps to frequencies:**

1. PCG32 produces a uniform double in [0, 1).
2. That value is mapped logarithmically to [200, 1800] Hz.
3. Tones are rejected if they fall within 50 cents of any existing tone.
4. The final list is sorted ascending.

The daily seed is derived from the UTC midnight Unix timestamp using the same PCG32 step function — reproducible by anyone given the date.

### Audio — No External Files

All audio is synthesized on-device at runtime:
- 16-bit signed PCM at 44100 Hz, mono.
- Written to a temporary WAV file with a minimal header.
- Played via `just_audio`'s `AudioSource.file`.
- Temporary files are deleted when the game session ends.

No audio files are bundled. No network audio is fetched. The app works fully offline for solo play.

### Scoring Algorithm

```
deviation_cents = |1200 × log₂(guess_hz / target_hz)|
score_i         = max(0, 20 × (1 − deviation_cents / 1200))
total_score     = Σ score_i   (0–100)
```

- Exact match → 20 points per tone.
- 1 octave away → 0 points.
- Continuous and smooth — no binary pass/fail.

### Visual Design

- 100% original — no images, icons, or sounds from third parties.
- All waveforms rendered via `CustomPainter` using dart:math.
- Frequency sliders use a custom `CustomPainter` track + thumb.
- Fonts: [SpaceMono](https://fonts.google.com/specimen/Space+Mono) — download and place in `assets/fonts/`.

---

## Adding SpaceMono Font

Download from Google Fonts (OFL licensed — free to use):
```bash
# macOS/Linux
curl -L "https://fonts.google.com/download?family=Space+Mono" -o SpaceMono.zip
unzip SpaceMono.zip
cp "Space_Mono/SpaceMono-Regular.ttf" echoed/assets/fonts/
cp "Space_Mono/SpaceMono-Bold.ttf" echoed/assets/fonts/
```

Or download manually from [fonts.google.com/specimen/Space+Mono](https://fonts.google.com/specimen/Space+Mono).

---

## Supabase Edge Functions

Edge Functions live in `supabase/functions/`. Each is a Deno TypeScript module.

They implement:
- Daily seed generation (deterministic, matches client-side PCG32)
- Server-side score verification (anti-cheat)
- RevenueCat webhook handling (premium entitlement sync)
- Offline seed payload signing (premium only)

See `supabase/schema.sql` for Row Level Security policies.

---

## Monetization

- **Free:** 3 solo games/day + 1 Daily Challenge + public multiplayer.
- **Premium ($3.99/mo or $29.99/yr):** Unlimited games, stats, offline daily sets, private groups, seasonal tone packs, no ads.
- **Trial:** 7-day free trial on both plans.
- **Provider:** RevenueCat (handles StoreKit 2 + Google Play Billing).

---

## Build for Production

```bash
# iOS — create archive in Xcode
flutter build ipa

# Android — release bundle
flutter build appbundle --release
```

Both targets use the same codebase.

---

## License

All code in this project is original. No copyrighted game mechanics, audio, or visual assets are referenced.
SpaceMono font: SIL Open Font License 1.1.
All other dependencies: see their respective licenses in `pubspec.lock`.
