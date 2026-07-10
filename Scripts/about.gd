extends Control

const HEAD_ROTATING_SPEED = 360
var is_letter_collected = {
	"0_C": false,
	"1_O": false,
	"2_C": false,
	"3_O": false,
	"4_N": false,
	"5_U": false,
	"6_T": false,
}
var letter_collected_cnt = 0
var head = null
var is_head_collected = [false, false, false]
var head_collected_cnt = 0
@onready var heads = [$Head1, $Head2, $Head3]
@onready var flying_letter = $FlyingLetter


func _ready() -> void:
	for h in heads:
		h.visible = false
	flying_letter.visible = false


func _process(delta: float) -> void:
	if head:
		head.rotation_degrees += HEAD_ROTATING_SPEED * delta
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)


func _on_close_pressed() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/menu.tscn")


func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	var key = str(meta)

	if is_letter_collected[key] == false:
		_play_letter_animation(key[key.length() - 1])
		letter_collected_cnt += 1

	is_letter_collected[key] = true
	if letter_collected_cnt == 7:
		_on_all_collected()


func _on_all_collected():
	head = heads.pick_random()
	for i in range(len(heads)):
		heads[i].visible = false
		if head == heads[i]:
			is_head_collected[i] = true
			head_collected_cnt += 1

	if head_collected_cnt == 3:
		print("Hidden game is unlocked.")

	_play_head_animation()


func _play_head_animation():
	head.visible = true
	var screen_size = get_viewport_rect().size
	var center_y = screen_size.y / 2

	var start_pos = Vector2(-500, center_y)
	var center_pos = Vector2(screen_size.x / 2, center_y)
	var end_pos = Vector2(screen_size.x + 500, center_y)
	head.global_position = start_pos
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(head, "global_position", center_pos, 0.8)
	tween.tween_interval(0.2)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(head, "global_position", end_pos, 0.8)


func _play_letter_animation(letter):
	var label = flying_letter.duplicate()

	add_child(label)

	label.visible = true
	label.text = letter

	label.reset_size()
	label.pivot_offset = label.size / 2
	label.global_position = get_global_mouse_position() - (label.size / 2)

	var tween := create_tween()
	tween.set_parallel(true)
	var target_pos := Vector2(10, 10)
	var duration := 2.0

	(
		tween
		. tween_property(label, "global_position", target_pos, duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(label, "modulate:a", 0.0, duration)
	tween.tween_property(label, "scale", Vector2(0.5, 0.5), duration)

	tween.chain().tween_callback(label.queue_free)
