// lib/core/utils/app_router.dart
// Centralised routing with go_router.
// Auth redirect is handled here — never in individual screens.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shatterforge/presentation/screens/battle/battle_screen.dart';

import '../../presentation/providers/app_providers.dart';
import '../../data/models/battle_args.dart';

// Route name constants — never use raw strings
class Routes {
  Routes._();
  static const String splash = '/';
  static const String home = '/home';
  static const String builder = '/builder';
  static const String battle = '/battle';
  static const String profile = '/profile';
  static const String leaderboard = '/leaderboard';
  static const String shop = '/shop';
  static const String signIn = '/auth/signin';
  static const String register = '/auth/register';
  static const String match = '/match/:matchId';
  static const String replay = '/replay/:replayId';
}

// Placeholder screens until full implementation
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0E),
      body: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFFF6B1A),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // Listenable that triggers router refresh on auth change
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final uid = ref.read(currentUidProvider);
      final isOnAuth = state.matchedLocation.startsWith('/auth');
      final isOnSplash = state.matchedLocation == Routes.splash;

      // Signed out — redirect to sign-in (except already on auth or splash)
      if (uid == null && !isOnAuth && !isOnSplash) {
        return Routes.signIn;
      }

      // Signed in but on auth screen — go home
      if (uid != null && isOnAuth) {
        return Routes.home;
      }

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const _PlaceholderScreen('SHATTERFORGE'),
      ),
      GoRoute(
        path: Routes.home,
        builder: (_, __) => const _PlaceholderScreen('Home'),
      ),
      GoRoute(
        path: Routes.builder,
        builder: (_, __) => const _PlaceholderScreen('Base Builder'),
      ),
      GoRoute(
        path: Routes.battle,
        builder: (context, state) {
          // Pass map + selected balls via extra
          final args = state.extra as BattleArgs;
          return BattleScreen(
            map: args.map,
            selectedBalls: args.selectedBalls,
          );
        },
      ),
      GoRoute(
        path: Routes.profile,
        builder: (_, __) => const _PlaceholderScreen('Profile'),
      ),
      GoRoute(
        path: Routes.leaderboard,
        builder: (_, __) => const _PlaceholderScreen('Leaderboard'),
      ),
      GoRoute(
        path: Routes.shop,
        builder: (_, __) => const _PlaceholderScreen('Shop'),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (_, __) => const _PlaceholderScreen('Sign In'),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, __) => const _PlaceholderScreen('Register'),
      ),
      GoRoute(
        path: '/match/:matchId',
        builder: (_, state) =>
            _PlaceholderScreen('Match ${state.pathParameters['matchId']}'),
      ),
      GoRoute(
        path: '/replay/:replayId',
        builder: (_, state) =>
            _PlaceholderScreen('Replay ${state.pathParameters['replayId']}'),
      ),
    ],
    errorBuilder: (_, state) =>
        _PlaceholderScreen('Route not found: ${state.error}'),
  );
});

// Notifier that triggers router refresh when auth state changes
class _AuthNotifier extends ChangeNotifier {
  final Ref _ref;

  _AuthNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
