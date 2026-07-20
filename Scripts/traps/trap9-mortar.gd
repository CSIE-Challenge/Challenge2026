class_name Trap9Mortar
extends Node2D

@export var shell_rotate_speed: float = 20.0
@export var shadow_flicker_frequency: float = 1

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap9-mortar"]["cooldown_times"]
var damage = trap_data["trap9-mortar"]["damage"]
var energy_costs = trap_data["trap9-mortar"]["energy_costs"]
var max_height = trap_data["trap9-mortar"]["max_height"]
var gravity = trap_data["trap9-mortar"]["gravity"]
var explosion_max_radius = trap_data["trap9-mortar"]["explosion_max_radius"]
var explosion_expand_speed = trap_data["trap9-mortar"]["explosion_expand_speed"]
var stay_time = trap_data["trap9-mortar"]["stay_time"]

var player: CharacterBody2D
var start_pos: Vector2
var end_pos: Vector2
var velocity: Vector2

var air_time: float = 2.0
var elapsed: float = 0.0

var flying: bool = false

var exploding: bool = false
var explosion_radius: float = 0.0
var shell_vertical_speed: float = 0.0
var my_shell_rotate_speed: float
var is_demo := false
var demo_shell: Sprite2D
var demo_shadow: Sprite2D

@onready var shell: Sprite2D = $ShellShadow/Shell
@onready var shell_shadow: Node2D = $ShellShadow
@onready var shadow: Sprite2D = $ShellShadow/Shadow
@onready var explosion: Sprite2D = $Explosion
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var effect: GPUParticles2D = $Explosion/GPUParticles2D
@onready var remote_shell: RemoteTransform2D = $ShellShadow/Remote


func _ready() -> void:
	_setup_layers()
	if is_demo:
		_setup_demo_display()
		return
	_reparent_shell_to_high_stage()


func _exit_tree() -> void:
	if is_instance_valid(shell) and shell.get_parent() != shell_shadow:
		if not shell.is_queued_for_deletion():
			shell.queue_free()


func _setup_layers() -> void:
	shell.z_index = Util.LAYERS["Trap9Mortar/Shell"]
	shadow.z_index = Util.LAYERS["Trap9Mortar/Shadow"]
	explosion.z_index = Util.LAYERS["Trap9Mortar/Explosion"]


func _reparent_shell_to_high_stage() -> void:
	if Global.high_stage and shell.get_parent() != Global.high_stage:
		shell.reparent(Global.high_stage)


func _setup_demo_display() -> void:
	shell_shadow.visible = false
	shell.visible = false
	shadow.visible = false


func _create_demo_sprite(sprite_name: String, source: Sprite2D, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = source.texture
	sprite.scale = source.scale
	sprite.centered = source.centered
	sprite.offset = source.offset
	sprite.top_level = true
	sprite.z_as_relative = false
	sprite.z_index = layer
	sprite.visible = false
	add_child(sprite)
	return sprite


func _ensure_demo_visuals() -> void:
	if not is_instance_valid(demo_shadow):
		demo_shadow = _create_demo_sprite(
			"DemoMortarShadow", shadow, Util.LAYERS["Trap9Mortar/Shadow"]
		)
	if not is_instance_valid(demo_shell):
		demo_shell = _create_demo_sprite("DemoMortarShell", shell, Util.LAYERS["Trap9Mortar/Shell"])


func _apply_demo_visuals(
	data: Dictionary,
	shadow_position: Vector2,
	shell_position: Vector2,
	shell_rotation: float,
	explosion_visible: bool
) -> void:
	_ensure_demo_visuals()
	_setup_demo_display()

	var show_shadow: bool = data.get("shadow_visible", not explosion_visible)
	show_shadow = show_shadow and data.get("shell_shadow_visible", not explosion_visible)
	show_shadow = show_shadow and not explosion_visible
	var show_shell: bool = data.get("shell_visible", not explosion_visible)
	show_shell = show_shell and not explosion_visible

	demo_shadow.global_position = shadow_position
	demo_shadow.rotation = shell_rotation
	demo_shadow.self_modulate = data.get("shadow_modulate", Color.BLACK)
	demo_shadow.visible = show_shadow

	demo_shell.global_position = shell_position
	demo_shell.rotation = shell_rotation
	demo_shell.self_modulate = Color.WHITE
	demo_shell.visible = show_shell


static func initialize(start_pos: Vector2, end_pos: Vector2, air_time: float) -> Trap9Mortar:
	var trap := preload("res://Scenes/traps/trap9-mortar.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(start_pos, end_pos, air_time)
	return trap


func _physics_process(delta: float) -> void:
	if flying:
		elapsed += delta
		shell_shadow.position += velocity * delta
		remote_shell.position.y += shell_vertical_speed * delta
		shell_vertical_speed += gravity * delta
		remote_shell.rotation += my_shell_rotate_speed * delta
		shadow.rotation = remote_shell.rotation
		shadow.self_modulate.r = 0.5 + 0.5 * sin(elapsed * shadow_flicker_frequency)
		if elapsed >= air_time:
			explode()

	if exploding:
		elapsed += delta
		for body in explosion_area.get_overlapping_bodies():
			if body == Global.game_manager.player:
				Global.player_hit.emit(damage)
		if elapsed >= air_time + stay_time:
			exploding = false
			explosion_area.monitoring = false
			_fade_out()


func activate(
	initial_position: Vector2,
	final_position: Vector2,
	flight_time: float,
) -> void:
	start_pos = initial_position
	end_pos = final_position
	air_time = flight_time

	elapsed = 0.0
	flying = true
	exploding = false
	explosion_area.monitoring = false

	explosion.visible = false
	effect.lifetime = stay_time

	remote_shell.position = Vector2.ZERO
	shell_shadow.position = start_pos
	velocity.x = (end_pos.x - start_pos.x) / air_time
	velocity.y = (end_pos.y - start_pos.y) / air_time
	shell_vertical_speed = gravity * air_time / -2
	my_shell_rotate_speed = shell_rotate_speed * randf_range(0.7, 1.3) * sign(randf_range(-1, 1))


func explode() -> void:
	flying = false

	shell.visible = false
	shadow.visible = false

	var circle := explosion_shape.shape as CircleShape2D
	circle.radius = explosion_max_radius
	explosion_area.monitoring = true

	var effect = explosion.get_node("GPUParticles2D") as GPUParticles2D
	effect.emitting = true
	exploding = true
	explosion_radius = 0.0
	explosion.visible = true
	explosion.rotation = randf_range(0, TAU)

	position = end_pos

	Audio.play_sfx(Audio.SFX.TRAP9_WATERMELON_FALL)


func _fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), stay_time / 2.5)
	await tween.finished
	queue_free()


#--------------------------------------
func serialize_state() -> Dictionary:
	return {
		"type": "trap9-mortar",
		"position": global_position,
		"shadow_position": shell_shadow.global_position,
		"demo_shell_position": shell_shadow.global_position + Vector2(0.0, remote_shell.position.y),
		"shell_y": remote_shell.position.y,
		"shell_rotation": remote_shell.rotation,
		"shadow_modulate": shadow.self_modulate,
		"shadow_visible": shadow.visible,
		"shell_visible": shell.visible,
		"shell_shadow_visible": shell_shadow.visible,
		"explosion_visibility": explosion.visible,
		"modulate": modulate,
		"particle_emitting": effect.emitting
	}


func apply_demo_state(data: Dictionary) -> void:
	var shadow_position: Vector2 = data.get("shadow_position", Vector2.ZERO)
	var shell_position: Vector2 = data.get(
		"demo_shell_position", shadow_position + Vector2(0.0, data.get("shell_y", 0.0))
	)
	var shell_rotation: float = data.get("shell_rotation", 0.0)
	var explosion_visible: bool = data.get("explosion_visibility", false)

	global_position = data.get("position", Vector2.ZERO)
	explosion.visible = explosion_visible
	modulate = data.get("modulate", Color.WHITE)
	effect.emitting = data.get("particle_emitting", false)

	if is_demo:
		_apply_demo_visuals(
			data, shadow_position, shell_position, shell_rotation, explosion_visible
		)
		return

	shell_shadow.global_position = shadow_position
	shell.global_position = shell_position
	shell.rotation = shell_rotation
	shadow.rotation = shell_rotation
	shadow.self_modulate = data.get("shadow_modulate", Color.BLACK)
	shell_shadow.visible = data.get("shell_shadow_visible", not explosion_visible)
	shadow.visible = data.get("shadow_visible", not explosion_visible)
	shell.visible = data.get("shell_visible", not explosion_visible)
