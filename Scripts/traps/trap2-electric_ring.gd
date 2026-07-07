class_name Trap2ElectricRing
extends Node2D
var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap2-electric_ring"]["cooldown_times"]
var damage = trap_data["trap2-electric_ring"]["damage"]
var energy_costs = trap_data["trap2-electric_ring"]["energy_costs"]
var standard_radius = trap_data["trap2-electric_ring"]["standard_radius"]
# ▲sprite的scale為1時，場景中實際的電圈半徑
var player_radius = trap_data["trap2-electric_ring"]["player_radius"]
var stay_time = trap_data["trap2-electric_ring"]["stay_time"]
var ring_thickness = trap_data["trap2-electric_ring"]["ring_thickness"]
# @export var test_player: CharacterBody2D
var test_player: CharacterBody2D
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


func _ready() -> void:
	$ElectricRingWarning.z_index = Util.LAYERS["Trap2ElectricRing/ElectricRingWarning"]
	$ElectricRing.z_index = Util.LAYERS["Trap2ElectricRing/ElectricRing"]


static func initialize(time: float, radius: float) -> Trap2ElectricRing:
	var trap := preload("res://Scenes/traps/trap2-electric_ring.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.spawn(radius, time)
	return trap


func _physics_process(delta: float) -> void:
	if died:
		return
	if not electric_on:
		current_fill += fill_speed * delta
		global_position = player.global_position
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
	player = Global.game_manager.player
	position = player.position
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
	queue_free()


func _detect_player():
	if player.isjumping:
		return
	var dist = player.global_position.distance_to(global_position)
	if dist < radius:
		if dist + player_radius >= radius:
			Global.player_hit.emit(damage)
	else:
		if dist - player_radius <= radius:
			Global.player_hit.emit(damage)
