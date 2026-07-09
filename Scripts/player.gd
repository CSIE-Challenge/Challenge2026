class_name Player
extends CharacterBody2D

@export var health: int

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

@onready var body_sprite = $BodySprite
@onready var shadow_sprite = $ShadowSprite
@onready var sand_tilemap = $"../../../BackGroundLayer/SandTileMap"
@onready var walk_particle = $WalkParticle
@onready var jump_particle = $JumpParticle
@onready var land_particle = $LandParticle


func _ready() -> void:
	_reload_from_game_data()
	health = max_health
	for x in range(4):
		for y in range(4):
			all_sand_tiles.append(Vector2i(x, y))
	var skin_path = "res://Assets/skins/" + PlayerData.equipped_skin + ".tres"
	var skin_data = load(skin_path)
	if skin_data and skin_data.skin_prefab:
		skin_instance = skin_data.skin_prefab.instantiate()
		skin_instance.z_index = 20
		skin_instance.set_meta("player", self)
		var hd_skin_layer = CanvasLayer.new()
		hd_skin_layer.layer = 100
		hd_skin_layer.follow_viewport_enabled = true
		var my_viewport = get_viewport()
		if my_viewport and my_viewport.get_parent():
			my_viewport.get_parent().add_child.call_deferred(hd_skin_layer)
		else:
			get_tree().current_scene.add_child.call_deferred(hd_skin_layer)
		hd_skin_layer.add_child.call_deferred(skin_instance)
		body_sprite.hide()
		if skin_instance.has_method("play_spawn"):
			if not skin_instance.is_node_ready():
				await skin_instance.ready
			skin_instance.play_spawn()
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


func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move(input_dir, move_speed, delta)
	if Input.is_action_just_pressed("jump"):
		_jump()
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
	else:
		modulate.a = 1


func _adjust_collision_layer() -> void:
	if isjumping:
		collision_layer = 0
	elif isinvincible:
		collision_layer = 8
	else:
		collision_layer = 1 | 8


func invincibility_toggle(on: bool):
	isinvincible = on
	_adjust_collision_layer()
	if not on:
		modulate.a = 1


func _on_energy_ball_collected(_energy_amount: int) -> void:
	if is_instance_valid(skin_instance) and skin_instance.has_method("play_eat_ball"):
		skin_instance.play_eat_ball()


func die():
	$ShadowSprite.hide()
	if is_instance_valid(skin_instance) and skin_instance.has_method("play_die"):
		await skin_instance.play_die()
