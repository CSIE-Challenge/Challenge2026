extends SceneTree

const GameDataScript = preload("res://Scripts/game_data.gd")


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var data := GameDataScript.new().data

	_assert_eq(
		data["game_manager"]["energy_increase_period"],
		1.0,
		"game manager energy_increase_period should load from Data/game.json"
	)
	_assert_eq(
		data["game_manager"]["player_invincibility_time"],
		1.0,
		"game manager player_invincibility_time should load from Data/game.json"
	)
	_assert_eq(
		data["player"]["move_speed"], 300.0, "player move_speed should load from Data/game.json"
	)
	_assert_eq(
		data["player"]["invincibility_flicker_period"],
		8,
		"player invincibility_flicker_period should load from Data/game.json"
	)

	_assert(
		data["energy_ball"]["spawn_bounds"]["width"] > 0.0,
		"energy_ball spawn bounds should be a valid rect"
	)
	_assert_eq(
		data["energy_ball"]["max_spawn_attempts"],
		100,
		"energy_ball max_spawn_attempts should load from Data/game.json"
	)

	_assert_eq(data["heal"]["energy_cost"], 40.0, "heal section should load from Data/game.json")

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
