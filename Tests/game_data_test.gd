extends SceneTree

const GameDataScript = preload("res://Scripts/game_data.gd")


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var game_data := GameDataScript.new()

	_assert_eq(
		game_data.get_float("game_manager", "energy_increase_period", -1.0),
		1.0,
		"game manager energy_increase_period should load from Data/game.json"
	)
	_assert_eq(
		game_data.get_float("game_manager", "player_invincibility_time", -1.0),
		1.0,
		"game manager player_invincibility_time should load from Data/game.json"
	)
	_assert_eq(
		game_data.get_int("game_manager", "energy_gain_per_ball", -1),
		10,
		"game manager energy_gain_per_ball should load from Data/game.json"
	)

	_assert_eq(
		game_data.get_float("player", "move_speed", -1.0),
		300.0,
		"player move_speed should load from Data/game.json"
	)
	_assert_eq(
		game_data.get_int("player", "invincibility_flicker_period", -1),
		8,
		"player invincibility_flicker_period should load from Data/game.json"
	)

	_assert(
		game_data.get_rect2("energy_ball", "spawn_bounds", Rect2()).size.x > 0.0,
		"energy_ball spawn bounds should be a valid rect"
	)
	_assert_eq(
		game_data.get_int("energy_ball", "max_spawn_attempts", -1),
		100,
		"energy_ball max_spawn_attempts should load from Data/game.json"
	)

	_assert_eq(
		game_data.get_float("heal", "energy_cost", -1.0),
		40.0,
		"heal section should load from Data/game.json"
	)

	var missing := game_data.get_float("missing_section", "key", 12.34)
	_assert_eq(missing, 12.34, "get_float should fallback when section/key missing")

	print("Game data tests passed")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _assert_eq(actual, expected, message := "") -> void:
	if actual == expected:
		return
	push_error("%s expected <%s>, got <%s>" % [message, expected, actual])
	quit(1)
