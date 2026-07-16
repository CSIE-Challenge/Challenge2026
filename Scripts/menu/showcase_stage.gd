extends Node2D

var current_skin: BaseSkin = null

@onready var body_pivot = $BodyPivot
@onready var shadow = $Shadow


func setup(skin_prefab: PackedScene):
	if skin_prefab:
		current_skin = skin_prefab.instantiate() as BaseSkin
		if current_skin:
			body_pivot.add_child(current_skin)
			_play_loop()


func set_shadow(shadow_on: bool):
	if shadow_on:
		shadow.scale = Vector2(0.2, 0.2)
		shadow.modulate.a = 1.0
	else:
		shadow.scale = Vector2.ZERO
		shadow.modulate.a = 0.0


func _play_loop():
	body_pivot.position.y = 0

	while is_inside_tree():
		# 1. Spawn (出生)
		if current_skin.has_method("play_spawn"):
			await current_skin.play_spawn()

		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			break

		# 2. Eat Ball (吃球)
		if current_skin.has_method("play_eat_ball"):
			await current_skin.play_eat_ball()

		await get_tree().create_timer(0.5).timeout
		if not is_inside_tree():
			break

		# 3. Jump (模擬玩家跳躍物理)
		if current_skin.has_method("play_jump"):
			current_skin.play_jump()

		var tween = create_tween()
		# 往上跳：物理引擎真實模擬 (-112.5 px 高度)
		(
			tween
			. tween_property(body_pivot, "position:y", -112.5, 0.3)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)

		# 往下掉：物理引擎真實模擬
		(
			tween
			. tween_property(body_pivot, "position:y", 0.0, 0.3)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)

		await tween.finished
		if not is_inside_tree():
			break

		# 4. Land (落地)
		if current_skin.has_method("play_land"):
			current_skin.play_land()

		await get_tree().create_timer(1.0).timeout
		if not is_inside_tree():
			break

		# 5. Die (死亡)
		if current_skin.has_method("play_die"):
			await current_skin.play_die()

		await get_tree().create_timer(1.0).timeout
