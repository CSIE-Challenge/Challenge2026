extends Area2D

const SPEED: float = 100

@export var direction: Vector2 = Vector2.UP

var player_on_trap: CharacterBody2D = null


func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if player_on_trap == null:
		return
	player_on_trap.global_position += SPEED * direction * delta


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body is CharacterBody2D:
		player_on_trap = body
		print("玩家踩到了履帶地塊")


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" and body is CharacterBody2D:
		player_on_trap = null
		print("玩家離開了履帶地塊")
