extends BaseSkin

const BASE_SCALE = Vector2(0.096, 0.096)
var tween: Tween
var button_normal = preload("res://Shapes/close_button/close_button.svg")
var button_hover = preload("res://Shapes/close_button/close_button_hover.svg")
var button_pressed = preload("res://Shapes/close_button/close_button_pressed.svg")
var text_color_normal = Color(0.992, 0.965, 0.886, 1.0)
var text_color_hover = Color(0.929, 0.843, 0.659, 1.0)
var text_color_pressed = Color(1.0, 1.0, 1.0, 1.0)
var input_stack: Array[String]

@onready var sprite = $ButtonSprite
@onready var label = $ButtonSprite/TextLabel


func _ready():
	input_stack.clear()


func _process(delta: float):
	if Input.is_action_just_pressed("move_up"):
		input_stack.push_front("W")
	if Input.is_action_just_pressed("move_left"):
		input_stack.push_front("A")
	if Input.is_action_just_pressed("move_down"):
		input_stack.push_front("S")
	if Input.is_action_just_pressed("move_right"):
		input_stack.push_front("D")

	if Input.is_action_just_released("move_up"):
		input_stack.erase("W")
	if Input.is_action_just_released("move_left"):
		input_stack.erase("A")
	if Input.is_action_just_released("move_down"):
		input_stack.erase("S")
	if Input.is_action_just_released("move_right"):
		input_stack.erase("D")

	if input_stack.is_empty():
		label.text = "X"
	else:
		label.text = input_stack.front()

	use(delta)


func play_spawn():
	sprite.scale = Vector2.ZERO
	sprite.modulate.a = 0.0
	style_play("normal")
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
	style_play("hover")
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
	style_play("normal")


func play_jump():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(sprite, "scale", BASE_SCALE * Vector2(1, 1.25), 0.15)
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.15)


func play_land():
	if tween:
		tween.kill()
	style_play("pressed")
	tween = create_tween()
	tween.tween_property(sprite, "scale", BASE_SCALE * Vector2(1.2, 1.1), 0.05)
	tween.tween_property(sprite, "scale", BASE_SCALE, 0.15)
	await tween.finished
	style_play("normal")


func style_play(style: String):
	match style:
		"normal":
			sprite.texture = button_normal
			label.add_theme_color_override("font_color", text_color_normal)
		"hover":
			sprite.texture = button_hover
			label.add_theme_color_override("font_color", text_color_hover)
		"pressed":
			sprite.texture = button_pressed
			label.add_theme_color_override("font_color", text_color_pressed)


func use(delta: float):
	return delta
