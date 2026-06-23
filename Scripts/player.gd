class_name Player
extends CharacterBody2D

signal player_landed(player_node: Node2D)  #This is used for the mines, trap no.1

@export var acceleration: float = 100
@export var move_speed: float
@export var jump_velocity: float
@export var jump_gravity: float
@export var jump_fall_multiplier: float
@export var max_health: float
@export var health: float
@export var invincibility_flicker_period: int

var isjumping := false
var current_jump_velocity: float
var current_sprite_y: float
var external_velocity: Vector2 = Vector2.ZERO
var isinvincible := false

@onready var body_sprite = $BodySprite


func _ready() -> void:
	health = max_health


func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move(input_dir, move_speed, delta)
	if Input.is_action_just_pressed("jump"):
		_jump()
	if isjumping:
		_jump_process(delta)
	if isinvincible:
		_invincible_flicker()


func move(dir: Vector2, speed: float, delta: float):
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


func _jump():
	if isjumping:
		return
	isjumping = true
	current_jump_velocity = jump_velocity
	current_sprite_y = 0
	_jump_invisiblility_toggle(true)


func _jump_process(delta: float):
	if current_jump_velocity < 0:
		current_jump_velocity -= jump_gravity * jump_fall_multiplier * delta
	else:
		current_jump_velocity -= jump_gravity * delta
	current_sprite_y += current_jump_velocity * delta
	if current_sprite_y <= 0:
		isjumping = false
		body_sprite.position.y = 0
		_jump_invisiblility_toggle(false)
	else:
		body_sprite.position.y = -current_sprite_y


func _invincible_flicker() -> void:
	if (
		(Engine.get_frames_drawn() % invincibility_flicker_period) * 2
		< invincibility_flicker_period
	):
		modulate.a = 0.2
	else:
		modulate.a = 1


func _jump_invisiblility_toggle(on: bool):
	if on:
		collision_layer = 0
	else:
		collision_layer = 1


func invincibility_toggle(on: bool):
	isinvincible = on
	if not on:
		modulate.a = 1
