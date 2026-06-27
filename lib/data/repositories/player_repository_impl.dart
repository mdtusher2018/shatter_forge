// lib/data/repositories/player_repository_impl.dart
// Implements the domain PlayerRepository contract.
// Converts raw datasource exceptions into typed domain Failures.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/player_entity.dart';
import '../../domain/repositories/player_repository.dart';
import '../datasources/remote/player_remote_datasource.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  final PlayerRemoteDatasource _remote;

  PlayerRepositoryImpl(this._remote);

  @override
  Stream<Either<Failure, PlayerEntity>> watchCurrentPlayer() {
    // This will be called with the current user's UID from the auth provider.
    // The provider layer passes the UID in; here we just expose the stream shape.
    throw UnimplementedError('Call watchPlayer(uid) instead.');
  }

  Stream<Either<Failure, PlayerEntity>> watchPlayer(String uid) {
    return _remote.watchPlayer(uid).map<Either<Failure, PlayerEntity>>(
      (model) => Right(model.toEntity()),
    ).handleError((error) {
      return Left(_mapException(error));
    });
  }

  @override
  Future<Either<Failure, PlayerEntity>> getPlayer(String uid) async {
    try {
      final model = await _remote.getPlayer(uid);
      return Right(model.toEntity());
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> updateProfile({
    required String uid,
    String? name,
    String? avatarUrl,
  }) async {
    try {
      final fields = <String, dynamic>{};
      if (name != null) fields['name'] = name;
      if (avatarUrl != null) fields['avatarUrl'] = avatarUrl;
      if (fields.isEmpty) return const Right(null);
      await _remote.updateProfile(uid, fields);
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  @override
  Future<Either<Failure, void>> equipBall({
    required String uid,
    required String ballId,
  }) async {
    try {
      await _remote.updateProfile(uid, {'activeBallId': ballId});
      return const Right(null);
    } catch (e) {
      return Left(_mapException(e));
    }
  }

  // ─── Exception → Failure mapping ───────────────────────────────────────
  Failure _mapException(Object e) {
    if (e is FirebaseException) {
      return switch (e.code) {
        'not-found'          => const NotFoundFailure('Player not found.'),
        'permission-denied'  => const PermissionFailure('Permission denied.'),
        'unavailable'        => const NetworkFailure(),
        'deadline-exceeded'  => const TimeoutFailure(),
        _                    => ServerFailure(message: e.message ?? 'Firebase error.'),
      };
    }
    return ServerFailure(message: e.toString());
  }
}
