// lib/core/constants/game_constants.dart — Phase 1 additions
// Extends the Phase 0 constants with Phase 1 physics values.
// Add these to the existing game_constants.dart file (or replace it entirely).

class GameConstants {
  GameConstants._();

  // ─── Physics ──────────────────────────────────────────────────────────────
  static const double gravity = 9.8;
  static const double ballBaseRadius = 12.0;
  static const double wallDefaultDensity = 1.0;
  static const double wallDefaultElasticity = 0.4;
  static const double wallDefaultFriction = 0.5;

  // Phase 1: ball launch speed (pixels/second)
  static const double ballBaseSpeed = 420.0;

  // Structural integrity
  static const double maxWallStress = 100.0;
  static const double stressTransferRatio = 0.6;
  static const double collapseChainDelayMs = 80.0;

  // ─── Map Builder ──────────────────────────────────────────────────────────
  static const int mapMinRows = 5;
  static const int mapMaxRows = 20;
  static const int mapMinCols = 5;
  static const int mapMaxCols = 20;
  static const int mapDefaultRows = 10;
  static const int mapDefaultCols = 10;
  static const int mapMinTiles = 20;
  static const double maxUnbreakableRatio = 0.25;
  static const int coreRequiredCount = 1;

  // ─── Base Validation Engine ───────────────────────────────────────────────
  static const int validationSimulations = 500;
  static const int validationTimeoutMs = 5000;

  // ─── Match ────────────────────────────────────────────────────────────────
  static const int matchDurationSeconds = 180;
  static const int planningPhaseSeconds = 30;
  static const int replayMaxDurationSeconds = 120;

  // ─── Ball ─────────────────────────────────────────────────────────────────
  static const int maxBallsPerTurn = 12;
  static const double ballMinSpeed = 200.0;
  static const double ballMaxSpeed = 800.0;
  static const double ballDefaultDamage = 50.0;

  // ─── Economy ──────────────────────────────────────────────────────────────
  static const int startingCoins = 500;
  static const int startingGems = 0;
  static const int coinsPerWin = 100;
  static const int coinsPerLoss = 20;
  static const int dailyChallengeReward = 250;

  // ─── Progression ──────────────────────────────────────────────────────────
  static const int maxPlayerLevel = 50;
  static const int startingElo = 1000;
  static const int eloGainPerWin = 25;
  static const int eloLossPerLoss = 20;

  // ─── Performance ──────────────────────────────────────────────────────────
  static const int particlePoolSize = 200;
  static const int debrisPoolSize = 100;
  static const int maxActiveParticles = 500;
  static const double targetFps = 60.0;

  // ─── UI ───────────────────────────────────────────────────────────────────
  static const double hudCornerRadius = 12.0;
  static const Duration uiTransitionDuration = Duration(milliseconds: 280);
  static const Duration screenFadeDuration = Duration(milliseconds: 400);
  static const Duration cameraShakeDuration = Duration(milliseconds: 350);
}
