extends BaseSkin

const TEX_RUN1 := preload("res://Shapes/drive_skin/run1.png")
const TEX_RUN2 := preload("res://Shapes/drive_skin/run2.png")
const TEX_JUMP := preload("res://Shapes/drive_skin/jump.png")
const BASE_SPRITE_SCALE := Vector2(0.022, 0.022)

var time_passed := 0.0
var is_dead := false
var is_flying := false
var is_spawning := true

@onready var sprite: Sprite2D = $Sprite2D
@onready var dust_particles: CPUParticles2D = $DustParticles
@onready var wool_particles: CPUParticles2D = $WoolParticles
@onready var treat_particles: CPUParticles2D = $TreatParticles
@onready var sparkle_particles: CPUParticles2D = $SparkleParticles


func _ready():
	scale = Vector2.ZERO
	sprite.texture = TEX_RUN1


func _process(delta):
	if is_dead or is_spawning or is_flying:
		return

	var parent = get_meta("player") if has_meta("player") else get_parent()
	if parent and "velocity" in parent:
		var vel = parent.velocity

		if vel.x > 10.0:
			scale.x = -abs(scale.x)
		elif vel.x < -10.0:
			scale.x = abs(scale.x)

		if vel.length() > 10.0:
			time_passed += delta * 12.0
			sprite.texture = TEX_RUN1 if int(time_passed) % 2 == 0 else TEX_RUN2
			sprite.position.y = -abs(sin(time_passed)) * 4.0
			sprite.rotation = sin(time_passed) * 0.04
		else:
			time_passed += delta * 4.0
			sprite.texture = TEX_RUN1
			sprite.position.y = lerp(sprite.position.y, sin(time_passed) * 1.5, delta * 8.0)
			sprite.rotation = lerp(sprite.rotation, 0.0, delta * 8.0)


func play_spawn():
	sprite.texture = TEX_RUN1
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.scale = BASE_SPRITE_SCALE
	sprite.rotation = 0.0
	sprite.position = Vector2.ZERO
	is_dead = false
	is_flying = false
	is_spawning = true

	scale = Vector2.ZERO
	wool_particles.restart()
	wool_particles.emitting = true
	sparkle_particles.restart()
	sparkle_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 0.8, 0.25)
	tween.tween_property(self, "scale", Vector2.ONE * 0.72, 0.08)
	tween.tween_property(self, "scale", Vector2.ONE * 0.8, 0.1)
	await tween.finished
	is_spawning = false


func play_jump():
	if is_dead:
		return
	is_flying = true
	sprite.texture = TEX_JUMP
	sparkle_particles.restart()
	sparkle_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", -8.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	await tween.finished


func play_land():
	if is_dead:
		return
	is_flying = false
	sprite.texture = TEX_RUN1
	dust_particles.restart()
	dust_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "position:y", 0.0, 0.08)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.024, 0.02), 0.08)
	tween.tween_property(sprite, "scale", BASE_SPRITE_SCALE, 0.12)


func play_eat_ball():
	if is_dead:
		return
	treat_particles.restart()
	treat_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.025, 0.025), 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.86, 0.72, 1.0), 0.1)
	tween.tween_property(sprite, "scale", BASE_SPRITE_SCALE, 0.1)
	tween.parallel().tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.14)


func play_die():
	is_dead = true
	is_flying = false
	sprite.texture = TEX_JUMP
	dust_particles.restart()
	dust_particles.emitting = true
	wool_particles.restart()
	wool_particles.emitting = true

	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite, "position:y", -24.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(sprite, "rotation", PI * 0.35, 0.25)
	(
		tween
		. chain()
		. tween_property(sprite, "position:y", 0.0, 0.28)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)
	await tween.finished
