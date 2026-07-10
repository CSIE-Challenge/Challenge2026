class_name ResultScreen
extends CanvasLayer

@onready var energy_spent_label: Label = %EnergySpentLabel
@onready var energy_balls_label: Label = %EnergyBallsLabel
@onready var jump_count_label: Label = %JumpCountLabel
@onready var distance_label: Label = %DistanceLabel
@onready var survival_time_label: Label = %SurvivalTimeLabel
@onready var remaining_health_label: Label = %RemainingHealthLabel
@onready var trap_count_label: Label = %TrapCountLabel


func show_results(results: Dictionary) -> void:
	energy_spent_label.text = "Total Energy Spent: %d" % int(results.get("energy_spent", 0))
	energy_balls_label.text = "Energy Balls Collected: %d" % int(results.get("energy_balls", 0))
	jump_count_label.text = "Jumps: %d" % int(results.get("jump_count", 0))
	distance_label.text = "Distance Traveled: %.1f" % float(results.get("distance_traveled", 0.0))
	survival_time_label.text = (
		"Survival Time: %.1f seconds" % float(results.get("survival_time", 0.0))
	)
	remaining_health_label.text = ("Remaining Health: %d" % int(results.get("remaining_health", 0)))
	trap_count_label.text = "Traps Placed: %d" % int(results.get("trap_count", 0))

	Audio.set_bgm(Audio.BGM.RESULT_SCREEN)
	show()
