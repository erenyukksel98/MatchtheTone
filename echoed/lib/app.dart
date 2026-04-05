import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/game_memorize_screen.dart';
import 'screens/game_recreate_screen.dart';
import 'screens/results_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/daily_screen.dart';
import 'screens/multiplayer_lobby_screen.dart';

/// Root application widget — wires together theme, routing, and Riverpod.
class EchoedApp extends ConsumerWidget {
  const EchoedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Echoed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}

/// GoRouter instance — exposed as a Riverpod provider so it can read auth state.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // No redirect logic needed — guest play is supported without auth.
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (ctx, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/daily',
        name: 'daily',
        builder: (ctx, state) => const DailyScreen(),
      ),
      GoRoute(
        path: '/play/memorize',
        name: 'memorize',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return GameMemorizeScreen(
            seed: extra['seed'] as int? ?? 0,
            mode: extra['mode'] as String? ?? 'solo',
            sessionCode: extra['sessionCode'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/play/recreate',
        name: 'recreate',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>;
          return GameRecreateScreen(
            seed: extra['seed'] as int,
            mode: extra['mode'] as String,
            targetFrequencies: List<double>.from(extra['frequencies'] as List),
            sessionCode: extra['sessionCode'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/results',
        name: 'results',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ResultsScreen(
            targetFrequencies: List<double>.from(extra['targetFrequencies'] as List),
            guessedFrequencies: List<double>.from(extra['guessedFrequencies'] as List),
            seed: extra['seed'] as int,
            mode: extra['mode'] as String,
            sessionCode: extra['sessionCode'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/leaderboard',
        name: 'leaderboard',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return LeaderboardScreen(
            date: extra['date'] as String?,
            sessionCode: extra['sessionCode'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/multi/lobby',
        name: 'lobby',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MultiplayerLobbyScreen(
            sessionCode: extra['sessionCode'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (ctx, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/premium',
        name: 'paywall',
        builder: (ctx, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return PaywallScreen(
            triggerSource: extra['triggerSource'] as String? ?? 'settings',
          );
        },
      ),
    ],
  );
});
