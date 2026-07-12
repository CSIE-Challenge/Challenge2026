extends Control

const FILE_SELECTOR_SCENE := "res://Scenes/menu/file_selector.tscn"
const MATCHMAKER_SCENE := "res://Scenes/menu/matchmaker.tscn"

var _track_tween: Tween

@onready var track_label: Label = $Panel/TrackLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var track_name = Audio.get_current_track_name()
	track_label.text = "♪ %s" % track_name if not track_name.is_empty() else ""

	Audio.track_changed.connect(_on_track_changed)
	Audio.set_bgm(Audio.BGM.MENU)


func _on_track_changed(track_name: String) -> void:
	if _track_tween and _track_tween.is_running():
		_track_tween.kill()

	var new_label = "♪ %s" % track_name if not track_name.is_empty() else ""

	_track_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	_track_tween.tween_property(track_label, "position:x", 420, 0.4).as_relative()
	_track_tween.tween_callback(func(): track_label.text = new_label)
	_track_tween.tween_property(track_label, "position:x", -420, 0.5).as_relative()


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
