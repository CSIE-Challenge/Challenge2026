class_name Player
extends CharacterBody2D

const DRIFT_REQUIREMENT = 1
const DRIFT_SKIN_ID = "default_skin"  # change to the driftwood skin

@export var health: int
@export var sand_particle: GradientTexture1D
@export var water_particle: GradientTexture1D
@export var juice_particle: GradientTexture1D
@export var stage_layer: CanvasLayer
@export var high_stage: Node2D

var acceleration := 100.0
var move_speed := 300.0
var jump_velocity := 750.0
var jump_gravity := 2500.0
var jump_fall_multiplier := 1.5
var max_health := 100
var invincibility_flicker_period := 8

var isjumping := false
var current_jump_velocity: float
var current_sprite_y: float
var external_velocity: Vector2 = Vector2.ZERO
var isinvincible := false
var jump_count := 0
var distance_traveled := 0.0
var all_sand_tiles: Array[Vector2i] = []
var last_stepped_cell = Vector2i(-1, -1)
var skin_instance: Node2D = null
var is_in_water := false
var juice_count := 0
var skin_id: String = ""
var pressed_move: bool = false

@onready var body_sprite = $BodySprite
@onready var shadow_sprite = $ShadowSprite
@onready var sand_tilemap = $"../../../BackGroundLayer/SandTileMap"
@onready var walk_particle = $WalkParticle
@onready var jump_particle = $JumpParticle
@onready var land_particle = $LandParticle
@onready var remote_land_particle = $RemoteTransform2D
@onready var trap_cleaner = $TrapCleaner


func update_skin() -> void:
	var new_skin_id = (
		Global.skin_override if Global.skin_override != "" else PlayerData.equipped_skin
	)
	if new_skin_id == skin_id:
		return
	skin_id = new_skin_id
	var new_skin_path = "res://Assets/skins/" + new_skin_id + ".tres"
	var new_skin_data = load(new_skin_path)
	var new_skin_instance: Node2D = null
	if new_skin_data and new_skin_data.skin_prefab:
		new_skin_instance = new_skin_data.skin_prefab.instantiate()
		new_skin_instance.z_index = 1
		new_skin_instance.set_meta("player", self)
		stage_layer.add_child.call_deferred(new_skin_instance)
		body_sprite.hide()
		if is_instance_valid(skin_instance):
			new_skin_instance.global_position = skin_instance.global_position
			skin_instance.modulate.a = modulate.a
			skin_instance.queue_free()
		skin_instance = new_skin_instance
		if skin_instance.has_method("play_spawn"):
			if not skin_instance.is_node_ready():
				await skin_instance.ready
			skin_instance.play_spawn()


func _ready() -> void:
	_reload_from_game_data()
	walk_particle.process_material.set("color_initial_ramp", sand_particle)
	land_particle.process_material.set("color_initial_ramp", sand_particle)
	jump_particle.process_material.set("color_initial_ramp", sand_particle)

	health = max_health
	shadow_sprite.visible = false
	trap_cleaner.body_entered.connect(_on_body_entered)
	trap_cleaner.area_entered.connect(_on_area_entered)
	for x in range(4):
		for y in range(4):
			all_sand_tiles.append(Vector2i(x, y))
	# Multiplayer matches may temporarily use the skin assigned by the matchmaker.
	update_skin()

	Global.energyball_collected.connect(_on_energy_ball_collected)


func _reload_from_game_data() -> void:
	var game_data := GameData.new()
	acceleration = game_data.data["player"]["acceleration"]
	move_speed = game_data.data["player"]["move_speed"]
	jump_velocity = game_data.data["player"]["jump_velocity"]
	jump_gravity = game_data.data["player"]["jump_gravity"]
	jump_fall_multiplier = game_data.data["player"]["jump_fall_multiplier"]
	max_health = game_data.data["player"]["max_health"]
	invincibility_flicker_period = game_data.data["player"]["invincibility_flicker_period"]


func reparent_land_particles() -> void:
	land_particle.reparent(high_stage)


func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0:
		pressed_move = true
	move(input_dir, move_speed, delta)
	if Input.is_action_just_pressed("jump"):
		_jump()
		pressed_move = true
	if isjumping:
		_jump_process(delta)
	if isinvincible:
		_invincible_flicker()
	if input_dir.length_squared() > 0 and not isjumping:
		walk_particle.emitting = true
		_update_sand_tilemap()
	else:
		walk_particle.emitting = false


func _process(_delta: float) -> void:
	if is_instance_valid(skin_instance):
		skin_instance.global_position = self.global_position + Vector2(0, -current_sprite_y)
	if Global.single_player:
		if (not pressed_move) and Global.game_manager.energy_ball_count >= DRIFT_REQUIREMENT:
			Global.skin_override = DRIFT_SKIN_ID
		else:
			Global.skin_override = ""
		update_skin()
		Global.game_manager.health_icon.update_icon()


func move(dir: Vector2, speed: float, delta: float):
	var previous_position := global_position
	var target_velocity = dir * speed
	var effective_acc = acceleration if not isjumping else 100.
	var weight = 1.0 - exp(-effective_acc * delta)
	if dir != Vector2.ZERO:
		velocity = velocity.lerp(target_velocity, weight)
	else:
		velocity = velocity.lerp(Vector2.ZERO, weight)
	velocity += external_velocity
	move_and_slide()
	velocity -= external_velocity
	distance_traveled += previous_position.distance_to(global_position)


func _update_sand_tilemap():
	var current_cell = sand_tilemap.local_to_map(position / 3)
	if current_cell == last_stepped_cell:
		return
	last_stepped_cell = current_cell
	var source_id = sand_tilemap.get_cell_source_id(current_cell)
	if source_id != -1:
		var random_tile = all_sand_tiles.pick_random()
		sand_tilemap.set_cell(current_cell, source_id, random_tile)


func _jump():
	if isjumping:
		return
	shadow_sprite.visible = true
	jump_particle.restart()
	jump_particle.emitting = true
	isjumping = true
	jump_count += 1
	current_jump_velocity = jump_velocity
	current_sprite_y = 0
	_adjust_collision_layer()
	Audio.play_sfx(Audio.SFX.JUMP)
	if is_instance_valid(skin_instance) and skin_instance.has_method("play_jump"):
		skin_instance.play_jump()


func _jump_process(delta: float):
	if current_jump_velocity < 0:
		current_jump_velocity -= jump_gravity * jump_fall_multiplier * delta
	else:
		current_jump_velocity -= jump_gravity * delta
	current_sprite_y += current_jump_velocity * delta
	if current_sprite_y <= 0:
		isjumping = false
		current_sprite_y = 0
		body_sprite.position.y = 0
		shadow_sprite.scale = Vector2(0.2, 0.2)
		shadow_sprite.modulate.a = 0.5
		_adjust_collision_layer()
		land_particle.restart()
		land_particle.emitting = true
		shadow_sprite.visible = false
		if juice_count > 0:
			Audio.play_sfx(Audio.SFX.LAND_JUICE)
		elif is_in_water:
			Audio.play_sfx(Audio.SFX.LAND_WATER)
		else:
			Audio.play_sfx(Audio.SFX.LAND_SAND)
		if is_instance_valid(skin_instance):
			skin_instance.global_position = self.global_position
			if skin_instance.has_method("play_land"):
				skin_instance.play_land()
	else:
		body_sprite.position.y = -current_sprite_y
		var jump_ratio = clamp(current_sprite_y / 120.0, 0.0, 1.0)
		shadow_sprite.scale = Vector2.ONE * lerp(0.2, 0.1, jump_ratio)
		shadow_sprite.modulate.a = lerp(0.5, 0.15, jump_ratio)


func _invincible_flicker() -> void:
	if (
		(Engine.get_frames_drawn() % invincibility_flicker_period) * 2
		< invincibility_flicker_period
	):
		modulate.a = 0.2
		skin_instance.modulate.a = modulate.a
	else:
		modulate.a = 1
		skin_instance.modulate.a = modulate.a


func _on_body_entered(body: Node2D):
	if body.has_method("seagull_die"):
		body.seagull_die()


func _on_area_entered(area: Area2D):
	if area.get_parent().has_method("disarm"):
		area.get_parent().disarm()


func _adjust_collision_layer() -> void:
	if isjumping:
		collision_layer = 0
		trap_cleaner.collision_mask = 0
	elif isinvincible:
		collision_layer = 8
		trap_cleaner.collision_mask = 4
	else:
		collision_layer = 1 | 8
		trap_cleaner.collision_mask = 0


func invincibility_toggle(on: bool):
	isinvincible = on
	_adjust_collision_layer()
	if not on:
		modulate.a = 1
		skin_instance.modulate.a = modulate.a


func _on_energy_ball_collected(_energy_amount: int) -> void:
	if is_instance_valid(skin_instance) and skin_instance.has_method("play_eat_ball"):
		skin_instance.play_eat_ball()


func die():
	$ShadowSprite.hide()
	if is_instance_valid(skin_instance) and skin_instance.has_method("play_die"):
		skin_instance.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		get_tree().paused = true
		await skin_instance.play_die()
		skin_instance.process_mode = Node.PROCESS_MODE_INHERIT
		get_tree().paused = false


func adjust_particle() -> void:
	adjust_walk_particle()
	adjust_jump_particle()
	adjust_land_particle()


func adjust_walk_particle() -> void:
	var old_particle = walk_particle
	var new_particle = old_particle.duplicate() as GPUParticles2D
	old_particle.get_parent().add_child(new_particle)
	new_particle.global_position = old_particle.global_position
	old_particle.emitting = false
	old_particle.finished.connect(old_particle.queue_free)
	var mat = new_particle.process_material.duplicate() as ParticleProcessMaterial
	if juice_count > 0:
		mat.color_initial_ramp = juice_particle
	elif is_in_water:
		mat.color_initial_ramp = water_particle
	else:
		mat.color_initial_ramp = sand_particle
	new_particle.process_material = mat
	new_particle.emitting = false
	walk_particle = new_particle


func adjust_jump_particle() -> void:
	var old_particle = jump_particle
	var new_particle = old_particle.duplicate() as GPUParticles2D
	old_particle.get_parent().add_child(new_particle)
	new_particle.global_position = old_particle.global_position
	old_particle.emitting = false
	old_particle.finished.connect(old_particle.queue_free)
	var mat = new_particle.process_material.duplicate() as ParticleProcessMaterial
	if juice_count > 0:
		mat.color_initial_ramp = juice_particle
	elif is_in_water:
		mat.color_initial_ramp = water_particle
	else:
		mat.color_initial_ramp = sand_particle
	new_particle.process_material = mat
	new_particle.emitting = false
	jump_particle = new_particle


func adjust_land_particle() -> void:
	var old_particle = land_particle
	var new_particle = old_particle.duplicate() as GPUParticles2D
	old_particle.get_parent().add_child(new_particle)
	new_particle.global_position = old_particle.global_position
	old_particle.emitting = false
	old_particle.finished.connect(old_particle.queue_free)
	var mat = new_particle.process_material.duplicate() as ParticleProcessMaterial
	if juice_count > 0:
		mat.color_initial_ramp = juice_particle
	elif is_in_water:
		mat.color_initial_ramp = water_particle
	else:
		mat.color_initial_ramp = sand_particle
	new_particle.process_material = mat
	new_particle.emitting = false
	land_particle = new_particle
	remote_land_particle.remote_path = remote_land_particle.get_path_to(land_particle)
