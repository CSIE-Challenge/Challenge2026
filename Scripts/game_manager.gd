extends Node2D

const MINE_TRAP_SCENE = preload("res://Scenes/mine_trap.tscn")
const SPREADING_RIPPLES_SCENE = preload("res://Scenes/spreading_ripples.tscn")
const ENERGY_GAIN_PER_BALL = 10
# Seats driven by a remote agent. The human plays directly on the keyboard, so
# only agent seats need wiring: add a name here to add an agent (1 agent for now).
const AGENT_SEATS: Array[String] = ["Agent1"]

@export var player: CharacterBody2D
@export var camera: Camera2D
@export var health_label: Label
@export var shotgun_trap_scene := preload("res://Scenes/shotgun_trap.tscn")
@export var energy_balls_label: Label
@export var energy_bar_label: Label
@export var energy_increase_period: int
@export var energy_ball_spawn_period: int
@export var player_invincibility_time: float

var energy_ball_count := 0
var energy_amount := 0
var rng := RandomNumberGenerator.new()
var player_invincible := false

@onready var player_invincibility_timer = $PlayerInvincibilityTimer

@onready var energy_increase_timer = $EnergyIncreaseTimer


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	GlobalSignal.energyball_collected.connect(_on_energyball_collected)
	player_invincibility_timer.timeout.connect(_on_player_invincibility_timer_timeout)
	health_label.text = "Health: %d" % player.max_health
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	energy_bar_label.text = "Energy Bar: %d" % energy_amount
	energy_increase_timer.wait_time = energy_increase_period

	var shotgun_trap = shotgun_trap_scene.instantiate()
	add_child(shotgun_trap)
	shotgun_trap.activate(
		Vector2(-250, 100) + Vector2(576, 324), Vector2(1, 0.2), Vector2(1, 0), Vector2(1, -0.2)
	)
	energy_increase_timer.wait_time = energy_ball_spawn_period
	player_invincible = false

	var ripple_trap = SPREADING_RIPPLES_SCENE.instantiate()
	add_child(ripple_trap)
	ripple_trap.activate(Vector2(300, 300), 150.0)

	_spawn_agents()


func _spawn_agents() -> void:
	for seat_name: String in AGENT_SEATS:
		var agent := GameAgent.new()
		agent.name = seat_name
		agent.game = self
		add_child(agent)


func on_player_hit(damage: int) -> void:
	if player_invincible:
		return
	_player_become_invincible()
	print("玩家受到了", damage, "點傷害")
	camera.shake_cam()
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		print("玩家死掉了！")


func _on_energyball_collected() -> void:
	energy_ball_count += 1
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	energy_amount += ENERGY_GAIN_PER_BALL
	energy_bar_label.text = "Energy Bar: %d" % energy_amount


func _player_become_invincible() -> void:
	player_invincible = true
	player.invincibility_toggle(true)
	player_invincibility_timer.start(player_invincibility_time)


func _on_player_invincibility_timer_timeout() -> void:
	player_invincible = false
	player.invincibility_toggle(false)


func _on_energy_increase_timer_timeout() -> void:
	energy_amount += 1
	energy_bar_label.text = "Energy Bar: %d" % energy_amount
