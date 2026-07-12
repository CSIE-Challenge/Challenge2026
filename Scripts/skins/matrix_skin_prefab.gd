extends BaseSkin

var last_pos: Vector2

@onready var sprite = $Sprite2D


func _process(_delta):
	if global_position.distance_to(last_pos) > 10.0:
		spawn_code()
		last_pos = global_position


func spawn_code():
	var lbl = Label.new()
	var chars = "0123456789ABCDEF"
	lbl.text = chars[randi() % chars.length()]
	lbl.modulate = Color(0.0, 1.0, 0.2, 0.8)  # Green code
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.top_level = true
	lbl.global_position = self.global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
	add_child(lbl)

	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.5)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


func play_spawn():
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_SPRING)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.2)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.5, 1.0, 1.0), 0.1)
	tween.tween_property(sprite, "modulate", Color(0.6, 0.1, 1.0, 1.0), 0.2)


func play_jump():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.12, 0.28), 0.15)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)


func play_land():
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(0.3, 0.1), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.15)
