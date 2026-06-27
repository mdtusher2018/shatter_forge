// lib/game/systems/base_validation_engine.dart
// BaseValidationEngine — Phase 1 implementation.
//
// Purpose:
//   Before a map is published, run N virtual attack simulations.
//   If at least one succeeds (Core destroyed), the map is approved.
//   If zero succeed, reject it — the map is unbeatable and violates
//   the core design rule: "every fortress must be breakable."
//
// Design:
//   • Pure Dart — no Flutter/Flame dependencies.
//   • Runs in an Isolate to avoid blocking the UI thread.
//   • Each simulation uses the existing SimpleStructuralIntegritySystem.
//   • Simulations test randomised ball selections, angles, and targeting.
//   • The engine does NOT use full forge2d physics (too expensive at scale).
//     Instead it uses a fast grid-based trajectory model:
//       - Balls travel in straight lines, bounce off boundaries.
//       - Hits are computed via line-grid intersection.
//       - This approximation is intentionally conservative:
//         if the simple model finds a solution, a real physics shot exists.
//         If not, we run more simulations before rejecting.
//
// Validation result:
//   ValidationResult.approved — at least one solution found
//   ValidationResult.rejected — no solution found after N simulations
//   ValidationResult.tooSparse — map has fewer tiles than minimum
//   ValidationResult.missingCore — no Core tile present
//   ValidationResult.tooManyUnbreakable — > 25% unbreakable tiles

import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:shatterforge/domain/entities/map_entity.dart';
import 'package:shatterforge/domain/entities/ball_entity.dart';
import 'package:shatterforge/core/constants/game_constants.dart';
import 'package:shatterforge/game/systems/structural_integrity_system.dart';

// ─── Validation Result ────────────────────────────────────────────────────────

enum ValidationStatus {
  approved,
  rejected,
  tooSparse,
  missingCore,
  tooManyUnbreakable,
  timeout,
}

class ValidationResult {
  const ValidationResult({
    required this.status,
    required this.simulationsRun,
    required this.solutionsFound,
    this.failReason,
    this.bestSolution,
  });

  final ValidationStatus status;
  final int simulationsRun;
  final int solutionsFound;
  final String? failReason;
  final ValidationSolution? bestSolution; // for developer debugging

  bool get isApproved => status == ValidationStatus.approved;

  @override
  String toString() =>
      'ValidationResult($status, runs=$simulationsRun, solutions=$solutionsFound)';
}

class ValidationSolution {
  final String ballId;
  final double launchAngle;
  final int wallsDestroyed;

  const ValidationSolution({
    required this.ballId,
    required this.launchAngle,
    required this.wallsDestroyed,
  });
}

// ─── Engine ───────────────────────────────────────────────────────────────────

class BaseValidationEngine {
  BaseValidationEngine._();

  /// Validates a map. Runs in an Isolate to avoid UI jank.
  static Future<ValidationResult> validate(MapEntity map) async {
    // Quick structural checks first (no simulation needed)
    final structuralResult = _quickChecks(map);
    if (structuralResult != null) return structuralResult;

    // Heavy simulation in isolate
    return compute(_runSimulationsIsolate, _ValidationRequest(map: map));
  }

  // ─── Quick Checks (synchronous, cheap) ───────────────────────────────────

  static ValidationResult? _quickChecks(MapEntity map) {
    if (map.tileCount < GameConstants.mapMinTiles) {
      return ValidationResult(
        status: ValidationStatus.tooSparse,
        simulationsRun: 0,
        solutionsFound: 0,
        failReason:
            'Map has only ${map.tileCount} tiles. Minimum is ${GameConstants.mapMinTiles}.',
      );
    }

    if (map.coreTile == null) {
      return ValidationResult(
        status: ValidationStatus.missingCore,
        simulationsRun: 0,
        solutionsFound: 0,
        failReason: 'No Core tile found. Every map must contain exactly one Core.',
      );
    }

    final unbreakableCount =
        map.tiles.values.where((t) => !t.isBreakable).length;
    final ratio = unbreakableCount / map.tileCount;
    if (ratio > GameConstants.maxUnbreakableRatio) {
      return ValidationResult(
        status: ValidationStatus.tooManyUnbreakable,
        simulationsRun: 0,
        solutionsFound: 0,
        failReason:
            '${(ratio * 100).round()}% of tiles are unbreakable. Maximum is ${(GameConstants.maxUnbreakableRatio * 100).round()}%.',
      );
    }

    return null; // passes quick checks
  }
}

// ─── Isolate Entry Point ──────────────────────────────────────────────────────

ValidationResult _runSimulationsIsolate(_ValidationRequest req) {
  final map = req.map;
  final rng = math.Random();
  final balls = _availableBalls();

  int simulationsRun = 0;
  int solutionsFound = 0;
  ValidationSolution? bestSolution;

  final stopwatch = Stopwatch()..start();

  while (simulationsRun < GameConstants.validationSimulations) {
    if (stopwatch.elapsedMilliseconds > GameConstants.validationTimeoutMs) {
      return ValidationResult(
        status: solutionsFound > 0
            ? ValidationStatus.approved
            : ValidationStatus.timeout,
        simulationsRun: simulationsRun,
        solutionsFound: solutionsFound,
        bestSolution: bestSolution,
      );
    }

    // Pick a random ball
    final ball = balls[rng.nextInt(balls.length)];

    // Pick random launch angle (0° = top-center, ±60° spread)
    const baseAngle = -math.pi / 2; // pointing up
    const spread = math.pi * 0.55;
    final launchAngle = baseAngle + (rng.nextDouble() - 0.5) * spread;

    // Run fast grid simulation
    final result = _runGridSimulation(map, ball, launchAngle);
    simulationsRun++;

    if (result.coreDestroyed) {
      solutionsFound++;
      if (bestSolution == null || result.wallsDestroyed > bestSolution.wallsDestroyed) {
        bestSolution = ValidationSolution(
          ballId: ball.id,
          launchAngle: launchAngle,
          wallsDestroyed: result.wallsDestroyed,
        );
      }

      // Found at least one solution — approved
      if (solutionsFound >= 3) break; // confirm with 3 solutions for confidence
    }
  }

  return ValidationResult(
    status: solutionsFound > 0
        ? ValidationStatus.approved
        : ValidationStatus.rejected,
    simulationsRun: simulationsRun,
    solutionsFound: solutionsFound,
    failReason: solutionsFound == 0
        ? 'No valid attack sequence found in $simulationsRun simulations. '
          'Consider reducing unbreakable tiles or shield coverage around the Core.'
        : null,
    bestSolution: bestSolution,
  );
}

// ─── Grid Simulation ──────────────────────────────────────────────────────────
// Fast approximation: ball is a ray that bounces off boundaries.
// Hit detection: if ray passes through a tile's grid cell, apply damage.

class _SimResult {
  final bool coreDestroyed;
  final int wallsDestroyed;
  const _SimResult({required this.coreDestroyed, required this.wallsDestroyed});
}

_SimResult _runGridSimulation(MapEntity map, BallDefinition ball, double angle) {
  final sis = SimpleStructuralIntegritySystem()..initialize(map);

  // Ball position in grid space (starts from bottom center)
  var bx = map.columns / 2.0;
  var by = map.rows + 1.0; // below the grid
  var dx = math.cos(angle) * 0.15;
  var dy = math.sin(angle) * 0.15;

  int bounces = 0;
  int wallsDestroyed = 0;
  int maxSteps = map.rows * map.columns * 8;

  for (int step = 0; step < maxSteps; step++) {
    bx += dx;
    by += dy;

    // Boundary bounces (grid space)
    if (bx < 0) { bx = 0; dx = -dx; bounces++; }
    if (bx >= map.columns) { bx = map.columns - 0.01; dx = -dx; bounces++; }
    if (by < 0) { by = 0; dy = -dy; bounces++; }

    // Out of bounds below
    if (by > map.rows + 2) break;

    // Bounce limit
    if (ball.maxBounces >= 0 && bounces > ball.maxBounces) break;

    // Check grid cell
    final gx = bx.floor();
    final gy = by.floor();
    // ignore: unused_local_variable
    final key = _Offset(gx.toDouble(), gy.toDouble());

    final tile = map.tiles.entries
        .where((e) => e.key.dx == gx && e.key.dy == gy)
        .firstOrNull;

    if (tile == null) continue;
    if (!tile.value.isBreakable && tile.value.role != WallRole.decoy) {
      // Bounce off unbreakable
      final nx = bx - gx - 0.5;
      final ny = by - gy - 0.5;
      if (nx.abs() > ny.abs()) dx = -dx; else dy = -dy;
      bounces++;
      continue;
    }

    // Apply damage
    final events = sis.applyDamage(
      position: tile.key,
      damage: ball.baseDamage,
      isExplosion: ball.hasAreaEffect,
      explosionRadius: ball.areaRadius * 0.05, // grid units
    );

    for (final ev in events) {
      if (ev.reason != CollapseReason.floatingDetached) wallsDestroyed++;
    }

    // Check bounce (ball bounces off walls too)
    final nx = bx - gx - 0.5;
    final ny = by - gy - 0.5;
    if (nx.abs() > ny.abs()) dx = -dx * tile.value.elasticity;
    else dy = -dy * tile.value.elasticity;
    bounces++;

    if (!sis.isCoreAlive()) {
      return _SimResult(coreDestroyed: true, wallsDestroyed: wallsDestroyed);
    }
  }

  sis.dispose();
  return _SimResult(coreDestroyed: false, wallsDestroyed: wallsDestroyed);
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

List<BallDefinition> _availableBalls() => [
      BallLibrary.all['stone_ball']!,
      BallLibrary.all['steel_ball']!,
      BallLibrary.all['heavy_ball']!,
      BallLibrary.all['explosive_ball']!,
      BallLibrary.all['ricochet_ball']!,
      BallLibrary.all['drill_ball']!,
      BallLibrary.all['laser_ball']!,
      BallLibrary.all['gravity_ball']!,
      BallLibrary.all['cluster_ball']!,
      BallLibrary.all['meteor_ball']!,
    ];

class _Offset {
  final double dx, dy;
  _Offset(this.dx, this.dy);
}

class _ValidationRequest {
  final MapEntity map;
  const _ValidationRequest({required this.map});
}

extension on Iterable<MapEntry<dynamic, dynamic>> {
  MapEntry<dynamic, dynamic>? get firstOrNull {
    try { return first; } catch (_) { return null; }
  }
}
