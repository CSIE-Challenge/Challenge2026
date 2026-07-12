extends BaseSkin

var tex_cover = preload("res://Shapes/among_us/井蓋.png")
var tex_peek = preload("res://Shapes/among_us/探頭小人.png")
var tex_run1 = preload("res://Shapes/among_us/小人跑步1.png")
var tex_run2 = preload("res://Shapes/among_us/小人跑步2.png")
var tex_stand = preload("res://Shapes/among_us/小人站立.png")
var tex_dead = preload("res://Shapes/among_us/小人死亡.png")

var time_passed = 0.0
var is_dead = false
var is_flying = false
var is_spawning = true

@onready var sprite = $Sprite2D
@onready var blood_particles = $BloodParticles


func _ready():
	scale = Vector2.ZERO


func _process(delta):
	if is_dead or is_spawning:
		return

	if not is_flying:
		# 走路動畫
		var parent = get_meta("player") if has_meta("player") else get_parent()
		# 讀取 coconut 節點的 velocity 屬性
		if parent and "velocity" in parent:
			var vel = parent.velocity

			# 轉向 (圖片本來朝左)
			if vel.x > 10.0:
				scale.x = -abs(scale.x)
			elif vel.x < -10.0:
				scale.x = abs(scale.x)

			if vel.length() > 10.0:
				time_passed += delta * 10.0
				var step = int(time_passed) % 6
				if step == 0:
					sprite.texture = tex_stand
				elif step == 1 or step == 2:
					sprite.texture = tex_run1
				elif step == 3:
					sprite.texture = tex_stand
				else:
					sprite.texture = tex_run2
			else:
				time_passed += delta * 4.0
				sprite.texture = tex_stand


func play_spawn():
	sprite.texture = tex_cover
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.rotation = 0
	sprite.position = Vector2.ZERO
	is_dead = false
	is_flying = false

	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.6, 0.3)
	await tween.finished

	await get_tree().create_timer(0.2).timeout
	if is_dead:
		return
	sprite.texture = tex_peek

	await get_tree().create_timer(0.2).timeout
	if is_dead:
		return
	sprite.texture = tex_run1

	#稍微向上作跳起勢
	var jump_tween = create_tween().set_parallel(true)
	(
		jump_tween
		. tween_property(sprite, "position:y", -20.0, 0.2)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		jump_tween
		. chain()
		. tween_property(sprite, "position:y", 0.0, 0.2)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	await jump_tween.finished

	if is_dead:
		return
	sprite.texture = tex_stand
	is_spawning = false


func play_jump():
	if is_dead:
		return
	is_flying = true
	sprite.texture = tex_run1


func play_land():
	if is_dead:
		return
	is_flying = false
	sprite.texture = tex_stand


func play_eat_ball():
	if is_dead:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.12), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.1)


func play_die():
	is_dead = true
	sprite.texture = tex_dead

	blood_particles.restart()
	blood_particles.emitting = true

	# 維持3秒
	await get_tree().create_timer(1.0).timeout
