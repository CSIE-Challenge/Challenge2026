extends Node2D

const MINE_TRAP_SCENE = preload("res://Scenes/mine_trap.tscn")
const ENERGY_GAIN_PER_BALL = 10

@export var player: CharacterBody2D
@export var health_label: Label
@export var shotgun_trap_scene := preload("res://Scenes/shotgun_trap.tscn")
@export var energy_balls_label: Label
@export var energy_bar_label: Label
@export var energy_increase_period: int

var energy_ball_count := 0
var energy_amount := 0
var rng := RandomNumberGenerator.new()

@onready var energy_increase_timer = $EnergyIncreaseTimer


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	GlobalSignal.energyball_collected.connect(_on_energyball_collected)
	health_label.text = "Health: %d" % player.max_health
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	energy_bar_label.text = "Energy Bar: %d" % energy_amount
	energy_increase_timer.wait_time = energy_increase_period

	var shotgun_trap = shotgun_trap_scene.instantiate()
	add_child(shotgun_trap)
	shotgun_trap.activate(
		Vector2(-250, 100) + Vector2(576, 324), Vector2(1, 0.2), Vector2(1, 0), Vector2(1, -0.2)
	)


func on_player_hit(damage: int) -> void:
	print("玩家受到了", damage, "點傷害")
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		print("玩家死掉了！")


func _on_energyball_collected() -> void:
	energy_ball_count += 1
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	energy_amount += ENERGY_GAIN_PER_BALL
	energy_bar_label.text = "Energy Bar: %d" % energy_amount


func _on_energy_increase_timer_timeout() -> void:
	energy_amount += 1
	energy_bar_label.text = "Energy Bar: %d" % energy_amount
