extends BaseSkin

var is_active = false
var max_trail_points = 25

@onready var sprite = $Sprite2D
@onready var trail = $Line2D
@onready var particles = $CPUParticles2D
@onready var death_particles = $DeathParticles


func _ready():
	trail.top_level = true
	trail.clear_points()


func _process(_delta):
	if is_active:
		trail.add_point(sprite.global_position)
		if trail.get_point_count() > max_trail_points:
			trail.remove_point(0)
	elif trail.get_point_count() > 0:
		trail.remove_point(0)


func play_spawn():
	scale = Vector2.ZERO
	is_active = true
	trail.clear_points()
	particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING).set_ease(
		Tween.EASE_OUT
	)


func play_die():
	is_active = false
	particles.emitting = false
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.2)


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)


func play_jump():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.3), 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15).set_trans(Tween.TRANS_SINE)


func play_land():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.35, 0.1), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15).set_trans(Tween.TRANS_SINE)
