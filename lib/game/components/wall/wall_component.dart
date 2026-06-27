// lib/game/components/wall/wall_component.dart
// WallComponent — Phase 1 implementation.
//
// Renders a wall tile with:
//   • 7 damage state visual progression (pristine → destroyed)
//   • Material-specific colors and glow effects
//   • Forge2D static body for physics collision
//   • Crack overlay drawn procedurally per damage state
//   • Destruction animation + removal
//   • Stress indicator (subtle pulse when under structural load)
//
// Performance notes:
//   • Uses PositionComponent (not RectangleComponent) to avoid unnecessary
//     rebuilds from Flame's component tree.
//   • Crack paths are pre-computed on first damage change and cached.
//   • No allocations in update() loop.

import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Vector2;
import 'package:flame_forge2d/flame_forge2d.dart' hide Vector2;
import 'package:flutter/material.dart' hide Gradient;

import 'package:shatterforge/domain/entities/map_entity.dart';
import 'package:shatterforge/core/theme/app_theme.dart';

typedef WallDestroyedCallback = void Function(WallComponent wall);

class WallComponent extends BodyComponent {
  WallComponent({
    required Vector2 position,
    required this.size,
    required this.tile,
    required this.onDestroyed,
  }) : _worldPos = position;

  final Vector2 _worldPos;
  final Vector2 size;
  TileEntity tile;
  final WallDestroyedCallback onDestroyed;

  // Runtime state
  double _currentHealth = 0;
  double _maxHealth = 0;
  DamageState _damageState = DamageState.pristine;
  bool _isCollapsing = false;
  double _collapseTimer = 0;
  double _collapseAlpha = 1.0;

  // Stress pulse animation
  double _stressPulse = 0;
  bool _pulsing = false;

  // Crack segments (pre-computed, cached)
  List<Offset> _crackPoints = [];
  bool _cracksDirty = true;

  // Paint objects (created once, reused)
  late final Paint _bodyPaint;
  late final Paint _glowPaint;
  late final Paint _crackPaint;
  late final Paint _borderPaint;

  static const double _collapseAnimDuration = 0.45;

  // ─── Material Config ───────────────────────────────────────────────────────

  static const Map<WallMaterial, _MaterialConfig> _materialConfigs = {
    WallMaterial.stone:      _MaterialConfig(Color(0xFF3A3840), Color(0xFF5A576A), Color(0xFFFF6B1A)),
    WallMaterial.reinforced: _MaterialConfig(Color(0xFF2A2A38), Color(0xFF4A4860), Color(0xFF9E9E9E)),
    WallMaterial.crystal:    _MaterialConfig(Color(0xFF1A2A3A), Color(0xFF3A5A7A), Color(0xFF00E5FF)),
    WallMaterial.energy:     _MaterialConfig(Color(0xFF1A1A2E), Color(0xFF2E2E56), Color(0xFF7B2FBE)),
    WallMaterial.wood:       _MaterialConfig(Color(0xFF3E2723), Color(0xFF5D4037), Color(0xFFFF8F00)),
    WallMaterial.glass:      _MaterialConfig(Color(0x33FFFFFF), Color(0x66FFFFFF), Color(0xFFE3F2FD)),
    WallMaterial.lava:       _MaterialConfig(Color(0xFF1A0A00), Color(0xFF3A1A00), Color(0xFFE53935)),
    WallMaterial.ice:        _MaterialConfig(Color(0xFF1A2A3A), Color(0xFF2A4A6A), Color(0xFF81D4FA)),
    WallMaterial.metal:      _MaterialConfig(Color(0xFF1A1A1A), Color(0xFF3A3A3A), Color(0xFF78909C)),
  };

  _MaterialConfig get _config =>
      _materialConfigs[tile.material] ?? _materialConfigs[WallMaterial.stone]!;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _currentHealth = tile.maxHealth;
    _maxHealth = tile.maxHealth;
    _initPaints();
    _updateDamageState();
  }

  void _initPaints() {
    _bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false; // perf on mobile

    _glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    _crackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    _borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = false;
  }

  // ─── Forge2D Body ─────────────────────────────────────────────────────────

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = _worldPos / 30.0; // Forge2D scale: 30px = 1m

    final shape = PolygonShape()
      ..setAsBox(
        (size.x / 2) / 30.0,
        (size.y / 2) / 30.0,
        Vector2(0, 0),
        0,
      );

    final fixtureDef = FixtureDef(shape)
      ..density = tile.density
      ..friction = tile.friction
      ..restitution = tile.elasticity;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  // ─── Damage ───────────────────────────────────────────────────────────────

  void takeDamage(double damage) {
    if (_isCollapsing) return;
    _currentHealth = (_currentHealth - damage).clamp(0, _maxHealth);
    _cracksDirty = true;
    _updateDamageState();
    _triggerStressPulse();

    if (_currentHealth <= 0) {
      _beginCollapse();
    }
  }

  void collapse() {
    if (!_isCollapsing) _beginCollapse();
  }

  void _beginCollapse() {
    if (_isCollapsing) return;
    _isCollapsing = true;
    _collapseTimer = 0;
    body.setType(BodyType.dynamic); // let it fall physically
    body.linearVelocity = Vector2(
      (math.Random().nextDouble() - 0.5) * 2,
      -1.0,
    );
    body.angularVelocity = (math.Random().nextDouble() - 0.5) * 3;
  }

  void _updateDamageState() {
    final prev = _damageState;
    _damageState = tile.copyWith(currentHealth: _currentHealth).computedDamageState;
    if (_damageState != prev) _cracksDirty = true;
  }

  void _triggerStressPulse() {
    _pulsing = true;
    _stressPulse = 0;
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    // Stress pulse
    if (_pulsing) {
      _stressPulse += dt * 6;
      if (_stressPulse >= math.pi) {
        _stressPulse = 0;
        _pulsing = false;
      }
    }

    // Collapse animation
    if (_isCollapsing) {
      _collapseTimer += dt;
      _collapseAlpha = (1 - _collapseTimer / _collapseAnimDuration).clamp(0, 1);
      if (_collapseTimer >= _collapseAnimDuration) {
        onDestroyed(this);
        removeFromParent();
      }
    }
  }

  // ─── Rendering ────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    if (_collapseAlpha <= 0) return;

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.x,
      height: size.y,
    );

    canvas.save();
    if (_isCollapsing) {
      canvas.drawColor(
        Colors.transparent,
        BlendMode.clear,
      );
    }

    if (_collapseAlpha < 1) {
      canvas.saveLayer(
        rect,
        Paint()..color = Color.fromRGBO(255, 255, 255, _collapseAlpha),
      );
    }

    // ── Background glow (energy / lava materials pulse) ──
    if (tile.material == WallMaterial.energy || tile.material == WallMaterial.lava) {
      final glowIntensity = _pulsing ? 0.4 + math.sin(_stressPulse) * 0.2 : 0.35;
      _glowPaint.color = _config.glowColor.withOpacity(glowIntensity);
      canvas.drawRect(rect.inflate(3), _glowPaint);
    }

    // ── Body fill (damage-tinted) ──
    final healthFraction = _currentHealth / _maxHealth;
    _bodyPaint.color = Color.lerp(
      _config.baseColor,
      _config.highlightColor,
      healthFraction,
    )!;

    // Damage darkening
    if (_damageState != DamageState.pristine) {
      final darkFactor = _damageDarkFactor(_damageState);
      _bodyPaint.color = Color.lerp(
        _bodyPaint.color,
        Colors.black,
        darkFactor,
      )!;
    }

    canvas.drawRect(rect, _bodyPaint);

    // ── Energy cracks / glow lines ──
    if (tile.material == WallMaterial.energy || tile.material == WallMaterial.lava) {
      _drawEnergyLines(canvas, rect);
    }

    // ── Cracks overlay ──
    if (_damageState != DamageState.pristine && _damageState != DamageState.destroyed) {
      _drawCracks(canvas, rect);
    }

    // ── Border ──
    _borderPaint.color = _config.glowColor.withOpacity(0.4);
    canvas.drawRect(rect.deflate(0.4), _borderPaint);

    // ── Role indicator (Core shield, reflector, etc.) ──
    _drawRoleIndicator(canvas, rect);

    if (_collapseAlpha < 1) canvas.restore();
    canvas.restore();
  }

  void _drawEnergyLines(Canvas canvas, Rect rect) {
    final rng = math.Random(tile.position.hashCode);
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _config.glowColor.withOpacity(0.6);

    for (int i = 0; i < 3; i++) {
      final x1 = rect.left + rng.nextDouble() * rect.width;
      final y1 = rect.top + rng.nextDouble() * rect.height;
      final x2 = rect.left + rng.nextDouble() * rect.width;
      final y2 = rect.top + rng.nextDouble() * rect.height;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  void _drawCracks(Canvas canvas, Rect rect) {
    if (_cracksDirty) {
      _crackPoints = _generateCrackPoints(rect, _damageState);
      _cracksDirty = false;
    }
    if (_crackPoints.isEmpty) return;

    _crackPaint.color = Colors.black.withOpacity(0.7);

    final path = Path();
    for (int i = 0; i < _crackPoints.length - 1; i += 2) {
      path.moveTo(_crackPoints[i].dx, _crackPoints[i].dy);
      path.lineTo(_crackPoints[i + 1].dx, _crackPoints[i + 1].dy);
    }
    canvas.drawPath(path, _crackPaint);

    // Light crack highlight (1px offset)
    _crackPaint.color = Colors.white.withOpacity(0.15);
    canvas.drawPath(path.shift(const Offset(0.5, 0.5)), _crackPaint);
  }

  List<Offset> _generateCrackPoints(Rect rect, DamageState state) {
    final rng = math.Random(tile.position.hashCode + state.index * 1000);
    final lines = <Offset>[];
    final count = _crackCountForState(state);

    for (int i = 0; i < count; i++) {
      // Start from edge or center based on damage level
      final cx = rect.left + rng.nextDouble() * rect.width;
      final cy = rect.top + rng.nextDouble() * rect.height;
      final angle = rng.nextDouble() * math.pi * 2;
      final length = 4.0 + rng.nextDouble() * (rect.shortestSide * 0.4);

      var px = cx;
      var py = cy;
      int segments = 2 + rng.nextInt(3);

      for (int s = 0; s < segments; s++) {
        final segLen = length / segments;
        final endX = px + math.cos(angle + (rng.nextDouble() - 0.5) * 0.8) * segLen;
        final endY = py + math.sin(angle + (rng.nextDouble() - 0.5) * 0.8) * segLen;
        lines.add(Offset(px, py));
        lines.add(Offset(endX, endY));
        px = endX;
        py = endY;
      }
    }
    return lines;
  }

  int _crackCountForState(DamageState state) {
    switch (state) {
      case DamageState.pristine: return 0;
      case DamageState.minorCracks: return 2;
      case DamageState.heavyCracks: return 5;
      case DamageState.fractures: return 9;
      case DamageState.partialCollapse: return 14;
      case DamageState.majorCollapse: return 20;
      case DamageState.destroyed: return 0;
    }
  }

  double _damageDarkFactor(DamageState state) {
    switch (state) {
      case DamageState.pristine: return 0;
      case DamageState.minorCracks: return 0.05;
      case DamageState.heavyCracks: return 0.15;
      case DamageState.fractures: return 0.28;
      case DamageState.partialCollapse: return 0.42;
      case DamageState.majorCollapse: return 0.60;
      case DamageState.destroyed: return 0.85;
    }
  }

  void _drawRoleIndicator(Canvas canvas, Rect rect) {
    switch (tile.role) {
      case WallRole.reflector:
        final p = Paint()
          ..color = SFColors.crystalCyanDim
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 4, p);
        break;
      case WallRole.explosive:
        final p = Paint()
          ..color = SFColors.lavaRed.withOpacity(0.6)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 5, p);
        break;
      case WallRole.gravitWell:
        final p = Paint()
          ..color = SFColors.coreBlueDim
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, 4, p);
        break;
      default:
        break;
    }
  }
}

// ─── Material Config Helper ───────────────────────────────────────────────────

class _MaterialConfig {
  final Color baseColor;
  final Color highlightColor;
  final Color glowColor;

  const _MaterialConfig(this.baseColor, this.highlightColor, this.glowColor);
}
