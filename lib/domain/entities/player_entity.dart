// lib/domain/entities/player_entity.dart
// Pure domain object — no Firebase, no JSON. The source of truth for player state.

import 'package:equatable/equatable.dart';

class PlayerEntity extends Equatable {
  final String uid;
  final String gameId;
  final String name;
  final String? avatarUrl;

  // Progression
  final int level;
  final int xp;
  final int elo;

  // Economy
  final int coins;
  final int gems;

  // Stats
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int totalTilesDestroyed;

  // Wall upgrade levels (1–10 each)
  final Map<String, int> wallUpgrades;

  // Ball unlock status
  final Set<String> unlockedBalls;
  final String activeBallId;

  // Hero
  final String? activeHeroId;

  const PlayerEntity({
    required this.uid,
    required this.gameId,
    required this.name,
    this.avatarUrl,
    this.level = 1,
    this.xp = 0,
    this.elo = 1000,
    this.coins = 500,
    this.gems = 0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.matchesLost = 0,
    this.totalTilesDestroyed = 0,
    this.wallUpgrades = const {},
    this.unlockedBalls = const {'stone_ball'},
    this.activeBallId = 'stone_ball',
    this.activeHeroId,
  });

  double get winRate => matchesPlayed == 0
      ? 0
      : (matchesWon / matchesPlayed * 100);

  PlayerEntity copyWith({
    String? name,
    String? avatarUrl,
    int? level,
    int? xp,
    int? elo,
    int? coins,
    int? gems,
    int? matchesPlayed,
    int? matchesWon,
    int? matchesLost,
    int? totalTilesDestroyed,
    Map<String, int>? wallUpgrades,
    Set<String>? unlockedBalls,
    String? activeBallId,
    String? activeHeroId,
  }) {
    return PlayerEntity(
      uid: uid,
      gameId: gameId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      elo: elo ?? this.elo,
      coins: coins ?? this.coins,
      gems: gems ?? this.gems,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      matchesLost: matchesLost ?? this.matchesLost,
      totalTilesDestroyed: totalTilesDestroyed ?? this.totalTilesDestroyed,
      wallUpgrades: wallUpgrades ?? this.wallUpgrades,
      unlockedBalls: unlockedBalls ?? this.unlockedBalls,
      activeBallId: activeBallId ?? this.activeBallId,
      activeHeroId: activeHeroId ?? this.activeHeroId,
    );
  }

  @override
  List<Object?> get props => [
        uid, gameId, name, avatarUrl, level, xp, elo,
        coins, gems, matchesPlayed, matchesWon, matchesLost,
        totalTilesDestroyed, wallUpgrades, unlockedBalls,
        activeBallId, activeHeroId,
      ];
}
