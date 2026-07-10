class_name Trap3TracingBullet
extends CharacterBody2D

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap3-tracing_bullet"]["cooldown_times"]
var damage = trap_data["trap3-tracing_bullet"]["damage"]
var energy_costs = trap_data["trap3-tracing_bullet"]["energy_costs"]
var turn_rate = trap_data["trap3-tracing_bullet"]["turn_rate"]
var wait_time = trap_data["trap3-tracing_bullet"]["wait_time"]
var target: Node2D = null
var speed := 0.0
var tracing := true
var flying := false
var wall_counter := 0
var is_demo := false
var effect_reparented := false
@onready var feather_effect = $FeatherEffect
@onready var leave_wall_detector = $Area2D
@onready var wait_timer = $WaitTimer
@onready var animation = $AnimationPlayer
@onready var sprite = $Seagull


static func initialize(pos: Vector2, dir: Vector2, speed: float) -> Trap3TracingBullet:
	var trap := preload("res://Scenes/traps/trap3-tracing_bullet.tscn").instantiate()
	trap.position = pos
	trap.rotation = dir.angle()
	trap.speed = speed
	trap.target = Global.game_manager.player
	Global.stage.add_child(trap)
	return trap


func _ready() -> void:
	$Seagull.z_index = Util.LAYERS["Trap3TracingBullet/Seagull"]
	$FeatherEffect.z_index = Util.LAYERS["Trap3TracingBullet/FeatherEffect"]
	if is_demo:
		return
	feather_effect.finished.connect(feather_effect.queue_free)
	tracing = true
	set_physics_process(true)
	wait_timer.timeout.connect(_on_wait_timer_out)
	wait_timer.start(wait_time)
	animation.play("spawn")


func _destroy() -> void:
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	await get_tree().create_timer(0.1).timeout
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
		feather_effect.reparent(Global.stage)
		if collision != null:
			var collider := collision.get_collider()
			if collider and collider == target:
				Global.player_hit.emit(damage)
				Audio.play_sfx(Audio.SFX.TRAP3_BULLET_HIT_WALL)
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


#-------------------------


func serialize_state() -> Dictionary:
	return {
		"type": "trap3-tracing_bullet",
		"position": global_position,
		"rotation": rotation,
		"scale": sprite.scale,
		"feather_effect": feather_effect.emitting
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	rotation = data.get("rotation", 0.0)
	sprite.scale = data.get("scale", Vector2.ZERO)
	feather_effect.emitting = data.get("feather_effect", false)
	feather_effect.global_position = global_position
	if !effect_reparented:
		effect_reparented = true
		feather_effect.reparent($"..")
