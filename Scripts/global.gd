extends Node

#當陷阱打到玩家時，就寫Global.player_hit.emit([整數傷害])
signal player_hit(damage: int)

signal energyball_collected

var game_manager: Node2D
var stage: Node2D
var trap_data: Dictionary
var _trap_data_path: String = "res://Data/trap.json"


func _ready() -> void:
	trap_data = _load_json(_trap_data_path)


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
