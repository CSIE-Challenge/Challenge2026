class_name Trap4Conveyor
extends Area2D

static var current_conveyor: Trap4Conveyor = null

var cooldown_times = TrapData.new().data["trap4-conveyor"]["cooldown_times"]
var damage = TrapData.new().data["trap4-conveyor"]["damage"]
var energy_costs = TrapData.new().data["trap4-conveyor"]["energy_costs"]
var speed = TrapData.new().data["trap4-conveyor"]["speed"]
var lifetime = TrapData.new().data["trap4-conveyor"]["lifetime"]
var direction: Vector2
var _is_disappearing: bool = false

@onready var wave_animation: AnimatedSprite2D = $AnimatedSprite2D


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
	# Trap should expire after the configured lifetime.
	await get_tree().create_timer(lifetime).timeout
	_destroy_trap()


func play_spawn():
	wave_animation.material.set_shader_parameter("reveal", 0.0)

	var tween = create_tween()
	tween.tween_property(wave_animation.material, "shader_parameter/reveal", 1.0, 0.5)


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
