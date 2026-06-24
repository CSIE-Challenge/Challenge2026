class_name Trap9Mortar
extends Node2D

@export var max_height: float = 300.0
@export var gravity: float = 200.0
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
@onready var explosion_area: Area2D = $ExplosionArea
@onready var explosion_shape: CollisionShape2D = $ExplosionArea/CollisionShape2D


static func initialize(start_pos: Vector2, end_pos: Vector2, air_time: float) -> Trap9Mortar:
	var trap := preload("res://Scenes/traps/trap9-mortar.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(start_pos, end_pos, air_time)
	return trap


func _ready() -> void:
	explosion.visible = false
	explosion.animation_finished.connect(_on_explosion_finished)

	shell.z_index = 1
	shadow.z_index = 0


func _process(delta: float) -> void:
	if flying:
		elapsed += delta

		velocity.y += gravity * delta

		shell.position += velocity * delta

		shadow.position = Vector2(shell.position.x, end_pos.y)

		if elapsed >= air_time:
			explode()

	if exploding:
		explosion_radius += explosion_expand_speed * delta

		if explosion_radius >= explosion_max_radius:
			queue_free()

		for body in explosion_area.get_overlapping_bodies():
			if body == Global.game_manager.player:
				Global.player_hit.emit(damage)

		queue_redraw()


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

	shell.position = start_pos
	shadow.position = start_pos
	velocity.x = (end_pos.x - start_pos.x) / air_time

	velocity.y = (end_pos.y - start_pos.y - 0.5 * gravity * air_time * air_time) / air_time


func _on_explosion_finished():
	explosion_area.monitoring = false
	queue_free()


func explode() -> void:
	flying = false

	shell.visible = false
	shadow.visible = false

	var circle := explosion_shape.shape as CircleShape2D
	circle.radius = explosion_max_radius
	explosion_area.monitoring = true

	explosion.visible = true
	exploding = true
	explosion_radius = 0.0

	position = end_pos
	# explosion.play()


func _draw():
	if exploding:
		draw_circle(Vector2.ZERO, explosion_radius, Color(1, 0.5, 0, 0.3))
