class_name GameData
extends Node

const FILE_PATH := "res://Data/game.json"

var data: Dictionary = {}


func _init() -> void:
	data = _load_data()


func _load_data() -> Dictionary:
	var loaded = _load_json_file(FILE_PATH)
	if loaded == null or typeof(loaded) != TYPE_DICTIONARY:
		return {}
	return loaded


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
