// lib/data/datasources/remote/player_remote_datasource.dart
// The ONLY file that may import cloud_firestore for player data.
// Throws exceptions — the repository layer converts them to Failures.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/player_model.dart';
import '../../../core/constants/firestore_paths.dart';

abstract interface class PlayerRemoteDatasource {
  Stream<PlayerModel> watchPlayer(String uid);
  Future<PlayerModel> getPlayer(String uid);
  Future<void> createPlayer(PlayerModel model);
  Future<void> updateProfile(String uid, Map<String, dynamic> fields);
}

class PlayerRemoteDatasourceImpl implements PlayerRemoteDatasource {
  final FirebaseFirestore _db;

  PlayerRemoteDatasourceImpl(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection(FirestorePaths.players).doc(uid);

  @override
  Stream<PlayerModel> watchPlayer(String uid) {
    return _doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Player document not found: $uid',
        );
      }
      return PlayerModel.fromFirestore(snap.data()!, uid);
    });
  }

  @override
  Future<PlayerModel> getPlayer(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists || snap.data() == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'not-found',
        message: 'Player not found: $uid',
      );
    }
    return PlayerModel.fromFirestore(snap.data()!, uid);
  }

  @override
  Future<void> createPlayer(PlayerModel model) async {
    await _doc(model.uid).set(model.toFirestore());
  }

  @override
  Future<void> updateProfile(String uid, Map<String, dynamic> fields) async {
    // Security rules enforce allowed field list — no client-side allow-list needed here
    await _doc(uid).update(fields);
  }
}
