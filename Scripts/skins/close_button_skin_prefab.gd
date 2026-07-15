extends BaseSkin

const BASE_SCALE = Vector2(0.096, 0.096)
var tween: Tween
var button_normal = preload("res://Shapes/close_button/close_button.svg")
var button_hover = preload("res://Shapes/close_button/close_button_hover.svg")
var button_pressed = preload("res://Shapes/close_button/close_button_pressed.svg")

@onready var sprite = $ButtonSprite


func play_spawn():
	sprite.scale = Vector2.ZERO
	sprite.modulate.a = 0.0
	sprite.texture = button_normal
	var tween = create_tween()
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	tween.parallel().tween_property(sprite, "modulate:a", 1.0, 0.2)
	await tween.finished


func play_die():
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	await tween.finished


func play_eat_ball():
	if tween:
		tween.kill()
	sprite.texture = button_hover
	tween = create_tween()
	(
		tween
		. tween_property(sprite, "scale", BASE_SCALE * 1.25, 0.15)
		. set_trans(Tween.TRANS_SPRING)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.15).set_trans(Tween.TRANS_SPRING).set_ease(
		Tween.EASE_OUT
	)

	await tween.finished
	sprite.texture = button_normal


func play_jump():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(sprite, "scale", BASE_SCALE * Vector2(1, 1.25), 0.15)
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.15)


func play_land():
	if tween:
		tween.kill()
	sprite.texture = button_pressed
	tween = create_tween()
	tween.tween_property(sprite, "scale", BASE_SCALE * Vector2(1.2, 1.1), 0.05)
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.15)
	await tween.finished
	sprite.texture = button_normal
