class_name Trap4Conveyor
extends Area2D

@export var speed: float = 100
@export var lifetime: float = 5.0
var direction: Vector2


static func initialize(pos: Vector2, dir: Vector2) -> Trap4Conveyor:
	var trap := preload("res://Scenes/traps/trap4-conveyor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.direction = dir.normalized()
	return trap


func _ready() -> void:
	# 陷阱生成時開始計時
	await get_tree().create_timer(lifetime).timeout
	_destroy_trap()


# 新增：處理陷阱超時消失的邏輯
func _destroy_trap() -> void:
	# 防呆檢查：確認節點還在場景樹中
	if not is_inside_tree():
		return

	# 【關鍵修復】檢查陷阱消失時，玩家是否還站在上面
	for body in get_overlapping_bodies():
		if body == Global.game_manager.player and body is CharacterBody2D:
			# 強制扣除玩家身上的推力，防止玩家永久滑行
			body.external_velocity -= speed * direction
			print("陷阱超時消失，強制解除玩家的履帶效果")

	# 將陷阱從場景中移除
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity += speed * direction
		print("玩家踩到了履帶地塊")


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity -= speed * direction
		print("玩家離開了履帶地塊")
