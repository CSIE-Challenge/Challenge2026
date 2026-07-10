extends ColorRect

var settings = ConfigFile.new()
var temp_music_volume: float
var temp_sfx_volume: float

@onready var music_slider = $PanelContainer/MarginContainer/VBoxContainer/MusicContainer/MusicSlider
@onready var sfx_slider = $PanelContainer/MarginContainer/VBoxContainer/SFXContainer/SFXSlider


func _ready() -> void:
	self.visible = false


func open() -> void:
	settings.load("user://settings.cfg")
	music_slider.value = settings.get_value("Volume", "music", 1.0)
	sfx_slider.value = settings.get_value("Volume", "sfx", 1.0)
	temp_music_volume = music_slider.value
	temp_sfx_volume = sfx_slider.value

	var panel = $PanelContainer
	self.modulate.a = 0.0
	self.visible = true
	panel.scale = Vector2(0.85, 0.85)
	panel.pivot_offset = panel.size / 2.0

	var tween = create_tween()
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(panel, "scale", Vector2.ONE, 0.2)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func close() -> void:
	settings.set_value("Volume", "music", music_slider.value)
	settings.set_value("Volume", "sfx", sfx_slider.value)
	settings.save("user://settings.cfg")

	var tween = create_tween()
	var panel = $PanelContainer
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	(
		tween
		. parallel()
		. tween_property(panel, "scale", Vector2(0.85, 0.85), 0.2)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	await tween.finished
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
