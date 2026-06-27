// lib/domain/repositories/map_repository.dart
import 'package:dartz/dartz.dart';
import '../entities/map_entity.dart';
import '../../core/errors/failures.dart';

abstract interface class MapRepository {
  /// Watch the current player's saved map (live updates).
  Stream<Either<Failure, MapEntity?>> watchMyMap(String ownerId);

  /// Fetch a map by ID (for loading an opponent's base in a match).
  Future<Either<Failure, MapEntity>> getMap(String mapId);

  /// Save a map draft (isValidated will be false until backend confirms).
  Future<Either<Failure, String>> saveMap(MapEntity map);

  /// Submit map for backend validation.
  /// Returns the validated map with isValidated = true if it passes.
  Future<Either<Failure, MapEntity>> submitForValidation(String mapId);

  /// Paginated list of validated public maps for matchmaking pool.
  Future<Either<Failure, List<MapEntity>>> getPublicMaps({
    int limit = 20,
    String? afterId,
  });

  /// Record the result of an attack on this map (for defense rating).
  Future<Either<Failure, void>> recordAttackResult({
    required String mapId,
    required bool attackerWon,
  });
}
