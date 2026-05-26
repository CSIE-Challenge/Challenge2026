extends Area2D

signal collected


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not visible or body.name != "Player":
		return

	visible = false
	collected.emit()
