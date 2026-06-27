// lib/domain/usecases/match/match_controller.dart
// MatchController — Riverpod StateNotifier for the complete match FSM.
//
// States: idle → matchmaking → planning → attacking → coreDestroyed / allBallsSpent → results
//
// This class owns:
//   • Match phase transitions
//   • Planning phase countdown
//   • Ball inventory management (which balls the attacker brought)
//   • Match result calculation (stars, coins, XP)
//   • Replay event recording (for Phase 3 replay system)
//
// ShatterforgeGame communicates up via MatchController via MatchEventCallback.
// HUD widgets watch MatchController's state.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shatterforge/domain/entities/ball_entity.dart';
import 'package:shatterforge/domain/entities/map_entity.dart';
import 'package:shatterforge/core/constants/game_constants.dart';

// ─── Match State ──────────────────────────────────────────────────────────────

enum MatchPhase {
  idle,
  loadingMap,
  planning,   // countdown before attack; player picks ball order
  attacking,  // balls in flight, physics running
  victory,    // attacker destroyed Core
  defeat,     // attacker ran out of balls
  results,    // star/coin/XP screen
}

class MatchState {
  const MatchState({
    this.phase = MatchPhase.idle,
    this.map,
    this.selectedBalls = const [],
    this.planningSecondsRemaining = GameConstants.planningPhaseSeconds,
    this.ballsUsed = 0,
    this.wallsDestroyed = 0,
    this.chainReactions = 0,
    this.starsEarned = 0,
    this.coinsEarned = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final MatchPhase phase;
  final MapEntity? map;
  final List<BallDefinition> selectedBalls;
  final int planningSecondsRemaining;
  final int ballsUsed;
  final int wallsDestroyed;
  final int chainReactions;
  final int starsEarned;
  final int coinsEarned;
  final bool isLoading;
  final String? errorMessage;

  int get ballsRemaining => selectedBalls.length - ballsUsed;
  bool get isPlanning => phase == MatchPhase.planning;
  bool get isAttacking => phase == MatchPhase.attacking;
  bool get isFinished =>
      phase == MatchPhase.victory ||
      phase == MatchPhase.defeat ||
      phase == MatchPhase.results;

  MatchState copyWith({
    MatchPhase? phase,
    MapEntity? map,
    List<BallDefinition>? selectedBalls,
    int? planningSecondsRemaining,
    int? ballsUsed,
    int? wallsDestroyed,
    int? chainReactions,
    int? starsEarned,
    int? coinsEarned,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MatchState(
      phase: phase ?? this.phase,
      map: map ?? this.map,
      selectedBalls: selectedBalls ?? this.selectedBalls,
      planningSecondsRemaining:
          planningSecondsRemaining ?? this.planningSecondsRemaining,
      ballsUsed: ballsUsed ?? this.ballsUsed,
      wallsDestroyed: wallsDestroyed ?? this.wallsDestroyed,
      chainReactions: chainReactions ?? this.chainReactions,
      starsEarned: starsEarned ?? this.starsEarned,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ─── Controller ───────────────────────────────────────────────────────────────

class MatchController extends StateNotifier<MatchState> {
  MatchController() : super(const MatchState());

  Timer? _planningTimer;

  // ─── Phase Transitions ────────────────────────────────────────────────────

  /// Load a specific map and enter planning phase.
  Future<void> startMatch({
    required MapEntity map,
    required List<BallDefinition> selectedBalls,
  }) async {
    state = state.copyWith(
      phase: MatchPhase.loadingMap,
      map: map,
      selectedBalls: selectedBalls,
      ballsUsed: 0,
      wallsDestroyed: 0,
      chainReactions: 0,
      planningSecondsRemaining: GameConstants.planningPhaseSeconds,
      isLoading: true,
      errorMessage: null,
    );

    // Simulate async map load (Phase 3: fetch from Firestore)
    await Future.delayed(const Duration(milliseconds: 400));

    state = state.copyWith(
      phase: MatchPhase.planning,
      isLoading: false,
    );

    _startPlanningCountdown();
  }

  void _startPlanningCountdown() {
    _planningTimer?.cancel();
    _planningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.planningSecondsRemaining - 1;
      if (remaining <= 0) {
        timer.cancel();
        _enterAttackPhase();
      } else {
        state = state.copyWith(planningSecondsRemaining: remaining);
      }
    });
  }

  /// Player manually ends planning phase early.
  void skipPlanningPhase() {
    _planningTimer?.cancel();
    _enterAttackPhase();
  }

  void _enterAttackPhase() {
    state = state.copyWith(phase: MatchPhase.attacking);
    // ShatterforgeGame.startAttackPhase() is called from BattleScreen
    // via a ref.listen on the phase.
  }

  // ─── In-Match Events (from ShatterforgeGame callbacks) ────────────────────

  void onBallLaunched(BallDefinition ball) {
    state = state.copyWith(ballsUsed: state.ballsUsed + 1);
  }

  void onWallDestroyed() {
    state = state.copyWith(wallsDestroyed: state.wallsDestroyed + 1);
  }

  void onChainReaction(int chainLength) {
    state = state.copyWith(
      chainReactions: state.chainReactions + 1,
    );
  }

  void onCoreDestroyed() {
    _endMatch(victory: true);
  }

  void onAllBallsSpent() {
    _endMatch(victory: false);
  }

  void _endMatch({required bool victory}) {
    _planningTimer?.cancel();

    final stars = _calculateStars(
      victory: victory,
      ballsRemaining: state.ballsRemaining,
      wallsDestroyed: state.wallsDestroyed,
      totalWalls: state.map?.tiles.length ?? 1,
    );

    final coins = victory
        ? GameConstants.coinsPerWin + state.chainReactions * 5
        : GameConstants.coinsPerLoss;

    state = state.copyWith(
      phase: victory ? MatchPhase.victory : MatchPhase.defeat,
      starsEarned: stars,
      coinsEarned: coins,
    );

    // Transition to results after delay (cinematic plays)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        state = state.copyWith(phase: MatchPhase.results);
      }
    });
  }

  int _calculateStars({
    required bool victory,
    required int ballsRemaining,
    required int wallsDestroyed,
    required int totalWalls,
  }) {
    if (!victory) return 0;
    final destructionRatio = totalWalls > 0 ? wallsDestroyed / totalWalls : 0.0;
    if (destructionRatio >= 0.9 && ballsRemaining >= 2) return 3;
    if (destructionRatio >= 0.6) return 2;
    return 1; // minimum for winning
  }

  void showResults() {
    state = state.copyWith(phase: MatchPhase.results);
  }

  void reset() {
    _planningTimer?.cancel();
    state = const MatchState();
  }

  @override
  void dispose() {
    _planningTimer?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final matchControllerProvider =
    StateNotifierProvider.autoDispose<MatchController, MatchState>(
  (ref) => MatchController(),
);
