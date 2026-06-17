extends Node2D

const MINE_TRAP_SCENE = preload("res://Scenes/mine_trap.tscn")
const ENERGY_GAIN_PER_BALL = 10

@export var player: CharacterBody2D
@export var health_label: Label
@export var energy_balls_label: Label
@export var energy_bar_label: Label

var energy_ball_count := 0
var energy_amount := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	GlobalSignal.energyball_collecetd.connect(_on_energyball_collected)
	health_label.text = "Health: %d" % player.max_health
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	energy_bar_label.text = "Energy Bar: %d" % energy_amount


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
