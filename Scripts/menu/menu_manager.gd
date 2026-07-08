extends Control

const FILE_SELECTOR_SCENE := "res://Scenes/menu/file_selector.tscn"
const MULTIPLAYER_READY_SCENE := "res://Scenes/menu/multiplayer_ready.tscn"

@onready var mode_panel = $Panel/ModePanel
@onready var single_button: Button = $Panel/ModePanel/VBoxContainer/ToggleRow/SingleButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mode_panel.visible = false
	Audio.set_bgm(Audio.BGM.MENU)


# --- Main menu -------------------------------------------------------------
func _on_start_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	mode_panel.visible = true


func _on_quit_button_button_up() -> void:
	var player := Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	await player.finished
	get_tree().quit()


func _on_volume_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	$VolumeSetting.open()


func _on_invisible_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	const HiddenGameController = preload("res://Scripts/menu/hidden_game_controller.gd")
	HiddenGameController.reset_dialogue_state()
	SceneTransition.transition_to("res://Scenes/menu/hidden_game.tscn")


# --- Mode selection (toggle + confirm) -------------------------------------
func _on_confirm_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	if single_button.button_pressed:
		# 單人模式: pick an agent script in the file selector scene.
		Global.single_player = true
		Global.agent_file = ""
		SceneTransition.transition_to(FILE_SELECTOR_SCENE)
	else:
		Global.single_player = false
		Global.agent_file = ""
		SceneTransition.transition_to(MULTIPLAYER_READY_SCENE)


func _on_mode_back_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	mode_panel.visible = false


func _on_about_button_pressed() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/about.tscn")


func _on_skin_shop_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_shop("res://Scenes/menu/skin_shop.tscn")
