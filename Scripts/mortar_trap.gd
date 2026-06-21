extends Node2D

@export var max_height: float = 300.0

var start_pos: Vector2
var end_pos: Vector2

var air_time: float = 2.0
var elapsed: float = 0.0

var flying: bool = false

@onready var shell: Sprite2D = $Shell
@onready var shadow: Sprite2D = $Shadow


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


func _process(delta: float) -> void:
	if not flying:
		return

	elapsed += delta

	var t = elapsed / air_time
	t = clamp(t, 0.0, 1.0)
	var ground_pos = start_pos.lerp(end_pos, t)

	shadow.global_position = ground_pos

	var height = 4.0 * max_height * t * (1.0 - t)

	shell.global_position = ground_pos + Vector2(0, -height)

	if t >= 1.0:
		flying = false
		print("BOOM")


func activate(initial_position: Vector2, final_position: Vector2, flight_time: float) -> void:
	start_pos = initial_position
	end_pos = final_position

	air_time = flight_time

	elapsed = 0.0
	flying = true
