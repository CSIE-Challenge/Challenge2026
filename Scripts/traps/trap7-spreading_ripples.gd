class_name Trap7SpreadingRipples
extends Area2D

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap7-spreading_ripples"]["cooldown_times"]
var damage = trap_data["trap7-spreading_ripples"]["damage"]
var energy_costs = trap_data["trap7-spreading_ripples"]["energy_costs"]
var warning_time = trap_data["trap7-spreading_ripples"]["warning_time"]
var max_radius = trap_data["trap7-spreading_ripples"]["max_radius"]
var ring_thickness = trap_data["trap7-spreading_ripples"]["ring_thickness"]

var white_ripple_thickness: float
var current_expand_rate: float = 7.0
var white_ripple_oscil_freq: float = 10.0
var time := 0.0
var is_demo := false
var is_expanding: bool = false
var collision_shape: CircleShape2D

@onready var warning_sprite: Sprite2D = $WarningSprite
@onready var water_particle = $WaterParticles


static func initialize(pos: Vector2, expand_rate: float) -> Trap7SpreadingRipples:
	var trap := preload("res://Scenes/traps/trap7-spreading_ripples.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(pos, expand_rate)
	return trap


func _ready() -> void:
	warning_sprite.position = Vector2.ZERO
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	collision_shape = $CollisionShape2D.shape
	collision_shape.radius = 0.0
	if is_demo:
		return
	visible = false
	monitoring = false


func activate(spawn_position: Vector2, expand_rate: float) -> void:
	position = spawn_position
	current_expand_rate = expand_rate
	visible = true
	monitoring = false

	warning_sprite.visible = true

	await get_tree().create_timer(warning_time).timeout
	_start_ripple_expansion()


func deactivate() -> void:
	queue_free()


func _start_ripple_expansion() -> void:
	warning_sprite.visible = false
	monitoring = true
	is_expanding = true
	water_particle.emitting = true


func _physics_process(delta: float) -> void:
	time += delta
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
		white_ripple_thickness = (
			0.8 * ring_thickness + sin(time * white_ripple_oscil_freq) * ring_thickness * 0.2
		)
	else:
		warning_sprite.modulate.a = abs(sin(time * 5.0)) + 0.2
		white_ripple_thickness = (
			0.8 * ring_thickness + sin(time * white_ripple_oscil_freq) * ring_thickness * 0.2
		)
	queue_redraw()
	water_particle.amount_ratio = collision_shape.radius / max_radius * 1.2
	water_particle.process_material.emission_ring_radius = collision_shape.radius
	water_particle.process_material.emission_ring_inner_radius = collision_shape.radius


func _draw():
	draw_arc(
		Vector2.ZERO,
		collision_shape.radius,
		0,
		PI * 2,
		120,
		Color(0.338, 0.419, 0.836, 1.0),
		ring_thickness,
		true
	)
	draw_arc(
		Vector2.ZERO,
		collision_shape.radius + white_ripple_thickness,
		0,
		PI * 2,
		120,
		Color(1.0, 1.0, 1.0, 1.0),
		white_ripple_thickness,
		true
	)


#--------------------------------------------
func serialize_state() -> Dictionary:
	return {
		"type": "trap7-spreading_ripples",
		"position": global_position,
		"radius": collision_shape.radius,
		"white_ripple_thickness": white_ripple_thickness,
		"warning_visibility": warning_sprite.visible,
		"warning_a": warning_sprite.modulate.a,
		"particle_emitting": water_particle.emitting,
		"particle_amount": water_particle.amount_ratio,
		"particle_radius": water_particle.process_material.emission_ring_radius
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	collision_shape.radius = data.get("radius", 0.0)
	white_ripple_thickness = data.get("white_ripple_thickness", 0.0)
	warning_sprite.visible = data.get("warning_visibility", false)
	warning_sprite.modulate.a = data.get("warning_a", 0.0)
	water_particle.emitting = data.get("particle_emitting", false)
	water_particle.amount_ratio = data.get("particle_amount", 0.0)
	water_particle.process_material.emission_ring_radius = data.get("particle_radius", 0.0)
	water_particle.process_material.emission_ring_inner_radius = (
		water_particle.process_material.emission_ring_radius
	)
	queue_redraw()
