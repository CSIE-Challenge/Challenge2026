extends Control

const FILE_SELECTOR_SCENE := "res://Scenes/menu/file_selector.tscn"
const MATCHMAKER_SCENE := "res://Scenes/menu/matchmaker.tscn"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Audio.set_bgm(Audio.BGM.MENU)


func _on_single_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	Global.single_player = true
	Global.agent_file = ""
	SceneTransition.transition_to(FILE_SELECTOR_SCENE)


func _on_double_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	Global.single_player = false
	Global.agent_file = ""
	SceneTransition.transition_to(MATCHMAKER_SCENE)


func _on_exit_button_button_up() -> void:
	var player: AudioStreamPlayer = Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	await player.finished
	get_tree().quit()


func _on_volume_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	$VolumeSetting.open()


func _on_invisible_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	const HiddenGameController = preload("res://Scripts/menu/hidden_game_controller.gd")
	HiddenGameController.reset_dialogue_state()
	SceneTransition.transition_to_distortion("res://Scenes/menu/hidden_game.tscn")


func _on_about_button_pressed() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/about.tscn")


func _on_skin_shop_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/menu/skin_shop.tscn")
