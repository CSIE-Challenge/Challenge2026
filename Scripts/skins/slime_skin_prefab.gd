extends BaseSkin

var jump_tween: Tween
var breathe_tween: Tween

@onready var sprite = $Sprite2D
@onready var splash = $SplashParticles
@onready var death_particles = $DeathParticles


func _ready():
	_start_breathe()


func _start_breathe():
	if breathe_tween:
		breathe_tween.kill()
	breathe_tween = create_tween().set_loops()
	breathe_tween.tween_property(sprite, "scale", Vector2(0.24, 0.16), 1.0).set_trans(
		Tween.TRANS_SINE
	)
	breathe_tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 1.0).set_trans(
		Tween.TRANS_SINE
	)


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(
		Tween.EASE_OUT
	)
	splash.restart()
	splash.emitting = true
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	if breathe_tween:
		breathe_tween.kill()
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.2)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.5, 1.0, 0.5, 0.9), 0.1)
	tween.tween_property(sprite, "modulate", Color(0.2, 0.8, 0.2, 0.8), 0.3)


func play_jump():
	var tween = create_tween()
	# 史萊姆起跳極度拉長
	tween.tween_property(sprite, "scale", Vector2(0.1, 0.35), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.22, 0.18), 0.15).set_trans(Tween.TRANS_SINE)


func play_land():
	splash.restart()
	splash.emitting = true
	var tween = create_tween()
	# 史萊姆落地極度壓扁
	tween.tween_property(sprite, "scale", Vector2(0.35, 0.1), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.22, 0.18), 0.15).set_trans(Tween.TRANS_SINE)
