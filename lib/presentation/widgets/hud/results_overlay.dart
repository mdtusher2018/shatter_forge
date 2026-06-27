// lib/presentation/widgets/hud/results_overlay.dart
// ResultsOverlay — post-match summary screen.
// Animates in with staggered slide-up + star pop.

import 'package:flutter/material.dart';
import 'package:shatterforge/core/theme/app_theme.dart';
import '../../../domain/usecases/match/match_controller.dart';

class ResultsOverlay extends StatefulWidget {
  const ResultsOverlay({
    super.key,
    required this.state,
    required this.onContinue,
    required this.onRematch,
  });

  final MatchState state;
  final VoidCallback onContinue;
  final VoidCallback onRematch;

  @override
  State<ResultsOverlay> createState() => _ResultsOverlayState();
}

class _ResultsOverlayState extends State<ResultsOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final AnimationController _starsCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _starsAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _starsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _starsAnim = CurvedAnimation(parent: _starsCtrl, curve: Curves.elasticOut);

    _slideCtrl.forward().then((_) => _starsCtrl.forward());
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _starsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVictory = widget.state.phase == MatchPhase.victory ||
        widget.state.starsEarned > 0;

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _slideCtrl,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: SFColors.bg1,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isVictory
                      ? SFColors.energyOrange.withOpacity(0.5)
                      : SFColors.danger.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isVictory
                        ? SFColors.energyOrange.withOpacity(0.2)
                        : SFColors.danger.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Result header
                  Text(
                    isVictory ? 'VICTORY' : 'DEFEAT',
                    style: SFTextStyles.headlineLarge.copyWith(
                      color: isVictory ? SFColors.energyOrange : SFColors.danger,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stars
                  if (isVictory)
                    ScaleTransition(
                      scale: _starsAnim,
                      child: _StarRow(stars: widget.state.starsEarned),
                    ),

                  const SizedBox(height: 20),

                  // Stats grid
                  _StatsGrid(state: widget.state),

                  const SizedBox(height: 24),

                  // Rewards
                  if (isVictory) _RewardsRow(state: widget.state),
                  if (isVictory) const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onRematch,
                          child: const Text('REMATCH'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          child: const Text('CONTINUE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Star Row ─────────────────────────────────────────────────────────────────

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            i < stars ? Icons.star_rounded : Icons.star_border_rounded,
            color: i < stars ? const Color(0xFFFFD700) : SFColors.border,
            size: i == 1 ? 52 : 40,
          ),
        ),
      ),
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SFColors.bg0,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _StatLine('Walls Destroyed', '${state.wallsDestroyed}', SFColors.energyOrange),
          const Divider(color: SFColors.border, height: 12),
          _StatLine('Balls Used', '${state.ballsUsed}', SFColors.textSecondary),
          const Divider(color: SFColors.border, height: 12),
          _StatLine('Chain Reactions', '${state.chainReactions}', SFColors.crystalCyan),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine(this.label, this.value, this.valueColor);
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: SFTextStyles.bodyMedium),
        Text(value, style: SFTextStyles.labelLarge.copyWith(color: valueColor)),
      ],
    );
  }
}

// ─── Rewards Row ─────────────────────────────────────────────────────────────

class _RewardsRow extends StatelessWidget {
  const _RewardsRow({required this.state});
  final MatchState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RewardChip(
          icon: '🪙',
          label: '+${state.coinsEarned}',
          color: const Color(0xFFFFD700),
        ),
        const SizedBox(width: 12),
        _RewardChip(
          icon: '⭐',
          label: '+${state.starsEarned * 10} XP',
          color: SFColors.energyOrange,
        ),
      ],
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.label, required this.color});
  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$icon $label',
        style: SFTextStyles.labelLarge.copyWith(color: color),
      ),
    );
  }
}

// Local color refs
class SFColors {
  static const Color bg0 = Color(0xFF0A0A0E);
  static const Color bg1 = Color(0xFF12121A);
  static const Color energyOrange = Color(0xFFFF6B1A);
  static const Color coreBlue = Color(0xFF2196F3);
  static const Color crystalCyan = Color(0xFF00E5FF);
  static const Color danger = Color(0xFFF44336);
  static const Color border = Color(0xFF2A2A3E);
  static const Color textSecondary = Color(0xFF9896A8);
}
