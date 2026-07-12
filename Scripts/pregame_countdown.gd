extends Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	pivot_offset = size / 2.0
	hide()


func play_countdown() -> void:
	for value in ["3", "2", "1"]:
		await show_number(value)

	await show_go()
	hide()


func show_number(value: String) -> void:
	text = value
	show()

	scale = Vector2.ONE * 3.0
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()

	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(self, "modulate:a", 1.0, 0.15)

	await tween.finished
	await get_tree().create_timer(0.4, true).timeout

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(self, "modulate:a", 0.0, 0.15)

	await fade.finished


func show_go() -> void:
	text = "GO !"
	show()

	await get_tree().process_frame
	pivot_offset = size / 2.0

	scale = Vector2.ONE * 7.0
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()

	(
		tween
		. tween_property(self, "scale", Vector2.ONE * 1.2, 0.5)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)

	tween.tween_property(self, "modulate:a", 1.0, 0.15)

	await tween.finished
	await get_tree().create_timer(0.6, true).timeout

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.set_parallel()

	fade.tween_property(self, "scale", Vector2.ONE * 1.5, 0.3)
	fade.tween_property(self, "modulate:a", 0.0, 0.3)

	await fade.finished
