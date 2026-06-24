extends Node2D


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		var bounds = Global.stage.stage_bounds
		match event.keycode:
			KEY_H:
				Global.player_hit.emit(3)
			KEY_1:
				Trap1Mine.initialize(
					(
						bounds.position
						+ Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
					)
				)
			KEY_2:
				Trap2ElectricRing.initialize(randf_range(1.0, 2.0), randf_range(75, 150))
			KEY_3:
				Trap3TracingBullet.initialize(Vector2(100, 0), Vector2(0, -100), 200)
			KEY_4:
				Trap4Conveyor.initialize(
					(
						bounds.position
						+ Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
					),
					Vector2(1, 0)
				)
			KEY_5:
				Trap5IceFloor.initialize(
					(
						bounds.position
						+ Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
					)
				)
			KEY_7:
				Trap7SpreadingRipples.initialize(Vector2(300, 300), 150.0)
			KEY_9:
				Trap9Mortar.initialize(
					(
						bounds.position
						+ Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
					),
					(
						bounds.position
						+ Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
					),
					2.0
				)
			KEY_0:
				Trap10Shotgun.initialize(
					Vector2(-250, 100), Vector2(1, 0.2), Vector2(1, 0), Vector2(1, -0.2)
				)
