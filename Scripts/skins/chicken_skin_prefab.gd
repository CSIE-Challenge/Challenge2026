extends BaseSkin

var tex_egg = preload("res://Shapes/chicken/蛋.png")
var tex_egg_crack = preload("res://Shapes/chicken/蛋裂.png")
var tex_egg_open = preload("res://Shapes/chicken/蛋大裂.png")
var tex_hatch = preload("res://Shapes/chicken/小雞出殼.png")
var tex_chicken = preload("res://Shapes/chicken/雞.png")
var tex_fly1 = preload("res://Shapes/chicken/雞飛1.png")
var tex_fly2 = preload("res://Shapes/chicken/雞飛2.png")
var tex_dead = preload("res://Shapes/chicken/XX眼.png")
var tex_cooked = preload("res://Shapes/chicken/死亡的雞.png")
var tex_walk1 = preload("res://Shapes/chicken/走路1.png")
var tex_walk2 = preload("res://Shapes/chicken/走路2.png")

var time_passed = 0.0
var is_dead = false
var is_flying = false
var is_spawning = true

@onready var sprite = $Sprite2D
@onready var hatch_particles = $HatchParticles
@onready var heart_particles = $HeartParticles
@onready var smoke_particles = $SmokeParticles
@onready var heart_viewport = $HeartViewport


func _ready():
	scale = Vector2.ZERO
	# 確保 Viewport 算繪完畢後抓取截圖作為粒子材質
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(heart_viewport):
		heart_particles.texture = ImageTexture.create_from_image(
			heart_viewport.get_texture().get_image()
		)
		heart_viewport.queue_free()


func _process(delta):
	if is_dead or is_spawning:
		return

	if not is_flying:
		# 走路動畫
		var parent = get_parent()
		# 當它是 coconut 時才有 velocity 屬性
		if parent and "velocity" in parent:
			var vel = parent.velocity

			# 轉向處理 (圖片原本朝左)
			if vel.x > 10.0:
				scale.x = -abs(scale.x)
			elif vel.x < -10.0:
				scale.x = abs(scale.x)

			if vel.length() > 10.0:
				time_passed += delta * 15.0
				var step = int(time_passed) % 4
				if step == 0:
					sprite.texture = tex_chicken
				elif step == 1:
					sprite.texture = tex_walk1
				elif step == 2:
					sprite.texture = tex_chicken
				else:
					sprite.texture = tex_walk2

				# 左右搖擺與上下微幅震動
				sprite.rotation = sin(time_passed) * 0.15
				sprite.position.y = -abs(sin(time_passed)) * 5.0
			else:
				time_passed += delta * 4.0
				sprite.texture = tex_chicken
				sprite.rotation = lerp(sprite.rotation, 0.0, delta * 10.0)
				sprite.position.y = lerp(sprite.position.y, sin(time_passed) * 2.0, delta * 10.0)


func play_spawn():
	sprite.texture = tex_egg
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.rotation = 0
	sprite.position = Vector2.ZERO
	is_dead = false
	is_flying = false

	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	await tween.finished

	await get_tree().create_timer(0.2).timeout
	if is_dead:
		return
	sprite.texture = tex_egg_crack
	hatch_particles.amount = 5
	hatch_particles.restart()
	hatch_particles.emitting = true

	await get_tree().create_timer(0.2).timeout
	if is_dead:
		return
	sprite.texture = tex_egg_open

	await get_tree().create_timer(0.2).timeout
	if is_dead:
		return
	sprite.texture = tex_hatch
	hatch_particles.amount = 30
	hatch_particles.restart()
	hatch_particles.emitting = true

	await get_tree().create_timer(0.2).timeout
	if is_dead:
		return
	sprite.texture = tex_chicken
	is_spawning = false


func play_jump():
	if is_dead:
		return
	is_flying = true
	sprite.texture = tex_fly1
	await get_tree().create_timer(0.15).timeout
	if is_dead:
		return
	sprite.texture = tex_fly2


func play_land():
	if is_dead:
		return
	is_flying = false
	sprite.texture = tex_chicken
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.06, 0.06), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.05, 0.05), 0.15)


func play_eat_ball():
	if is_dead:
		return
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.07, 0.07), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.05, 0.05), 0.1)
	heart_particles.restart()
	heart_particles.emitting = true


func play_die():
	is_dead = true
	sprite.texture = tex_dead

	# 先一邊旋轉稍微上跳
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", -50.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(sprite, "rotation", PI * 4, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)

	# 下落
	(
		tween
		. chain()
		. tween_property(sprite, "position:y", 0.0, 0.4)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)

	await tween.finished
	# 落地瞬間噴發煙霧並變成烤雞
	smoke_particles.restart()
	smoke_particles.emitting = true
	sprite.texture = tex_cooked
	# 變成烤雞的顏色 (焦糖色)
	# sprite.modulate = Color(1.0, 0.6, 0.2)
	await get_tree().create_timer(1.0).timeout
