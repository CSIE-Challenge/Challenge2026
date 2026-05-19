extends Node2D


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	
func on_player_hit(damage:int):
	print("玩家受到了",damage,"點傷害")
