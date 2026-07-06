class_name Trap1Mine
extends Node2D

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap1-mine"]["cooldown_times"]
var damage = trap_data["trap1-mine"]["damage"]
var energy_costs = trap_data["trap1-mine"]["energy_costs"]
var arming_time = trap_data["trap1-mine"]["arming_time"]
# ▲How long it takes to turn completely red
var area_scale = trap_data["trap1-mine"]["scale"]

var is_armed := false
var isjumping_2_frame_ago := false
var isjumping_1_frame_ago := false
var is_demo := false

@onready var mine_warning: Sprite2D = $MineWarning
@onready var mine_body: Sprite2D = $MineBody
@onready var spawn_particle: GPUParticles2D = $SpawnParticle
@onready var explosion_particle: GPUParticles2D = $ExplosionParticle
@onready var explosion_area: Area2D = $ExplosionArea


static func initialize(pos: Vector2) -> Trap1Mine:
	var trap := preload("res://Scenes/traps/trap1-mine.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.start_arming_sequence()
	return trap


func start_arming_sequence() -> void:
	mine_warning.visible = true
	mine_body.visible = false
	scale = Vector2(area_scale, area_scale)

	await get_tree().create_timer(arming_time).timeout
	on_arming_complete()


func on_arming_complete() -> void:
	spawn_particle.emitting = true
	mine_warning.visible = false
	mine_body.visible = true
	is_armed = true

	mine_body.scale = Vector2(0.3, 0.3)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(mine_body, "scale", Vector2(0.5, 0.5), 0.5)

	# Check if the player is already standing inside the hitbox when arming finishes
	var player = Global.game_manager.player
	if explosion_area.overlaps_body(player) and not player.isjumping:
		disarm()


func explode() -> void:
	Global.player_hit.emit.call_deferred(damage)  #Replace this with the actual damage

	# explode animation
	set_process(false)
	set_physics_process(false)
	mine_body.visible = false
	explosion_particle.emitting = true
	await explosion_particle.finished

	queue_free()


func disarm() -> void:
	queue_free()


func _physics_process(_delta: float) -> void:
	var player = Global.game_manager.player
	if is_armed and explosion_area.overlaps_body(player):
		if isjumping_2_frame_ago and not player.isjumping:
			explode()
		elif not player.isjumping:
			disarm()

	isjumping_2_frame_ago = isjumping_1_frame_ago
	isjumping_1_frame_ago = player.isjumping


func serialize_state() -> Dictionary:
	return {
		"type": "trap1-mine",
		"position": global_position,
		"is_armed": is_armed,
		"body_scale": mine_body.scale.x,
		"spawn_particle_on": spawn_particle.emitting,
		"explosion_particle_on": explosion_particle.emitting,
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	var armed: bool = data.get("is_armed", false)
	if armed:
		mine_warning.visible = false
		mine_body.visible = true
		var sc: float = data.get("body_scale", 0.5)
		mine_body.scale = Vector2(sc, sc)
	else:
		mine_warning.visible = true
		mine_body.visible = false

	if data.get("spawn_particle_on", false) and not spawn_particle.emitting:
		spawn_particle.emitting = true
	if data.get("explosion_particle_on", false) and not explosion_particle.emitting:
		explosion_particle.emitting = true
