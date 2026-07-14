extends BaseSkin

const BODY_COLOR := Color(0.1, 0.1, 0.1, 1.0)
const RED_COLOR := Color(0.8, 0.13, 0.13, 1.0)
const ROOT_BASE_Y := 15.0
const NIL_TEXTURE := preload("res://Shapes/nil_text.svg")

var is_dead: bool = false
var is_spawning: bool = false
var is_flying: bool = false
var walk_time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var arm_l: Sprite2D = $Visual/ArmL
@onready var arm_r: Sprite2D = $Visual/ArmR
@onready var root_l: Sprite2D = $Visual/RootL
@onready var root_m: Sprite2D = $Visual/RootM
@onready var root_r: Sprite2D = $Visual/RootR
@onready var crown: Sprite2D = $Visual/Crown
@onready var crown_l: Sprite2D = $Visual/CrownL
@onready var crown_r: Sprite2D = $Visual/CrownR
@onready var eye_white_l: Sprite2D = $Visual/EyeWhiteL
@onready var eye_white_r: Sprite2D = $Visual/EyeWhiteR
@onready var pupil_l: Sprite2D = $Visual/PupilL
@onready var pupil_r: Sprite2D = $Visual/PupilR
@onready var vein_l: Sprite2D = $Visual/VeinL
@onready var vein_r: Sprite2D = $Visual/VeinR
@onready var trail_particles: CPUParticles2D = $TrailParticles
@onready var spawn_particles: CPUParticles2D = $SpawnParticles
@onready var death_particles: CPUParticles2D = $DeathParticles


func _ready() -> void:
	scale = Vector2.ZERO


func _process(delta: float) -> void:
	if is_dead or is_spawning:
		trail_particles.emitting = false
		return

	var parent = get_meta("player") if has_meta("player") else get_parent()
	var vel := Vector2.ZERO
	if parent and "velocity" in parent:
		vel = parent.velocity

	if vel.x > 10.0:
		visual.scale.x = abs(visual.scale.x)
	elif vel.x < -10.0:
		visual.scale.x = -abs(visual.scale.x)

	if is_flying:
		trail_particles.emitting = false
		visual.rotation = lerp(visual.rotation, -0.1, delta * 8.0)
		arm_l.rotation = lerp(arm_l.rotation, -0.4, delta * 10.0)
		arm_r.rotation = lerp(arm_r.rotation, 0.4, delta * 10.0)
		return

	if vel.length() > 15.0:
		walk_time += delta * 12.0
		var swing := sin(walk_time)
		arm_l.rotation = swing * 0.5
		arm_r.rotation = -swing * 0.5
		root_l.position.y = lerp(
			root_l.position.y, ROOT_BASE_Y - maxf(0.0, swing) * 2.0, delta * 14.0
		)
		root_r.position.y = lerp(
			root_r.position.y, ROOT_BASE_Y - maxf(0.0, -swing) * 2.0, delta * 14.0
		)
		visual.position.y = -absf(swing) * 1.5
		trail_particles.emitting = true
	else:
		walk_time += delta * 2.5
		arm_l.rotation = lerp(arm_l.rotation, 0.0, delta * 8.0)
		arm_r.rotation = lerp(arm_r.rotation, 0.0, delta * 8.0)
		root_l.position.y = lerp(root_l.position.y, ROOT_BASE_Y, delta * 8.0)
		root_r.position.y = lerp(root_r.position.y, ROOT_BASE_Y, delta * 8.0)
		visual.position.y = sin(walk_time) * 1.0
		trail_particles.emitting = false

	_pulse_veins()


func _pulse_veins() -> void:
	vein_l.modulate = RED_COLOR.lerp(Color.WHITE, (sin(walk_time) + 1.0) * 0.15)
	vein_r.modulate = RED_COLOR.lerp(Color.WHITE, (sin(walk_time) + 1.0) * 0.15)


func play_spawn() -> void:
	is_dead = false
	is_flying = false
	is_spawning = true
	visual.modulate = Color.WHITE
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE
	body.modulate = BODY_COLOR
	vein_l.modulate = RED_COLOR
	vein_r.modulate = RED_COLOR
	arm_l.rotation = 0.0
	arm_r.rotation = 0.0

	spawn_particles.restart()
	spawn_particles.emitting = true

	body.modulate = RED_COLOR
	scale = Vector2.ZERO
	var tween := create_tween()
	(
		tween
		. tween_property(self, "scale", Vector2.ONE * 1.2, 0.18)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame

	var recolor := create_tween()
	recolor.tween_property(body, "modulate", BODY_COLOR, 0.25)

	var crown_start_y := crown.position.y - 8.0
	crown.position.y = crown_start_y
	var crown_tween := create_tween()
	(
		crown_tween
		. tween_property(crown, "position:y", crown_start_y + 8.0, 0.2)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)

	is_spawning = false


func play_jump() -> void:
	if is_dead:
		return
	is_flying = true

	# 旋轉操作（quarter-turn，明顯可見）
	var tween := create_tween()
	tween.tween_property(visual, "rotation", PI / 2.0, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(visual, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)

	var stretch := create_tween()
	stretch.tween_property(visual, "scale:y", abs(visual.scale.y) * 1.25, 0.1)
	stretch.tween_property(visual, "scale:y", abs(visual.scale.y), 0.15)


func play_land() -> void:
	if is_dead:
		return
	is_flying = false
	visual.rotation = 0.0

	spawn_particles.restart()
	spawn_particles.emitting = true

	var sx := signf(visual.scale.x)
	if sx == 0.0:
		sx = 1.0

	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector2(sx * 1.25, 0.75), 0.05)
	tween.tween_property(visual, "scale", Vector2(sx, 1.0), 0.18)

	var recolor := create_tween()
	recolor.tween_property(body, "modulate", RED_COLOR, 0.05)
	recolor.tween_property(body, "modulate", BODY_COLOR, 0.2)

	var root_tween := create_tween().set_parallel(true)
	root_tween.tween_property(root_l, "position:y", ROOT_BASE_Y + 3.0, 0.05)
	root_tween.tween_property(root_r, "position:y", ROOT_BASE_Y + 3.0, 0.05)
	root_tween.chain().tween_property(root_l, "position:y", ROOT_BASE_Y, 0.15)
	root_tween.tween_property(root_r, "position:y", ROOT_BASE_Y, 0.15)

	# NIL 葉節點出現在腳下，1.5 秒後淡出
	_spawn_nil_text()


func _spawn_nil_text() -> void:
	var nil_sprite := Sprite2D.new()
	nil_sprite.texture = NIL_TEXTURE
	nil_sprite.modulate = Color(0.2, 0.2, 0.2, 1.0)
	nil_sprite.scale = Vector2(1.5, 1.5)
	get_parent().add_child(nil_sprite)
	nil_sprite.global_position = global_position + Vector2(0, 28)

	var t := nil_sprite.create_tween()
	t.tween_interval(0.66)
	t.tween_property(nil_sprite, "modulate:a", 0.0, 0.33)
	t.tween_callback(nil_sprite.queue_free)


func play_eat_ball() -> void:
	if is_dead:
		return
	# recolor cascade：模擬 insert recoloring 沿路傳播
	var cascade := create_tween()
	cascade.tween_property(body, "modulate", RED_COLOR, 0.06)
	cascade.tween_property(body, "modulate", BODY_COLOR, 0.07)
	cascade.tween_property(body, "modulate", RED_COLOR * 0.85, 0.06)
	cascade.tween_property(body, "modulate", BODY_COLOR, 0.1)

	# 眨眼
	var blink := create_tween()
	blink.tween_property(pupil_l, "scale:y", 0.01, 0.06)
	blink.parallel().tween_property(pupil_r, "scale:y", 0.01, 0.06)
	blink.tween_property(pupil_l, "scale:y", pupil_l.scale.y, 0.1)
	blink.parallel().tween_property(pupil_r, "scale:y", pupil_r.scale.y, 0.1)

	# 脈絡閃亮
	var pulse := create_tween().set_parallel(true)
	pulse.tween_property(vein_l, "modulate", Color.WHITE, 0.07)
	pulse.tween_property(vein_r, "modulate", Color.WHITE, 0.07)
	pulse.chain().tween_property(vein_l, "modulate", RED_COLOR, 0.18)
	pulse.tween_property(vein_r, "modulate", RED_COLOR, 0.18)

	var pop := create_tween()
	pop.tween_property(visual, "scale", Vector2.ONE * 1.12, 0.08)
	pop.tween_property(visual, "scale", Vector2.ONE, 0.14)


func play_die() -> void:
	is_dead = true
	is_spawning = false
	trail_particles.emitting = false

	death_particles.restart()
	death_particles.emitting = true

	var flash := create_tween().set_parallel(true)
	flash.tween_property(body, "modulate", RED_COLOR * 1.4, 0.08)
	flash.tween_property(vein_l, "modulate", Color.WHITE, 0.08)
	flash.tween_property(vein_r, "modulate", Color.WHITE, 0.08)

	await get_tree().create_timer(0.1).timeout

	var shake := create_tween()
	shake.tween_property(visual, "rotation", 0.25, 0.08)
	shake.tween_property(visual, "rotation", -0.25, 0.08)
	shake.tween_property(visual, "rotation", 0.15, 0.07)
	shake.tween_property(visual, "rotation", 0.0, 0.07)

	await get_tree().create_timer(0.25).timeout

	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
