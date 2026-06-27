// lib/data/models/player_model.dart
// Data layer model: handles Firestore serialization.
// Maps TO/FROM the domain PlayerEntity.
// This is the ONLY place where Firebase field names are hardcoded.

import '../../domain/entities/player_entity.dart';

class PlayerModel {
  final String uid;
  final String gameId;
  final String name;
  final String? avatarUrl;
  final int level;
  final int xp;
  final int elo;
  final int coins;
  final int gems;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int totalTilesDestroyed;
  final Map<String, int> wallUpgrades;
  final List<String> unlockedBalls;
  final String activeBallId;
  final String? activeHeroId;

  const PlayerModel({
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
    this.unlockedBalls = const ['stone_ball'],
    this.activeBallId = 'stone_ball',
    this.activeHeroId,
  });

  // ─── Firestore ──────────────────────────────────────────────────────────
  factory PlayerModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return PlayerModel(
      uid: uid,
      gameId: data['gameId'] as String? ?? uid,
      name: data['name'] as String? ?? 'Unnamed',
      avatarUrl: data['avatarUrl'] as String?,
      level: (data['level'] as num?)?.toInt() ?? 1,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      elo: (data['elo'] as num?)?.toInt() ?? 1000,
      coins: (data['coins'] as num?)?.toInt() ?? 500,
      gems: (data['gems'] as num?)?.toInt() ?? 0,
      matchesPlayed: (data['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (data['matchesWon'] as num?)?.toInt() ?? 0,
      matchesLost: (data['matchesLost'] as num?)?.toInt() ?? 0,
      totalTilesDestroyed: (data['totalTilesDestroyed'] as num?)?.toInt() ?? 0,
      wallUpgrades: (data['wallUpgrades'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
          {},
      unlockedBalls: (data['unlockedBalls'] as List<dynamic>?)
              ?.cast<String>() ??
          ['stone_ball'],
      activeBallId: data['activeBallId'] as String? ?? 'stone_ball',
      activeHeroId: data['activeHeroId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'gameId': gameId,
        'name': name,
        'avatarUrl': avatarUrl,
        'level': level,
        'xp': xp,
        'elo': elo,
        'coins': coins,
        'gems': gems,
        'matchesPlayed': matchesPlayed,
        'matchesWon': matchesWon,
        'matchesLost': matchesLost,
        'totalTilesDestroyed': totalTilesDestroyed,
        'wallUpgrades': wallUpgrades,
        'unlockedBalls': unlockedBalls,
        'activeBallId': activeBallId,
        'activeHeroId': activeHeroId,
      };

  // ─── Domain conversion ──────────────────────────────────────────────────
  PlayerEntity toEntity() => PlayerEntity(
        uid: uid,
        gameId: gameId,
        name: name,
        avatarUrl: avatarUrl,
        level: level,
        xp: xp,
        elo: elo,
        coins: coins,
        gems: gems,
        matchesPlayed: matchesPlayed,
        matchesWon: matchesWon,
        matchesLost: matchesLost,
        totalTilesDestroyed: totalTilesDestroyed,
        wallUpgrades: wallUpgrades,
        unlockedBalls: unlockedBalls.toSet(),
        activeBallId: activeBallId,
        activeHeroId: activeHeroId,
      );

  static PlayerModel fromEntity(PlayerEntity entity) => PlayerModel(
        uid: entity.uid,
        gameId: entity.gameId,
        name: entity.name,
        avatarUrl: entity.avatarUrl,
        level: entity.level,
        xp: entity.xp,
        elo: entity.elo,
        coins: entity.coins,
        gems: entity.gems,
        matchesPlayed: entity.matchesPlayed,
        matchesWon: entity.matchesWon,
        matchesLost: entity.matchesLost,
        totalTilesDestroyed: entity.totalTilesDestroyed,
        wallUpgrades: entity.wallUpgrades,
        unlockedBalls: entity.unlockedBalls.toList(),
        activeBallId: entity.activeBallId,
        activeHeroId: entity.activeHeroId,
      );
}
