// lib/game/components/vfx/particle_system.dart
// ShatterforgeParticleSystem — pooled particle manager.
//
// Design goals:
//   • Zero dynamic allocation during gameplay (pool pre-allocated on load)
//   • Material-specific particle colors and behaviors
//   • Supports: impact sparks, debris chunks, smoke puffs, glow flashes
//   • All particles rendered in a single batched canvas draw call per type
//
// Pool architecture:
//   _particles: fixed-size List<_Particle> allocated once
//   _active:    which indices are currently alive
//   _nextSlot:  round-robin allocation (oldest particle reused)

import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Gradient;

import 'package:shatterforge/domain/entities/map_entity.dart';

class ShatterforgeParticleSystem extends Component {
  ShatterforgeParticleSystem({required this.poolSize});

  final int poolSize;

  late final List<_Particle> _pool;
  int _nextSlot = 0;

  // Paint cache
  late final Paint _sparkPaint;
  late final Paint _debrisPaint;
  late final Paint _smokePaint;
  late final Paint _flashPaint;

  // ─── Material Color Maps ───────────────────────────────────────────────────

  static const Map<WallMaterial, _ParticleConfig> _materialConfigs = {
    WallMaterial.stone:      _ParticleConfig(Color(0xFF8D8A98), Color(0xFF5A576A), Color(0xFFFF6B1A)),
    WallMaterial.reinforced: _ParticleConfig(Color(0xFF78909C), Color(0xFF546E7A), Color(0xFF9E9E9E)),
    WallMaterial.crystal:    _ParticleConfig(Color(0xFF00E5FF), Color(0xFF81D4FA), Color(0xFFFFFFFF)),
    WallMaterial.energy:     _ParticleConfig(Color(0xFF7B2FBE), Color(0xFF9C27B0), Color(0xFFFF6B1A)),
    WallMaterial.wood:       _ParticleConfig(Color(0xFF5D4037), Color(0xFF8D6E63), Color(0xFFFF8F00)),
    WallMaterial.glass:      _ParticleConfig(Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFFFFFFFF)),
    WallMaterial.lava:       _ParticleConfig(Color(0xFFE53935), Color(0xFFFF6D00), Color(0xFFFFEB3B)),
    WallMaterial.ice:        _ParticleConfig(Color(0xFF81D4FA), Color(0xFFE3F2FD), Color(0xFFFFFFFF)),
    WallMaterial.metal:      _ParticleConfig(Color(0xFF78909C), Color(0xFF455A64), Color(0xFFFFEB3B)),
  };

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _pool = List.generate(poolSize, (_) => _Particle());
    _initPaints();
  }

  void _initPaints() {
    _sparkPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    _debrisPaint = Paint()
      ..style = PaintingStyle.fill;

    _smokePaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    _flashPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
  }

  // ─── Spawners ─────────────────────────────────────────────────────────────

  /// Spawned on ball-wall contact.
  void spawnImpact({
    required Vector2 position,
    required WallMaterial material,
    required Color ballColor,
  }) {
    final cfg = _materialConfigs[material] ?? _materialConfigs[WallMaterial.stone]!;

    // Sparks
    _spawnBurst(
      count: 8,
      position: position,
      type: _ParticleType.spark,
      colorA: cfg.sparkColor,
      colorB: ballColor,
      speedMin: 60,
      speedMax: 220,
      lifetimeMin: 0.15,
      lifetimeMax: 0.45,
      sizeMin: 1.5,
      sizeMax: 4.0,
      gravity: 200,
    );

    // Flash
    _spawnSingle(
      position: position,
      type: _ParticleType.flash,
      colorA: Colors.white,
      colorB: ballColor,
      speed: 0,
      lifetime: 0.08,
      sizeStart: 20,
      sizeEnd: 0,
    );

    // Debris (1-3 chunks)
    _spawnBurst(
      count: 2,
      position: position,
      type: _ParticleType.debris,
      colorA: cfg.debrisColor,
      colorB: cfg.debrisColor,
      speedMin: 30,
      speedMax: 120,
      lifetimeMin: 0.4,
      lifetimeMax: 0.9,
      sizeMin: 3,
      sizeMax: 8,
      gravity: 300,
    );
  }

  /// Spawned on wall/tile destruction.
  void spawnDestruction({
    required Vector2 position,
    required WallMaterial material,
  }) {
    final cfg = _materialConfigs[material] ?? _materialConfigs[WallMaterial.stone]!;

    // Heavy debris shower
    _spawnBurst(
      count: 14,
      position: position,
      type: _ParticleType.debris,
      colorA: cfg.debrisColor,
      colorB: cfg.sparkColor,
      speedMin: 80,
      speedMax: 300,
      lifetimeMin: 0.5,
      lifetimeMax: 1.4,
      sizeMin: 4,
      sizeMax: 14,
      gravity: 400,
    );

    // Smoke cloud
    _spawnBurst(
      count: 5,
      position: position,
      type: _ParticleType.smoke,
      colorA: const Color(0x55888888),
      colorB: const Color(0x00888888),
      speedMin: 15,
      speedMax: 60,
      lifetimeMin: 0.6,
      lifetimeMax: 1.2,
      sizeMin: 10,
      sizeMax: 30,
      gravity: -20, // smoke rises
    );

    // Energy glow flash
    _spawnSingle(
      position: position,
      type: _ParticleType.flash,
      colorA: cfg.glowColor,
      colorB: Colors.transparent,
      speed: 0,
      lifetime: 0.25,
      sizeStart: 60,
      sizeEnd: 0,
    );
  }

  // ─── Internal Helpers ─────────────────────────────────────────────────────

  final math.Random _rng = math.Random();

  void _spawnBurst({
    required int count,
    required Vector2 position,
    required _ParticleType type,
    required Color colorA,
    required Color colorB,
    required double speedMin,
    required double speedMax,
    required double lifetimeMin,
    required double lifetimeMax,
    required double sizeMin,
    required double sizeMax,
    required double gravity,
  }) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * math.pi * 2;
      final speed = speedMin + _rng.nextDouble() * (speedMax - speedMin);
      _allocate(
        type: type,
        position: position.clone(),
        velocity: Vector2(math.cos(angle) * speed, math.sin(angle) * speed),
        lifetime: lifetimeMin + _rng.nextDouble() * (lifetimeMax - lifetimeMin),
        colorA: colorA,
        colorB: colorB,
        sizeStart: sizeMin + _rng.nextDouble() * (sizeMax - sizeMin),
        sizeEnd: 0,
        gravity: gravity,
      );
    }
  }

  void _spawnSingle({
    required Vector2 position,
    required _ParticleType type,
    required Color colorA,
    required Color colorB,
    required double speed,
    required double lifetime,
    required double sizeStart,
    required double sizeEnd,
  }) {
    _allocate(
      type: type,
      position: position.clone(),
      velocity: Vector2.zero(),
      lifetime: lifetime,
      colorA: colorA,
      colorB: colorB,
      sizeStart: sizeStart,
      sizeEnd: sizeEnd,
      gravity: 0,
    );
  }

  void _allocate({
    required _ParticleType type,
    required Vector2 position,
    required Vector2 velocity,
    required double lifetime,
    required Color colorA,
    required Color colorB,
    required double sizeStart,
    required double sizeEnd,
    required double gravity,
  }) {
    final p = _pool[_nextSlot % poolSize];
    _nextSlot++;

    p.active = true;
    p.type = type;
    p.x = position.x;
    p.y = position.y;
    p.vx = velocity.x;
    p.vy = velocity.y;
    p.lifetime = lifetime;
    p.maxLifetime = lifetime;
    p.colorA = colorA;
    p.colorB = colorB;
    p.sizeStart = sizeStart;
    p.sizeEnd = sizeEnd;
    p.gravity = gravity;
    p.rotation = _rng.nextDouble() * math.pi * 2;
    p.rotationSpeed = (_rng.nextDouble() - 0.5) * 8;
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    for (final p in _pool) {
      if (!p.active) continue;
      p.lifetime -= dt;
      if (p.lifetime <= 0) {
        p.active = false;
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.gravity * dt;
      p.vx *= 0.98; // drag
      p.rotation += p.rotationSpeed * dt;
    }
  }

  // ─── Render ───────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    for (final p in _pool) {
      if (!p.active) continue;
      final t = 1.0 - (p.lifetime / p.maxLifetime);
      final color = Color.lerp(p.colorA, p.colorB, t) ?? p.colorA;
      final size = p.sizeStart + (p.sizeEnd - p.sizeStart) * t;
      if (size <= 0) continue;

      switch (p.type) {
        case _ParticleType.spark:
          _sparkPaint.color = color;
          canvas.drawRect(
            Rect.fromCenter(center: Offset(p.x, p.y), width: size * 0.5, height: size),
            _sparkPaint,
          );
          break;

        case _ParticleType.debris:
          _debrisPaint.color = color;
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rotation);
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: size, height: size * 0.7),
            _debrisPaint,
          );
          canvas.restore();
          break;

        case _ParticleType.smoke:
          _smokePaint.color = color;
          canvas.drawCircle(Offset(p.x, p.y), size, _smokePaint);
          break;

        case _ParticleType.flash:
          _flashPaint.color = color;
          canvas.drawCircle(Offset(p.x, p.y), size, _flashPaint);
          break;
      }
    }
  }
}

// ─── Particle Data ────────────────────────────────────────────────────────────

enum _ParticleType { spark, debris, smoke, flash }

class _Particle {
  bool active = false;
  _ParticleType type = _ParticleType.spark;
  double x = 0, y = 0;
  double vx = 0, vy = 0;
  double lifetime = 0, maxLifetime = 1;
  Color colorA = const Color(0xFFFFFFFF);
  Color colorB = const Color(0x00FFFFFF);
  double sizeStart = 4, sizeEnd = 0;
  double gravity = 0;
  double rotation = 0, rotationSpeed = 0;
}

// ─── Config ───────────────────────────────────────────────────────────────────

class _ParticleConfig {
  final Color sparkColor;
  final Color debrisColor;
  final Color glowColor;

  const _ParticleConfig(this.sparkColor, this.debrisColor, this.glowColor);
}
