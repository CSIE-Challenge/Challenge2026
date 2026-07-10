class_name GameData

var data: Dictionary
var _game_data_path: String = "res://Data/game.json"


func _init() -> void:
	data = Util.load_json(_game_data_path)
