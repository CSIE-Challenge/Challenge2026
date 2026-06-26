class_name Trap5IceFloor
extends Area2D


static func initialize(pos: Vector2) -> Trap5IceFloor:
	var trap := preload("res://Scenes/traps/trap5-icefloor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	return trap


func _ready() -> void:
	await get_tree().create_timer(5.0).timeout
	_destroy_trap()


func _destroy_trap() -> void:
	if not is_inside_tree():
		return

	for body in get_overlapping_bodies():
		if body == Global.game_manager.player:
			body.acceleration = 100
			print("冰面超時消失，強制恢復玩家正常加速度")

	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player entered icefloor")
		body.acceleration = 5


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player left icefloor")
		body.acceleration = 100
