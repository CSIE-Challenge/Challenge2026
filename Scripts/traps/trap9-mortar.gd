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

@onready var shell: Sprite2D = $ShellShadow/Shell
@onready var shell_shadow: Node2D = $ShellShadow
@onready var shadow: Sprite2D = $ShellShadow/Shadow
@onready var explosion: Sprite2D = $Explosion
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D
@onready var effect: GPUParticles2D = $Explosion/GPUParticles2D
@onready var remote_shell: RemoteTransform2D = $ShellShadow/Remote


func _ready() -> void:
	if is_demo:
		return
	$ShellShadow/Shell.z_index = Util.LAYERS["Trap9Mortar/Shell"]
	$ShellShadow/Shadow.z_index = Util.LAYERS["Trap9Mortar/Shadow"]
	$Explosion.z_index = Util.LAYERS["Trap9Mortar/Explosion"]
	shell.reparent(Global.high_stage)


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
		"shell_y": remote_shell.position.y,
		"shell_rotation": remote_shell.rotation,
		"shadow_modulate": shadow.self_modulate,
		"explosion_visibility": explosion.visible,
		"modulate": modulate,
		"particle_emitting": effect.emitting
	}


func apply_demo_state(data: Dictionary) -> void:
	shell_shadow.global_position = data.get("shadow_position", Vector2.ZERO)
	global_position = data.get("position", Vector2.ZERO)
	shell.position.y = data.get("shell_y", 0.0)
	shell.rotation = data.get("shell_rotation", 0.0)
	shadow.rotation = shell.rotation
	shadow.self_modulate = data.get("shadow_modulate", Color.BLACK)
	explosion.visible = data.get("explosion_visibility", false)
	shell_shadow.visible = !explosion.visible
	modulate = data.get("modulate", Color.WHITE)
	effect.emitting = data.get("particle_emitting", false)
