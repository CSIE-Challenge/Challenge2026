extends Area2D

const SPEED: float = 100

@export var direction: Vector2 = Vector2.UP


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" and body is CharacterBody2D:
		body.external_velocity += SPEED * direction
		print("玩家踩到了履帶地塊")


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player" and body is CharacterBody2D:
		body.external_velocity -= SPEED * direction
		print("玩家離開了履帶地塊")
