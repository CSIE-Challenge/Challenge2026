class_name ResultScreen
extends CanvasLayer

var fade_tween: Tween

@onready var stat_names_label: Label = %StatNamesLabel
@onready var stat_values_label: Label = %StatValuesLabel
@onready var health_icon = $"ResultRoot/HealthIcons"
@onready var vboxcontainer = %VBoxContainer
@onready var result_root: Control = $ResultRoot


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

	stat_names_label.text = "\n".join(names)
	stat_values_label.text = "\n".join(values)

	health_icon.modulate.a = 0.0
	health_icon.reversed = 1
	health_icon.set_icon_size(Vector2(22, 22))
	health_icon._ensure_icons()
	health_icon.set_health(int(results.get("remaining_health", 0)))

	await get_tree().process_frame
	_align_health_icon()
	await get_tree().process_frame
	health_icon.modulate.a = 1.0
	Audio.set_bgm(Audio.BGM.RESULT_SCREEN)
	_fade_in(3)


func _align_health_icon() -> void:
	var character_index: int = stat_names_label.text.find("Remaining Health")
	if character_index == -1:
		push_warning("Cannot find Remaining Health in StatNamesLabel")
		return
	var character_rect: Rect2 = stat_names_label.get_character_bounds(character_index)
	if character_rect.size == Vector2.ZERO:
		push_warning("Remaining Health text has not been laid out yet")
		return

	var target_local_center: Vector2 = character_rect.position + character_rect.size * 0.5
	var target_global_center: Vector2 = (
		stat_names_label.get_global_transform() * target_local_center
	)
	var icon_rect: Rect2 = health_icon.get_global_rect()
	var icon_center_y: float = icon_rect.position.y + icon_rect.size.y * 0.5
	var target_right_x: float = vboxcontainer.get_global_rect().end.x

	health_icon.global_position += Vector2(
		target_right_x - icon_rect.end.x, target_global_center.y - icon_center_y
	)


func _fade_in(duration: float = 1.5) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	result_root.modulate.a = 0.0
	result_root.show()
	show()
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
