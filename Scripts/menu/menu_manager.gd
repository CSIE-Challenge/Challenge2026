extends Control

const FILE_SELECTOR_SCENE := "res://Scenes/menu/file_selector.tscn"

@onready var about_panel = $Panel/AboutPanel
@onready var mode_panel = $Panel/ModePanel
@onready var single_button: Button = $Panel/ModePanel/VBoxContainer/ToggleRow/SingleButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	about_panel.visible = false
	mode_panel.visible = false
	if not AudioManager.menutheme.has_stream_playback():
		AudioManager.menutheme.play()


# --- Main menu -------------------------------------------------------------
func _on_start_button_button_up() -> void:
	mode_panel.visible = true


func _on_quit_button_button_up() -> void:
	get_tree().quit()


func _on_volume_button_button_up() -> void:
	$VolumeSetting.open()


func _on_invisible_button_up() -> void:
	SceneTransition.transition_to("res://Scenes/menu/hidden_game.tscn")


func _on_about_buttom_button_up() -> void:
	about_panel.visible = true


func _on_close_button_button_up() -> void:
	about_panel.visible = false


# --- Mode selection (toggle + confirm) -------------------------------------
func _on_confirm_button_up() -> void:
	if single_button.button_pressed:
		# 單人模式: pick an agent script in the file selector scene.
		Global.single_player = true
		Global.agent_file = ""
		SceneTransition.transition_to(FILE_SELECTOR_SCENE)
	else:
		# 雙人模式: no dedicated scene yet (placeholder).
		Global.single_player = false
		Global.agent_file = ""
		print("[Menu] 雙人模式 selected (not implemented yet)")


func _on_mode_back_button_up() -> void:
	mode_panel.visible = false
