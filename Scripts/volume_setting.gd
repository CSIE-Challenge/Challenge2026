extends Node2D

var settings = ConfigFile.new()

@onready var music_slider = $VBoxContainer/MusicSlider
@onready var sfx_slider = $VBoxContainer/SFXSlider


func _ready() -> void:
	self.visible = false


func open() -> void:
	settings.load("user://settings.cfg")
	music_slider.value = settings.get_value("Volume", "music", 1.0)
	sfx_slider.value = settings.get_value("Volume", "sfx", 1.0)
	self.visible = true


func close() -> void:
	settings.set_value("Volume", "music", music_slider.value)
	settings.set_value("Volume", "sfx", sfx_slider.value)
	settings.save("user://settings.cfg")
	self.visible = false


func _on_exit_button_button_up() -> void:
	close()
