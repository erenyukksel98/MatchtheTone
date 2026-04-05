# Echoed — Product Requirements Document

**Tagline:** Five tones. One shot. How sharp is your ear?
**Version:** 1.0 — MVP
**Date:** April 2026
**Status:** Draft

---

## Table of Contents

1. [Overview](#1-overview)
2. [Features](#2-features)
3. [Screens & User Flows](#3-screens--user-flows)
4. [Monetization](#4-monetization)
5. [Tech Architecture](#5-tech-architecture)
6. [Analytics](#6-analytics)
7. [Roadmap](#7-roadmap)

---

## 1. Overview

### 1.1 Product Summary

Echoed is a cross-platform mobile game (iOS + Android) that trains and tests absolute and relative pitch recognition through a purely original, procedurally generated audio mechanic. Every round, five pure sine-wave tones — each a frequency between 200 Hz and 1800 Hz — play in sequence. The player memorizes them, then reconstructs all five using logarithmic sliders. Scores are calculated by Hz deviation across all five tones and displayed instantly alongside a waveform overlay comparison.

There are no melodies, no musical scales, no copyrighted sounds, and no references to any existing pitch-training product. Echoed is a reaction-speed-for-ears game — the challenge is pure auditory memory and precision.

### 1.2 Target Audience

| Segment | Description |
|---|---|
| Casual players | People who enjoy quick cognitive challenges — word games, number puzzles |
| Musicians & students | Ear training practice with a game-like feedback loop |
| Competitive players | Daily Challenge leaderboard chasers, multiplayer friends |
| Premium users | People who want long-term stats, unlimited plays, offline access |

### 1.3 Core Value Propositions

- **Original mechanic.** No existing app teaches pitch by slider-matching pure sine tones with this scoring precision.
- **Deterministic fairness.** Every player in a multiplayer session hears the exact same tones from the same seed. No advantage for any platform.
- **Instant, precise feedback.** Scores are computed in milliseconds per tone and rendered with waveform overlay.
- **Freemium depth.** The free experience is complete and fun; premium unlocks data and breadth.

### 1.4 Platforms

- iOS 16+
- Android 10+
- Built with Flutter (single codebase)

### 1.5 Success Definition (6 months post-launch)

- 50,000 total downloads
- 18% Day-7 retention
- 4% free-to-premium conversion
- 4.4+ average App Store rating
- 1,500+ paying subscribers

---

## 2. Features

### 2.1 Core Game Loop

#### Tone Generation

- **Five tones per round**, each a pure sine wave.
- **Frequency range:** 200–1800 Hz. No tone repeats within a round.
- **Seed-based determinism:** Each round has a 64-bit integer seed. Passing the same seed to the same algorithm (see §5.4) produces identical tones on every device, every time.
- **Generation formula:** From the seed, derive five values using a seeded LCG or PCG32 random function. Map each value logarithmically to [200, 1800] Hz. This ensures perceptually even spacing rather than linear bunching.
- **Duration:** Each tone plays for exactly 1.5 seconds with a 0.01-second linear fade-in and fade-out to eliminate clicks.
- **Amplitude:** Fixed at 0.7 (normalized, no clipping). No volume variation in free tier.
- **Synthesis:** Device audio engine only (Flutter's `dart:ffi` + platform audio APIs — no internet audio, no samples, no libraries with licensing implications).

#### Memorization Phase

- **Time limit:** 300 seconds (5 minutes) maximum. Timer is visible and counts down.
- Player sees five numbered tone indicators (1–5).
- Tapping a tone indicator plays that single tone again. Replays are unlimited during the memorization phase.
- Tones do **not** replay automatically after first playback — player must tap each one.
- A progress indicator shows how many seconds remain.
- Player may press "Ready" at any time to skip remaining memorization time and move to the recall phase.
- A subtle pulsing animation plays on each indicator while its tone is active.

#### Recall Phase

- Memorization phase ends. Tone indicators disappear.
- Five vertical logarithmic sliders appear, one per tone. Each slider spans the full 200–1800 Hz range.
- Sliders start at the midpoint (approximately 600 Hz on a log scale).
- **Free tier:** Frequency only. A live frequency readout (e.g. "734 Hz") appears above each slider as the player drags.
- **Premium:** Two additional sub-sliders per tone for volume (0.1–1.0 normalized) and duration (0.5–3.0 seconds). These are only scored for accuracy in Hard mode.
- The player can press the small speaker icon next to each slider to preview their current guess (plays the tone at the slider's current value).
- Once all five sliders are positioned, player presses "Submit."

#### Scoring

Scoring is computed immediately on Submit, on-device, requiring no server round-trip.

**Per-tone score (0–20 points):**

```
deviation_cents = |1200 × log2(guess_hz / target_hz)|
score_i = max(0, 20 × (1 - deviation_cents / 1200))
```

This means:
- Exact match → 20 points
- 1 octave off (1200 cents) → 0 points
- ~half-octave off → ~10 points
- Smooth, continuous scoring — no binary pass/fail threshold

**Total score:** Sum of all five per-tone scores (0–100).

**Score grades (display only, not gamification tiers):**

| Score | Grade |
|---|---|
| 95–100 | Perfect |
| 80–94 | Sharp |
| 60–79 | Tuned |
| 40–59 | Drifting |
| 0–39 | Off-key |

**Hard mode scoring addon:** In Hard mode, a small timbre variation (random harmonic overtone at ≤5% amplitude) is added to each tone. This does not affect the scoring formula — scoring remains Hz-based — but makes memorization harder.

#### Result Display

- All five sliders remain frozen showing player's guesses.
- A waveform overlay screen animates in: for each tone, a split-view shows the target sine wave (thin, bright) and the player's guess sine wave (thicker, slightly different color). Waves oscillate for 2 seconds then freeze.
- Per-tone score appears beside each slider.
- Total score displayed large at the top with the grade label.
- Share button generates a snapshot card (score, game code, waveform overlay thumbnail) for system share sheet.

### 2.2 Game Modes

#### Solo Mode

- Generates a new random seed per round.
- Available unlimited times per day on premium. Free: 3 rounds/day.
- No leaderboard.

#### Daily Challenge

- One shared seed per calendar day (UTC midnight reset).
- All players — free and premium — get the same five tones.
- One attempt per player per day (free or premium).
- Daily leaderboard resets at UTC midnight.
- Premium: Can download the daily set in advance for offline play (see §2.4).

#### Hard Mode

- Toggle available in Solo and Daily Challenge.
- Adds a random harmonic overtone (one extra sine wave at a harmonic frequency with amplitude ≤5% of the fundamental) to each tone during memorization and recall preview.
- Timbre variation is deterministic from the same seed (derived from seed + mode_flag).
- Hard mode results are ranked separately on leaderboards.

#### Multiplayer — Shared Session

- Player A creates a session → receives a 6-character alphanumeric game code and a deep link.
- Player B enters the code or follows the deep link → joins the session.
- Up to 8 players per session.
- When all players are ready (or host starts), all clients receive the same seed.
- **Synchronization:** The server broadcasts `session_start` with the seed and a UTC timestamp 3 seconds in the future. All clients begin their memorization phase simultaneously at that timestamp.
- There is no real-time audio streaming. Each client generates tones locally from the seed. Determinism (§5.4) ensures identical tones.
- After all players submit, the server collects results and displays a ranked leaderboard for the session.
- Free tier: Can join sessions but cannot create private groups (premium only). Can participate in up to 3 sessions/day alongside their solo game limit.
- Premium: Unlimited sessions, private persistent groups with history.

### 2.3 Account System

| Feature | Guest | Free Account | Premium |
|---|---|---|---|
| Solo games/day | 3 | 3 | Unlimited |
| Daily Challenge | 1/day | 1/day | 1/day |
| Join multiplayer | Yes | Yes | Yes |
| Create sessions | Yes (public) | Yes (public) | Yes (public + private groups) |
| View play history | No | Last 7 days | Full history |
| Stats graphs | No | No | Yes |
| Offline daily sets | No | No | Yes |
| Seasonal tone packs | No | No | Yes |
| Ads | Yes | Yes | No |

**Guest mode:** Game is fully playable without an account. Progress is stored locally (AsyncStorage / SharedPreferences). If the device is lost or app reinstalled, progress is lost.

**Account creation:** Email + password or Apple Sign-In / Google Sign-In. No social graph is built. Account is for sync and premium access only.

### 2.4 Offline Mode (Premium)

- Each day at 00:01 UTC, the server publishes the next 7 daily seeds as a signed payload.
- Premium devices with the app open in the background download this payload automatically.
- If a premium player has no internet, the app uses the locally cached seed to play the daily challenge.
- The player's result is uploaded when connectivity resumes. If upload fails within 24 hours, the result is not submitted to the leaderboard (but is saved locally for personal history).

### 2.5 Seasonal Tone Packs (Premium)

- Curated named sets of 10–30 rounds with unique seeds.
- Themes: "Deep Rumbles" (200–400 Hz only), "Upper Register" (1000–1800 Hz), "Compressed Range" (narrow 50 Hz window), etc.
- Released quarterly. Past packs remain accessible to premium subscribers.
- All tones procedurally generated — no recordings, no samples.
- Packs are generated server-side by a seeded algorithm and stored as signed seed lists (not audio files).

---

## 3. Screens & User Flows

### 3.1 Screen Inventory

| Screen | Route | Description |
|---|---|---|
| Splash / Loading | `/` | App logo, determinism check |
| Home | `/home` | Mode selector, daily challenge banner |
| Solo Game — Memorization | `/play/memorize` | Tone indicators, timer, replay controls |
| Solo Game — Recall | `/play/recall` | Five sliders, submit |
| Result | `/result` | Score, grade, waveform overlay, share |
| Daily Challenge | `/daily` | Today's challenge entry, leaderboard |
| Daily Leaderboard | `/daily/leaderboard` | Ranked results for today |
| Multiplayer Lobby | `/multi/lobby` | Game code, player list, ready button |
| Multiplayer Result | `/multi/result` | Session leaderboard |
| Stats | `/stats` | Play history, score graph (premium) |
| Settings | `/settings` | Sound, theme, account |
| Sign Up / Sign In | `/auth` | Email or SSO |
| Paywall | `/premium` | Upgrade screen |
| Seasonal Packs | `/packs` | List of available tone packs |

### 3.2 Key User Flows

#### Flow A — First-Time Guest Solo Game

```
App launch
→ Splash (logo, 1.5s)
→ Home (guest mode, "Play" button prominent)
→ [Tap Play]
→ Memorization screen: 5 tone indicators appear with pulse animation
→ Player taps each tone to listen (unlimited replays for 300s)
→ Player taps "Ready" or timer expires
→ Recall screen: 5 sliders appear mid-position
→ Player drags sliders to guess each frequency
→ Player taps speaker icons to preview guesses
→ Player taps "Submit"
→ Result screen: waveform overlay animates, per-tone scores reveal, total score
→ [Tap "Share"] → system share sheet
→ [Tap "Play Again"] → new Solo game (decrements daily count)
→ After 3rd game → Soft paywall prompt ("You've used your 3 free games today. Unlock unlimited with Echoed Premium.")
```

#### Flow B — Daily Challenge

```
Home screen → "Daily Challenge" banner (always visible)
→ [Tap banner]
→ Daily screen: shows today's date, global attempt count, player's previous attempt if exists
→ [Tap "Begin"]
→ Memorization screen (same as Solo)
→ Recall screen (same as Solo)
→ Submit → Result screen
→ Result screen shows "Your rank: #47 of 312 players today" (updated in real time)
→ [Tap "View Leaderboard"] → Daily Leaderboard
```

#### Flow C — Multiplayer Session (Host)

```
Home → [Tap "Play With Friends"]
→ Multiplayer Lobby: 6-char code displays prominently, deep link copy button
→ Host sees live list of joined players
→ [Tap "Start"] (minimum 2 players; host can force-start solo for testing)
→ Server broadcasts seed + start_time
→ All players enter Memorization screen simultaneously
→ ... (game proceeds same as Solo)
→ After Submit: result uploads, loading state
→ Session Leaderboard reveals with all player scores ranked
→ [Tap "Play Again"] → new session in same lobby
```

#### Flow D — Upgrade to Premium

```
Any soft paywall trigger or tap "Go Premium" in Settings
→ Paywall screen: clear feature list, two pricing options (monthly / annual)
→ [Tap "Start 7-Day Free Trial"]
→ RevenueCat paywall sheet (native iOS/Android)
→ Purchase confirmed → app unlocks immediately
→ "Welcome to Premium" confirmation screen
→ Redirect to Home
```

#### Flow E — Account Creation (Optional)

```
Home → Settings → "Create Account"
→ Auth screen: email/password or "Continue with Apple" / "Continue with Google"
→ Email flow: enter email → receive 6-digit OTP → verify → set password
→ Account created → local guest progress migrates to account
→ Return to Home
```

### 3.3 Navigation Architecture

- **Bottom navigation bar:** Home | Daily | Multiplayer | Stats | Settings
- Stats tab shows paywall prompt for guests and free users; premium users see full stats.
- All game screens (Memorization, Recall, Result) are full-screen with no nav bar (immersive game state).
- Back navigation during active game shows a confirmation dialog ("Leave game? Your progress will be lost.")

---

## 4. Monetization

### 4.1 Pricing

| Plan | Price | Billing |
|---|---|---|
| Free | $0 | — |
| Monthly Premium | $3.99/month | Billed monthly |
| Annual Premium | $29.99/year | Billed annually (~$2.50/mo) |

7-day free trial on both plans (new subscribers only). Trial converts automatically unless cancelled.

### 4.2 Payment Infrastructure

- **iOS:** Apple In-App Purchase (StoreKit 2)
- **Android:** Google Play Billing
- **Management layer:** RevenueCat — handles entitlement verification, receipt validation, subscription state, webhooks, and cross-platform consistency.
- **Server-side verification:** All entitlement checks are server-verified via RevenueCat SDK. Client-side entitlement state is treated as a hint only; premium gates are always confirmed server-side before granting premium content (especially offline seed payloads and private group creation).

### 4.3 Paywall Triggers (Soft Gates)

| Event | Paywall Trigger |
|---|---|
| 4th solo game of the day | "You've used your 3 free games today." |
| Tapping Stats tab (no account) | "Track your progress with Premium." |
| Trying to create a private group | "Private groups are a Premium feature." |
| Accessing a Seasonal Pack | "Unlock seasonal tone packs with Premium." |
| Tapping offline mode toggle | "Download daily challenges offline with Premium." |

All soft gates use a dismissable bottom sheet — the player is never hard-blocked from the app. Dismissing the sheet returns them to the previous screen.

### 4.4 Free Tier Limits

- 3 solo games per 24-hour window (rolling, not calendar-day-based). Timer resets from the time of the first game.
- 1 Daily Challenge per UTC day.
- Join up to 3 multiplayer sessions per 24-hour window.
- Ads displayed between games (rewarded ad option: watch 30s ad to unlock 1 extra game).

### 4.5 Ad Strategy

- **Provider:** Google AdMob (banner between game results; interstitial after every 3rd game result).
- **Rewarded ads:** Player opts in to watch a 30-second rewarded ad to earn one extra solo game for the day.
- **Premium users:** No ads, ever. No rewarded ad option shown (not needed).
- No ads appear during active game sessions (Memorization or Recall screens).

### 4.6 Revenue Projections (12-month target)

| Metric | Target |
|---|---|
| Monthly active users | 40,000 |
| Premium subscribers | 1,600 (4%) |
| Monthly recurring revenue | ~$5,200 |
| Annual recurring revenue | ~$62,000 |
| AdMob CPM estimate | $2.50 |
| Monthly ad revenue | ~$1,400 |

---

## 5. Tech Architecture

### 5.1 Tech Stack

| Layer | Technology |
|---|---|
| Mobile client | Flutter 3.x (Dart) |
| Audio synthesis | Flutter `dart:ffi` + platform audio (AVAudioEngine on iOS, AudioTrack on Android) |
| Local storage | `shared_preferences` (settings, guest progress), `sqflite` (local history) |
| State management | Riverpod 2 |
| Navigation | Go Router |
| Backend | Supabase (PostgreSQL + Auth + Realtime + Edge Functions) |
| Payments | RevenueCat SDK |
| Analytics | PostHog (self-hosted or cloud) |
| Crash reporting | Sentry |
| CI/CD | GitHub Actions → Fastlane → App Store Connect / Google Play |

**Why Supabase over Firebase:** Supabase provides PostgreSQL (relational, queryable leaderboards), open-source (no vendor lock-in), built-in Realtime for multiplayer session state, and Row-Level Security for user data isolation. Firebase Firestore would require more complex querying for leaderboards.

### 5.2 System Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter Client                         │
│  ┌────────────┐  ┌───────────┐  ┌─────────────────────┐ │
│  │ Audio Eng  │  │ Game State │  │  RevenueCat SDK      │ │
│  │ (FFI/PCM)  │  │ (Riverpod) │  │  (entitlements)      │ │
│  └────────────┘  └───────────┘  └─────────────────────┘ │
└──────────────────┬───────────────────────────────────────┘
                   │ HTTPS / WebSocket
┌──────────────────▼───────────────────────────────────────┐
│                    Supabase                               │
│  ┌────────────┐  ┌────────────┐  ┌────────────────────┐  │
│  │ Auth       │  │ PostgreSQL  │  │ Realtime (WS)      │  │
│  │ (email/SSO)│  │ (game data) │  │ (multiplayer sync) │  │
│  └────────────┘  └────────────┘  └────────────────────┘  │
│  ┌────────────────────────────────────────────────────┐   │
│  │  Edge Functions (Deno)                              │   │
│  │  - generate_daily_seed                              │   │
│  │  - create_session / join_session / broadcast_start  │   │
│  │  - submit_result / fetch_leaderboard                │   │
│  │  - verify_premium (RevenueCat webhook handler)      │   │
│  └────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
         │ Webhooks
┌────────▼───────────┐
│   RevenueCat Cloud  │
│   (subscription     │
│    entitlements)    │
└────────────────────┘
```

### 5.3 Data Models

#### `users`
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
email           TEXT UNIQUE
display_name    TEXT
created_at      TIMESTAMPTZ DEFAULT now()
is_premium      BOOLEAN DEFAULT false
premium_until   TIMESTAMPTZ
revenuecat_id   TEXT
```

#### `game_sessions` (multiplayer)
```sql
id              UUID PRIMARY KEY
code            CHAR(6) UNIQUE NOT NULL
host_user_id    UUID REFERENCES users(id)
seed            BIGINT NOT NULL
mode            TEXT CHECK (mode IN ('solo', 'hard'))
status          TEXT CHECK (status IN ('waiting', 'active', 'complete'))
created_at      TIMESTAMPTZ DEFAULT now()
started_at      TIMESTAMPTZ
```

#### `session_players`
```sql
session_id      UUID REFERENCES game_sessions(id)
user_id         UUID REFERENCES users(id)  -- NULL for guests
guest_token     TEXT  -- ephemeral guest identifier
joined_at       TIMESTAMPTZ DEFAULT now()
is_ready        BOOLEAN DEFAULT false
PRIMARY KEY (session_id, COALESCE(user_id::TEXT, guest_token))
```

#### `game_results`
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
user_id         UUID REFERENCES users(id)  -- NULL for guests
guest_token     TEXT
session_id      UUID REFERENCES game_sessions(id)
seed            BIGINT NOT NULL
mode            TEXT
is_daily        BOOLEAN DEFAULT false
challenge_date  DATE  -- for daily challenges
total_score     NUMERIC(5,2)
tone_scores     JSONB  -- [{tone: 1, target_hz: 440, guess_hz: 438, score: 19.8}, ...]
submitted_at    TIMESTAMPTZ DEFAULT now()
```

#### `daily_challenges`
```sql
challenge_date  DATE PRIMARY KEY
seed            BIGINT NOT NULL UNIQUE
generated_at    TIMESTAMPTZ DEFAULT now()
```

#### `seasonal_packs`
```sql
id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
name            TEXT NOT NULL
description     TEXT
theme_tag       TEXT
released_at     DATE
seeds           BIGINT[]  -- ordered list of seeds for rounds in this pack
is_active       BOOLEAN DEFAULT true
```

#### `subscriptions` (mirror of RevenueCat state)
```sql
user_id         UUID REFERENCES users(id) PRIMARY KEY
plan            TEXT CHECK (plan IN ('monthly', 'annual'))
status          TEXT CHECK (status IN ('active', 'trial', 'expired', 'cancelled'))
current_period_end TIMESTAMPTZ
updated_at      TIMESTAMPTZ DEFAULT now()
```

### 5.4 Deterministic Tone Generation

This is the most critical algorithm in the product. It must be identical across all platforms.

**Algorithm: Seeded Logarithmic Frequency Generator**

```dart
/// Generates 5 unique frequencies in [minHz, maxHz] from a 64-bit seed.
/// Uses PCG32 as the underlying PRNG for quality and portability.
List<double> generateTones({
  required int seed,
  double minHz = 200.0,
  double maxHz = 1800.0,
  int count = 5,
}) {
  final prng = PCG32(seed);
  final Set<double> tones = {};
  final logMin = log(minHz);
  final logMax = log(maxHz);

  while (tones.length < count) {
    final raw = prng.nextDouble(); // uniform [0, 1)
    // Map to log scale, then back to Hz
    final hz = exp(logMin + raw * (logMax - logMin));
    final rounded = (hz * 10).round() / 10; // round to 0.1 Hz

    // Reject if too close to an existing tone (within 50 cents)
    bool tooClose = tones.any((t) {
      return (1200 * (log(rounded / t) / log(2))).abs() < 50;
    });

    if (!tooClose) tones.add(rounded);
  }

  return tones.toList()..sort(); // return ascending order
}
```

**PCG32 implementation:** A compact, self-contained Dart implementation of PCG32 (no external dependencies) must be bundled with the app. The full reference implementation is at [pcg-random.org](https://www.pcg-random.org/) and is available under Apache 2.0. The Dart port must match output bit-for-bit with the C reference.

**Server-side generation:** The same algorithm must be implemented in Deno (TypeScript) for the Edge Functions that generate daily seeds and verify submitted results. The TypeScript PCG32 port is included in the Edge Function bundle.

**Daily seed generation:** Each day's seed is generated server-side at 00:00 UTC using:
```
seed = PCG32(unix_timestamp_of_midnight_utc).next()
```
This is reproducible from the date alone, providing an additional integrity check.

**Multiplayer seed generation:** Session seeds are generated server-side at session start:
```
seed = PCG32(crypto.randomUUID().hashCode).next()
```

### 5.5 Audio Synthesis

**Platform-native synthesis (no audio files):**

- **iOS:** AVAudioEngine + AVAudioPlayerNode + AVAudioPCMBuffer. PCM buffer is pre-filled with sine wave samples at 44100 Hz sample rate.
- **Android:** AudioTrack in streaming mode. PCM buffer streamed from Dart via platform channel.

**Tone generation formula (per sample):**

```
sample[i] = amplitude × sin(2π × frequency × i / sampleRate)
```

With linear fade-in/out over the first and last `sampleRate × 0.01` samples (10ms).

**Hard mode overtone:**

```
sample[i] = 0.95 × amplitude × sin(2π × f × i / sr)
          + 0.05 × amplitude × sin(2π × f_harmonic × i / sr)
```

Where `f_harmonic` is the second harmonic (2×f) or third harmonic (3×f), deterministically chosen per tone from the seed.

**No audio files are bundled. No network audio is fetched. All sound is synthesized on-device.**

### 5.6 API Design (Supabase Edge Functions)

All endpoints require Supabase JWT auth header except where noted. Guest operations use an ephemeral `guest_token` (UUID stored in device local storage).

#### `POST /functions/v1/create-session`
**Auth:** Optional (guest or user)
**Body:** `{ mode: "solo" | "hard" }`
**Response:** `{ session_id, code, seed_broadcast_at: null }`

#### `POST /functions/v1/join-session`
**Auth:** Optional
**Body:** `{ code: "ABC123" }`
**Response:** `{ session_id, seed: null, player_count, status }`

#### `POST /functions/v1/start-session`
**Auth:** Required (host only)
**Body:** `{ session_id }`
**Response:** `{ seed, start_at: ISO8601 }`
*(Supabase Realtime broadcasts `session_start` event to all subscribers in the session channel)*

#### `POST /functions/v1/submit-result`
**Auth:** Optional
**Body:**
```json
{
  "session_id": "...",  // null for solo
  "seed": 1234567890,
  "mode": "solo",
  "is_daily": false,
  "challenge_date": null,
  "tone_guesses": [
    { "tone_index": 0, "guess_hz": 438.5 },
    ...
  ]
}
```
**Server-side:** Regenerates target frequencies from seed (determinism guarantee). Computes authoritative score. Rejects if deviation between client-computed and server-computed score > 0.1 points (anti-cheat).
**Response:** `{ result_id, total_score, tone_scores, rank }`

#### `GET /functions/v1/daily-leaderboard?date=YYYY-MM-DD&limit=50&offset=0`
**Auth:** None required
**Response:** `{ date, entries: [{ rank, display_name, total_score, mode }] }`

#### `GET /functions/v1/player-stats?user_id=...`
**Auth:** Required (own user only)
**Response:** `{ games_played, avg_score, best_score, score_history: [...], streak_days }`

#### `GET /functions/v1/seasonal-packs`
**Auth:** Premium entitlement required
**Response:** `{ packs: [{ id, name, description, theme_tag, round_count, released_at }] }`

#### `POST /functions/v1/offline-seeds`
**Auth:** Premium entitlement required
**Response:** `{ seeds: [{ date, seed, signed_payload }] }` — next 7 days

#### `POST /functions/v1/revenuecat-webhook`
**Auth:** RevenueCat webhook secret header
**Body:** RevenueCat event payload
**Action:** Updates `subscriptions` table, updates `users.is_premium`

### 5.7 Multiplayer Real-Time Sync

Uses Supabase Realtime (PostgreSQL-backed channels, WebSocket transport).

**Channel naming:** `session:{session_id}`

**Events broadcast:**
| Event | Payload | Trigger |
|---|---|---|
| `player_joined` | `{ guest_token_or_user_id, display_name, player_count }` | On join |
| `player_ready` | `{ player_id }` | Player taps Ready in lobby |
| `session_start` | `{ seed, start_at }` | Host taps Start |
| `result_submitted` | `{ player_id, total_score }` | On result submit |
| `leaderboard_update` | `{ entries }` | When all players have submitted |

**Client-side sync:**
- Client subscribes to channel on join.
- `session_start` event triggers local tone generation from the received seed.
- `start_at` is a UTC timestamp 3 seconds in the future, giving all clients time to prepare audio buffers before the memorization phase starts.
- Clock skew tolerance: ±500ms. If device clock is off by more than 2s, the client shows a "Device clock out of sync" warning.

### 5.8 Security

- **Anti-cheat:** All scores are computed server-side from the authoritative seed. Client-submitted scores are verified; submissions that deviate from server-computed scores by >0.1 points are rejected.
- **Seed secrecy:** For active multiplayer sessions (status: 'waiting'), seeds are stored server-side and not sent to clients until the host starts the session. This prevents a player from pre-generating tones.
- **RLS:** Supabase Row Level Security ensures users can only read their own `game_results` and `subscriptions` rows.
- **Guest tokens:** Generated as a UUID on first app launch, stored in device secure storage. Guest tokens are not tied to any identity and expire after 90 days of inactivity.
- **Premium verification:** RevenueCat entitlement is verified on every premium-gated API call. Client-side entitlement state is treated as an optimistic UI hint only.

### 5.9 Offline Architecture

Premium users' offline flow:

1. App background fetch (iOS) / WorkManager (Android) triggers `POST /offline-seeds` daily at ~00:05 UTC.
2. Response contains signed seed payloads for the next 7 daily challenges.
3. Seeds are stored in device secure storage (flutter_secure_storage).
4. On daily challenge load, app checks connectivity. If offline and premium, loads cached seed.
5. After game completes offline, result is queued in a local pending queue (sqflite).
6. On next connectivity, pending results are uploaded. If the challenge date has passed, the result is saved to personal history but not submitted to the leaderboard.

---

## 6. Analytics

### 6.1 Analytics Stack

- **Tool:** PostHog (self-hosted on Supabase Postgres, or PostHog Cloud)
- **SDK:** `posthog_flutter` package
- **PII policy:** No PII in event properties. User ID is a hashed UUID. No email addresses, names, or device IDs in event payloads.

### 6.2 Core Events

| Event | Properties | Trigger |
|---|---|---|
| `app_opened` | `session_id`, `platform` | App foreground |
| `game_started` | `mode`, `is_daily`, `is_hard`, `is_premium` | Memorization screen loads |
| `tone_replayed` | `tone_index`, `replay_count` | Player taps tone indicator |
| `game_submitted` | `mode`, `total_score`, `time_spent_memorizing`, `time_spent_recalling`, `per_tone_scores[]` | Submit tapped |
| `result_shared` | `mode`, `total_score` | Share button tapped |
| `paywall_shown` | `trigger_source` | Paywall sheet opens |
| `paywall_dismissed` | `trigger_source` | Paywall dismissed without purchase |
| `subscription_started` | `plan`, `is_trial` | RevenueCat purchase confirmed |
| `subscription_cancelled` | `plan`, `days_active` | RevenueCat cancellation webhook |
| `session_created` | — | Multiplayer session created |
| `session_joined` | — | Multiplayer session joined |
| `daily_challenge_completed` | `score`, `rank`, `player_count_at_time` | Daily result submitted |

### 6.3 Key Metrics & Dashboards

**Retention Dashboard**
- D1, D7, D30 retention curves
- Breakdown: guest vs. free account vs. premium

**Monetization Dashboard**
- Paywall impression rate (per trigger source)
- Paywall conversion rate
- Trial-to-paid conversion rate
- MRR, ARR, churn rate
- ARPU

**Engagement Dashboard**
- Average games/day per active user
- Average score over time (learning curve)
- Tone replay count per game (proxy for engagement depth)
- Hard mode adoption rate
- Multiplayer session creation and join rates
- Daily Challenge participation rate

**Audio Quality Dashboard**
- Time spent in memorization phase vs. maximum 300s (tracks if players use full time)
- Submission rate (games started vs. games submitted — measures rage-quit rate)
- Per-tone average deviation by tone position (are certain slider positions systematically harder?)

### 6.4 A/B Testing Plan

| Test | Variants | Success Metric |
|---|---|---|
| Paywall copy | Benefit-led vs. Feature-led | Conversion rate |
| Daily Challenge placement | Home banner vs. Tab | Daily participation rate |
| Rewarded ad opt-in | After 2nd game vs. After 3rd game | Ad revenue + retention impact |
| Hard mode unlock | Always available vs. After 10 games | Hard mode adoption |

---

## 7. Roadmap

### 7.1 MVP (v1.0) — Target: 12 Weeks

**Scope:** Core game loop complete and shippable. All listed features at launch level.

| Week | Milestone |
|---|---|
| 1–2 | Project setup, Flutter scaffold, audio synthesis (iOS + Android), PCG32 implementation |
| 3–4 | Game loop (Memorization + Recall + Scoring), local-only play |
| 5–6 | Supabase setup, Auth, daily challenge generation, result submission, daily leaderboard |
| 7–8 | Multiplayer lobby + session sync (Supabase Realtime), Hard mode |
| 9–10 | RevenueCat integration, paywall, premium gates, AdMob |
| 11 | Stats screen (premium), offline seeds (premium), seasonal pack framework |
| 12 | QA, accessibility audit, App Store / Google Play submission prep |

**MVP Feature List:**
- [x] Solo mode (3 games/day free, unlimited premium)
- [x] Daily Challenge (1/day, all users)
- [x] Hard mode
- [x] Multiplayer (shared session, up to 8 players)
- [x] Guest play (no account required)
- [x] Account creation (email + Apple/Google SSO)
- [x] Scoring (per-tone cents-based)
- [x] Result screen with waveform overlay
- [x] Share card generation
- [x] Daily leaderboard
- [x] Premium subscription (monthly + annual via RevenueCat)
- [x] AdMob (banner + interstitial + rewarded)
- [x] Offline daily seeds (premium)
- [x] Stats screen — score history graph (premium)
- [x] PostHog analytics
- [x] Sentry crash reporting

**NOT in MVP:**
- Seasonal tone packs (v2)
- Private persistent groups (v2)
- Social features (v2)
- Desktop/web (v3)

### 7.2 v2.0 — Target: 6 Months Post-Launch

**Theme:** Depth for retained users + community.

| Feature | Priority | Notes |
|---|---|---|
| Seasonal tone packs | P0 | Quarterly release, 10-30 rounds per pack |
| Private persistent groups | P0 | Premium: named groups, shared history, group leaderboard |
| Score breakdown animation | P1 | Animated per-tone reveal on result screen |
| Streak system | P1 | Daily streak counter, streak-protect item (premium) |
| Tone pack creator (internal tool) | P1 | Admin tool for generating and QA-ing seasonal packs |
| Push notifications | P1 | Daily challenge reminder, multiplayer invite |
| iPad + tablet layout | P2 | Adaptive layout for larger screens |
| In-game tutorial | P2 | Optional guided first game |
| Accessibility | P2 | VoiceOver/TalkBack labels, high-contrast mode, reduced motion |
| Widget — Daily Challenge | P3 | iOS/Android home screen widget |
| Spectator mode | P3 | Watch live multiplayer sessions |

### 7.3 v3.0 — Target: 12 Months Post-Launch

**Theme:** Platform expansion + social.

| Feature | Notes |
|---|---|
| Web app (Flutter Web or React) | Browser-playable version for discoverability |
| Public player profiles | Optional public profile with career stats |
| Tone pack marketplace | Community-created packs (curated by Echoed team) |
| Corporate / classroom licenses | Team subscriptions for music schools |
| Advanced analytics for premium | Percentile rank, improvement rate, weakest tone position |
| API for third-party integrations | Embed Echoed rounds in other apps (e.g. music learning platforms) |

---

## Appendix A — Tone Slider UX Specification

### Logarithmic Slider Mapping

The slider widget maps a linear drag position [0, 1] to a logarithmic frequency:

```
f(p) = exp(ln(200) + p × (ln(1800) - ln(200)))
```

Where `p` is the normalized slider position (0 = bottom, 1 = top).

**Tick marks** (visual only, not snap points) at notable Hz values:
200, 300, 450, 600, 800, 1000, 1200, 1500, 1800

**No snapping.** The slider is continuous — no musical scale alignment, no Hz rounding during drag. The player can position to any value. Values are rounded to 0.1 Hz on submit only.

**Live frequency readout:** A floating label above the slider thumb shows current Hz value during drag. Updates at 60fps.

**Speaker preview button:** Tapping the small speaker icon next to a slider plays the player's current guess frequency as a 0.5-second tone. This preview does not affect scoring.

---

## Appendix B — Score Card / Share Asset

The share card is generated on-device (no server round-trip) as a rasterized image:

- **Dimensions:** 1080×1080px (square for Instagram) and 1080×1920px (story format)
- **Content:** Echoed logo (top), game mode label, score (large numeral), grade label, 5 waveform mini-charts (target vs. guess), game code (for multiplayer), date (for daily), footer with app store link text
- **No photographs, no stock imagery.** All visual elements are generated programmatically (Flutter CustomPainter).

---

## Appendix C — Accessibility Requirements (MVP Baseline)

| Requirement | Detail |
|---|---|
| VoiceOver / TalkBack | All interactive elements have semantic labels. Tone indicators announce "Tone 1 — tap to play." Sliders announce current Hz value on change. |
| Minimum tap target | 44×44pt (Apple HIG / Material guidelines) |
| Reduced motion | If device reduced-motion is enabled, waveform overlay animation is replaced with a static comparison view |
| Contrast | All text meets WCAG AA (4.5:1 minimum) |
| Font scaling | UI supports Dynamic Type / font scale up to 150% without layout breakage |

---

## Appendix D — Localization Plan

**MVP:** English only.
**v2:** Spanish, French, German, Japanese, Korean (5 additional locales). No audio content is language-dependent — only UI copy requires translation.

---

*End of Document*
