class_name Trap1Mine
extends Node2D

var cooldown_times = TrapData.new().data["trap1-mine"]["cooldown_times"]
var damage = TrapData.new().data["trap1-mine"]["damage"]
var energy_costs = TrapData.new().data["trap1-mine"]["energy_costs"]
var arming_time = TrapData.new().data["trap1-mine"]["arming_time"]
# ▲How long it takes to turn completely red

var is_armed := false
var isjumping_2_frame_ago := false
var isjumping_1_frame_ago := false
var animation_time = 0

@onready var mine_body: Sprite2D = $MineBody
@onready var explosion_particle: GPUParticles2D = $ExplosionParticle
@onready var explosion_area: Area2D = $ExplosionArea


static func initialize(pos: Vector2) -> Trap1Mine:
	var trap := preload("res://Scenes/traps/trap1-mine.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.start_arming_sequence()
	return trap


func start_arming_sequence() -> void:
	var tween = create_tween()

	mine_body.material.set_shader_parameter("progress", 0.0)
	mine_body.material.set_shader_parameter("radar_mul", 0.0)
	tween.tween_property(mine_body.material, "shader_parameter/progress", 1.0, arming_time)
	tween.tween_callback(on_arming_complete)


func on_arming_complete() -> void:
	is_armed = true
	mine_body.material.set_shader_parameter("radar_mul", 1.0)

	# Check if the player is already standing inside the hitbox when arming finishes
	var player = Global.game_manager.player
	if explosion_area.overlaps_body(player) and not player.isjumping:
		disarm()


func explode() -> void:
	print("BOOM! Player landed on the mine trap!")
	Global.player_hit.emit.call_deferred(damage)  #Replace this with the actual damage
	explosion_particle.emitting = true
	await get_tree().create_timer(explosion_particle.lifetime).timeout
	queue_free()


func disarm() -> void:
	print("Player disarmed the mine trap!")
	queue_free()


func _physics_process(delta: float) -> void:
	var player = Global.game_manager.player
	if is_armed and explosion_area.overlaps_body(player):
		if isjumping_2_frame_ago and not player.isjumping:
			explode()
		elif not player.isjumping:
			disarm()

	isjumping_2_frame_ago = isjumping_1_frame_ago
	isjumping_1_frame_ago = player.isjumping
