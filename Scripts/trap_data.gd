class_name TrapData

var data: Dictionary
var _trap_data_path: String = "res://Data/trap.json"


func _init() -> void:
	data = Util.load_json(_trap_data_path)
