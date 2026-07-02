class_name Trap3TracingBullet
extends CharacterBody2D

const PLAYER_COLLISION_LAYER := 1
const WALL_COLLISION_LAYER := 2
const TRAP_COLLISION_LAYER := 4
var cooldown_times = TrapData.new().data["trap3-tracing_bullet"]["cooldown_times"]
var damage = TrapData.new().data["trap3-tracing_bullet"]["damage"]
var energy_costs = TrapData.new().data["trap3-tracing_bullet"]["energy_costs"]
var turn_rate = TrapData.new().data["trap3-tracing_bullet"]["turn_rate"]
var wait_time = TrapData.new().data["trap3-tracing_bullet"]["wait_time"]
var target: Node2D = null
var speed := 0.0
var tracing := true
var flying := false
var wall_counter := 0
@onready var feather_effect = $FeatherEffect
@onready var leave_wall_detector = $Area2D
@onready var wait_timer = $WaitTimer
@onready var animation = $AnimationPlayer


static func initialize(pos: Vector2, dir: Vector2, speed: float) -> Trap3TracingBullet:
	var trap := preload("res://Scenes/traps/trap3-tracing_bullet.tscn").instantiate()
	trap.position = pos
	trap.rotation = dir.angle()
	trap.speed = speed
	trap.target = Global.game_manager.player
	Global.stage.add_child(trap)
	return trap


func _ready() -> void:
	collision_layer = TRAP_COLLISION_LAYER
	collision_mask = 0
	leave_wall_detector.collision_mask = WALL_COLLISION_LAYER
	tracing = true
	set_physics_process(true)
	wait_timer.timeout.connect(_on_wait_timer_out)
	wait_timer.start(wait_time)
	leave_wall_detector.body_entered.connect(_on_wall_entered)
	leave_wall_detector.body_exited.connect(_on_wall_exited)
	animation.play("spawn")


func _destroy() -> void:
	queue_free()


func _physics_process(delta):
	if target == null:
		_destroy()
		return
	if !flying:
		return
	if tracing:
		turn_toward_target(delta)

		if target_passed_stop_line():
			tracing = false

	velocity = Vector2.RIGHT.rotated(rotation) * speed

	var collision := move_and_collide(velocity * delta)

	if collision or abs(position.x) > 1000 or abs(position.y) > 1000:
		feather_effect.emitting = true
		feather_effect.finished.connect(feather_effect.queue_free)
		feather_effect.reparent(Global.stage)
		if collision != null:
			var collider := collision.get_collider()
			if collider and collider == target:
				Global.player_hit.emit(damage)
				_destroy()
			elif (collider.collision_layer & WALL_COLLISION_LAYER) != 0:
				_destroy()
		else:
			_destroy()


func turn_toward_target(delta):
	var desired_angle := (target.global_position - global_position).angle()

	rotation = rotate_toward(rotation, desired_angle, turn_rate * delta)


func target_passed_stop_line() -> bool:
	var forward := Vector2.RIGHT.rotated(rotation)
	var to_target := target.global_position - global_position

	return to_target.dot(forward) < 0


func _on_wait_timer_out():
	flying = true


func _on_wall_entered(_body: Node2D) -> void:
	wall_counter += 1


func _on_wall_exited(_body: Node2D) -> void:
	wall_counter -= 1
	if wall_counter <= 0:
		collision_mask = PLAYER_COLLISION_LAYER | WALL_COLLISION_LAYER
