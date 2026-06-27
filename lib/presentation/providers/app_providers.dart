// lib/presentation/providers/app_providers.dart
// All Riverpod providers for Phase 0.
// As the app grows, split into feature-level provider files.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/remote/player_remote_datasource.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../domain/entities/player_entity.dart';
import '../../core/errors/failures.dart';
import 'package:dartz/dartz.dart';

// ─── Infrastructure ──────────────────────────────────────────────────────────

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// ─── Auth ────────────────────────────────────────────────────────────────────

/// Emits the current Firebase User (or null when signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Convenience: the current user's UID, or null.
final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// True when a user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUidProvider) != null;
});

// ─── Datasources ─────────────────────────────────────────────────────────────

final playerRemoteDatasourceProvider = Provider<PlayerRemoteDatasource>((ref) {
  return PlayerRemoteDatasourceImpl(ref.watch(firestoreProvider));
});

// ─── Repositories ────────────────────────────────────────────────────────────

final playerRepositoryProvider = Provider<PlayerRepositoryImpl>((ref) {
  return PlayerRepositoryImpl(ref.watch(playerRemoteDatasourceProvider));
});

// ─── Player ──────────────────────────────────────────────────────────────────

/// Live stream of the current player's data. Rebuilds on auth change.
final currentPlayerProvider =
    StreamProvider<Either<Failure, PlayerEntity>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const Left(SessionExpiredFailure()));
  return ref.watch(playerRepositoryProvider).watchPlayer(uid);
});

/// Unwrapped player entity — null while loading or if error.
final playerEntityProvider = Provider<PlayerEntity?>((ref) {
  return ref.watch(currentPlayerProvider).valueOrNull?.getOrElse(() => throw StateError('no player')); // handled by UI
});

// ─── Match State (stub for Phase 1) ──────────────────────────────────────────

enum MatchPhase { idle, matchmaking, planning, attacking, results }

final matchPhaseProvider = StateProvider<MatchPhase>((ref) => MatchPhase.idle);
