class_name Trap5IceFloor
extends Area2D

@export var lifetime: float = 5.0
var _data: Dictionary = Global.trap_data["trap5-icefloor"]


static func initialize(pos: Vector2) -> Trap5IceFloor:
	var trap := preload("res://Scenes/traps/trap5-icefloor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	return trap


func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	_destroy_trap()


# 新增：處理冰面超時消失的邏輯
func _destroy_trap() -> void:
	# 防呆檢查：確認節點還在場景樹中
	if not is_inside_tree():
		return

	# 【關鍵修復】檢查冰面消失時，玩家是否還站在上面
	for body in get_overlapping_bodies():
		if body == Global.game_manager.player:
			# 強制恢復玩家的正常加速度
			body.acceleration = 100
			print("冰面超時消失，強制恢復玩家正常加速度")

	# 將冰面從場景中移除
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player entered icefloor")
		body.acceleration = 5


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player left icefloor")
		body.acceleration = 100
