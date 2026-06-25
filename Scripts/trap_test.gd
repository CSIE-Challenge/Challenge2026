extends Node2D


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		print("meow")
		match event.keycode:
			KEY_H:
				Global.player_hit.emit(3)
			KEY_1:
				Trap1Mine.initialize(_random_pos())
			KEY_2:
				Trap2ElectricRing.initialize(randf_range(1.0, 2.0), randf_range(75, 150))
			KEY_3:
				Trap3TracingBullet.initialize(Vector2(100, 0), Vector2(0, -100), 200)
			KEY_4:
				Trap4Conveyor.initialize(_random_pos(), Vector2(1, 0))
			KEY_5:
				Trap5IceFloor.initialize(_random_pos())
			KEY_6:
				var angle = randf_range(0, PI * 26)
				Trap6Scanline.initialize(Vector2(cos(angle), sin(angle)), 100)
			KEY_7:
				Trap7SpreadingRipples.initialize(Vector2(300, 300), 150.0)
			KEY_8:
				Trap8ElectricArc.initialize(_random_pos(), _random_pos())
			KEY_9:
				Trap9Mortar.initialize(_random_pos(), _random_pos(), 2.0)
			KEY_0:
				Trap10Shotgun.initialize(
					Vector2(-250, 100), Vector2(1, 0.2), Vector2(1, 0), Vector2(1, -0.2)
				)


func _random_pos() -> Vector2:
	var bounds = Global.stage.stage_bounds
	return bounds.position + Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))
