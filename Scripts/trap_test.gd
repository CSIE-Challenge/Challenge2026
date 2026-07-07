extends Node2D
var trap_data = TrapData.new().data


func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_H:
				Global.player_hit.emit(3)
			KEY_1:
				var dict = _generate_trap1_dictionary()
				Clamper.clamp_trap1(trap_data, dict)
				Trap1Mine.initialize(dict["position"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_2:
				var dict = _generate_trap2_dictionary()
				Clamper.clamp_trap2(trap_data, dict)
				Trap2ElectricRing.initialize(dict["delay_time"], dict["radius"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_3:
				var dict = _generate_trap3_dictionary()
				Clamper.clamp_trap3(trap_data, dict)
				Trap3TracingBullet.initialize(dict["position"], dict["direction"], dict["speed"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_4:
				var dict = _generate_trap4_dictionary()
				Clamper.clamp_trap4(trap_data, dict)
				Trap4Conveyor.initialize(dict["position"], dict["direction"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_5:
				var dict = _generate_trap5_dictionary()
				Clamper.clamp_trap5(trap_data, dict)
				Trap5IceFloor.initialize(dict["position"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_6:
				var dict = _generate_trap6_dictionary()
				Clamper.clamp_trap6(trap_data, dict)
				Trap6Scanline.initialize(dict["direction"], dict["speed"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_7:
				var dict = _generate_trap7_dictionary()
				Clamper.clamp_trap7(trap_data, dict)
				Trap7SpreadingRipples.initialize(dict["position"], dict["expand_rate"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_8:
				var dict = _generate_trap8_dictionary()
				Clamper.clamp_trap8(trap_data, dict)
				Trap8ElectricArc.initialize(dict["start_position"], dict["end_position"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_9:
				var dict = _generate_trap9_dictionary()
				Clamper.clamp_trap9(trap_data, dict)
				Trap9Mortar.initialize(
					dict["start_position"], dict["end_position"], dict["air_time"]
				)
				Audio.play_sfx(Audio.SFX.SET_TRAP)
			KEY_0:
				var dict = _generate_trap10_dictionary()
				Clamper.clamp_trap10(trap_data, dict)
				Trap10Shotgun.initialize(dict["position"], dict["dir1"], dict["dir2"], dict["dir3"])
				Audio.play_sfx(Audio.SFX.SET_TRAP)


func _random_pos() -> Vector2:
	var bounds = Global.stage.stage_bounds
	return bounds.position + Vector2(randf_range(0, bounds.size.x), randf_range(0, bounds.size.y))


func _generate_trap1_dictionary() -> Dictionary:
	var d = {"position": _random_pos()}
	return d


func _generate_trap2_dictionary() -> Dictionary:
	var d = {"delay_time": randf_range(1.0, 2.0), "radius": randf_range(75, 150)}
	return d


func _generate_trap3_dictionary() -> Dictionary:
	var pos = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var d = {"position": pos, "direction": -pos, "speed": randf_range(100.0, 300.0)}
	return d


func _generate_trap4_dictionary() -> Dictionary:
	var pos = _random_pos()
	var dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var d = {
		"position": pos,
		"direction": dir,
	}
	return d


func _generate_trap5_dictionary() -> Dictionary:
	var pos = _random_pos()
	var d = {
		"position": pos,
	}
	return d


func _generate_trap6_dictionary() -> Dictionary:
	var dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	var d = {"direction": dir, "speed": randf_range(120.0, 250.0)}
	return d


func _generate_trap7_dictionary() -> Dictionary:
	var pos = _random_pos() * randf_range(1.0, 2.0)
	var d = {"position": pos, "expand_rate": randf_range(100.0, 200.0)}
	return d


func _generate_trap8_dictionary() -> Dictionary:
	var pos = _random_pos() * randf_range(1.0, 2.0)
	var pos2 = _random_pos() * randf_range(1.0, 2.0)
	var d = {"start_position": pos, "end_position": pos2}
	return d


func _generate_trap9_dictionary() -> Dictionary:
	var pos = _random_pos()
	var pos2 = _random_pos()
	var d = {"start_position": pos, "end_position": pos2, "air_time": randf_range(2.0, 3.5)}
	return d


func _generate_trap10_dictionary() -> Dictionary:
	var pos = _random_pos()
	var d = {
		"position": pos,
		"dir1": -pos.rotated(randf_range(-PI / 6, PI / 6)),
		"dir2": -pos.rotated(randf_range(-PI / 6, PI / 6)),
		"dir3": -pos.rotated(randf_range(-PI / 6, PI / 6))
	}
	return d
