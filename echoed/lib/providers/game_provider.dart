import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../models/game_model.dart';
import '../models/tone_model.dart';
import '../services/audio_service.dart';
import '../services/supabase_service.dart';
import '../services/scoring_service.dart';
import '../services/tone_generator.dart';
import 'auth_provider.dart';

// ── Daily play count guard ────────────────────────────────────────────────────

const String _playCountKey = 'echoed_daily_play_count';
const String _playDateKey = 'echoed_daily_play_date';

/// Reads and manages the rolling daily play count for free users.
class PlayLimitNotifier extends StateNotifier<int> {
  PlayLimitNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_playDateKey);
    final today = _todayKey();
    if (storedDate != today) {
      // New day — reset counter
      await prefs.setString(_playDateKey, today);
      await prefs.setInt(_playCountKey, 0);
      state = 0;
    } else {
      state = prefs.getInt(_playCountKey) ?? 0;
    }
  }

  Future<void> increment() async {
    final prefs = await SharedPreferences.getInstance();
    final newCount = state + 1;
    await prefs.setString(_playDateKey, _todayKey());
    await prefs.setInt(_playCountKey, newCount);
    state = newCount;
  }

  bool canPlay(bool isPremium) {
    if (isPremium) return true;
    return state < AppConstants.freeGamesPerDay;
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

final playLimitProvider = StateNotifierProvider<PlayLimitNotifier, int>((ref) {
  return PlayLimitNotifier();
});

// ── Session code generator ────────────────────────────────────────────────────

/// Generates a cryptographically random 6-character alphanumeric game code.
String generateSessionCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous chars (0,O,1,I)
  final rng = math.Random.secure();
  return List.generate(AppConstants.sessionCodeLength, (_) => chars[rng.nextInt(chars.length)]).join();
}

// ── Game State Notifier ───────────────────────────────────────────────────────

class GameNotifier extends StateNotifier<GameModel?> {
  GameNotifier(this._audio, this._supabase, this._ref) : super(null);

  final AudioService _audio;
  final SupabaseService _supabase;
  final Ref _ref;

  /// Initialize a new solo or hard mode game.
  Future<void> startSoloGame({bool hardMode = false}) async {
    final seed = math.Random.secure().nextInt(0x7FFFFFFF);
    await _initGame(
      seed: seed,
      mode: hardMode ? 'hard' : 'solo',
      isHardMode: hardMode,
    );
  }

  /// Initialize a daily challenge game.
  Future<void> startDailyChallenge({bool hardMode = false}) async {
    final today = DateTime.now().toUtc();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Try server-generated seed first; fall back to local deterministic seed
    int seed = ToneGenerator.dailySeedForDate(today);
    try {
      final serverSeed = await _supabase.fetchDailySeed(dateStr);
      if (serverSeed != null) seed = serverSeed;
    } catch (_) {}

    await _initGame(
      seed: seed,
      mode: hardMode ? 'hard' : 'daily',
      isHardMode: hardMode,
      isDaily: true,
    );
  }

  /// Join an existing multiplayer session by code.
  Future<String?> joinOrCreateMultiplayerSession({
    required String? code,
    bool isHost = false,
  }) async {
    final userId = _supabase.currentUser?.id;
    final guestToken = await _ref.read(guestTokenProvider.future);

    if (isHost || code == null) {
      // Host: generate code + seed on server
      final sessionCode = generateSessionCode();
      final seed = math.Random.secure().nextInt(0x7FFFFFFF);
      final session = await _supabase.createSession(
        userId: userId,
        guestToken: guestToken,
        mode: 'solo',
        code: sessionCode,
        seed: seed,
      );
      await _supabase.joinSession(
        sessionId: session['id'] as String,
        userId: userId,
        guestToken: guestToken,
      );
      return sessionCode;
    } else {
      // Guest: look up session by code
      final session = await _supabase.fetchSessionByCode(code.toUpperCase());
      if (session == null) return null;
      final sessionId = session['id'] as String;
      final seed = session['seed'] as int;

      await _supabase.joinSession(
        sessionId: sessionId,
        userId: userId,
        guestToken: guestToken,
      );

      await _initGame(
        seed: seed,
        mode: 'multiplayer',
        sessionCode: code.toUpperCase(),
        isHardMode: false,
      );
      return code;
    }
  }

  /// Begin game with a specific session code (host scenario after lobby).
  Future<void> startMultiplayerGame({
    required String sessionCode,
    required int seed,
    bool hardMode = false,
  }) async {
    await _initGame(
      seed: seed,
      mode: hardMode ? 'hard' : 'multiplayer',
      isHardMode: hardMode,
      sessionCode: sessionCode,
    );
  }

  Future<void> _initGame({
    required int seed,
    required String mode,
    bool isHardMode = false,
    bool isDaily = false,
    String? sessionCode,
  }) async {
    final frequencies = ToneGenerator.generateFrequencies(seed: seed);
    final tones = frequencies
        .asMap()
        .entries
        .map((e) => ToneModel(index: e.key, targetHz: e.value))
        .toList();

    state = GameModel(
      seed: seed,
      mode: mode,
      tones: tones,
      phase: GamePhase.idle,
      sessionCode: sessionCode,
      isHardMode: isHardMode,
    );

    // Preload audio in background
    _audio.preloadTones(
      frequencies: frequencies,
      seed: seed,
      hardMode: isHardMode,
    );
  }

  // ── Memorization phase ─────────────────────────────────────────────────────

  void beginMemorization() {
    if (state == null) return;
    state = state!.copyWith(
      phase: GamePhase.memorizing,
      memorizeStartTime: DateTime.now(),
    );
  }

  Future<void> playTone(int index) async {
    final g = state;
    if (g == null) return;
    await _audio.playTone(
      frequencies: g.tones.map((t) => t.targetHz).toList(),
      index: index,
      seed: g.seed,
      hardMode: g.isHardMode,
    );
  }

  void endMemorization() {
    if (state == null) return;
    _audio.stop();
    state = state!.copyWith(
      phase: GamePhase.recalling,
      recallStartTime: DateTime.now(),
    );
  }

  // ── Recall phase ──────────────────────────────────────────────────────────

  Future<void> previewGuess(double hz) async {
    await _audio.playPreviewHz(hz);
  }

  Future<GameModel?> submitGuesses(List<double> guesses) async {
    final g = state;
    if (g == null) return null;

    // Compute scores
    final scoredTones = ScoringService.scoreRound(
      tones: g.tones,
      guesses: guesses,
    );
    final total = ScoringService.totalScore(scoredTones);
    final grade = ScoringService.gradeLabel(total);

    final completed = g.copyWith(
      tones: scoredTones,
      phase: GamePhase.complete,
      totalScore: total,
      gradeLabel: grade,
    );
    state = completed;

    // Submit to Supabase in background
    _submitToServer(completed, guesses);

    // Increment play count for free users
    _ref.read(playLimitProvider.notifier).increment();

    return completed;
  }

  Future<void> _submitToServer(GameModel game, List<double> guesses) async {
    try {
      final userId = _supabase.currentUser?.id;
      final guestToken = await _ref.read(guestTokenProvider.future);
      final today = DateTime.now().toUtc();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final toneScores = game.tones
          .map((t) => {
                'tone_index': t.index,
                'target_hz': t.targetHz,
                'guess_hz': t.guessHz,
                'score_cents': t.scoreCents,
                'score_points': t.scorePoints,
              })
          .toList();

      await _supabase.submitResult(
        userId: userId,
        guestToken: userId == null ? guestToken : null,
        sessionId: null, // TODO: wire session ID for multiplayer
        seed: game.seed,
        mode: game.mode,
        isDaily: game.mode == 'daily',
        challengeDate: game.mode == 'daily' ? dateStr : null,
        totalScore: game.totalScore ?? 0,
        toneScores: toneScores,
      );
    } catch (_) {
      // Submit is best-effort; game result is already shown locally.
    }
  }

  void resetGame() {
    _audio.stop();
    state = null;
  }
}

final gameNotifierProvider = StateNotifierProvider<GameNotifier, GameModel?>((ref) {
  return GameNotifier(
    ref.watch(audioServiceProvider),
    ref.watch(supabaseServiceProvider),
    ref,
  );
});

// ── Streak provider ────────────────────────────────────────────────────────────

const String _streakCountKey = 'echoed_streak_count';
const String _streakLastDateKey = 'echoed_streak_last_date';

/// Reads the current consecutive-days streak from SharedPreferences.
/// A streak increments when the user completes at least one game on a new UTC day.
/// Call [StreakNotifier.recordGamePlayed] after any game completion.
class StreakNotifier extends StateNotifier<int> {
  StreakNotifier() : super(0) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_streakCountKey) ?? 0;
    state = streak;
  }

  String _todayKey() {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> recordGamePlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString(_streakLastDateKey);
    if (lastDate == today) return; // already recorded today

    final yesterday = () {
      final d = DateTime.now().toUtc().subtract(const Duration(days: 1));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }();

    final newStreak = (lastDate == yesterday) ? (state + 1) : 1;
    await prefs.setInt(_streakCountKey, newStreak);
    await prefs.setString(_streakLastDateKey, today);
    state = newStreak;
  }
}

final streakProvider = StateNotifierProvider<StreakNotifier, int>(
  (_) => StreakNotifier(),
);
