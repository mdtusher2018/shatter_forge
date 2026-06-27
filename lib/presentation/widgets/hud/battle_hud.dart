// lib/presentation/widgets/hud/battle_hud.dart
// BattleHud — in-match heads-up display.
//
// Panels:
//   Top-left:  attacker info + ELO delta estimate
//   Top-center: match timer
//   Top-right: defender info
//   Bottom:    ball queue (current + next 3), surrender button
//   Ambient:   chain reaction counter (animated, fades after 2s)

import 'package:flutter/material.dart';

import 'package:shatterforge/core/theme/app_theme.dart';
import '../../../domain/usecases/match/match_controller.dart';
import 'package:shatterforge/domain/entities/ball_entity.dart';

class BattleHud extends StatelessWidget {
  const BattleHud({
    super.key,
    required this.state,
    required this.onSurrender,
  });

  final MatchState state;
  final VoidCallback onSurrender;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            _TopBar(state: state, onSurrender: onSurrender),
            const Spacer(),
            if (state.isAttacking) _BallQueue(state: state),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onSurrender});

  final MatchState state;
  final VoidCallback onSurrender;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attacker panel
        Expanded(
          child: _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Attacker', style: SFTextStyles.hudLabel),
                const SizedBox(height: 2),
                Text('You', style: SFTextStyles.labelLarge),
                const SizedBox(height: 4),
                _StatRow(
                  icon: Icons.bolt,
                  label: 'Walls',
                  value: '${state.wallsDestroyed}',
                  color: SFColors.energyOrange,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Center: timer + chain
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimerDisplay(phase: state.phase),
            if (state.chainReactions > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _ChainBadge(count: state.chainReactions),
              ),
            const SizedBox(height: 8),
            // Surrender
            GestureDetector(
              onTap: onSurrender,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: SFColors.danger.withOpacity(0.15),
                  border: Border.all(color: SFColors.danger.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'SURRENDER',
                  style:
                      SFTextStyles.labelSmall.copyWith(color: SFColors.danger),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),

        // Defender panel
        Expanded(
          child: _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Defender', style: SFTextStyles.hudLabel),
                const SizedBox(height: 2),
                Text('Fortress',
                    style: SFTextStyles.labelLarge, textAlign: TextAlign.right),
                const SizedBox(height: 4),
                _StatRow(
                  icon: Icons.shield,
                  label: 'Walls',
                  value:
                      '${(state.map?.tiles.length ?? 0) - state.wallsDestroyed}',
                  color: SFColors.coreBlue,
                  reversed: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Timer ────────────────────────────────────────────────────────────────────

class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay({required this.phase});
  final MatchPhase phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: SFColors.bg1.withOpacity(0.9),
        border: Border.all(color: SFColors.borderEnergy, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        phase == MatchPhase.planning ? 'PLAN' : 'ATTACK',
        style: SFTextStyles.hudTimer.copyWith(fontSize: 16),
      ),
    );
  }
}

// ─── Chain Badge ─────────────────────────────────────────────────────────────

class _ChainBadge extends StatelessWidget {
  const _ChainBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B1A), Color(0xFFE53935)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x55FF6B1A), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Text(
        '⚡ CHAIN ×$count',
        style: SFTextStyles.labelSmall.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Ball Queue ───────────────────────────────────────────────────────────────

class _BallQueue extends StatelessWidget {
  const _BallQueue({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    final balls = state.selectedBalls;
    final used = state.ballsUsed;
    final preview = balls.skip(used).take(5).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SFColors.bg1.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SFColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < preview.length; i++)
            _BallSlot(
              ball: preview[i],
              isActive: i == 0,
              size: i == 0 ? 52.0 : 36.0,
            ),
          if (state.ballsRemaining > 5)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '+${state.ballsRemaining - 5}',
                style: SFTextStyles.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _BallSlot extends StatelessWidget {
  const _BallSlot({
    required this.ball,
    required this.isActive,
    required this.size,
  });

  final BallDefinition ball;
  final bool isActive;
  final double size;

  static const Map<String, Color> _ballColors = {
    'stone_ball': Color(0xFF8D8A98),
    'steel_ball': Color(0xFF78909C),
    'heavy_ball': Color(0xFF546E7A),
    'explosive_ball': Color(0xFFE53935),
    'cluster_ball': Color(0xFFFF8F00),
    'plasma_ball': Color(0xFF7B2FBE),
    'gravity_ball': Color(0xFF1565C0),
    'laser_ball': Color(0xFF00E5FF),
    'drill_ball': Color(0xFF37474F),
    'emp_ball': Color(0xFFFFEB3B),
    'ice_ball': Color(0xFF81D4FA),
    'fire_ball': Color(0xFFFF6D00),
    'ricochet_ball': Color(0xFF00BFA5),
    'rocket_ball': Color(0xFFD50000),
  };

  @override
  Widget build(BuildContext context) {
    final color = _ballColors[ball.id] ?? const Color(0xFFFF6B1A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
              border: Border.all(
                color: isActive ? color : color.withOpacity(0.3),
                width: isActive ? 2.5 : 1.0,
              ),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12)]
                  : null,
            ),
            child: Center(
              child: Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 3),
            Text(
              ball.displayName.split(' ').first.toUpperCase(),
              style: SFTextStyles.labelSmall.copyWith(
                fontSize: 9,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SFColors.bg1.withOpacity(0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SFColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.reversed = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: color, size: 12),
      const SizedBox(width: 4),
      Text(label, style: SFTextStyles.hudLabel),
      const Spacer(),
      Text(value, style: SFTextStyles.labelLarge.copyWith(color: color)),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: reversed ? children.reversed.toList() : children,
    );
  }
}

// Color references
class SFColors {
  static const Color bg0 = Color(0xFF0A0A0E);
  static const Color bg1 = Color(0xFF12121A);
  static const Color bg2 = Color(0xFF1A1A26);
  static const Color energyOrange = Color(0xFFFF6B1A);
  static const Color energyOrangeGlow = Color(0x33FF6B1A);
  static const Color borderEnergy = Color(0x66FF6B1A);
  static const Color coreBlue = Color(0xFF2196F3);
  static const Color danger = Color(0xFFF44336);
  static const Color border = Color(0xFF2A2A3E);
  static const Color textPrimary = Color(0xFFE8E6F0);
  static const Color textMuted = Color(0xFF5C5A6E);
}
