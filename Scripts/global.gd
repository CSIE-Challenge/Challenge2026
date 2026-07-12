extends Node

#當陷阱打到玩家時，就寫Global.player_hit.emit([整數傷害])
signal player_hit(damage: int)

signal energyball_collected(energy_gain: int)

var game_manager: Node2D
var stage_canvaslayer: CanvasLayer
var stage: Node2D
var high_stage: Node2D
var single_player: bool = false
var agent_file: String = ""

var settings = ConfigFile.new()
var game_version: String = "0.0.0"


func _ready() -> void:
	settings.load("user://settings.cfg")

	var music_volume = settings.get_value("Volume", "music", 1.0)
	var sfx_volume = settings.get_value("Volume", "sfx", 1.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))

	load_version_file()


func load_version_file() -> void:
	var file_path := "res://version.txt"

	if FileAccess.file_exists(file_path):
		var file := FileAccess.open(file_path, FileAccess.READ)
		game_version = file.get_as_text().strip_edges()
		file.close()
	else:
		push_warning("version.txt not found! Using default version.")
