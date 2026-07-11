extends Control

const HEAD_ROTATING_SPEED = 360
const HiddenGameController = preload("res://Scripts/menu/hidden_game_controller.gd")

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
var head_click_cnt = 0

@onready var heads = [$Head1, $Head2, $Head3]
@onready var flying_letter = $FlyingLetter
@onready var collected_label = $CollectedLetter
@onready var richtextlabel = $Panel/RichTextLabel


func _ready() -> void:
	for h in heads:
		h.visible = false
	flying_letter.visible = false

	richtextlabel.text = richtextlabel.text.replace("x.y.z", Global.game_version)

	if PlayerData.has_entered_hidden_game:
		$"Panel/HBoxContainer/Scerct Stage".visible = true


func _process(delta: float) -> void:
	if head:
		head.rotation_degrees += HEAD_ROTATING_SPEED * delta
		head.modulate = Color(1, 1 - 0.15 * head_click_cnt, 1 - 0.15 * head_click_cnt)
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


func _on_sprite_input(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (
		event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	):
		return
	if not viewport.visible:
		return

	head_click_cnt += 1
	if head_click_cnt >= 5:
		print("Hidden game unlocked.")
		PlayerData.has_entered_hidden_game = true
		if head and head.texture:
			PlayerData.last_selected_avatar = head.texture.resource_path
		PlayerData.save_data()

		HiddenGameController.reset_dialogue_state()
		SceneTransition.transition_to("res://Scenes/menu/hidden_game.tscn")


func _on_all_collected():
	head = heads.pick_random()
	for i in range(len(heads)):
		heads[i].visible = false
		heads[i].z_index = -999
	_play_head_animation()


func _play_head_animation():
	head.visible = true
	head.z_index = 999
	head_click_cnt = 0

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

	tween.chain().tween_callback(
		func():
			label.queue_free()
			_update_collected_label()
	)


func _update_collected_label() -> void:
	var bbcodes = []
	bbcodes.resize(is_letter_collected.size())
	bbcodes.fill("")

	for key in is_letter_collected:
		var idx = int(key[0])
		var char = key[key.length() - 1]
		if is_letter_collected[key]:
			bbcodes[idx] = char
		else:
			bbcodes[idx] = "[color=transparent]" + char + "[/color]"
	collected_label.text = "".join(bbcodes)


func _on_secret_stage_pressed() -> void:
	Audio.play_sfx(Audio.SFX.BUTTON_PRESS)
	HiddenGameController.reset_dialogue_state()
	SceneTransition.transition_to("res://Scenes/menu/hidden_game.tscn")
