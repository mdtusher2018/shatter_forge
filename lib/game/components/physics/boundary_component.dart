// lib/game/components/physics/boundary_component.dart
// BoundaryComponent — Forge2D static bodies forming the arena walls.
// Left wall, right wall, ceiling, floor (floor = out-of-bounds sensor).
//
// Design: Left, right, and top are solid walls (ball bounces off).
// Bottom is a sensor — triggers ball out-of-bounds when crossed.

import 'package:flame/components.dart' hide Vector2;
import 'package:flame_forge2d/flame_forge2d.dart';

class BoundaryComponent extends Component {
  BoundaryComponent({required this.gameSize});

  final Vector2 gameSize;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _buildBoundaries();
  }

  Future<void> _buildBoundaries() async {
    final w = gameSize.x / 30.0;
    final h = gameSize.y / 30.0;
    const t = 1.0; // thickness in meters

    // Left wall
    await add(_SolidWall(
      position: Vector2(-t / 2, h / 2),
      size: Vector2(t, h),
    ));

    // Right wall
    await add(_SolidWall(
      position: Vector2(w + t / 2, h / 2),
      size: Vector2(t, h),
    ));

    // Ceiling
    await add(_SolidWall(
      position: Vector2(w / 2, -t / 2),
      size: Vector2(w + t * 2, t),
    ));

    // Floor — out of bounds sensor (handled in BallComponent update)
    // Not added as a physics body; ball Y check is in update().
  }
}

class _SolidWall extends BodyComponent {
  _SolidWall({required this.position, required this.size});

  final Vector2 position;
  final Vector2 size;

  @override
  Body createBody() {
    final bodyDef = BodyDef()
      ..type = BodyType.static
      ..position = position;

    final shape = PolygonShape()
      ..setAsBox(size.x / 2, size.y / 2, Vector2(0, 0), 0);

    final fixtureDef = FixtureDef(shape)
      ..density = 0
      ..friction = 0.2
      ..restitution = 0.85;

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void render(canvas) {
    // Invisible — boundaries are debug-only visible in dev mode
  }
}
