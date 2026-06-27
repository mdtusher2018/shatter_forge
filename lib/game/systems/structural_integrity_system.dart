// lib/game/systems/structural_integrity_system.dart
// Structural Integrity System — Phase 0 skeleton, fully implemented in Phase 1.
//
// HOW IT WORKS:
//   1. Every tile has a load it can bear (based on material + upgrade level).
//   2. When a support tile is destroyed, its load redistributes to neighbours.
//   3. If a neighbour exceeds its stress threshold, it collapses too (chain).
//   4. Floating tiles with no support path to the fortress anchor collapse.
//
// This file defines the interface and data types.
// The Flame/forge2d integration happens in Phase 1.

import 'dart:ui';
import '../../domain/entities/map_entity.dart';

// ─── Stress Node ─────────────────────────────────────────────────────────────
// Lightweight runtime representation of each tile's structural state.

class StressNode {
  final Offset gridPosition;
  double currentStress;     // 0.0 – 100.0
  double maxStress;         // Collapses when exceeded
  bool isAnchored;          // True if connected to fortress anchor
  bool isDestroyed;

  StressNode({
    required this.gridPosition,
    required this.maxStress,
    this.currentStress = 0.0,
    this.isAnchored = false,
    this.isDestroyed = false,
  });
}

// ─── Collapse Event ───────────────────────────────────────────────────────────
class CollapseEvent {
  final Offset position;
  final CollapseReason reason;
  final int chainDepth;   // 0 = directly destroyed, 1+ = cascade

  const CollapseEvent({
    required this.position,
    required this.reason,
    this.chainDepth = 0,
  });
}

enum CollapseReason {
  directDamage,
  stressOverload,
  floatingDetached,
  explosionRadius,
}

// ─── System Interface ─────────────────────────────────────────────────────────
abstract class StructuralIntegritySystem {
  /// Build the stress graph from a MapEntity at match start.
  void initialize(MapEntity map);

  /// Apply damage to a tile. Returns all collapse events triggered.
  /// Includes chain reactions.
  List<CollapseEvent> applyDamage({
    required Offset position,
    required double damage,
    bool isExplosion = false,
    double explosionRadius = 0,
  });

  /// Re-check floating tiles after any collapse.
  /// Returns positions of tiles that detach due to loss of support.
  List<Offset> resolveFloating();

  /// Returns the stress value (0–100) for display / AI use.
  double getStress(Offset position);

  /// Returns true if the Core tile still exists (match not over).
  bool isCoreAlive();

  /// Dispose all internal state.
  void dispose();
}

// ─── Simple Implementation (Phase 0 placeholder) ─────────────────────────────
// Replaced by forge2d-backed implementation in Phase 1.

class SimpleStructuralIntegritySystem implements StructuralIntegritySystem {
  final Map<Offset, StressNode> _nodes = {};
  Offset? _corePosition;

  static const double _stressTransferRatio = 0.6;
  static const double _maxStressDefault = 100.0;

  @override
  void initialize(MapEntity map) {
    _nodes.clear();
    _corePosition = null;

    for (final entry in map.tiles.entries) {
      final tile = entry.value;
      final stress = tile.isBreakable ? _maxStressDefault : double.infinity;
      _nodes[entry.key] = StressNode(
        gridPosition: entry.key,
        maxStress: stress,
        isAnchored: !tile.isBreakable,
      );

      // Mark Core position (role == WallRole.decoy used as placeholder)
      if (tile.role == WallRole.decoy) {
        _corePosition = entry.key;
      }
    }

    _propagateAnchors();
  }

  @override
  List<CollapseEvent> applyDamage({
    required Offset position,
    required double damage,
    bool isExplosion = false,
    double explosionRadius = 0,
  }) {
    final events = <CollapseEvent>[];
    final node = _nodes[position];
    if (node == null || node.isDestroyed) return events;

    node.currentStress += damage;

    if (node.currentStress >= node.maxStress) {
      _collapse(node, CollapseReason.directDamage, 0, events);
    }

    if (isExplosion && explosionRadius > 0) {
      _applyExplosion(position, damage * 0.5, explosionRadius, events);
    }

    return events;
  }

  void _collapse(StressNode node, CollapseReason reason, int depth,
      List<CollapseEvent> events) {
    if (node.isDestroyed) return;
    node.isDestroyed = true;
    events.add(CollapseEvent(
      position: node.gridPosition,
      reason: reason,
      chainDepth: depth,
    ));

    // Transfer stress to adjacent nodes
    final neighbours = _getNeighbours(node.gridPosition);
    for (final neighbour in neighbours) {
      if (neighbour.isDestroyed) continue;
      neighbour.currentStress += node.currentStress * _stressTransferRatio;
      if (neighbour.currentStress >= neighbour.maxStress) {
        _collapse(neighbour, CollapseReason.stressOverload, depth + 1, events);
      }
    }
  }

  void _applyExplosion(Offset center, double damage, double radius,
      List<CollapseEvent> events) {
    for (final entry in _nodes.entries) {
      if (entry.value.isDestroyed) continue;
      final dx = entry.key.dx - center.dx;
      final dy = entry.key.dy - center.dy;
      // Grid distance approximation (actual pixel distance computed in Phase 1)
      final dist = (dx * dx + dy * dy).abs();
      if (dist < radius / 80) {
        // 80 = approx tile size placeholder
        entry.value.currentStress += damage * (1 - dist / (radius / 80));
        if (entry.value.currentStress >= entry.value.maxStress) {
          _collapse(entry.value, CollapseReason.explosionRadius, 1, events);
        }
      }
    }
  }

  @override
  List<Offset> resolveFloating() {
    _propagateAnchors();
    final detached = <Offset>[];
    for (final entry in _nodes.entries) {
      if (!entry.value.isDestroyed && !entry.value.isAnchored) {
        entry.value.isDestroyed = true;
        detached.add(entry.key);
      }
    }
    return detached;
  }

  void _propagateAnchors() {
    // BFS from anchor nodes to mark all connected tiles as anchored
    final queue = <Offset>[];
    for (final entry in _nodes.entries) {
      entry.value.isAnchored = false;
      if (entry.value.maxStress == double.infinity) {
        entry.value.isAnchored = true;
        queue.add(entry.key);
      }
    }
    while (queue.isNotEmpty) {
      final pos = queue.removeAt(0);
      for (final n in _getNeighbours(pos)) {
        if (!n.isDestroyed && !n.isAnchored) {
          n.isAnchored = true;
          queue.add(n.gridPosition);
        }
      }
    }
  }

  List<StressNode> _getNeighbours(Offset pos) {
    final dirs = [
      const Offset(1, 0), const Offset(-1, 0),
      const Offset(0, 1), const Offset(0, -1),
    ];
    return dirs
        .map((d) => _nodes[Offset(pos.dx + d.dx, pos.dy + d.dy)])
        .whereType<StressNode>()
        .toList();
  }

  @override
  double getStress(Offset position) => _nodes[position]?.currentStress ?? 0;

  @override
  bool isCoreAlive() {
    if (_corePosition == null) return false;
    return !(_nodes[_corePosition!]?.isDestroyed ?? true);
  }

  @override
  void dispose() => _nodes.clear();
}
