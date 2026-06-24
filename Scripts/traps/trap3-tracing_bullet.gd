class_name Trap3TracingBullet
extends CharacterBody2D

const PLAYER_COLLISION_LAYER := 1
const WALL_COLLISION_LAYER := 2

@export var max_turn_rate := 2.0

var target: Node2D = null
var speed := 0.0
var active := false
var tracing := true
var _data: Dictionary = Global.trap_data["trap3-tracing_bullet"]


static func initialize(pos: Vector2, dir: Vector2, speed: float) -> Trap3TracingBullet:
	var trap := preload("res://Scenes/traps/trap3-tracing_bullet.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(pos, dir, speed, Global.game_manager.player)
	return trap


func _ready() -> void:
	collision_mask = PLAYER_COLLISION_LAYER | WALL_COLLISION_LAYER
	set_physics_process(false)
	visible = false


func activate(
	spawn_position: Vector2, initial_direction: Vector2, new_speed: float, new_target: Node2D
):
	position = spawn_position
	rotation = initial_direction.angle()

	speed = new_speed
	target = new_target

	active = true
	tracing = true
	visible = true
	set_physics_process(true)


func deactivate():
	queue_free()


func _physics_process(delta):
	if not active:
		return

	if target == null:
		deactivate()
		return

	if tracing:
		turn_toward_target(delta)

		if target_passed_stop_line():
			tracing = false

	velocity = Vector2.RIGHT.rotated(rotation) * speed

	var collision := move_and_collide(velocity * delta)

	if collision:
		var collider := collision.get_collider()

		if collider == target:
			Global.player_hit.emit(67)
			deactivate()
		elif (collider.collision_layer & WALL_COLLISION_LAYER) != 0:
			deactivate()


func turn_toward_target(delta):
	var desired_angle := (target.global_position - global_position).angle()

	rotation = rotate_toward(rotation, desired_angle, max_turn_rate * delta)


func target_passed_stop_line() -> bool:
	var forward := Vector2.RIGHT.rotated(rotation)
	var to_target := target.global_position - global_position

	return to_target.dot(forward) < 0
