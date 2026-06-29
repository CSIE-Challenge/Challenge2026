class_name TrapData
extends Node

var data: Dictionary
var _trap_data_path: String = "res://Data/trap.json"


func _load_json(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error(
			"[Util] Failed to open file: %s, reason: %d" % [file_path, FileAccess.get_open_error()]
		)
		return null

	var content = file.get_as_text()
	file.close()

	var json_parsed = JSON.parse_string(content)
	if json_parsed == null:
		push_error("[Util] Failed to parse JSON from file: ", file_path)
		return null

	return json_parsed


func _init() -> void:
	data = _load_json(_trap_data_path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
