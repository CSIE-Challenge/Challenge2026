extends Node2D

const MINE_TRAP_SCENE = preload("res://Scenes/mine_trap.tscn")

@export var player: CharacterBody2D
@export var health_label: Label
@export var energy_counter_label: Label

var energy_ball_count := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	GlobalSignal.energyball_collecetd.connect(_on_energyball_collected)
	health_label.text = "Health: %d" % player.health
	energy_counter_label.text = "Energy Balls: %d" % energy_ball_count


func on_player_hit(damage: int) -> void:
	print("玩家受到了", damage, "點傷害")
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		print("玩家死掉了！")


func _on_energyball_collected() -> void:
	energy_ball_count += 1
	energy_counter_label.text = "Energy Balls: %d" % energy_ball_count


func spawn_mine_trap(spawn_position: Vector2) -> void:
	var new_trap: Node2D = MINE_TRAP_SCENE.instantiate()

	add_child(new_trap)
	new_trap.initialize(spawn_position)
