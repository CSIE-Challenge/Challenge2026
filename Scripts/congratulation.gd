extends Node2D
var time: float = 0
var head_scale: float
var stunned_time: float = 0

# Arguments for the three general coordinators
var hscale = [0.2, 0.11, 0.11]
var left_position = [Vector2(-35, -1), Vector2(-116, 11), Vector2(-96, 8)]
var left_scale = [Vector2(0.8, 0.8), Vector2(1.4, 1.4), Vector2(1.5, 1.5)]
var right_position = [Vector2(43, 1), Vector2(14, 11), Vector2(65, 3)]
var right_scale = [Vector2(0.8, 0.8), Vector2(1.4, 1.4), Vector2(1.5, 1.5)]

@onready var head: AnimatedSprite2D = $Head
@onready var left_spiral: Sprite2D = $Head/LeftSpiral
@onready var right_spiral: Sprite2D = $Head/RightSpiral
@onready var speech_balloon: Sprite2D = $SpeechBalloon
@onready var text_label: Label = $SpeechBalloon/TextLabel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	head.modulate.a = 0
	speech_balloon.modulate.a = 0
	text_label.modulate.a = 0


func _process(delta: float) -> void:
	time += delta
	speech_balloon.position.y = -64 + 1 * sin(time * 5)
	if stunned_time > 0:
		stunned_time -= delta
		head.rotation_degrees = 10 * sin(stunned_time * 8)
		left_spiral.rotation -= delta * 10
		right_spiral.rotation -= delta * 10
		left_spiral.visible = true
		right_spiral.visible = true
		text_label.text = "Ouch!"
	else:
		head.rotation_degrees = 0
		head.scale = Vector2(head_scale * sign(sin(time * 5)), head_scale)
		left_spiral.visible = false
		right_spiral.visible = false
		text_label.text = "Congrats!"


func _spawn() -> void:
	await _spawn_head()
	_spawn_speech()
	return


func _spawn_head() -> void:
	var head_index = randi_range(0, 2)
	head.play(str(head_index))
	head_scale = hscale[head_index]
	left_spiral.position = left_position[head_index]
	left_spiral.scale = left_scale[head_index]
	right_spiral.position = right_position[head_index]
	right_spiral.scale = right_scale[head_index]
	left_spiral.rotation_degrees = randf_range(-30, 30)
	for i in 100:
		head.modulate.a += 0.01
		await get_tree().create_timer(0.01).timeout
	return


func _spawn_speech() -> void:
	for i in 100:
		speech_balloon.modulate.a += 0.01
		text_label.modulate.a += 0.01
		await get_tree().create_timer(0.005).timeout
	return


func _hit() -> void:
	stunned_time = 2.5
