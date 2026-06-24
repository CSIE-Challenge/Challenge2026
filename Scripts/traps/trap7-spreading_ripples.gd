class_name Trap7SpreadingRipples
extends Area2D

@export var warning_time: float = 1.5
@export var max_radius: float = 1000.0
@export var damage: int = 10
@export var ring_thickness: float = 10.0

var current_expand_rate: float = 10.0
var is_expanding: bool = false
var _data: Dictionary = Global.trap_data["trap7-spreading_ripples"]

@onready var warning_sprite: Sprite2D = $WarningSprite
@onready var ripple_sprite: Sprite2D = $RippleSprite
@onready var collision_shape: CircleShape2D = $CollisionShape2D.shape


static func initialize(pos: Vector2, expand_rate: float) -> Trap7SpreadingRipples:
	var trap := preload("res://Scenes/traps/trap7-spreading_ripples.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(pos, expand_rate)
	return trap


func _ready() -> void:
	visible = false
	monitoring = false
	warning_sprite.position = Vector2.ZERO
	collision_shape.radius = 0.0


func activate(spawn_position: Vector2, expand_rate: float) -> void:
	position = spawn_position
	current_expand_rate = expand_rate
	visible = true
	monitoring = false

	warning_sprite.visible = true
	ripple_sprite.visible = false
	ripple_sprite.scale = Vector2.ZERO

	await get_tree().create_timer(warning_time).timeout
	_start_ripple_expansion()


func deactivate() -> void:
	queue_free()


func _start_ripple_expansion() -> void:
	warning_sprite.visible = false
	ripple_sprite.visible = true
	monitoring = true
	is_expanding = true


func _process(delta: float) -> void:
	if is_expanding and monitoring:
		collision_shape.radius += current_expand_rate * delta
		for body in get_overlapping_bodies():
			if body == Global.game_manager.player:
				var distance = global_position.distance_to(body.global_position)
				if abs(distance - collision_shape.radius) <= (ring_thickness / 2):
					Global.player_hit.emit(damage)

		if collision_shape.radius >= max_radius:
			is_expanding = false
			deactivate()
	queue_redraw()


func _draw():
	draw_arc(
		Vector2.ZERO,
		collision_shape.radius,
		0,
		PI * 2,
		120,
		Color(0.74, 0.3, 0.3),
		ring_thickness,
		true
	)
