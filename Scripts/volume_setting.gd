extends Node2D

var settings = ConfigFile.new()
var temp_music_volume: float
var temp_sfx_volume: float

@onready var music_slider = $VBoxContainer/MusicSlider
@onready var sfx_slider = $VBoxContainer/SFXSlider


func _ready() -> void:
	self.visible = false


func open() -> void:
	settings.load("user://settings.cfg")
	music_slider.value = settings.get_value("Volume", "music", 1.0)
	sfx_slider.value = settings.get_value("Volume", "sfx", 1.0)
	temp_music_volume = music_slider.value
	temp_sfx_volume = sfx_slider.value
	self.visible = true


func close() -> void:
	settings.set_value("Volume", "music", music_slider.value)
	settings.set_value("Volume", "sfx", sfx_slider.value)
	settings.save("user://settings.cfg")
	self.visible = false


func _on_save_button_button_up() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	close()


func _on_revert_button_button_up() -> void:
	music_slider.value = temp_music_volume
	sfx_slider.value = temp_sfx_volume
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)


func _on_sfx_slider_drag_ended(_value_changed: bool) -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
