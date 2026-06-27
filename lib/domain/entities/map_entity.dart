// lib/domain/entities/map_entity.dart
// Wall tile model upgraded with full physics properties from the GDD.
// This replaces and extends TileModel / GridData from the original codebase.

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

// ─── Material ────────────────────────────────────────────────────────────────
// Every wall material carries physics and presentation properties.
// Backend can tune these independently without client updates (Remote Config).

enum WallMaterial {
  stone,
  reinforced,
  crystal,
  energy,
  wood,
  glass,
  lava,
  ice,
  metal,
}

// ─── Wall Type ───────────────────────────────────────────────────────────────
// Defines structural role and special behaviours.

enum WallRole {
  standard,       // Normal damage-taking wall
  unbreakable,    // Cannot be destroyed; counts as support
  support,        // Structural column — collapse causes chain reaction
  explosive,      // Detonates on destruction with AOE
  healing,        // Heals adjacent walls periodically
  invisible,      // Transparent until hit
  speed,          // Increases ball speed on contact
  multiHit,       // Takes 3× the normal hit count to reveal damage states
  reflector,      // Reflects ball at doubled angle
  gravitWell,     // Pulls the ball toward it
  trapBlock,      // Deals damage back to attacker
  decoy,          // Looks like Core; destroys ball on contact
}

// ─── Damage State ────────────────────────────────────────────────────────────
enum DamageState {
  pristine,
  minorCracks,
  heavyCracks,
  fractures,
  partialCollapse,
  majorCollapse,
  destroyed,
}

// ─── Tile Entity ─────────────────────────────────────────────────────────────
class TileEntity extends Equatable {
  // Grid position (column, row)
  final Offset position;

  // Visual
  final WallMaterial material;
  final Color tintColor;
  final String shape;             // Rectangle, Hexagon, Triangle, etc.
  final String? basePosition;    // Triangle orientation
  final String? shapeOrientation;
  final double rotationAngle;

  // Physics properties (all tunable per material / upgrade level)
  final double maxHealth;
  final double currentHealth;
  final double density;           // kg/m² — affects structural load calc
  final double elasticity;        // 0–1: how much kinetic energy is reflected
  final double friction;
  final double shockResistance;   // Reduces explosion radius transferred
  final double heatResistance;    // Reduces fire/lava damage
  final double electricResistance;

  // Structural role
  final WallRole role;
  final bool isBreakable;
  final int maxCountPerMap;       // Builder cap for this type

  // State
  final DamageState damageState;

  // Upgrade level (1–10, affects health and material resistances)
  final int upgradeLevel;

  const TileEntity({
    required this.position,
    required this.material,
    this.tintColor = Colors.transparent,
    this.shape = 'Rectangle',
    this.basePosition,
    this.shapeOrientation,
    this.rotationAngle = 0,
    required this.maxHealth,
    required this.currentHealth,
    this.density = 1.0,
    this.elasticity = 0.4,
    this.friction = 0.5,
    this.shockResistance = 0.0,
    this.heatResistance = 0.0,
    this.electricResistance = 0.0,
    this.role = WallRole.standard,
    this.isBreakable = true,
    this.maxCountPerMap = 9999,
    this.damageState = DamageState.pristine,
    this.upgradeLevel = 1,
  });

  double get healthPercent =>
      currentHealth.clamp(0, maxHealth) / maxHealth;

  DamageState get computedDamageState {
    final p = healthPercent;
    if (p > 0.85) return DamageState.pristine;
    if (p > 0.65) return DamageState.minorCracks;
    if (p > 0.45) return DamageState.heavyCracks;
    if (p > 0.25) return DamageState.fractures;
    if (p > 0.10) return DamageState.partialCollapse;
    if (p > 0.0)  return DamageState.majorCollapse;
    return DamageState.destroyed;
  }

  TileEntity takeDamage(double damage) => copyWith(
    currentHealth: (currentHealth - damage).clamp(0, maxHealth),
  );

  TileEntity heal(double amount) => copyWith(
    currentHealth: (currentHealth + amount).clamp(0, maxHealth),
  );

  TileEntity copyWith({
    Offset? position,
    WallMaterial? material,
    Color? tintColor,
    String? shape,
    String? basePosition,
    String? shapeOrientation,
    double? rotationAngle,
    double? maxHealth,
    double? currentHealth,
    double? density,
    double? elasticity,
    double? friction,
    double? shockResistance,
    double? heatResistance,
    double? electricResistance,
    WallRole? role,
    bool? isBreakable,
    int? maxCountPerMap,
    DamageState? damageState,
    int? upgradeLevel,
  }) {
    return TileEntity(
      position: position ?? this.position,
      material: material ?? this.material,
      tintColor: tintColor ?? this.tintColor,
      shape: shape ?? this.shape,
      basePosition: basePosition ?? this.basePosition,
      shapeOrientation: shapeOrientation ?? this.shapeOrientation,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      maxHealth: maxHealth ?? this.maxHealth,
      currentHealth: currentHealth ?? this.currentHealth,
      density: density ?? this.density,
      elasticity: elasticity ?? this.elasticity,
      friction: friction ?? this.friction,
      shockResistance: shockResistance ?? this.shockResistance,
      heatResistance: heatResistance ?? this.heatResistance,
      electricResistance: electricResistance ?? this.electricResistance,
      role: role ?? this.role,
      isBreakable: isBreakable ?? this.isBreakable,
      maxCountPerMap: maxCountPerMap ?? this.maxCountPerMap,
      damageState: damageState ?? this.damageState,
      upgradeLevel: upgradeLevel ?? this.upgradeLevel,
    );
  }

  @override
  List<Object?> get props => [
        position, material, shape, role, maxHealth, currentHealth,
        upgradeLevel, damageState,
      ];
}

// ─── Map Entity ───────────────────────────────────────────────────────────────
class MapEntity extends Equatable {
  final String id;
  final String ownerId;
  final int rows;
  final int columns;
  final Map<Offset, TileEntity> tiles;
  final bool isValidated;      // Set by backend validation engine
  final bool isPublic;
  final int likes;
  final int dislikes;
  final int totalAttacks;
  final int totalWins;         // Times defenders won (attacker failed)
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MapEntity({
    required this.id,
    required this.ownerId,
    required this.rows,
    required this.columns,
    required this.tiles,
    this.isValidated = false,
    this.isPublic = false,
    this.likes = 0,
    this.dislikes = 0,
    this.totalAttacks = 0,
    this.totalWins = 0,
    required this.createdAt,
    this.updatedAt,
  });

  int get tileCount => tiles.length;

  /// Returns tiles that act as structural supports for stress calculation
  List<TileEntity> get supportTiles => tiles.values
      .where((t) => t.role == WallRole.support || !t.isBreakable)
      .toList();

  /// Returns the Core tile — must exist exactly once
  TileEntity? get coreTile => tiles.values
      .where((t) => t.role == WallRole.decoy)
      .firstOrNull; // Will be renamed 'core' in full implementation

  double get defenseRating => totalAttacks == 0
      ? 0
      : totalWins / totalAttacks * 100;

  MapEntity copyWith({
    String? id,
    String? ownerId,
    int? rows,
    int? columns,
    Map<Offset, TileEntity>? tiles,
    bool? isValidated,
    bool? isPublic,
    int? likes,
    int? dislikes,
    int? totalAttacks,
    int? totalWins,
    DateTime? updatedAt,
  }) {
    return MapEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      tiles: tiles ?? this.tiles,
      isValidated: isValidated ?? this.isValidated,
      isPublic: isPublic ?? this.isPublic,
      likes: likes ?? this.likes,
      dislikes: dislikes ?? this.dislikes,
      totalAttacks: totalAttacks ?? this.totalAttacks,
      totalWins: totalWins ?? this.totalWins,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, ownerId, rows, columns, tiles, isValidated];
}
