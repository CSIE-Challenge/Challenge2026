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
var _data = Global.trap_data["trap8-electric_arc"]

@onready var player: CharacterBody2D = $"../Player"
@onready var start_point: Node2D = $start_point
@onready var end_point: Node2D = $end_point
@onready var start_point_sprite: Sprite2D = $start_point/sprite
@onready var end_point_sprite: Sprite2D = $end_point/sprite
@onready var arc: Line2D = $arc


static func initialize(start_pos: Vector2, end_pos: Vector2) -> Trap8ElectricArc:
	var trap := preload("res://Scenes/traps/trap8-electric_arc.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.spawn(start_pos, end_pos)
	return trap


func _ready():
	arc_on = false
	arc.position = Vector2.ZERO
	_build_arc()
	_visible_set(0)


func _build_arc() -> void:
	arc.add_point(Vector2.ZERO, 0)
	arc.add_point(Vector2.ZERO, 1)
	arc.width = 4.0


func _randx() -> float:
	return randf_range(326, 826)


func _randy() -> float:
	return randf_range(74, 574)


func _physics_process(delta: float) -> void:
	_points_rotate(delta)
	_scaling(delta)
	_detect_player()


func _points_rotate(delta: float):
	start_point.global_rotation += points_revolution_speed * delta
	end_point.global_rotation += -points_revolution_speed * delta


func _scaling(delta: float) -> void:
	points_scale += (points_assigned_scale - points_scale) * scaling_rate * delta
	start_point_sprite.scale = points_scale
	end_point_sprite.scale = points_scale
	arc.width += (arc_assigned_width - arc.width) * scaling_rate * delta


func spawn(start_position: Vector2, end_position: Vector2) -> void:
	start_point.position = start_position
	end_point.position = end_position
	arc.set_point_position(0, start_position)
	arc.set_point_position(1, end_position)
	points_scale = Vector2.ZERO
	points_assigned_scale = points_default_scale
	arc.width = 0
	arc_assigned_width = arc_width

	_visible_set(1)
	await get_tree().create_timer(delay_time).timeout

	_visible_set(2)
	arc_on = true
	await get_tree().create_timer(duration_time).timeout

	points_assigned_scale = Vector2.ZERO
	arc_assigned_width = 0
	arc_on = false
	await get_tree().create_timer(0.5).timeout
	_visible_set(0)
	queue_free()


func _visible_set(mode: int) -> void:
	# 0 = invisible, 1 = warning, 2 = actived
	start_point_sprite.visible = (mode > 0)
	end_point_sprite.visible = (mode > 0)
	arc.visible = (mode > 0)
	if mode == 2:
		start_point_sprite.modulate = Color(1.0, 0.0, 0.0, 1.0)
		end_point_sprite.modulate = Color(1.0, 0.0, 0.0, 1.0)
		arc.modulate = Color(1.0, 0.0, 0.0, 1.0)
	else:
		start_point_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		end_point_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		arc.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _detect_player() -> void:
	if not arc_on:
		return
	var vector_start_to_end = end_point.global_position - start_point.global_position
	var vector_start_to_player = player.global_position - start_point.global_position
	var vector_end_to_player = player.global_position - end_point.global_position
	var dist = abs(
		(vector_start_to_end.cross(vector_start_to_player)) / vector_start_to_end.length()
	)
	if (
		(
			dist <= player_radius + arc_width
			and vector_start_to_player.dot(vector_start_to_end) >= 0
			and vector_end_to_player.dot(-vector_start_to_end) >= 0
		)
		or vector_start_to_player.length() <= player_radius + points_radius
		or vector_end_to_player.length() <= player_radius + points_radius
	):
		Global.player_hit.emit(5)
