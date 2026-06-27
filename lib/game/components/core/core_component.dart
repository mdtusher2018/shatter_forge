// lib/game/components/core/core_component.dart
// CoreComponent — the enemy's Fortress Core.
// Destroying this wins the match.
//
// Visual: pulsing energy orb with rotating rings and lava cracks.
// Physics: static forge2d body (same collision shape as walls).
// When health reaches zero: destruction animation, then onDestroyed().

import 'dart:math' as math;
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart' hide Gradient;

import 'package:shatterforge/domain/entities/map_entity.dart';

typedef CoreDestroyedCallback = void Function();

class CoreComponent extends BodyComponent {
  CoreComponent({
    required Vector2 position,
    required this.size,
    required this.tile,
    required this.onDestroyed,
  }) : _worldPos = position;

  final Vector2 _worldPos;
  final Vector2 size;
  final TileEntity tile;
  final CoreDestroyedCallback onDestroyed;

  double _health = 0;
  double _maxHealth = 0;
  double _pulsePhase = 0;
  double _ringRotation = 0;
  bool _isDestroying = false;
  double _destroyTimer = 0;

  static const double _destroyDuration = 1.2;

  late final Paint _corePaint;
  late final Paint _glowPaint;
  late final Paint _ringPaint;
  // ignore: unused_field
  late final Paint _shieldPaint;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _health = tile.maxHealth * 2; // Core has double wall health
    _maxHealth = _health;
    _initPaints();
  }

  void _initPaints() {
    _corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF2196F3);

    _glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    _ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = const Color(0xFF00E5FF);

    _shieldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = _worldPos / 30.0;

    final shape = PolygonShape()
      ..setAsBox(
        (size.x / 2) / 30.0,
        (size.y / 2) / 30.0,
        Vector2(0, 0),
        0,
      );

    final fixtureDef = FixtureDef(shape)
      ..density = 5.0
      ..friction = 0.5
      ..restitution = 0.2;

    final b = world.createBody(bodyDef)..createFixture(fixtureDef);
    b.userData = this;
    return b;
  }

  // ─── Damage ───────────────────────────────────────────────────────────────

  void takeDamage(double damage) {
    if (_isDestroying) return;
    _health = (_health - damage).clamp(0, _maxHealth);
    if (_health <= 0) _beginDestruction();
  }

  void _beginDestruction() {
    _isDestroying = true;
    _destroyTimer = 0;
  }

  double get healthPercent => _health / _maxHealth;

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _pulsePhase += dt * 2.5;
    _ringRotation += dt * 0.8;

    if (_isDestroying) {
      _destroyTimer += dt;
      if (_destroyTimer >= _destroyDuration) {
        onDestroyed();
        removeFromParent();
      }
    }
  }

  // ─── Render ───────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final r = math.min(size.x, size.y) * 0.45;

    if (_isDestroying) {
      _renderDestruction(canvas, r);
      return;
    }

    final pulse = 1.0 + math.sin(_pulsePhase) * 0.08;
    final healthAlpha = 0.5 + healthPercent * 0.5;

    // ── Outer glow ──
    _glowPaint.color = const Color(0xFF2196F3).withOpacity(0.3 * healthAlpha);
    canvas.drawCircle(Offset.zero, r * 1.8 * pulse, _glowPaint);

    // ── Shield hex rings ──
    for (int i = 0; i < 3; i++) {
      _drawHexRing(
        canvas,
        r * (0.7 + i * 0.2),
        _ringRotation + i * (math.pi / 3),
        healthAlpha * (1.0 - i * 0.2),
      );
    }

    // ── Stone/rock outer shell ──
    final shellPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF25232B);
    canvas.drawCircle(Offset.zero, r * 1.1, shellPaint);

    // ── Core orb ──
    final gradient = RadialGradient(
      colors: [
        const Color(0xFF00E5FF),
        const Color(0xFF2196F3),
        const Color(0xFF0D47A1),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    _corePaint.shader = gradient.createShader(rect);
    canvas.drawCircle(Offset.zero, r * pulse, _corePaint);

    // ── Energy cracks on shell ──
    _drawEnergyCracks(canvas, r * 1.1);

    // ── Health indicator arc ──
    _drawHealthArc(canvas, r * 1.45);

    // ── HP label ──
    _drawHealthLabel(canvas, r);
  }

  void _drawHexRing(Canvas canvas, double r, double rotation, double alpha) {
    _ringPaint.color = const Color(0xFF00E5FF).withOpacity(alpha * 0.6);
    final path = Path();
    for (int i = 0; i <= 6; i++) {
      final angle = rotation + i * (math.pi / 3);
      final x = math.cos(angle) * r;
      final y = math.sin(angle) * r;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, _ringPaint);
  }

  void _drawEnergyCracks(Canvas canvas, double r) {
    final rng = math.Random(42);
    final crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFFF6B1A).withOpacity(0.7);

    for (int i = 0; i < 6; i++) {
      final angle = i * (math.pi / 3) + rng.nextDouble() * 0.4;
      final startR = r * 0.6;
      final endR = r;
      canvas.drawLine(
        Offset(math.cos(angle) * startR, math.sin(angle) * startR),
        Offset(math.cos(angle + 0.15) * endR, math.sin(angle + 0.15) * endR),
        crackPaint,
      );
    }
  }

  void _drawHealthArc(Canvas canvas, double r) {
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white.withOpacity(0.1);
    final hpPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
            const Color(0xFFF44336),
            const Color(0xFF00E5FF),
            healthPercent,
          ) ??
          const Color(0xFF00E5FF);

    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * healthPercent, false, hpPaint);
  }

  void _drawHealthLabel(Canvas canvas, double r) {
    final pct = (healthPercent * 100).toInt();
    final tp = TextPainter(
      text: TextSpan(
        text: '$pct%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, r * 1.6));
  }

  void _renderDestruction(Canvas canvas, double r) {
    final progress = _destroyTimer / _destroyDuration;
    final scale = 1.0 + progress * 3.0;
    final alpha = (1.0 - progress).clamp(0.0, 1.0);

    // Expanding shockwave
    _glowPaint.color = const Color(0xFF00E5FF).withOpacity(alpha * 0.8);
    canvas.drawCircle(Offset.zero, r * scale, _glowPaint);

    // Core fade
    _corePaint.shader = null;
    _corePaint.color = const Color(0xFF2196F3).withOpacity(alpha);
    canvas.drawCircle(Offset.zero, r * (1 + progress * 0.5), _corePaint);

    // Flash
    final flashPaint = Paint()
      ..color = Colors.white.withOpacity((1 - progress * 2).clamp(0, 1))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, r * 2 * progress, flashPaint);
  }
}
