extends Node2D

@export var max_height: float = 300.0
@export var gravity: float = 1000.0

var start_pos: Vector2
var end_pos: Vector2
var velocity: Vector2

var air_time: float = 2.0
var elapsed: float = 0.0

var flying: bool = false

@onready var shell: Sprite2D = $Shell
@onready var shadow: Sprite2D = $Shadow


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	shell.z_index = 1
	shadow.z_index = 0


func _process(delta: float) -> void:
	if not flying:
		return

	elapsed += delta

	velocity.y += gravity * delta

	shell.global_position += velocity * delta

	shadow.global_position = Vector2(shell.global_position.x, end_pos.y)

	if elapsed >= air_time:
		flying = false
		print("BOOM")


func activate(initial_position: Vector2, final_position: Vector2, flight_time: float) -> void:
	start_pos = initial_position
	end_pos = final_position

	air_time = flight_time

	elapsed = 0.0
	flying = true

	shell.global_position = start_pos
	shadow.global_position = start_pos
	velocity.x = (end_pos.x - start_pos.x) / air_time

	velocity.y = (end_pos.y - start_pos.y - 0.5 * gravity * air_time * air_time) / air_time
