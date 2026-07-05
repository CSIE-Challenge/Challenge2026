extends Label
var combo_scale = [1, 1.2, 1.3, 1.5, 1.5, 1.6]
var time_elapsed := 0.0
var now_combo: int


func initialize(combo: int):
	now_combo = combo
	pivot_offset = size / 2
	var move_tween = create_tween()
	(
		move_tween
		. tween_property(self, "global_position:y", global_position.y - 45, 0.8)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	scale = Vector2(0.3, 0.3)
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.3, 1.3) * combo_scale[combo], 0.2)
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0) * combo_scale[combo], 0.1)
	scale_tween.tween_interval(0.4)

	scale_tween.tween_property(self, "scale", Vector2.ZERO, 0.13)
	scale_tween.chain().tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	time_elapsed += delta
	if now_combo >= 4:
		var b = abs(sin(time_elapsed * TAU * 3))
		var g = 0.75 + sin(time_elapsed * TAU * 1.05 * 3) * 0.25
		var color = Color(1, g, b, 1)
		modulate = color
