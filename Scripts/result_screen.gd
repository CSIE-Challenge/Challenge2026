class_name ResultScreen
extends CanvasLayer

var fade_tween: Tween

@onready var stat_names_label: Label = %StatNamesLabel
@onready var stat_values_label: Label = %StatValuesLabel
@onready var health_icon = $"ResultRoot/HealthIcons"
@onready var vboxcontainer = %VBoxContainer
@onready var result_root: Control = $ResultRoot


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			if visible:
				_on_home_button_button_up()
				get_viewport().set_input_as_handled()


func show_results(results: Dictionary) -> void:
	var survival_seconds := int(results.get("survival_time", 0.0))

	var names: Array[String] = [
		"Survival Time",
		"Remaining Health",
		"Energy Balls Collected",
		"Jumps",
		"Distance Traveled",
		"Total Energy Spent"
	]

	var values: Array[String] = [
		"%02d:%02d" % [survival_seconds / 60, survival_seconds % 60],
		"",
		str(int(results.get("energy_balls", 0))),
		str(int(results.get("jump_count", 0))),
		"%.1f" % float(results.get("distance_traveled", 0.0)),
		str(int(results.get("energy_spent", 0))),
	]

	var opponent_energy_balls := int(results.get("opponent_energy_balls", -1))
	if opponent_energy_balls >= 0:
		# This row is multiplayer-only; single-player leaves opponent_energy_balls at -1.
		names.insert(3, "Opponent Energy Balls")
		values.insert(3, str(opponent_energy_balls))

	stat_names_label.text = "\n".join(names)
	stat_values_label.text = "\n".join(values)

	health_icon.modulate.a = 0.0
	health_icon.reversed = 1
	health_icon.set_icon_size(Vector2(25, 25))
	health_icon._ensure_icons()
	health_icon.set_health(int(results.get("remaining_health", 0)))

	result_root.modulate.a = 0.0
	health_icon.modulate.a = 0.0
	show()
	result_root.show()
	health_icon.show()
	health_icon.queue_sort()
	vboxcontainer.queue_sort()

	await get_tree().process_frame
	await get_tree().process_frame

	_align_health_icon()
	health_icon.modulate.a = 1.0

	Audio.set_bgm(Audio.BGM.RESULT_SCREEN)
	_fade_in(3.0)


func _align_health_icon() -> void:
	var character_index := stat_names_label.text.find("Remaining Health")
	if character_index == -1:
		push_warning("Cannot find Remaining Health in StatNamesLabel")
		return
	var character_rect := stat_names_label.get_character_bounds(character_index)
	if character_rect.size == Vector2.ZERO:
		push_warning("Remaining Health text has not been laid out yet")
		return

	var character_center_local := character_rect.get_center()
	var character_center_global := stat_names_label.get_global_transform() * character_center_local
	var values_right_global := (
		stat_values_label.get_global_transform() * Vector2(stat_values_label.size.x, 0.0)
	)
	var icon_transform: Transform2D = health_icon.get_global_transform()
	var icon_right_center_global: Vector2 = (
		icon_transform * Vector2(health_icon.size.x, health_icon.size.y * 0.5)
	)
	var target_global := Vector2(values_right_global.x, character_center_global.y)
	health_icon.global_position += (target_global - icon_right_center_global)


func _fade_in(duration: float = 1.5) -> void:
	show()
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	(
		fade_tween
		. tween_property(result_root, "modulate:a", 1.0, duration)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)


func _on_home_button_button_up() -> void:
	var player: AudioStreamPlayer = Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/menu.tscn")
	await get_tree().create_timer(2).timeout
	hide()
	get_tree().paused = false


func _on_exit_button_button_up() -> void:
	var player: AudioStreamPlayer = Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
