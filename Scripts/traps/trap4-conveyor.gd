class_name Trap4Conveyor
extends Area2D

@export var speed: float = 100
var direction: Vector2


static func initialize(pos: Vector2, dir: Vector2) -> Trap4Conveyor:
	var trap := preload("res://Scenes/traps/trap4-conveyor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.direction = dir.normalized()
	return trap


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity += speed * direction
		print("玩家踩到了履帶地塊")


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity -= speed * direction
		print("玩家離開了履帶地塊")
