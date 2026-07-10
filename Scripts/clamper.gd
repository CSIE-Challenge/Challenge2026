class_name Clamper
extends RefCounted


static func clamp_trap1(data: Dictionary, params: Dictionary):
	var pos = params["position"]
	params["position"].x = clampf(
		pos.x, data["trap1-mine"]["position_min_x"], data["trap1-mine"]["position_max_x"]
	)
	params["position"].y = clampf(
		pos.y, data["trap1-mine"]["position_min_y"], data["trap1-mine"]["position_max_y"]
	)


static func clamp_trap2(data: Dictionary, params: Dictionary):
	params["delay_time"] = clampf(
		params["delay_time"],
		data["trap2-electric_ring"]["min_delay_time"],
		data["trap2-electric_ring"]["max_delay_time"]
	)
	params["radius"] = clampf(
		params["radius"],
		data["trap2-electric_ring"]["min_radius"],
		data["trap2-electric_ring"]["max_radius"]
	)


#trap3: position, direction, speed
static func clamp_trap3(data: Dictionary, params: Dictionary):
	var pos = params["position"].normalized()
	if pos == Vector2.ZERO:
		pos = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if abs(pos.x) > abs(pos.y):
		var mult = data["trap3-tracing_bullet"]["spawn_x"] * sign(pos.x) / pos.x
		pos = Vector2(data["trap3-tracing_bullet"]["spawn_x"] * sign(pos.x), pos.y * mult)
	else:
		var mult = data["trap3-tracing_bullet"]["spawn_y"] * sign(pos.y) / pos.y
		pos = Vector2(pos.x * mult, data["trap3-tracing_bullet"]["spawn_y"] * sign(pos.y))
	params["position"] = pos

	if params["direction"] == Vector2.ZERO:
		params["direction"] = Vector2.RIGHT.rotated(randf_range(0, TAU))

	params["speed"] = clampf(
		params["speed"],
		data["trap3-tracing_bullet"]["min_speed"],
		data["trap3-tracing_bullet"]["max_speed"]
	)


#trap4: position, direction
static func clamp_trap4(data: Dictionary, params: Dictionary):
	var pos = params["position"]
	pos.x = clampf(
		pos.x, data["trap4-conveyor"]["position_min_x"], data["trap4-conveyor"]["position_max_x"]
	)
	pos.y = clampf(
		pos.y, data["trap4-conveyor"]["position_min_y"], data["trap4-conveyor"]["position_max_y"]
	)
	params["position"] = pos
	var dir = params["direction"]
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if abs(dir.x) > abs(dir.y):
		dir = Vector2(dir.x, 0)
	else:
		dir = Vector2(0, dir.y)
	params["direction"] = dir


#trap5: position
static func clamp_trap5(data: Dictionary, params: Dictionary):
	var pos = params["position"]
	pos.x = clampf(
		pos.x, data["trap5-icefloor"]["position_min_x"], data["trap5-icefloor"]["position_max_x"]
	)
	pos.y = clampf(
		pos.y, data["trap5-icefloor"]["position_min_y"], data["trap5-icefloor"]["position_max_y"]
	)
	params["position"] = pos


#trap6: direction, speed
static func clamp_trap6(data: Dictionary, params: Dictionary):
	if params["direction"] == Vector2.ZERO:
		params["direction"] = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if not params.has("speed"):
		params["speed"] = randf_range(
			data["trap6-scanline"]["min_speed"], data["trap6-scanline"]["max_speed"]
		)
	else:
		params["speed"] = clampf(
			params["speed"],
			data["trap6-scanline"]["min_speed"],
			data["trap6-scanline"]["max_speed"]
		)


#trap7: position, expand_rate
static func clamp_trap7(data: Dictionary, params: Dictionary):
	var pos = params["position"]
	pos.x = clampf(
		pos.x,
		data["trap7-spreading_ripples"]["position_min_x"],
		data["trap7-spreading_ripples"]["position_max_x"]
	)
	pos.y = clampf(
		pos.y,
		data["trap7-spreading_ripples"]["position_min_y"],
		data["trap7-spreading_ripples"]["position_max_y"]
	)
	params["position"] = pos
	params["expand_rate"] = clampf(
		params["expand_rate"],
		data["trap7-spreading_ripples"]["min_expand_rate"],
		data["trap7-spreading_ripples"]["max_expand_rate"]
	)


#trap8: start_position, end_position
static func clamp_trap8(data: Dictionary, params: Dictionary):
	var pos1 = params["start_position"].normalized()
	if pos1 == Vector2.ZERO:
		pos1 = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if abs(pos1.x) > abs(pos1.y):
		var mult = data["trap8-electric_arc"]["spawn_x"] * sign(pos1.x) / pos1.x
		pos1 = Vector2(data["trap8-electric_arc"]["spawn_x"] * sign(pos1.x), pos1.y * mult)
	else:
		var mult = data["trap8-electric_arc"]["spawn_y"] * sign(pos1.y) / pos1.y
		pos1 = Vector2(pos1.x * mult, data["trap8-electric_arc"]["spawn_y"] * sign(pos1.y))
	params["start_position"] = pos1

	var pos2 = params["end_position"].normalized()
	if pos2 == Vector2.ZERO:
		pos2 = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if abs(pos2.x) > abs(pos2.y):
		var mult = data["trap8-electric_arc"]["spawn_x"] * sign(pos2.x) / pos2.x
		pos2 = Vector2(data["trap8-electric_arc"]["spawn_x"] * sign(pos2.x), pos2.y * mult)
	else:
		var mult = data["trap8-electric_arc"]["spawn_y"] * sign(pos2.y) / pos2.y
		pos2 = Vector2(pos2.x * mult, data["trap8-electric_arc"]["spawn_y"] * sign(pos2.y))
	params["end_position"] = pos2


#trap9: start_position, end_position, air_time
static func clamp_trap9(data: Dictionary, params: Dictionary):
	var pos1 = params["start_position"].normalized()
	if pos1 == Vector2.ZERO:
		pos1 = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if abs(pos1.x) > abs(pos1.y):
		var mult = data["trap9-mortar"]["spawn_x"] * sign(pos1.x) / pos1.x
		pos1 = Vector2(data["trap9-mortar"]["spawn_x"] * sign(pos1.x), pos1.y * mult)
	else:
		var mult = data["trap9-mortar"]["spawn_y"] * sign(pos1.y) / pos1.y
		pos1 = Vector2(pos1.x * mult, data["trap9-mortar"]["spawn_y"] * sign(pos1.y))
	params["start_position"] = pos1
	var pos2 = params["end_position"]
	pos2.x = clampf(
		pos2.x,
		-data["trap9-mortar"]["max_end_position_x"],
		data["trap9-mortar"]["max_end_position_x"]
	)
	pos2.y = clampf(
		pos2.y,
		-data["trap9-mortar"]["max_end_position_y"],
		data["trap9-mortar"]["max_end_position_y"]
	)
	params["end_position"] = pos2
	if not params.has("air_time"):
		params["air_time"] = randf_range(
			data["trap9-mortar"]["min_air_time"], data["trap9-mortar"]["max_air_time"]
		)
	params["air_time"] = clampf(
		params["air_time"],
		data["trap9-mortar"]["min_air_time"],
		data["trap9-mortar"]["max_air_time"]
	)


#trap10: position, dir1, 2, 3
static func clamp_trap10(data: Dictionary, params: Dictionary):
	var pos = params["position"].normalized()
	if pos == Vector2.ZERO:
		pos = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if abs(pos.x) > abs(pos.y):
		var mult = data["trap10-shotgun"]["spawn_x"] * sign(pos.x) / pos.x
		pos = Vector2(data["trap10-shotgun"]["spawn_x"] * sign(pos.x), pos.y * mult)
	else:
		var mult = data["trap10-shotgun"]["spawn_y"] * sign(pos.y) / pos.y
		pos = Vector2(pos.x * mult, data["trap10-shotgun"]["spawn_y"] * sign(pos.y))
	params["position"] = pos
	if params["dir1"] == Vector2.ZERO:
		params["dir1"] = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if params["dir2"] == Vector2.ZERO:
		params["dir2"] = Vector2.RIGHT.rotated(randf_range(0, TAU))
	if params["dir3"] == Vector2.ZERO:
		params["dir3"] = Vector2.RIGHT.rotated(randf_range(0, TAU))
