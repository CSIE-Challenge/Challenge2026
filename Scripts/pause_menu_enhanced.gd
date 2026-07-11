class_name PauseMenu
extends CanvasLayer

signal resume_requested(elapsed_time: int)
signal main_menu_requested
signal restart_requested
signal exit_requested

var settings = ConfigFile.new()
var temp_music_volume: float
var temp_sfx_volume: float
var phase_duration = GameData.new().data["game_manager"]["phase_duration"]

# gdlint: disable=max-line-length
@onready var color_rect = $ColorRect
@onready var panel = $ColorRect/PanelContainer
@onready
var music_slider = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/VolumeContainer/MusicContainer/MusicSlider
@onready
var sfx_slider = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/VolumeContainer/SFXContainer/SFXSlider
@onready
var _time_slider: HSlider = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer/TimeSlider
@onready
var _phase_label = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer/PhaseLabel
@onready
var _time_label = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer/TimeLabel
@onready
var _resume_button: Button = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer2/ResumeButton
@onready
var _restart_button: Button = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer2/RestartButton
@onready
var _main_menu_button: Button = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer3/MainMenuButton
@onready
var _exit_button: Button = $ColorRect/PanelContainer/MarginContainer/VBoxContainer/ActionContainer/HBoxContainer3/ExitButton
# gdlint: enable=max-line-length


func close() -> void:
	visible = false


#region Action


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	_resume_button.button_up.connect(_on_resume_button_up)
	_restart_button.button_up.connect(_on_restart_button_up)
	_main_menu_button.button_up.connect(_on_main_menu_button_up)
	_exit_button.button_up.connect(_on_exit_button_up)


func _on_resume_button_up() -> void:
	if visible:
		resume_requested.emit(_time_slider.value)


func _on_restart_button_up() -> void:
	restart_requested.emit()


func _on_main_menu_button_up() -> void:
	main_menu_requested.emit()


func _on_exit_button_up() -> void:
	exit_requested.emit()


#endregion

#region Volume


func open(elapsed_time: float) -> void:
	_time_slider.value = elapsed_time
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	settings.load("user://settings.cfg")
	music_slider.value = settings.get_value("Volume", "music", 1.0)
	sfx_slider.value = settings.get_value("Volume", "sfx", 1.0)
	temp_music_volume = music_slider.value
	temp_sfx_volume = sfx_slider.value

	color_rect.modulate.a = 0.0
	visible = true
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size / 2.0

	var tween = create_tween()
	tween.parallel().tween_property(color_rect, "modulate:a", 1.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(panel, "scale", Vector2.ONE, 0.2)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func save() -> void:
	settings.set_value("Volume", "music", music_slider.value)
	settings.set_value("Volume", "sfx", sfx_slider.value)
	settings.save("user://settings.cfg")


func _on_sfx_slider_drag_ended(_value_changed: bool) -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)


#endregion


func _on_time_slider_value_changed(value: float) -> void:
	var minute = int(floor(value)) / 60
	var second = int(floor(value)) % 60
	_time_label.text = "%02d:%02d" % [minute, second]
	for i in range(len(phase_duration)):
		if value > phase_duration[i]:
			value -= phase_duration[i]
		else:
			_phase_label.text = "Phase %d" % i
			break
