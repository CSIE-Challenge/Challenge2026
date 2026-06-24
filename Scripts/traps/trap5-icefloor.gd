class_name Trap5IceFloor
extends Area2D

var _data: Dictionary = Global.trap_data["trap5-icefloor"]


static func initialize(pos: Vector2) -> Trap5IceFloor:
	var trap := preload("res://Scenes/traps/trap5-icefloor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	return trap


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player entered icefloor")
		body.acceleration = 5


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player left icefloor")
		body.acceleration = 100
