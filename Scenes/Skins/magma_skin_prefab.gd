extends BaseSkin

var throb_tween: Tween

@onready var sprite = $Sprite2D
@onready var fire = $FireParticles
@onready var splash = $SplashParticles
@onready var death_particles = $DeathParticles


func _ready():
	_start_throb()


func play_spawn():
	scale = Vector2.ZERO
	fire.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func play_die():
	if throb_tween:
		throb_tween.kill()
	fire.emitting = false
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.4)


func _start_throb():
	if throb_tween:
		throb_tween.kill()
	throb_tween = create_tween().set_loops()
	throb_tween.tween_property(sprite, "scale", Vector2(0.22, 0.22), 0.6).set_trans(
		Tween.TRANS_SINE
	)
	throb_tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.6).set_trans(Tween.TRANS_SINE)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 1.0, 0.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.0, 1.0), 0.3)


func play_jump():
	if throb_tween:
		throb_tween.kill()
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.16, 0.25), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
	tween.finished.connect(_start_throb)


func play_land():
	if throb_tween:
		throb_tween.kill()
	splash.restart()
	splash.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.26, 0.16), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
	tween.finished.connect(_start_throb)
