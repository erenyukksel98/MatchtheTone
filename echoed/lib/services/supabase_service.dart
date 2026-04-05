import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

/// ---------------------------------------------------------------------------
/// SupabaseService — wraps all Supabase calls: auth, database, realtime.
/// ---------------------------------------------------------------------------
class SupabaseService {
  SupabaseService();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Auth ───────────────────────────────────────────────────────────────────

  /// Current Supabase auth session (null if guest).
  Session? get currentSession => _client.auth.currentSession;

  /// Current Supabase user (null if guest).
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: displayName != null ? {'display_name': displayName} : null,
    );
    if (response.user != null && displayName != null) {
      await _upsertUser(response.user!, displayName: displayName);
    }
    return response;
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> _upsertUser(User user, {String? displayName}) async {
    await _client.from('users').upsert({
      'id': user.id,
      'email': user.email,
      'display_name': displayName ?? user.email?.split('@').first,
    });
  }

  // ── User profile ───────────────────────────────────────────────────────────

  Future<UserModel?> fetchUserProfile(String userId) async {
    final data = await _client.from('users').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return UserModel.fromJson(data);
  }

  Future<void> updateDisplayName(String userId, String displayName) async {
    await _client.from('users').update({'display_name': displayName}).eq('id', userId);
  }

  // ── Daily challenge ────────────────────────────────────────────────────────

  /// Fetch today's daily challenge seed from Supabase.
  /// Returns null if not yet generated (client should fall back to local generation).
  Future<int?> fetchDailySeed(String dateStr) async {
    final data = await _client
        .from('daily_challenges')
        .select('seed')
        .eq('challenge_date', dateStr)
        .maybeSingle();
    if (data == null) return null;
    return data['seed'] as int?;
  }

  // ── Game results ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitResult({
    required String? userId,
    required String? guestToken,
    required String? sessionId,
    required int seed,
    required String mode,
    required bool isDaily,
    required String? challengeDate,
    required double totalScore,
    required List<Map<String, dynamic>> toneScores,
  }) async {
    final payload = {
      'user_id': userId,
      'guest_token': guestToken,
      'session_id': sessionId,
      'seed': seed,
      'mode': mode,
      'is_daily': isDaily,
      'challenge_date': challengeDate,
      'total_score': totalScore,
      'tone_scores': toneScores,
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await _client
        .from('game_results')
        .insert(payload)
        .select()
        .single();
    return response;
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────

  Future<List<LeaderboardEntry>> fetchDailyLeaderboard({
    required String dateStr,
    int limit = 50,
    int offset = 0,
  }) async {
    // Uses a Supabase view/function that computes rank
    final data = await _client
        .from('daily_leaderboard')
        .select()
        .eq('challenge_date', dateStr)
        .order('total_score', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).asMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      map['rank'] = entry.key + 1 + offset;
      return LeaderboardEntry.fromJson(map);
    }).toList();
  }

  Future<List<LeaderboardEntry>> fetchSessionLeaderboard(String sessionId) async {
    final data = await _client
        .from('game_results')
        .select('*, users(display_name)')
        .eq('session_id', sessionId)
        .order('total_score', ascending: false);

    return (data as List).asMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      final user = map['users'] as Map<String, dynamic>?;
      map['display_name'] = user?['display_name'] ?? 'Guest';
      map['rank'] = entry.key + 1;
      return LeaderboardEntry.fromJson(map);
    }).toList();
  }

  // ── Player stats ───────────────────────────────────────────────────────────

  Future<PlayerStats?> fetchPlayerStats(String userId) async {
    final data = await _client.rpc('get_player_stats', params: {'p_user_id': userId});
    if (data == null) return null;
    return PlayerStats.fromJson(data as Map<String, dynamic>);
  }

  // ── Multiplayer sessions ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> createSession({
    required String? userId,
    required String? guestToken,
    required String mode,
    required String code,
    required int seed,
  }) async {
    final data = await _client.from('game_sessions').insert({
      'code': code,
      'host_user_id': userId,
      'seed': seed,
      'mode': mode,
      'status': 'waiting',
    }).select().single();
    return data;
  }

  Future<Map<String, dynamic>?> fetchSessionByCode(String code) async {
    return _client.from('game_sessions').select().eq('code', code).maybeSingle();
  }

  Future<void> joinSession({
    required String sessionId,
    required String? userId,
    required String? guestToken,
  }) async {
    await _client.from('session_players').upsert({
      'session_id': sessionId,
      'user_id': userId,
      'guest_token': guestToken,
    });
  }

  Future<void> markPlayerReady({
    required String sessionId,
    required String? userId,
    required String? guestToken,
  }) async {
    final filter = userId != null
        ? _client.from('session_players').update({'is_ready': true}).eq('session_id', sessionId).eq('user_id', userId)
        : _client.from('session_players').update({'is_ready': true}).eq('session_id', sessionId).eq('guest_token', guestToken!);
    await filter;
  }

  Future<void> startSession(String sessionId, int seed) async {
    await _client.from('game_sessions').update({
      'status': 'active',
      'started_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  /// Subscribe to a multiplayer session channel.
  RealtimeChannel subscribeToSession({
    required String sessionId,
    required void Function(Map<String, dynamic> payload) onEvent,
  }) {
    return _client
        .channel('session:$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'game_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) => onEvent(payload.newRecord ?? {}),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'session_players',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'session_id',
            value: sessionId,
          ),
          callback: (payload) => onEvent(payload.newRecord ?? {}),
        )
        .subscribe();
  }
}

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});
