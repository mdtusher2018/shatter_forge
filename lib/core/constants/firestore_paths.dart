// lib/core/constants/firestore_paths.dart
// Centralised Firestore collection paths.
// Change collection names here, never scattered across the codebase.

class FirestorePaths {
  FirestorePaths._();

  // Top-level collections
  static const String players = 'players';
  static const String maps = 'maps';
  static const String matches = 'matches';
  static const String leaderboard = 'leaderboard';
  static const String guilds = 'guilds';
  static const String replays = 'replays';

  // Document paths
  static String player(String uid) => '$players/$uid';
  static String map(String mapId) => '$maps/$mapId';
  static String match(String matchId) => '$matches/$matchId';
  static String replay(String replayId) => '$replays/$replayId';
  static String guild(String guildId) => '$guilds/$guildId';

  // Subcollections
  static String guildMembers(String guildId) => '$guilds/$guildId/members';
  static String guildMember(String guildId, String uid) =>
      '$guilds/$guildId/members/$uid';
}
