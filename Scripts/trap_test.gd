extends Node2D


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_H:
				GlobalSignal.player_hit.emit(3)
			KEY_0:
				var ShotgunTrapScene = preload("res://Scenes/traps/trap10-shotgun.tscn")
				var shotgun_trap = ShotgunTrapScene.instantiate()
				add_child(shotgun_trap)
				shotgun_trap.activate(
					Vector2(-250, 100) + Vector2(576, 324),
					Vector2(1, 0.2),
					Vector2(1, 0),
					Vector2(1, -0.2)
				)
			KEY_7:
				var SpreadingRipplesScene = preload(
					"res://Scenes/traps/trap7-spreading_ripples.tscn"
				)
				var ripple_trap = SpreadingRipplesScene.instantiate()
				add_child(ripple_trap)
				ripple_trap.activate(Vector2(300, 300), 150.0)
