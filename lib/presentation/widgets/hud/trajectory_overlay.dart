// lib/presentation/widgets/hud/trajectory_overlay.dart
// TrajectoryOverlay — draws the aiming trajectory preview over the game canvas.
// Uses CustomPainter for zero-allocation rendering.
// Reads trajectory points directly from ShatterforgeGame each frame.

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:shatterforge/game/world/shatterforge_game.dart';

class TrajectoryOverlay extends StatefulWidget {
  const TrajectoryOverlay({super.key, required this.game});
  final ShatterforgeGame game;

  @override
  State<TrajectoryOverlay> createState() => _TrajectoryOverlayState();
}

class _TrajectoryOverlayState extends State<TrajectoryOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (widget.game.isAiming) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.game.isAiming) return const SizedBox.shrink();
    return CustomPaint(
      painter: _TrajectoryPainter(
        points: widget.game.trajectoryPoints,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter({required this.points});

  final List<dynamic> points; // Vector2 list

  final _dotPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    for (int i = 0; i < points.length; i++) {
      final t = i / points.length;
      final alpha = (1 - t) * 0.8;
      final radius = 3.0 * (1 - t * 0.6);

      _dotPaint.color = Color.fromRGBO(255, 107, 26, alpha);
      canvas.drawCircle(
        Offset(points[i].x.toDouble(), points[i].y.toDouble()),
        radius,
        _dotPaint,
      );
    }

    // Arrow at end of trajectory
    if (points.length >= 2) {
      final last = points.last;
      final prev = points[points.length - 2];
      final dx = last.x - prev.x;
      final dy = last.y - prev.y;
      final len = (dx * dx + dy * dy).toDouble();
      if (len > 0) {
        _dotPaint.color = const Color(0x88FF6B1A);
        canvas.drawCircle(
          Offset(last.x.toDouble(), last.y.toDouble()),
          5.0,
          _dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrajectoryPainter old) => true;
}
