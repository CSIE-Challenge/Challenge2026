extends Area2D

const PlayerScript = preload("res://Scripts/player.gd")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.get_script() == PlayerScript:
		print("player entered icefloor")
		body.acceleration = 5


func _on_body_exited(body: Node2D) -> void:
	if body.get_script() == PlayerScript:
		print("player left icefloor")
		body.acceleration = 100
