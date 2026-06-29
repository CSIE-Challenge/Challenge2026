class_name Trap8ElectricArc
extends Node2D

@export var points_radius: int = 10
@export var points_default_scale: Vector2 = Vector2(0.15, 0.15)
@export var points_revolution_speed: float = 8
@export var arc_width: float = 5.0
@export var scaling_rate: float = 10
@export var player_radius: float = 5
@export var delay_time: float = 2.0
@export var duration_time: float = 5

var points_scale: Vector2
var points_assigned_scale: Vector2
var arc_assigned_width: float
var arc_on: bool

@onready var player: CharacterBody2D = $"../Player"
@onready var crack: Sprite2D = $Crack
@onready var start_point: Node2D = $StartPoint
@onready var end_point: Node2D = $EndPoint
@onready var start_cone: Sprite2D = $StartPoint/Cone
@onready var end_cone: Sprite2D = $EndPoint/Cone
@onready var raycast = $RayCast2D


static func initialize(start_pos: Vector2, end_pos: Vector2) -> Trap8ElectricArc:
	var trap := preload("res://Scenes/traps/trap8-electric_arc.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.spawn(start_pos, end_pos)
	return trap


func _ready():
	arc_on = false
	_set_state(0)


func _physics_process(_delta: float) -> void:
	_detect_player()


func spawn(start_position: Vector2, end_position: Vector2) -> void:
	# position set-up
	start_point.position = start_position
	end_point.position = end_position
	crack.position = start_position
	raycast.position = start_position
	raycast.target_position = end_position - start_position

	var dir = end_position - start_position
	var ratio = dir.length() / crack.texture.get_height()
	var width = clamp(ratio, 0.3, 0.75)

	crack.rotation = dir.angle() - PI / 2
	crack.apply_scale(Vector2(width, ratio))

	# warning phase
	arc_assigned_width = arc_width
	_spawn_animation()
	_set_state(1)
	await get_tree().create_timer(delay_time).timeout

	# activated phase
	arc_on = true
	_activate_animation()
	_set_state(2)
	await get_tree().create_timer(duration_time).timeout

	# despawn phase
	points_assigned_scale = Vector2.ZERO
	arc_assigned_width = 0
	arc_on = false
	_despawn_animation()
	await get_tree().create_timer(0.2).timeout
	_set_state(0)
	queue_free()


func _spawn_animation() -> void:
	# start cone
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING).set_parallel()

	start_cone.self_modulate.a = 0.0
	start_cone.position = Vector2(5, -8)
	start_cone.rotation_degrees = 20

	tween.tween_property(start_cone, "self_modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(start_cone, "position", Vector2.ZERO, 0.5)
	tween.tween_property(start_cone, "rotation_degrees", 0, 0.5)

	# end cone
	end_cone.self_modulate.a = 0.0
	end_cone.position = Vector2(5, -8)
	end_cone.rotation_degrees = 20

	tween.tween_property(end_cone, "self_modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(end_cone, "position", Vector2.ZERO, 0.5)
	tween.tween_property(end_cone, "rotation_degrees", 0, 0.5)

	# crack
	crack.material.set_shader_parameter("progress", 0.0)
	tween.tween_property(crack.material, "shader_parameter/progress", 0.2, delay_time).set_trans(
		Tween.TRANS_LINEAR
	)


func _activate_animation():
	var tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(crack.material, "shader_parameter/progress", 1.0, 1.0)


func _despawn_animation():
	var tween = create_tween().set_parallel()
	tween.tween_property(crack.material, "shader_parameter/progress", 0.0, 0.2)
	tween.tween_property(start_cone, "self_modulate:a", 0.0, 0.2)
	tween.tween_property(end_cone, "self_modulate:a", 0.0, 0.2)


func _set_state(mode: int) -> void:
	match mode:
		0:  # invisible
			start_cone.visible = false
			end_cone.visible = false
		1:  # warning
			start_cone.visible = true
			end_cone.visible = true
		2:  # activated
			start_cone.visible = true
			end_cone.visible = true


func _detect_player() -> void:
	if not arc_on:
		return
	if raycast.is_colliding():
		Global.player_hit.emit(5)
