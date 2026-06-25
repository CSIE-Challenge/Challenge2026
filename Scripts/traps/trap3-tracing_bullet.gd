class_name Trap3TracingBullet
extends CharacterBody2D

const PLAYER_COLLISION_LAYER := 1
const WALL_COLLISION_LAYER := 2
const TRAP_COLLISION_LAYER := 4

@export var max_turn_rate := 2.0
@export var max_speed := 300.0
@export var min_speed := 100.0

var target: Node2D = null
var speed := 0.0
var tracing := true
var _data: Dictionary = Global.trap_data["trap3-tracing_bullet"]

@onready var feather_effect = $FeatherEffect


static func initialize(pos: Vector2, dir: Vector2, speed: float) -> Trap3TracingBullet:
	var trap := preload("res://Scenes/traps/trap3-tracing_bullet.tscn").instantiate()
	trap.position = pos
	trap.rotation = dir.angle()
	trap.speed = speed
	trap.target = Global.game_manager.player
	Global.stage.add_child(trap)
	return trap


func _ready() -> void:
	speed = clamp(speed, min_speed, max_speed)
	collision_layer = TRAP_COLLISION_LAYER
	collision_mask = PLAYER_COLLISION_LAYER | WALL_COLLISION_LAYER
	tracing = true
	set_physics_process(true)


func _physics_process(delta):
	if target == null:
		queue_free()
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
			queue_free()
		elif (collider.collision_layer & WALL_COLLISION_LAYER) != 0:
			queue_free()


func turn_toward_target(delta):
	var desired_angle := (target.global_position - global_position).angle()

	rotation = rotate_toward(rotation, desired_angle, max_turn_rate * delta)


func target_passed_stop_line() -> bool:
	var forward := Vector2.RIGHT.rotated(rotation)
	var to_target := target.global_position - global_position

	return to_target.dot(forward) < 0
