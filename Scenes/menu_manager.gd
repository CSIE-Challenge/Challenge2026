extends Control

var target_path: String = "res://Scenes/gameplay.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass  # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_start_button_button_up() -> void:
	get_tree().change_scene_to_file(target_path)


func _on_quit_button_button_up() -> void:
	get_tree().quit()
