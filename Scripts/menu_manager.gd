extends Control

var target_path: String = "res://Scenes/gameplay.tscn"
@onready var about_panel = $Panel/AboutPanel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	about_panel.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_start_button_button_up() -> void:
	get_tree().change_scene_to_file(target_path)


func _on_quit_button_button_up() -> void:
	get_tree().quit()


func _on_invisible_button_up() -> void:
	SceneTransition.transition_to("res://Scenes/hidden_game.tscn")


func _on_about_buttom_button_up() -> void:
	about_panel.visible = true


func _on_close_button_button_up() -> void:
	about_panel.visible = false
