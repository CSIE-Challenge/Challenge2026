extends Node2D
@export var standard_radius: float  #sprite的scale為1時，場景中實際的電圈半徑
@export var player_radius: float
@export var stay_time: float
@export var ring_thickness: float
var player: CharacterBody2D
var current_fill: float
var radius: float
var fill_speed: float
var electric_on: bool
var current_stay_time
var died: bool
@onready var ring_sprite = $ElectricRing
@onready var warning_sprite = $ElectricRingWarning
@onready var animation = $AnimationPlayer


func _ready():
	player = GameManager.player
	spawn(randf_range(75, 150), randf_range(1.0, 2.0))


func _physics_process(delta: float) -> void:
	if died:
		return
	if not electric_on:
		current_fill += fill_speed * delta
		position = player.position
		warning_sprite.material.set_shader_parameter("fill", current_fill)
		if current_fill >= 1.0:
			electric_on = true
			warning_sprite.visible = false
			ring_sprite.visible = true
			current_stay_time = stay_time
			animation.play("electric_ring")
	else:
		current_stay_time -= delta
		if current_stay_time <= 0.0:
			animation.play("electric_ring_die")
		else:
			_detect_player()


func spawn(set_radius: float, delay_time: float):
	radius = set_radius
	died = false
	warning_sprite.visible = true
	ring_sprite.visible = false
	electric_on = false
	fill_speed = 1.0 / delay_time
	current_fill = 0.0
	var sc = radius / standard_radius
	ring_sprite.scale = Vector2.ONE * sc
	warning_sprite.scale = Vector2.ONE * sc
	warning_sprite.material.set_shader_parameter("thickness", ring_thickness / sc)
	ring_sprite.material.set_shader_parameter("thickness", ring_thickness / sc)


func _die():
	died = true
	electric_on = false
	warning_sprite.visible = false
	ring_sprite.visible = false


func _detect_player():
	if player.isjumping:
		return
	var dist = player.position.distance_to(position)
	if dist < radius:
		if dist + player_radius >= radius:
			GlobalSignal.player_hit.emit(randi_range(0, 10))
	else:
		if dist - player_radius <= radius:
			GlobalSignal.player_hit.emit(randi_range(0, 10))
