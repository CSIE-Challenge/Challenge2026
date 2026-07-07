class_name Trap4Conveyor
extends Area2D

static var current_conveyor: Trap4Conveyor = null

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap4-conveyor"]["cooldown_times"]
var damage = trap_data["trap4-conveyor"]["damage"]
var energy_costs = trap_data["trap4-conveyor"]["energy_costs"]
var speed = trap_data["trap4-conveyor"]["speed"]
var lifetime = trap_data["trap4-conveyor"]["lifetime"]
var area_scale = trap_data["trap4-conveyor"]["scale"]
var direction: Vector2
var is_demo: bool = false
var _is_disappearing: bool = false

@onready var wave_animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


static func initialize(pos: Vector2, dir: Vector2) -> Trap4Conveyor:
	if current_conveyor != null and is_instance_valid(current_conveyor):
		current_conveyor._destroy_trap()
	var trap := preload("res://Scenes/traps/trap4-conveyor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.direction = dir.normalized()
	trap.rotation = trap.direction.angle() - PI / 2

	current_conveyor = trap

	trap.play_spawn()

	return trap


func _ready() -> void:
	$AnimatedSprite2D.z_index = Util.LAYERS["Trap4Conveyor/AnimatedSprite2D"]
	# Trap should expire after the configured lifetime.
	if is_demo:
		return
	scale = Vector2(area_scale, area_scale)
	await get_tree().create_timer(lifetime).timeout
	var rectshape = collision_shape.shape as RectangleShape2D
	var tween = create_tween()  #despawn animation
	tween.set_parallel(true)
	tween.tween_property(wave_animation.material, "shader_parameter/reverse_reveal", 0.0, 0.5)
	tween.tween_property(rectshape, "size", Vector2(100, 0), 0.5)
	tween.tween_property(collision_shape, "position", Vector2(75, 0), 0.5)
	await tween.finished
	_destroy_trap()


func play_spawn():
	wave_animation.material.set_shader_parameter("reveal", 0.0)
	wave_animation.material.set_shader_parameter("reverse_reveal", 1.0)
	var rect_shape = collision_shape.shape as RectangleShape2D
	rect_shape.size = Vector2(100, 0)
	collision_shape.position = Vector2(0, -75)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave_animation.material, "shader_parameter/reveal", 1.0, 0.5)
	tween.tween_property(rect_shape, "size", Vector2(100, 100), 0.5)
	tween.tween_property(collision_shape, "position", Vector2(0, 0), 0.5)


func _destroy_trap() -> void:
	if not is_inside_tree():
		return
	if current_conveyor == self:
		current_conveyor = null

	_is_disappearing = true
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity += speed * direction


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player and body is CharacterBody2D:
		body.external_velocity -= speed * direction


#-----------------------------------------
func serialize_state() -> Dictionary:
	return {
		"type": "trap4-conveyor",
		"position": global_position,
		"rotation": rotation,
		"scale": scale,
		"shader_reveal": wave_animation.material.get_shader_parameter("reveal"),
		"shader_reverse_reveal": wave_animation.material.get_shader_parameter("reverse_reveal")
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	rotation = data.get("rotation", 0.0)
	wave_animation.material.set_shader_parameter("reveal", data.get("shader_reveal", 1.0))
	scale = data.get("scale", Vector2.ZERO)
	wave_animation.material.set_shader_parameter(
		"reverse_reveal", data.get("shader_reverse_reveal", 1.0)
	)
