class_name Trap8ElectricArc
extends Node2D

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap8-electric_arc"]["cooldown_times"]
var damage = trap_data["trap8-electric_arc"]["damage"]
var energy_costs = trap_data["trap8-electric_arc"]["energy_costs"]
var points_radius = trap_data["trap8-electric_arc"]["points_radius"]
var points_default_scale_array = trap_data["trap8-electric_arc"]["points_default_scale"]
var points_default_scale = Vector2(points_default_scale_array[0], points_default_scale_array[1])
var points_revolution_speed = trap_data["trap8-electric_arc"]["points_revolution_speed"]
var arc_width = trap_data["trap8-electric_arc"]["arc_width"]
var scaling_rate = trap_data["trap8-electric_arc"]["scaling_rate"]
var player_radius = trap_data["trap8-electric_arc"]["player_radius"]
var delay_time = trap_data["trap8-electric_arc"]["delay_time"]
var duration_time = trap_data["trap8-electric_arc"]["duration_time"]

var points_scale: Vector2
var points_assigned_scale: Vector2
var arc_assigned_width: float
var arc_on: bool
var activated: bool
var is_demo := false

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
	$Crack.z_index = Util.LAYERS["Trap8ElectricArc/Crack"]
	$StartPoint/Cone.z_index = Util.LAYERS["Trap8ElectricArc/Cone"]
	$EndPoint/Cone.z_index = Util.LAYERS["Trap8ElectricArc/Cone"]
	if is_demo:
		return
	activated = false
	visible = false


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
	_spawn_animation()
	visible = true
	await get_tree().create_timer(delay_time).timeout

	# activated phase
	activated = true
	_activate_animation()
	await get_tree().create_timer(duration_time).timeout

	# despawn phase
	activated = false
	_despawn_animation()
	await get_tree().create_timer(0.2).timeout

	visible = false
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


func _detect_player() -> void:
	if not activated:
		return
	if raycast.is_colliding():
		Global.player_hit.emit(damage)


func serialize_state() -> Dictionary:
	return {
		"type": "trap8-electric_arc",
		"start_pos": start_point.position,
		"end_pos": end_point.position,
		"visible": visible,
		"crack_rot": crack.rotation,
		"crack_scale": crack.scale,
		"crack_progress": crack.material.get_shader_parameter("progress"),
		"cone_s_alpha": start_cone.self_modulate.a,
		"cone_s_pos": start_cone.position,
		"cone_s_rot": start_cone.rotation_degrees,
		"cone_e_alpha": end_cone.self_modulate.a,
		"cone_e_pos": end_cone.position,
		"cone_e_rot": end_cone.rotation_degrees,
	}


func apply_demo_state(data: Dictionary) -> void:
	var start_pos: Vector2 = data.get("start_pos", Vector2.ZERO)
	var end_pos: Vector2 = data.get("end_pos", Vector2.ZERO)
	start_point.position = start_pos
	end_point.position = end_pos
	crack.position = start_pos

	crack.rotation = data.get("crack_rot", 0.0)
	crack.scale = data.get("crack_scale", Vector2.ONE)
	crack.material.set_shader_parameter("progress", data.get("crack_progress", 0.0))

	start_cone.self_modulate.a = data.get("cone_s_alpha", 0.0)
	start_cone.position = data.get("cone_s_pos", Vector2(5, -8))
	start_cone.rotation_degrees = data.get("cone_s_rot", 20.0)

	end_cone.self_modulate.a = data.get("cone_e_alpha", 0.0)
	end_cone.position = data.get("cone_e_pos", Vector2(5, -8))
	end_cone.rotation_degrees = data.get("cone_e_rot", 20.0)

	visible = data.get("visible", false)
