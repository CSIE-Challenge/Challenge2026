class_name ResultScreen
extends CanvasLayer

@onready var stat_names_label: Label = %StatNamesLabel
@onready var stat_values_label: Label = %StatValuesLabel


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
		str(int(results.get("remaining_health", 0))),
		str(int(results.get("trap_count", 0)))
	]

	stat_names_label.text = "\n".join(names)
	stat_values_label.text = "\n".join(values)

	show()
