// lib/domain/entities/ball_entity.dart
// All 23 ball types from the GDD defined as domain entities.
// Physics properties are tunable via Remote Config or backend data.

import 'package:equatable/equatable.dart';

enum BallCategory {
  physical,   // Stone, Steel, Heavy — purely kinetic
  explosive,  // Explosive, Cluster, Meteor — area damage
  elemental,  // Fire, Ice, Acid, Plasma, Lava — material reactions
  energy,     // Gravity, EMP, Laser, Void, Black Hole — field effects
  tactical,   // Sticky, Magnetic, Chain Lightning, Ricochet — trajectory
  advanced,   // Drill, Nano, Rocket — special mechanics
}

class BallDefinition extends Equatable {
  final String id;
  final String displayName;
  final String description;
  final BallCategory category;

  // Physics
  final double baseDamage;
  final double radius;
  final double mass;
  final double bounciness;      // 0 = dead stop, 1 = perfect elastic
  final double penetration;     // 0 = stops on first hit, 1 = passes through
  final int maxBounces;         // -1 = unlimited

  // Special behavior flags
  final bool hasAreaEffect;
  final double areaRadius;      // Only if hasAreaEffect
  final bool pierces;           // Passes through walls
  final bool splits;            // Splits into sub-projectiles
  final int splitCount;
  final bool hasGravityField;
  final bool disablesShields;
  final bool ignites;
  final bool freezes;
  final bool corrodes;

  // Unlock / progression
  final int unlockLevel;        // Player level required
  final int coinCost;           // Unlock cost (0 = free / starter)
  final bool isPremium;         // Requires gems or battle pass

  const BallDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.category,
    required this.baseDamage,
    this.radius = 12.0,
    this.mass = 1.0,
    this.bounciness = 0.6,
    this.penetration = 0.0,
    this.maxBounces = 8,
    this.hasAreaEffect = false,
    this.areaRadius = 0,
    this.pierces = false,
    this.splits = false,
    this.splitCount = 0,
    this.hasGravityField = false,
    this.disablesShields = false,
    this.ignites = false,
    this.freezes = false,
    this.corrodes = false,
    this.unlockLevel = 1,
    this.coinCost = 0,
    this.isPremium = false,
  });

  @override
  List<Object?> get props => [id];
}

// ─── All 23 Ball Definitions ─────────────────────────────────────────────────
class BallLibrary {
  BallLibrary._();

  static const Map<String, BallDefinition> all = {
    'stone_ball': BallDefinition(
      id: 'stone_ball',
      displayName: 'Stone Ball',
      description: 'The standard projectile. Reliable, predictable trajectory.',
      category: BallCategory.physical,
      baseDamage: 50,
      mass: 1.0,
      bounciness: 0.55,
      maxBounces: 10,
      unlockLevel: 1,
      coinCost: 0,
    ),
    'steel_ball': BallDefinition(
      id: 'steel_ball',
      displayName: 'Steel Ball',
      description: 'Heavier — more wall damage, less bounce height.',
      category: BallCategory.physical,
      baseDamage: 85,
      mass: 2.2,
      bounciness: 0.35,
      radius: 13.0,
      maxBounces: 6,
      unlockLevel: 3,
      coinCost: 800,
    ),
    'heavy_ball': BallDefinition(
      id: 'heavy_ball',
      displayName: 'Heavy Ball',
      description: 'Massive kinetic force. Crushes support columns in one hit.',
      category: BallCategory.physical,
      baseDamage: 140,
      mass: 4.0,
      bounciness: 0.15,
      radius: 16.0,
      maxBounces: 3,
      unlockLevel: 6,
      coinCost: 2000,
    ),
    'explosive_ball': BallDefinition(
      id: 'explosive_ball',
      displayName: 'Explosive Ball',
      description: 'Detonates on impact. Damages all tiles in radius.',
      category: BallCategory.explosive,
      baseDamage: 60,
      bounciness: 0.0,
      hasAreaEffect: true,
      areaRadius: 80.0,
      maxBounces: 1,
      unlockLevel: 5,
      coinCost: 1500,
    ),
    'cluster_ball': BallDefinition(
      id: 'cluster_ball',
      displayName: 'Cluster Ball',
      description: 'Splits into 5 sub-projectiles on first impact.',
      category: BallCategory.explosive,
      baseDamage: 30,
      bounciness: 0.5,
      splits: true,
      splitCount: 5,
      maxBounces: 4,
      unlockLevel: 8,
      coinCost: 2500,
    ),
    'plasma_ball': BallDefinition(
      id: 'plasma_ball',
      displayName: 'Plasma Ball',
      description: 'Bypasses energy shields. Melts crystal walls instantly.',
      category: BallCategory.elemental,
      baseDamage: 75,
      bounciness: 0.7,
      disablesShields: true,
      maxBounces: 8,
      unlockLevel: 10,
      coinCost: 3000,
    ),
    'gravity_ball': BallDefinition(
      id: 'gravity_ball',
      displayName: 'Gravity Ball',
      description: 'Emits a gravity pulse on impact. Pulls surrounding tiles.',
      category: BallCategory.energy,
      baseDamage: 40,
      bounciness: 0.5,
      hasGravityField: true,
      hasAreaEffect: true,
      areaRadius: 100.0,
      unlockLevel: 12,
      coinCost: 3500,
    ),
    'laser_ball': BallDefinition(
      id: 'laser_ball',
      displayName: 'Laser Ball',
      description: 'Pierces through all walls in its path. No bounce.',
      category: BallCategory.energy,
      baseDamage: 55,
      pierces: true,
      bounciness: 0.0,
      maxBounces: 0,
      unlockLevel: 14,
      coinCost: 4000,
    ),
    'drill_ball': BallDefinition(
      id: 'drill_ball',
      displayName: 'Drill Ball',
      description: 'Bores through the first wall it hits, exiting the other side.',
      category: BallCategory.advanced,
      baseDamage: 90,
      pierces: true,
      penetration: 0.5,
      bounciness: 0.2,
      maxBounces: 5,
      unlockLevel: 15,
      coinCost: 4500,
    ),
    'emp_ball': BallDefinition(
      id: 'emp_ball',
      displayName: 'EMP Ball',
      description: 'Disables energy shields and turrets in large area.',
      category: BallCategory.energy,
      baseDamage: 20,
      bounciness: 0.6,
      hasAreaEffect: true,
      areaRadius: 150.0,
      disablesShields: true,
      unlockLevel: 11,
      coinCost: 3200,
    ),
    'ice_ball': BallDefinition(
      id: 'ice_ball',
      displayName: 'Ice Ball',
      description: 'Freezes walls on contact — frozen tiles shatter in one hit.',
      category: BallCategory.elemental,
      baseDamage: 45,
      bounciness: 0.65,
      freezes: true,
      unlockLevel: 7,
      coinCost: 2200,
    ),
    'fire_ball': BallDefinition(
      id: 'fire_ball',
      displayName: 'Fire Ball',
      description: 'Ignites on contact. Fire spreads to adjacent wood/crystal tiles.',
      category: BallCategory.elemental,
      baseDamage: 55,
      bounciness: 0.5,
      ignites: true,
      unlockLevel: 7,
      coinCost: 2200,
    ),
    'acid_ball': BallDefinition(
      id: 'acid_ball',
      displayName: 'Acid Ball',
      description: 'Corrodes walls over 3 seconds after impact. Stacks.',
      category: BallCategory.elemental,
      baseDamage: 30,
      bounciness: 0.55,
      corrodes: true,
      unlockLevel: 9,
      coinCost: 2800,
    ),
    'poison_ball': BallDefinition(
      id: 'poison_ball',
      displayName: 'Poison Ball',
      description: 'Spreads DOT effect to all tiles in contact with first hit.',
      category: BallCategory.elemental,
      baseDamage: 25,
      bounciness: 0.6,
      hasAreaEffect: true,
      areaRadius: 60.0,
      unlockLevel: 9,
      coinCost: 2800,
    ),
    'sticky_ball': BallDefinition(
      id: 'sticky_ball',
      displayName: 'Sticky Ball',
      description: 'Adheres to the first wall. Detonates after 1.5 seconds.',
      category: BallCategory.tactical,
      baseDamage: 80,
      bounciness: 0.0,
      hasAreaEffect: true,
      areaRadius: 70.0,
      maxBounces: 0,
      unlockLevel: 10,
      coinCost: 3000,
    ),
    'magnetic_ball': BallDefinition(
      id: 'magnetic_ball',
      displayName: 'Magnetic Ball',
      description: 'Attracted to metal and steel walls. Homes in after launch.',
      category: BallCategory.tactical,
      baseDamage: 70,
      bounciness: 0.4,
      maxBounces: 6,
      unlockLevel: 13,
      coinCost: 3800,
    ),
    'chain_lightning_ball': BallDefinition(
      id: 'chain_lightning_ball',
      displayName: 'Chain Lightning',
      description: 'Discharges electricity to up to 4 adjacent tiles on impact.',
      category: BallCategory.tactical,
      baseDamage: 40,
      bounciness: 0.55,
      hasAreaEffect: true,
      areaRadius: 40.0,
      maxBounces: 8,
      unlockLevel: 16,
      coinCost: 5000,
    ),
    'meteor_ball': BallDefinition(
      id: 'meteor_ball',
      displayName: 'Meteor Ball',
      description: 'Massive. Leaves burning crater. 3× explosion radius.',
      category: BallCategory.explosive,
      baseDamage: 200,
      radius: 20.0,
      mass: 6.0,
      bounciness: 0.0,
      hasAreaEffect: true,
      areaRadius: 140.0,
      maxBounces: 1,
      unlockLevel: 18,
      coinCost: 6000,
    ),
    'nano_ball': BallDefinition(
      id: 'nano_ball',
      displayName: 'Nano Ball',
      description: 'Tiny radius — passes through small gaps. Targets Core directly.',
      category: BallCategory.advanced,
      baseDamage: 35,
      radius: 5.0,
      mass: 0.3,
      bounciness: 0.8,
      maxBounces: 20,
      unlockLevel: 17,
      coinCost: 5500,
    ),
    'void_ball': BallDefinition(
      id: 'void_ball',
      displayName: 'Void Ball',
      description: 'Absorbs all wall energy on contact, then releases it at Core.',
      category: BallCategory.energy,
      baseDamage: 60,
      bounciness: 0.5,
      maxBounces: 6,
      unlockLevel: 19,
      coinCost: 7000,
    ),
    'black_hole_ball': BallDefinition(
      id: 'black_hole_ball',
      displayName: 'Black Hole',
      description: 'Pulls all nearby tiles into destruction radius. Rare drop.',
      category: BallCategory.energy,
      baseDamage: 150,
      hasAreaEffect: true,
      hasGravityField: true,
      areaRadius: 200.0,
      bounciness: 0.0,
      maxBounces: 1,
      unlockLevel: 25,
      coinCost: 0,
      isPremium: true,
    ),
    'ricochet_ball': BallDefinition(
      id: 'ricochet_ball',
      displayName: 'Ricochet Ball',
      description: 'Perfect angle preservation on every bounce. 20-bounce limit.',
      category: BallCategory.tactical,
      baseDamage: 45,
      bounciness: 1.0,
      maxBounces: 20,
      unlockLevel: 8,
      coinCost: 2500,
    ),
    'rocket_ball': BallDefinition(
      id: 'rocket_ball',
      displayName: 'Rocket Ball',
      description: 'Steers mid-flight using swipe. Detonates on command.',
      category: BallCategory.advanced,
      baseDamage: 100,
      hasAreaEffect: true,
      areaRadius: 90.0,
      bounciness: 0.0,
      maxBounces: 0,
      unlockLevel: 20,
      coinCost: 8000,
    ),
  };

  static BallDefinition? get(String id) => all[id];

  static List<BallDefinition> get starterBalls =>
      all.values.where((b) => b.unlockLevel <= 1).toList();

  static List<BallDefinition> byCategory(BallCategory cat) =>
      all.values.where((b) => b.category == cat).toList();
}
