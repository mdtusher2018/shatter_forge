// lib/presentation/screens/battle/battle_screen.dart
// BattleScreen — the full-screen match UI.
//
// Layout:
//   Stack:
//     [0] GameWidget (Flame game — fills screen)
//     [1] TrajectoryOverlay (drawn in Flutter, synced to game state)
//     [2] HUD (timer, balls remaining, chain counter)
//     [3] PlanningPhaseOverlay (shown only during planning)
//     [4] ResultsOverlay (shown after match ends)
//
// Communication:
//   • MatchController (Riverpod) owns match state
//   • BattleScreen listens to phase changes and calls game.startAttackPhase()
//   • ShatterforgeGame fires callbacks → MatchController.on*() methods
//   • HUD rebuilds only on MatchState changes (ConsumerWidget)

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shatterforge/core/theme/app_theme.dart';
import 'package:shatterforge/domain/entities/ball_entity.dart';
import 'package:shatterforge/domain/entities/map_entity.dart';
import '../../../domain/usecases/match/match_controller.dart';
import 'package:shatterforge/game/world/shatterforge_game.dart';
import 'package:shatterforge/presentation/widgets/hud/battle_hud.dart' hide SFColors;
import 'package:shatterforge/presentation/widgets/hud/planning_overlay.dart' hide SFColors;
import 'package:shatterforge/presentation/widgets/hud/trajectory_overlay.dart';
import 'package:shatterforge/presentation/widgets/hud/results_overlay.dart' hide SFColors;
import 'package:shatterforge/core/utils/app_router.dart';

class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({
    super.key,
    required this.map,
    required this.selectedBalls,
  });

  final MapEntity map;
  final List<BallDefinition> selectedBalls;

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> {
  ShatterforgeGame? _game;

  @override
  void initState() {
    super.initState();
    // Start the match after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(matchControllerProvider.notifier).startMatch(
            map: widget.map,
            selectedBalls: widget.selectedBalls,
          );
    });
  }

  void _initGame() {
    final controller = ref.read(matchControllerProvider.notifier);
    _game = ShatterforgeGame(
      map: widget.map,
      selectedBalls: widget.selectedBalls,
      onEvent: (event, data) {
        switch (event) {
          case MatchEvent.ballLaunched:
            controller.onBallLaunched(data as BallDefinition);
            break;
          case MatchEvent.wallDestroyed:
            controller.onWallDestroyed();
            break;
          case MatchEvent.chainReaction:
            controller.onChainReaction(data as int);
            break;
          case MatchEvent.coreDestroyed:
            controller.onCoreDestroyed();
            break;
          case MatchEvent.allBallsSpent:
            controller.onAllBallsSpent();
            break;
          case MatchEvent.coreHit:
            break; // HUD shake handled via provider update
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize game once
    _game ??= (() { _initGame(); return _game!; })();

    // Listen for phase transitions to drive game engine
    ref.listen<MatchState>(matchControllerProvider, (prev, next) {
      if (prev?.phase != MatchPhase.attacking &&
          next.phase == MatchPhase.attacking) {
        _game?.startAttackPhase();
      }
    });

    final matchState = ref.watch(matchControllerProvider);

    return Scaffold(
      backgroundColor: SFColors.bg0,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Flame game ──────────────────────────────────────────────────
          GameWidget(game: _game!),

          // ── Trajectory preview overlay ──────────────────────────────────
          if (matchState.isAttacking)
            TrajectoryOverlay(game: _game!),

          // ── HUD ─────────────────────────────────────────────────────────
          BattleHud(
            state: matchState,
            onSurrender: () => _confirmSurrender(context),
          ),

          // ── Planning overlay ─────────────────────────────────────────────
          if (matchState.isPlanning)
            PlanningOverlay(
              secondsRemaining: matchState.planningSecondsRemaining,
              balls: matchState.selectedBalls,
              onReady: () =>
                  ref.read(matchControllerProvider.notifier).skipPlanningPhase(),
            ),

          // ── Results overlay ──────────────────────────────────────────────
          if (matchState.phase == MatchPhase.results)
            ResultsOverlay(
              state: matchState,
              onContinue: () => context.go(Routes.home),
              onRematch: () {
                ref.read(matchControllerProvider.notifier).reset();
                ref.read(matchControllerProvider.notifier).startMatch(
                      map: widget.map,
                      selectedBalls: widget.selectedBalls,
                    );
              },
            ),

          // ── Loading ──────────────────────────────────────────────────────
          if (matchState.isLoading)
            const Center(
              child: _LoadingIndicator(),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmSurrender(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SFColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Surrender?', style: SFTextStyles.headlineSmall),
        content: Text(
          'You will lose this match and earn minimal rewards.',
          style: SFTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SFColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Surrender'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(matchControllerProvider.notifier).onAllBallsSpent();
    }
  }
}

// ─── Loading Indicator ────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SFColors.bg0.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: SFColors.energyOrange,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text('Loading Fortress...', style: SFTextStyles.labelLarge),
          ],
        ),
      ),
    );
  }
}
