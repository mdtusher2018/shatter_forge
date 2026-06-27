// lib/game/world/shatterforge_game.dart
// SHATTERFORGE — Phase 1 core game class.
// Replaces the original BrickBreaker. Flame + forge2d integrated.
//
// Architecture:
//   ShatterforgeGame (FlameGame + HasCollisionDetection)
//     └── ShatterforgeWorld (extends Forge2DWorld)
//         ├── WallComponent (per tile)
//         ├── BallComponent (per launched ball)
//         ├── CoreComponent (enemy fortress core)
//         └── BoundaryComponent (arena walls)
//
// Game FSM lives in MatchController (Riverpod StateNotifier).
// This class only owns the rendering / physics loop.
// All state changes are communicated upward via callbacks.

import 'dart:ui';
import 'package:flame/components.dart' hide Vector2;
import 'package:flame/events.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide Route;

import 'package:shatterforge/domain/entities/map_entity.dart';
import 'package:shatterforge/domain/entities/ball_entity.dart';
import 'package:shatterforge/core/constants/game_constants.dart';
import '../components/wall/wall_component.dart';
import '../components/ball/ball_component.dart';
import '../components/core/core_component.dart';
import '../components/physics/boundary_component.dart';
import '../components/vfx/particle_system.dart';
import 'package:shatterforge/game/systems/structural_integrity_system.dart';

// ─── Match Events ─────────────────────────────────────────────────────────────
// Bubbles up to the Flutter layer so the HUD and controller can react.

enum MatchEvent {
  ballLaunched,
  wallDestroyed,
  coreHit,
  coreDestroyed,   // Attacker wins
  allBallsSpent,   // Attacker loses
  chainReaction,
}

typedef MatchEventCallback = void Function(MatchEvent event, dynamic data);

// ─── ShatterforgeGame ─────────────────────────────────────────────────────────

class ShatterforgeGame extends Forge2DGame
    with TapCallbacks, DragCallbacks, HasCollisionDetection {
  ShatterforgeGame({
    required this.map,
    required this.selectedBalls,
    required this.onEvent,
  }) : super(
          gravity: Vector2(0, GameConstants.gravity * 30), // scaled to pixel space
          zoom: 1.0,
        );

  // ─── Input
  final MapEntity map;
  final List<BallDefinition> selectedBalls;
  final MatchEventCallback onEvent;

  // ─── Runtime State
  late final ShatterforgeParticleSystem _particles;
  late final SimpleStructuralIntegritySystem _sis;

  CoreComponent? _core;
  final List<BallComponent> _activeBalls = [];
  final List<WallComponent> _walls = [];

  int _ballIndex = 0;       // which ball is queued next
  bool _aiming = false;
  Vector2 _aimStart = Vector2.zero();
  Vector2 _aimDirection = Vector2(0, -1); // default: straight up
  bool _matchEnded = false;

  // Trajectory preview points (computed each frame while aiming)
  final List<Vector2> _trajectoryPoints = [];

  // ─── Getters used by HUD ──────────────────────────────────────────────────
  int get ballsRemaining => selectedBalls.length - _ballIndex;
  BallDefinition? get queuedBall =>
      _ballIndex < selectedBalls.length ? selectedBalls[_ballIndex] : null;
  List<Vector2> get trajectoryPoints => List.unmodifiable(_trajectoryPoints);
  bool get isAiming => _aiming;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Camera
    camera.viewfinder.anchor = Anchor.topLeft;

    // Particle system (object pool, no dynamic allocation during play)
    _particles = ShatterforgeParticleSystem(
      poolSize: GameConstants.particlePoolSize,
    );
    await add(_particles);

    // Structural integrity system
    _sis = SimpleStructuralIntegritySystem();
    _sis.initialize(map);

    // Build arena boundaries
    await add(BoundaryComponent(gameSize: Vector2(size.x, size.y)));

    // Build all wall tiles from the map entity
    await _buildWalls();

    // Pause briefly so the player can see the fortress before attacking
    // (planning phase timer is in the Flutter layer; game starts paused)
    pauseEngine();
  }

  @override
  void onRemove() {
    _sis.dispose();
    super.onRemove();
  }

  // ─── Map Building ─────────────────────────────────────────────────────────

  Future<void> _buildWalls() async {
    final tileSize = _computeTileSize();

    for (final entry in map.tiles.entries) {
      final pos = entry.key;
      final tile = entry.value;

      final worldPos = Vector2(
        pos.dx * tileSize.x + tileSize.x / 2,
        pos.dy * tileSize.y + tileSize.y / 2,
      );

      if (tile.role == WallRole.decoy) {
        // Core tile
        final core = CoreComponent(
          position: worldPos,
          size: tileSize,
          tile: tile,
          onDestroyed: _onCoreDestroyed,
        );
        _core = core;
        await add(core);
      } else {
        final wall = WallComponent(
          position: worldPos,
          size: tileSize,
          tile: tile,
          onDestroyed: (w) => _onWallDestroyed(w, pos),
        );
        _walls.add(wall);
        await add(wall);
      }
    }
  }

  Vector2 _computeTileSize() {
    // Fit the entire map into the visible area with 10% padding
    final padW = size.x * 0.10;
    final padH = size.y * 0.10;
    final availW = size.x - padW * 2;
    final availH = size.y - padH * 2;
    return Vector2(availW / map.columns, availH / map.rows);
  }

  // ─── Phase Control (called from Flutter) ──────────────────────────────────

  /// Called when the planning phase ends and attacking begins.
  void startAttackPhase() {
    resumeEngine();
  }

  // ─── Aiming & Launch ──────────────────────────────────────────────────────

  @override
  void onDragStart(DragStartEvent event) {
    if (_matchEnded || queuedBall == null) return;
    _aiming = true;

    _aimStart = Vector2(event.localPosition.x, event.localPosition.y);
    super.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_aiming) return;
    final delta = _aimStart - Vector2(event.localDelta.x, event.localDelta.y); // pull-back gesture
    if (delta.length > 5) {
      _aimDirection = delta.normalized();
    }
    _updateTrajectoryPreview();
    super.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!_aiming) return;
    _aiming = false;
    _trajectoryPoints.clear();
    _launchBall(_aimDirection);
    super.onDragEnd(event);
  }

  void _launchBall(Vector2 direction) {
    final def = queuedBall;
    if (def == null || _matchEnded) return;

    final launchPos = Vector2(size.x / 2, size.y - 60); // bottom center
    const speed = GameConstants.ballBaseSpeed;

    final ball = BallComponent(
      definition: def,
      startPosition: launchPos,
      velocity: direction * speed,
      onWallHit: _onBallWallHit,
      onOutOfBounds: _onBallOutOfBounds,
      particleSystem: _particles,
    );

    _activeBalls.add(ball);
    add(ball);
    _ballIndex++;

    onEvent(MatchEvent.ballLaunched, def);
  }

  // ─── Trajectory Preview ───────────────────────────────────────────────────

  void _updateTrajectoryPreview() {
    _trajectoryPoints.clear();
    if (queuedBall == null) return;

    final def = queuedBall!;
    final startPos = Vector2(size.x / 2, size.y - 60);
    final speed = GameConstants.ballBaseSpeed;
    var pos = startPos.clone();
    var vel = _aimDirection * speed;

    // Simple Euler integration preview (ignores forge2d; good enough for preview)
    for (int i = 0; i < 60; i++) {
      _trajectoryPoints.add(pos.clone());
      pos += vel * 0.016; // 16ms step

      // Simple boundary bounce
      if (pos.x <= def.radius || pos.x >= size.x - def.radius) {
        vel.x = -vel.x;
      }
      if (pos.y <= def.radius) {
        vel.y = -vel.y;
      }

      // Stop if going down and below launch point
      if (pos.y > size.y) break;
    }
  }

  // ─── Callbacks ────────────────────────────────────────────────────────────

  void _onBallWallHit(BallComponent ball, WallComponent wall) {
    final pos = Offset(
      wall.position.x,
      wall.position.y,
    );
    final collapseEvents = _sis.applyDamage(
      position: pos,
      damage: ball.definition.baseDamage,
      isExplosion: ball.definition.hasAreaEffect,
      explosionRadius: ball.definition.areaRadius,
    );

    // Apply damage visually to the wall
    wall.takeDamage(ball.definition.baseDamage);

    // Trigger chain reactions
    if (collapseEvents.length > 1) {
      onEvent(MatchEvent.chainReaction, collapseEvents.length);
      for (final e in collapseEvents.skip(1)) {
        _collapseWallAt(e.position);
      }
    }

    // Resolve floating
    final floating = _sis.resolveFloating();
    for (final f in floating) {
      _collapseWallAt(f);
    }
  }

  void _onWallDestroyed(WallComponent wall, Offset gridPos) {
    _walls.remove(wall);
    onEvent(MatchEvent.wallDestroyed, gridPos);

    // Spawn destruction VFX
    _particles.spawnDestruction(
      position: wall.position,
      material: wall.tile.material,
    );
  }

  void _onCoreDestroyed() {
    if (_matchEnded) return;
    _matchEnded = true;
    pauseEngine();
    onEvent(MatchEvent.coreDestroyed, null);
  }

  void _onBallOutOfBounds(BallComponent ball) {
    _activeBalls.remove(ball);
    ball.removeFromParent();

    if (_activeBalls.isEmpty && _ballIndex >= selectedBalls.length) {
      // All balls spent
      if (!_matchEnded && !_sis.isCoreAlive() == false) {
        _matchEnded = true;
        pauseEngine();
        onEvent(MatchEvent.allBallsSpent, null);
      }
    }
  }

  void _collapseWallAt(Offset gridPos) {
    final tileSize = _computeTileSize();
    final worldX = gridPos.dx * tileSize.x + tileSize.x / 2;
    final worldY = gridPos.dy * tileSize.y + tileSize.y / 2;

    final wall = _walls.firstWhere(
      (w) => (w.position.x - worldX).abs() < 2 && (w.position.y - worldY).abs() < 2,
      orElse: () => throw StateError('Wall not found at $gridPos'),
    );

    wall.collapse();
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    // Core alive check
    if (!_matchEnded && _core != null && !_sis.isCoreAlive()) {
      _onCoreDestroyed();
    }
  }
}
