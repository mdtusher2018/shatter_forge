// lib/presentation/widgets/hud/planning_overlay.dart
// PlanningOverlay — shown during the 30-second planning phase.
// Player sees the fortress, reviews ball loadout, can skip early.

import 'package:flutter/material.dart';
import 'package:shatterforge/core/theme/app_theme.dart';
import 'package:shatterforge/domain/entities/ball_entity.dart';

class PlanningOverlay extends StatelessWidget {
  const PlanningOverlay({
    super.key,
    required this.secondsRemaining,
    required this.balls,
    required this.onReady,
  });

  final int secondsRemaining;
  final List<BallDefinition> balls;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              SFColors.bg0.withOpacity(0.97),
              SFColors.bg0.withOpacity(0.0),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timer
            Text(
              'STUDY THE FORTRESS',
              style: SFTextStyles.headlineSmall.copyWith(
                color: SFColors.energyOrange,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$secondsRemaining seconds remaining',
              style: SFTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),

            // Ball list preview
            SizedBox(
              height: 56,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: balls.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _BallPill(ball: balls[i], index: i + 1),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Ready button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onReady,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: SFColors.energyOrange,
                ),
                child: Text(
                  'READY — ATTACK NOW',
                  style: SFTextStyles.labelLarge.copyWith(
                    color: Colors.black,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BallPill extends StatelessWidget {
  const _BallPill({required this.ball, required this.index});
  final BallDefinition ball;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SFColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SFColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$index', style: SFTextStyles.labelSmall.copyWith(color: SFColors.textMuted)),
          Text(ball.displayName.split(' ').first, style: SFTextStyles.labelSmall),
        ],
      ),
    );
  }
}

// Inline color refs to avoid circular imports
class SFColors {
  static const Color bg0 = Color(0xFF0A0A0E);
  static const Color bg2 = Color(0xFF1A1A26);
  static const Color energyOrange = Color(0xFFFF6B1A);
  static const Color border = Color(0xFF2A2A3E);
  static const Color textMuted = Color(0xFF5C5A6E);
}
