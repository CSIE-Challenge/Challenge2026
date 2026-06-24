extends Node2D

const ENERGY_GAIN_PER_BALL = 10
# Seats driven by a remote agent. The human plays directly on the keyboard, so
# only agent seats need wiring: add a name here to add an agent (1 agent for now).
const AGENT_SEATS: Array[String] = ["Agent1"]

@export var player: CharacterBody2D
@export var camera: Camera2D
@export var health_label: Label
@export var energy_balls_label: Label
@export var energy_bar_label: Label
@export var opponent_energy_bar_label: Label
@export var energy_increase_period: int
@export var energy_ball_spawn_period: int
@export var player_invincibility_time: float

var energy_ball_count := 0
var energy_amount := 0
var rng := RandomNumberGenerator.new()
var player_invincible := false

@onready var player_invincibility_timer = $PlayerInvincibilityTimer
@onready var stage = $"../SubViewport/Stage"
@onready var energy_increase_timer = $EnergyIncreaseTimer


func _ready() -> void:
	Global.player_hit.connect(on_player_hit)
	Global.energyball_collected.connect(_on_energyball_collected)
	Global.game_manager = self
	player_invincibility_timer.timeout.connect(_on_player_invincibility_timer_timeout)
	NetworkManager.energy_changed.connect(_on_network_energy_changed)
	health_label.text = "Health: %d" % player.max_health
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	_update_energy_label()
	_update_opponent_energy_label(0, 0)
	energy_increase_timer.wait_time = energy_increase_period

	energy_increase_timer.wait_time = energy_ball_spawn_period
	player_invincible = false

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
	NetworkManager.request_add_energy(ENERGY_GAIN_PER_BALL, "energy_ball")


func _player_become_invincible() -> void:
	player_invincible = true
	player.invincibility_toggle(true)
	player_invincibility_timer.start(player_invincibility_time)


func _on_player_invincibility_timer_timeout() -> void:
	player_invincible = false
	player.invincibility_toggle(false)


func _on_energy_increase_timer_timeout() -> void:
	NetworkManager.request_add_energy(1, "passive_regeneration")


func _on_network_energy_changed(peer_id: int, energy: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		energy_amount = energy
		_update_energy_label()
		return

	_update_opponent_energy_label(peer_id, energy)


func _update_energy_label() -> void:
	energy_bar_label.text = "My Energy: %d" % energy_amount


func _update_opponent_energy_label(peer_id: int, energy: int) -> void:
	if peer_id == 0:
		opponent_energy_bar_label.text = "Opponent Energy: waiting"
		return
	opponent_energy_bar_label.text = "Opponent Energy (%d): %d" % [peer_id, energy]
