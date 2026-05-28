extends CharacterBody2D

@export var max_turn_rate := deg_to_rad(180.0)

var target: Node2D = null
var speed := 0.0
var active := false
var tracing := true


func _ready() -> void:
	set_physics_process(false)
	visible = false


func activate(
	spawn_position: Vector2, initial_direction: Vector2, new_speed: float, new_target: Node2D
):
	global_position = spawn_position
	rotation = initial_direction.angle()

	speed = new_speed
	target = new_target

	active = true
	tracing = true
	visible = true
	set_physics_process(true)


func deactivate():
	active = false
	visible = false
	set_physics_process(false)
	velocity = Vector2.ZERO


func _physics_process(delta):
	if not active:
		return

	if target == null:
		deactivate()
		return

	if tracing:
		turn_toward_target(delta)

		if target_passed_stop_line():
			print("target passed stop line")
			tracing = false

	velocity = Vector2.RIGHT.rotated(rotation) * speed
	move_and_slide()


func turn_toward_target(delta):
	var desired_angle := (target.global_position - global_position).angle()

	rotation = rotate_toward(rotation, desired_angle, max_turn_rate * delta)


func target_passed_stop_line() -> bool:
	var forward := Vector2.RIGHT.rotated(rotation)
	var to_target := target.global_position - global_position

	return to_target.dot(forward) < 0
