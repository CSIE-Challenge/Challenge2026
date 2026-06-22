extends Node2D

@export var max_height: float = 300.0
@export var gravity: float = 300.0
@export var test_player: CharacterBody2D
@export var explosion_max_radius: float = 100.0
@export var explosion_expand_speed: float = 400.0
@export var damage: int = 20

var player: CharacterBody2D
var start_pos: Vector2
var end_pos: Vector2
var velocity: Vector2

var air_time: float = 2.0
var elapsed: float = 0.0

var flying: bool = false

var exploding: bool = false
var explosion_radius: float = 0.0

@onready var shell: Sprite2D = $Shell
@onready var shadow: Sprite2D = $Shadow
@onready var explosion: AnimatedSprite2D = $Explosion


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	explosion.visible = false
	explosion.animation_finished.connect(_on_explosion_finished)
	shell.z_index = 1
	shadow.z_index = 0


func _process(delta: float) -> void:
	if flying:
		elapsed += delta

		velocity.y += gravity * delta

		shell.global_position += velocity * delta

		shadow.global_position = Vector2(shell.global_position.x, end_pos.y)

		if elapsed >= air_time:
			explode()

	if exploding:
		explosion_radius += explosion_expand_speed * delta

		if explosion_radius >= explosion_max_radius:
			queue_free()

		queue_redraw()


func activate(
	initial_position: Vector2,
	final_position: Vector2,
	flight_time: float,
	target_player: CharacterBody2D
) -> void:
	player = target_player
	start_pos = initial_position
	end_pos = final_position

	air_time = flight_time

	elapsed = 0.0
	flying = true
	exploding = false

	shell.global_position = start_pos
	shadow.global_position = start_pos
	velocity.x = (end_pos.x - start_pos.x) / air_time

	velocity.y = (end_pos.y - start_pos.y - 0.5 * gravity * air_time * air_time) / air_time


func _on_explosion_finished():
	queue_free()


func explode() -> void:
	flying = false

	shell.visible = false
	shadow.visible = false

	explosion.global_position = end_pos
	explosion.visible = true
	exploding = true
	explosion_radius = 0.0

	global_position = end_pos

	if player == null:
		player = test_player
	var dist = player.global_position.distance_to(end_pos)

	if dist <= explosion_max_radius:
		GlobalSignal.player_hit.emit(damage)


func _draw():
	if exploding:
		draw_circle(Vector2.ZERO, explosion_radius, Color(1, 0.5, 0, 0.3))
