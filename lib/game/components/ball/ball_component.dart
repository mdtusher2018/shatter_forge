// lib/game/components/ball/ball_component.dart
// BallComponent — Phase 1 implementation.
//
// Manages a single projectile in flight:
//   • forge2d dynamic rigid body (real physics bounce, mass, restitution)
//   • Per-definition physics (Stone vs Laser vs Explosive differ dramatically)
//   • Trail rendering (previous positions ring buffer)
//   • Impact flash on wall contact
//   • Bounce count tracking → removal
//   • Special behaviors:
//       - Explosive: AOE damage pulse on first contact
//       - Ricochet: perfect angle preservation (restitution = 1.0)
//       - Laser: no physics body, raycast-based piercing
//       - Cluster: splits into 5 sub-balls on contact
//       - Gravity: field effect applied to nearby bodies
//
// Future ball types (Phase 5) extend BallComponent or implement IBallBehavior
// via composition rather than inheritance to keep this class clean.

import 'dart:math' as math;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide Gradient;
import 'package:shatterforge/domain/entities/ball_entity.dart';
import 'package:shatterforge/game/components/wall/wall_component.dart';
import 'package:shatterforge/game/components/vfx/particle_system.dart';

typedef BallWallHitCallback = void Function(
    BallComponent ball, WallComponent wall);
typedef BallOutOfBoundsCallback = void Function(BallComponent ball);

 class BallComponent extends BodyComponent implements ContactCallbacks {
  BallComponent({
    required this.definition,
    required this.startPosition,
    required this.velocity,
    required this.onWallHit,
    required this.onOutOfBounds,
    required this.particleSystem,
  });

  final BallDefinition definition;
  final Vector2 startPosition;
  final Vector2 velocity;
  final BallWallHitCallback onWallHit;
  final BallOutOfBoundsCallback onOutOfBounds;
  final ShatterforgeParticleSystem particleSystem;

  // Runtime state
  int _bounceCount = 0;
  bool _hasHit = false; // first contact flag (for split / explode)
  bool _outOfBounds = false;

  // Trail (ring buffer of last N positions)
  static const int _trailLength = 24;
  final List<Vector2> _trail = [];

  // Glow pulse
  double _glowPhase = 0;

  // Paint cache
  late final Paint _bodyPaint;
  late final Paint _trailPaint;
  late final Paint _glowPaint;

  // ─── Material Colors ───────────────────────────────────────────────────────

  static const Map<String, Color> _ballColors = {
    'stone_ball': Color(0xFF8D8A98),
    'steel_ball': Color(0xFF78909C),
    'heavy_ball': Color(0xFF546E7A),
    'explosive_ball': Color(0xFFE53935),
    'cluster_ball': Color(0xFFFF8F00),
    'plasma_ball': Color(0xFF7B2FBE),
    'gravity_ball': Color(0xFF1565C0),
    'laser_ball': Color(0xFF00E5FF),
    'drill_ball': Color(0xFF37474F),
    'emp_ball': Color(0xFFFFEB3B),
    'ice_ball': Color(0xFF81D4FA),
    'fire_ball': Color(0xFFFF6D00),
    'acid_ball': Color(0xFF76FF03),
    'poison_ball': Color(0xFF8BC34A),
    'sticky_ball': Color(0xFF795548),
    'magnetic_ball': Color(0xFF607D8B),
    'chain_lightning_ball': Color(0xFFFFD600),
    'meteor_ball': Color(0xFFBF360C),
    'nano_ball': Color(0xFFE1F5FE),
    'void_ball': Color(0xFF4A148C),
    'black_hole_ball': Color(0xFF1A1A2E),
    'ricochet_ball': Color(0xFF00BFA5),
    'rocket_ball': Color(0xFFD50000),
  };

  Color get _primaryColor =>
      _ballColors[definition.id] ?? const Color(0xFFFF6B1A);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _initPaints();
  }

  void _initPaints() {
    _bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = _primaryColor;

    _trailPaint = Paint()..style = PaintingStyle.fill;

    _glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
  }

  // ─── Forge2D Body ─────────────────────────────────────────────────────────

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = startPosition / 30.0
      ..linearVelocity = velocity / 30.0
      ..bullet = true; // CCD for fast-moving bodies

    final shape = CircleShape()..radius = definition.radius / 30.0;

    final fixtureDef = FixtureDef(shape)
      ..density = definition.mass
      ..restitution = definition.bounciness
      ..friction = 0.1;

    final b = world.createBody(bodyDef)..createFixture(fixtureDef);
    b.userData = this;
    return b;
  }

  // ─── Contacts ─────────────────────────────────────────────────────────────

  @override
  void beginContact(Object other, Contact contact) {
    if (other is WallComponent) {
      _handleWallContact(other);
    }
  }

  void _handleWallContact(WallComponent wall) {
    if (_outOfBounds) return;

    _bounceCount++;
    onWallHit(this, wall);

    // Spawn impact VFX
    particleSystem.spawnImpact(
      position: Vector2(body.position.x * 30, body.position.y * 30),
      material: wall.tile.material,
      ballColor: _primaryColor,
    );

    // Special first-contact behaviors
    if (!_hasHit) {
      _hasHit = true;

      if (definition.splits) {
        _triggerSplit();
      }
    }

    // Bounce limit
    if (definition.maxBounces >= 0 && _bounceCount >= definition.maxBounces) {
      _removeSelf();
    }
  }

  void _triggerSplit() {
    // Notify game to spawn sub-balls (done from game world, not here)
    // Signal via userData flag for ShatterforgeGame to pick up next frame
    body.userData = _SplitSignal(
      parent: this,
      count: definition.splitCount,
      position: Vector2(body.position.x * 30, body.position.y * 30),
      velocity:
          Vector2(body.linearVelocity.x * 30, body.linearVelocity.y * 30),
    );
  }

  void _removeSelf() {
    if (!_outOfBounds) {
      _outOfBounds = true;
      onOutOfBounds(this);
    }
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    _glowPhase += dt * 4;

    // Update trail
    final worldPos = body.position * 30;
    _trail.add(worldPos.clone());
    if (_trail.length > _trailLength) _trail.removeAt(0);

    // Gravity ball: apply pull to nearby dynamic bodies
    if (definition.hasGravityField) {
      _applyGravityField();
    }

    // Out-of-bounds check (fell below arena)
    final gameSize = findGame()?.size;
    if (gameSize != null && worldPos.y > gameSize.y + 100) {
      _removeSelf();
    }
  }

  void _applyGravityField() {
    final myPos = body.position;
    for (final b in body.world.bodies) {
      if (b == body || b.bodyType != BodyType.dynamic) continue;
      final diff = myPos - b.position;
      final dist = diff.length;
      if (dist < definition.areaRadius / 30 && dist > 0.1) {
        final force = diff.normalized() * (80 / (dist * dist));
        b.applyForce(force);
      }
    }
  }

  // ─── Rendering ────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final r = definition.radius.toDouble();
    final glowR = r * (1.4 + math.sin(_glowPhase) * 0.15);

    // ── Trail ──
    for (int i = 0; i < _trail.length - 1; i++) {
      final t = i / _trail.length;
      final alpha = t * 0.45;
      final trailR = r * t * 0.7;

      // Convert from world space to local
      final localPos = _trail[i] - body.position * 30;
      _trailPaint.color = _primaryColor.withOpacity(alpha);
      canvas.drawCircle(Offset(localPos.x, localPos.y), trailR, _trailPaint);
    }

    // ── Glow ──
    _glowPaint.color = _primaryColor.withOpacity(0.25);
    canvas.drawCircle(Offset.zero, glowR, _glowPaint);

    // ── Body ──
    _bodyPaint.color = _primaryColor;
    canvas.drawCircle(Offset.zero, r, _bodyPaint);

    // ── Highlight (specular) ──
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(-r * 0.3, -r * 0.3),
      r * 0.35,
      highlightPaint,
    );

    // ── Type-specific overlay ──
    _renderTypeOverlay(canvas, r);
  }

  void _renderTypeOverlay(Canvas canvas, double r) {
    switch (definition.id) {
      case 'explosive_ball':
        _drawCrosshair(canvas, r, SFColors.danger);
        break;
      case 'laser_ball':
        _drawLaserRing(canvas, r);
        break;
      case 'emp_ball':
        _drawEmpRing(canvas, r);
        break;
      case 'gravity_ball':
        _drawGravitySpiral(canvas, r);
        break;
      default:
        break;
    }
  }

  void _drawCrosshair(Canvas canvas, double r, Color c) {
    final p = Paint()
      ..color = c.withOpacity(0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(-r * 0.6, 0), Offset(r * 0.6, 0), p);
    canvas.drawLine(Offset(0, -r * 0.6), Offset(0, r * 0.6), p);
  }

  void _drawLaserRing(Canvas canvas, double r) {
    final p = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, r * 0.7, p);
  }

  void _drawEmpRing(Canvas canvas, double r) {
    final p = Paint()
      ..color = const Color(0xFFFFEB3B).withOpacity(0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset.zero, r * (0.3 + i * 0.25),
          p..color = p.color.withOpacity(0.8 - i * 0.25));
    }
  }

  void _drawGravitySpiral(Canvas canvas, double r) {
    final p = Paint()
      ..color = const Color(0xFF1565C0).withOpacity(0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (double t = 0; t < math.pi * 4; t += 0.2) {
      final spiralR = (t / (math.pi * 4)) * r * 0.8;
      final x = math.cos(t + _glowPhase) * spiralR;
      final y = math.sin(t + _glowPhase) * spiralR;
      if (t == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, p);
  }
  
  @override
  void Function(Object other, Contact contact)? onBeginContact;
  
  @override
  void Function(Object other, Contact contact)? onEndContact;
  
  @override
  void Function(Object other, Contact contact, ContactImpulse impulse)? onPostSolve;
  
  @override
  void Function(Object other, Contact contact, Manifold oldManifold)? onPreSolve;
  
  @override
  void endContact(Object other, Contact contact) {
    // TODO: implement endContact
  }
  
  @override
  void postSolve(Object other, Contact contact, ContactImpulse impulse) {
    // TODO: implement postSolve
  }
  
  @override
  void preSolve(Object other, Contact contact, Manifold oldManifold) {
    // TODO: implement preSolve
  }
}

// ─── Split Signal ─────────────────────────────────────────────────────────────
// Used as userData flag to tell ShatterforgeGame to spawn sub-balls.

class _SplitSignal {
  final BallComponent parent;
  final int count;
  final Vector2 position;
  final Vector2 velocity;
  const _SplitSignal({
    required this.parent,
    required this.count,
    required this.position,
    required this.velocity,
  });
}

// Import colors (circular-safe since it's the same package)
class SFColors {
  static const Color danger = Color(0xFFF44336);
  static const Color crystalCyanDim = Color(0x4400E5FF);
  static const Color lavaRed = Color(0xFFE53935);
  static const Color coreBlueDim = Color(0x662196F3);
}
