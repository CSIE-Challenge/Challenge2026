extends Node

#當陷阱打到玩家時，就寫Global.player_hit.emit([整數傷害])
signal player_hit(damage: int)

signal energyball_collected

var game_manager: Node2D
var stage: Node2D
var single_player: bool = false
var agent_file: String = ""

var settings = ConfigFile.new()


func _ready() -> void:
	settings.load("user://settings.cfg")

	var music_volume = settings.get_value("Volume", "music", 1.0)
	var sfx_volume = settings.get_value("Volume", "sfx", 1.0)

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sfx_volume))
