extends Node2D
const ZERO_VECTOR = Vector2(0, 0)
var points_standard_scale: Vector2 = Vector2(0.15, 0.15)
var points_revolution_speed: float = 8
var arc_standard_width: float = 5.0
var scaling_rate: float = 10
var points_scale: Vector2
var points_assigned_scale: Vector2
var arc_assigned_width: float
@onready var start_point: Node2D = $start_point
@onready var end_point: Node2D = $end_point
@onready var start_point_sprite: Sprite2D = $start_point/sprite
@onready var end_point_sprite: Sprite2D = $end_point/sprite
@onready var arc: Line2D = $arc


func _ready():
	_build_arc()
	_visible_set(0)
	_spawn(Vector2(_randx(), _randy()), Vector2(_randx(), _randy()), 2.0, 3.0)


func _build_arc() -> void:
	arc.add_point(ZERO_VECTOR, 0)
	arc.add_point(ZERO_VECTOR, 1)
	arc.width = 4.0


func _randx() -> float:
	return randf_range(0, 1152)


func _randy() -> float:
	return randf_range(0, 648)


func _physics_process(delta: float) -> void:
	_points_rotate(delta)
	_scaling(delta)


func _points_rotate(delta: float):
	start_point.global_rotation += points_revolution_speed * delta
	end_point.global_rotation += -points_revolution_speed * delta


func _scaling(delta: float) -> void:
	points_scale += (points_assigned_scale - points_scale) * scaling_rate * delta
	start_point_sprite.scale = points_scale
	end_point_sprite.scale = points_scale
	arc.width += (arc_assigned_width - arc.width) * scaling_rate * delta


func _spawn(
	start_position: Vector2, end_position: Vector2, delay_time: float, duration_time: float
) -> void:
	start_point.global_position = start_position
	end_point.global_position = end_position
	arc.set_point_position(0, start_position)
	arc.set_point_position(1, end_position)
	points_scale = ZERO_VECTOR
	points_assigned_scale = points_standard_scale
	arc.width = 0
	arc_assigned_width = arc_standard_width

	_visible_set(1)
	await get_tree().create_timer(delay_time).timeout

	_visible_set(2)
	await get_tree().create_timer(duration_time).timeout

	points_assigned_scale = ZERO_VECTOR
	arc_assigned_width = 0
	await get_tree().create_timer(0.5).timeout
	_visible_set(0)


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
