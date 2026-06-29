extends Control

const HEAD_ROTATING_SPEED = 1080
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
@onready var collect_sfx = $CollectSfx
@onready var head1 = $Head1


func _ready() -> void:
	head1.visible = false


func _process(delta: float) -> void:
	head1.rotation_degrees += HEAD_ROTATING_SPEED * delta


func _on_close_pressed() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	SceneTransition.transition_to("res://Scenes/menu.tscn")


func _on_rich_text_label_meta_clicked(meta: Variant) -> void:
	var key = str(meta)
	if is_letter_collected[key] == false:
		collect_sfx.play()
		letter_collected_cnt += 1

	is_letter_collected[key] = true
	if letter_collected_cnt == 7:
		_on_all_collected()


func play_animation(node):
	var screen_size = get_viewport_rect().size
	var center_y = screen_size.y / 2

	var start_pos = Vector2(-500, center_y)
	var center_pos = Vector2(screen_size.x / 2, center_y)
	var end_pos = Vector2(screen_size.x + 500, center_y)
	node.global_position = start_pos
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "global_position", center_pos, 0.8)
	tween.tween_interval(0.2)
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(node, "global_position", end_pos, 0.8)


func _on_all_collected():
	head1.visible = true
	play_animation(head1)
