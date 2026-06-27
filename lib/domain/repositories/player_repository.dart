// lib/domain/repositories/player_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/player_entity.dart';
import '../../core/errors/failures.dart';

abstract interface class PlayerRepository {
  /// Stream of the currently signed-in player's live data.
  Stream<Either<Failure, PlayerEntity>> watchCurrentPlayer();

  /// Fetch any player by UID (for leaderboard, spectator, etc.)
  Future<Either<Failure, PlayerEntity>> getPlayer(String uid);

  /// Update display fields (name, avatarUrl).
  Future<Either<Failure, void>> updateProfile({
    required String uid,
    String? name,
    String? avatarUrl,
  });

  /// Equip a ball — validated against unlockedBalls on backend.
  Future<Either<Failure, void>> equipBall({
    required String uid,
    required String ballId,
  });
}
