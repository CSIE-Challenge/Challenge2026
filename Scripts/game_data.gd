class_name GameData
extends Node

const FILE_PATH := "res://Data/game.json"

const DEFAULT_DATA := {
	"game_manager":
	{"energy_increase_period": 1.0, "player_invincibility_time": 1.0, "energy_gain_per_ball": 10},
	"player":
	{
		"acceleration": 100.0,
		"move_speed": 300.0,
		"jump_velocity": 750.0,
		"jump_gravity": 2500.0,
		"jump_fall_multiplier": 1.5,
		"max_health": 100.0,
		"invincibility_flicker_period": 8
	},
	"team_status_service":
	{
		"default_max_health": 5.0,
		"default_start_health": 5.0,
		"default_max_energy": 100.0,
		"default_start_energy": 0.0,
		"default_energy_regen_rate": 5.0,
		"default_heal_uses": 2,
		"default_heal_amount": 2,
		"default_heal_energy_cost": 40,
		"lifesteal_regen_multiplier": 2.0
	},
	"energy_ball":
	{
		"spawn_bounds": {"x": -220.0, "y": -220.0, "width": 440.0, "height": 440.0},
		"min_spawn_distance_from_player": 48.0,
		"max_spawn_attempts": 100,
		"coconut_flicker_speed": 0.2,
		"coconut_rotate_speed": 0.1,
		"coconut_rotate_amplitude": 0.5
	}
}

var data: Dictionary = {}


func _init() -> void:
	data = _load_data()


func _load_data() -> Dictionary:
	if data != {} and not data.is_empty():
		return data.duplicate(true)

	var loaded = _load_json_file(FILE_PATH)
	if loaded == null or typeof(loaded) != TYPE_DICTIONARY:
		return DEFAULT_DATA.duplicate(true)

	var merged := DEFAULT_DATA.duplicate(true)
	for section in loaded:
		if typeof(section) != TYPE_STRING:
			continue
		var section_data = loaded[section]
		if typeof(section_data) == TYPE_DICTIONARY:
			merged[section] = section_data.duplicate(true)
	return merged


func _load_json_file(file_path: String) -> Variant:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return null

	var content := file.get_as_text()
	file.close()
	if content.is_empty():
		return null

	var json_parsed = JSON.parse_string(content)
	if json_parsed == null:
		return null

	return json_parsed


func get_section(section: String) -> Dictionary:
	var section_data: Dictionary = data.get(section, {})
	if typeof(section_data) != TYPE_DICTIONARY:
		return {}
	return section_data.duplicate(true)


func get_float(section: String, key: String, fallback: float) -> float:
	var section_data: Dictionary = get_section(section)
	var value: Variant = section_data.get(key, fallback)
	if typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_FLOAT:
		return value
	return fallback


func get_int(section: String, key: String, fallback: int) -> int:
	var section_data: Dictionary = get_section(section)
	var value: Variant = section_data.get(key, fallback)
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return fallback


func get_vector2(section: String, key: String, fallback: Vector2) -> Vector2:
	var section_data: Dictionary = get_section(section)
	var value: Variant = section_data.get(key, null)

	if value is Array:
		var value_as_array := value as Array
		if value_as_array.size() >= 2:
			return Vector2(
				_to_float(value_as_array[0], fallback.x), _to_float(value_as_array[1], fallback.y)
			)

	if value is Dictionary:
		var value_as_dict := value as Dictionary
		return Vector2(
			_to_float(value_as_dict.get("x", fallback.x), fallback.x),
			_to_float(value_as_dict.get("y", fallback.y), fallback.y)
		)

	return fallback


func get_rect2(section: String, key: String, fallback: Rect2) -> Rect2:
	var section_data: Dictionary = get_section(section)
	var value: Variant = section_data.get(key, null)

	if value is Array:
		var value_as_array := value as Array
		if value_as_array.size() >= 4:
			return Rect2(
				Vector2(
					_to_float(value_as_array[0], fallback.position.x),
					_to_float(value_as_array[1], fallback.position.y)
				),
				Vector2(
					_to_float(value_as_array[2], fallback.size.x),
					_to_float(value_as_array[3], fallback.size.y)
				),
			)

	if value is Dictionary:
		var value_as_dict := value as Dictionary
		return Rect2(
			Vector2(
				_to_float(value_as_dict.get("x", fallback.position.x), fallback.position.x),
				_to_float(value_as_dict.get("y", fallback.position.y), fallback.position.y)
			),
			Vector2(
				_to_float(value_as_dict.get("width", fallback.size.x), fallback.size.x),
				_to_float(value_as_dict.get("height", fallback.size.y), fallback.size.y)
			)
		)

	return fallback


func _to_float(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_INT:
		return float(value)
	if typeof(value) == TYPE_FLOAT:
		return value
	return fallback
