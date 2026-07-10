class_name ResultScreen
extends CanvasLayer

@onready var stat_names_label: Label = %StatNamesLabel
@onready var stat_values_label: Label = %StatValuesLabel
@onready var health_icon = $HealthIcons
@onready var vboxcontainer = %VBoxContainer


func show_results(results: Dictionary) -> void:
	var survival_seconds := int(results.get("survival_time", 0.0))

	var names: Array[String] = [
		"Total Energy Spent",
		"Energy Balls Collected",
		"Jumps",
		"Distance Traveled",
		"Survival Time",
		"Remaining Health",
		"Traps Placed"
	]

	var values: Array[String] = [
		str(int(results.get("energy_spent", 0))),
		str(int(results.get("energy_balls", 0))),
		str(int(results.get("jump_count", 0))),
		"%.1f" % float(results.get("distance_traveled", 0.0)),
		"%02d:%02d" % [survival_seconds / 60, survival_seconds % 60],
		"",
		str(int(results.get("trap_count", 0)))
	]

	stat_names_label.text = "\n".join(names)
	stat_values_label.text = "\n".join(values)

	health_icon.modulate.a = 0.0
	health_icon.reversed = 1
	health_icon.set_icon_size(Vector2(22, 22))
	health_icon._ensure_icons()
	health_icon.set_health(int(results.get("remaining_health", 0)))
	show()
	await get_tree().process_frame
	health_icon.global_position.x += (
		vboxcontainer.get_global_rect().end.x - health_icon.get_global_rect().end.x
	)
	health_icon.modulate.a = 1.0


func _on_exit_button_button_up() -> void:
	SceneTransition.transition_to("res://Scenes/menu.tscn")
	hide()
	await get_tree().create_timer(2.1).timeout
	get_tree().paused = false
