extends Area2D

@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D


func _ready() -> void:
	add_to_group("attack_ball")
	# 連接玩家碰撞訊號
	body_entered.connect(_on_body_entered)

	var pulse_tween = create_tween().set_loops()
	(
		pulse_tween
		. tween_property(sprite, "scale", Vector2(0.10, 0.10), 1.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		pulse_tween
		. tween_property(sprite, "scale", Vector2(0.08, 0.08), 1.5)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _on_body_entered(body: Node2D) -> void:
	# 請根據您專案中椰子玩家的節點名稱或 Group 做判定
	if body.name == "coconut" or body.is_in_group("player"):
		# 1. 禁用碰撞，避免重複觸發，並隱藏本體
		collision_shape.set_deferred("disabled", true)
		sprite.hide()

		# 2. 獲取 Boss 節點參照
		var boss_node = get_node_or_null("../boss")

		# 3. 散出 15 個追蹤圓點
		var dot_count = 15
		var DotScene = preload("res://Scenes/Menu/attack_dot.tscn")  # 預載圓點場景

		for i in range(dot_count):
			var dot = DotScene.instantiate()
			get_parent().add_child(dot)

			# 給予隨機方向與初始噴射速度
			var random_angle = randf_range(0.0, 2.0 * PI)
			var random_dir = Vector2.from_angle(random_angle)
			var initial_speed = randf_range(250.0, 600.0)

			dot.init(global_position, random_dir, initial_speed, boss_node)

		# 4. 圓點生成後，本體即可安全銷毀
		queue_free()
	if body.is_in_group("walls"):
		queue_free()
