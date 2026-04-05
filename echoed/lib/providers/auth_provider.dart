import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/revenuecat_service.dart';

// ── Guest Token ──────────────────────────────────────────────────────────────

const String _guestTokenKey = 'echoed_guest_token';

/// Provides a persistent guest token (UUID) stored in SharedPreferences.
/// Used for guest play and anonymous session participation.
final guestTokenProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  var token = prefs.getString(_guestTokenKey);
  if (token == null) {
    token = const Uuid().v4();
    await prefs.setString(_guestTokenKey, token);
  }
  return token;
});

// ── Auth State ───────────────────────────────────────────────────────────────

/// Streams the Supabase auth state changes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current Supabase user (null if not signed in / guest).
final currentSupabaseUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// ── User Profile ─────────────────────────────────────────────────────────────

/// Fetches and caches the full UserModel from Supabase for the logged-in user.
final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final supabase = ref.watch(supabaseServiceProvider);
  final authState = ref.watch(authStateProvider);

  // Re-fetch on auth state change
  authState.when(
    data: (_) {},
    loading: () {},
    error: (_, __) {},
  );

  final user = supabase.currentUser;
  if (user == null) return null;
  return supabase.fetchUserProfile(user.id);
});

// ── Premium Status ────────────────────────────────────────────────────────────

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

/// Whether the current user has an active premium entitlement.
/// Checks RevenueCat first (authoritative), falls back to Supabase user record.
final isPremiumProvider = FutureProvider<bool>((ref) async {
  final rcService = ref.watch(revenueCatServiceProvider);
  return rcService.isPremium();
});

// ── Auth Actions ──────────────────────────────────────────────────────────────

/// Notifier for auth actions (sign-in, sign-up, sign-out).
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._supabase, this._rcService) : super(const AsyncValue.data(null));

  final SupabaseService _supabase;
  final RevenueCatService _rcService;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      final user = _supabase.currentUser;
      if (user != null) {
        await _rcService.loginUser(user.id);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _supabase.signInWithEmail(email: email, password: password);
      final user = _supabase.currentUser;
      if (user != null) {
        await _rcService.loginUser(user.id);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _supabase.signOut();
      await _rcService.logoutUser();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(
    ref.watch(supabaseServiceProvider),
    ref.watch(revenueCatServiceProvider),
  );
});
