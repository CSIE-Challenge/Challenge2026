class_name Trap4Conveyor
extends Area2D

@export var speed: float = 100
@export var lifetime: float = 5.0
var direction: Vector2
var _is_disappearing: bool = false


static func initialize(pos: Vector2, dir: Vector2) -> Trap4Conveyor:
	var trap := preload("res://Scenes/traps/trap4-conveyor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.direction = dir.normalized()
	return trap


func _ready() -> void:
	# Trap should expire after the configured lifetime.
	await get_tree().create_timer(lifetime).timeout
	_destroy_trap()


func _destroy_trap() -> void:
	if not is_inside_tree():
		return

	_is_disappearing = true
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity += speed * direction
		print("玩家踩到了履帶地塊")


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity -= speed * direction
		if _is_disappearing:
			print("陷阱超時消失，強制解除玩家的履帶效果")
		else:
			print("玩家離開了履帶地塊")
