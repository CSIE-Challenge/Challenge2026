extends Node2D
const MINE_TRAP_SCENE = preload("res://Scenes/mine_trap.tscn")

@export var player: CharacterBody2D
@export var health_label: Label


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	health_label.text = "Health: %d" % player.max_health


func on_player_hit(damage: int):
	spawn_mine_trap(Vector2(600, 400))
	print("玩家受到了", damage, "點傷害")
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		print("玩家死掉了！")


func spawn_mine_trap(spawn_position: Vector2) -> void:
	var new_trap: Area2D = MINE_TRAP_SCENE.instantiate()

	add_child(new_trap)
	new_trap.global_position = spawn_position
