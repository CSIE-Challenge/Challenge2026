extends Node2D

@export var player: CharacterBody2D
@export var health_label: Label


func _ready() -> void:
	GlobalSignal.player_hit.connect(on_player_hit)
	health_label.text = "Health: %d" % player.health


func on_player_hit(damage: int):
	print("玩家受到了", damage, "點傷害")
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		print("玩家死掉了！")
