import 'package:shatterforge/domain/entities/ball_entity.dart';
import 'package:shatterforge/domain/entities/map_entity.dart';

class BattleArgs {
  final MapEntity map;
  final List<BallDefinition> selectedBalls;
  const BattleArgs({required this.map, required this.selectedBalls});
}