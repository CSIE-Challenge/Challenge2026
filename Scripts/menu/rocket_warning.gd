extends Node2D

@export var pulse_speed: float = 0.12  # 閃爍頻率

var warning_pos: Vector2
var duriation: float

@onready var circle = $WarningCircle
@onready var label = $WarningLabel


func init(pos: Vector2, wait_duration: float):
	warning_pos = pos
	duriation = wait_duration
	position = pos


func _ready() -> void:
	# 閃爍動畫
	var tween = create_tween().set_loops()
	tween.tween_property(circle, "modulate:a", 0.9, pulse_speed)
	tween.parallel().tween_property(label, "modulate:a", 1.0, pulse_speed)
	tween.tween_property(circle, "modulate:a", 0.2, pulse_speed)
	tween.parallel().tween_property(label, "modulate:a", 0.3, pulse_speed)

	get_tree().create_timer(duriation).timeout.connect(
		func():
			tween.kill()
			queue_free()
	)
