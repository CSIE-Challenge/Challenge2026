extends CollisionShape2D

var direction: Vector2
var speed: float
var duration: float
var radius: float = 67.0

# 🌟 新增：控制是否已經啟動移動與碰撞的開關
var is_active: bool = false


func init(
	start_global_pos: Vector2, start_dir: Vector2, start_speed: float, life_time: float
) -> void:
	global_position = start_global_pos
	direction = start_dir.normalized()
	speed = start_speed
	duration = life_time

	shape = CircleShape2D.new()
	shape.radius = radius


func _ready() -> void:
	# 🌟 1. 初始狀態：關閉物理傷害判定，將大小設為 0 並隱藏
	set_deferred("disabled", true)
	scale = Vector2.ZERO
	modulate.a = 0.0

	var rot_tween = create_tween().set_loops()
	rot_tween.tween_property(self, "rotation", PI * 2, 0.3).as_relative()

	# 🌟 2. 華麗的出現動畫 (1.0 秒)
	var appear_duration = 1.0
	var appear_tween = create_tween().set_parallel(true)
	# 使用 TRANS_BACK 會有一點「放大過頭再縮回來」的彈性出現感
	(
		appear_tween
		. tween_property(self, "scale", Vector2.ONE, appear_duration)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	appear_tween.tween_property(self, "modulate:a", 1.0, appear_duration)
	is_active = true
	# 等待出現動畫播完
	await appear_tween.finished

	# 🌟 3. 動畫結束，正式啟動：開啟傷害判定並允許移動
	set_deferred("disabled", false)

	# 4. 等待存活時間到期 (扣除掉前面動畫花費的時間)
	await get_tree().create_timer(duration - appear_duration).timeout

	# 5. 淡出前先關閉傷害，避免視覺消失了卻還打中玩家
	set_deferred("disabled", true)
	var fade = create_tween().set_parallel(true)
	fade.tween_property(self, "scale", Vector2.ZERO, 0.2)
	fade.tween_property(self, "modulate:a", 0.0, 0.2)
	fade.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	# 🌟 如果還在播出現動畫，就直接 return 不移動也不算碰撞
	if not is_active:
		return

	global_position += direction * speed * delta

	var walls = get_node_or_null("../../Walls")
	if not walls:
		return

	var half = walls.dynamic_base_half if "dynamic_base_half" in walls else Vector2(220, 160)
	var local_pos = walls.to_local(global_position)

	var bounced_horiz = false
	var bounced_vert = false

	if local_pos.x <= -half.x + radius:
		local_pos.x = -half.x + radius
		direction.x = abs(direction.x)
		bounced_horiz = true
	elif local_pos.x >= half.x - radius:
		local_pos.x = half.x - radius
		direction.x = -abs(direction.x)
		bounced_horiz = true

	if local_pos.y <= -half.y + radius:
		local_pos.y = -half.y + radius
		direction.y = abs(direction.y)
		bounced_vert = true
	elif local_pos.y >= half.y - radius:
		local_pos.y = half.y - radius
		direction.y = -abs(direction.y)
		bounced_vert = true

	if bounced_horiz or bounced_vert:
		Audio.play_sfx(Audio.SFX.HIDDEN_GAME_BIGBALL_HITWALL)
		global_position = walls.to_global(local_pos)
		speed += 12.0

		scale = Vector2(0.6, 1.4) if bounced_horiz else Vector2(1.4, 0.6)
		var bounce_tween = create_tween()
		(
			bounce_tween
			. tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
		)

		if walls.has_method("bounce_punch"):
			walls.bounce_punch(bounced_horiz)
