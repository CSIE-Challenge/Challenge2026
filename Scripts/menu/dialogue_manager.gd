extends CanvasLayer

signal choice_selected(choice_index: int)
signal dialogue_finished
signal custom_event_triggered(event_name: String)

enum State { IDLE, TYPING, WAITING_TIME, WAITING_INPUT, WAITING_CHOICE, FINISHED }

const DEFAULT_SPEED = 0.03

var dialogue_queue: Array[String] = []
var current_choices: Array[String] = []
var current_state: State = State.IDLE
var active_commands: Dictionary = {}
var wait_timer: SceneTreeTimer = null

var selected_choice_index: int = 0
var choices_fully_appeared: bool = false
var choice_labels: Array[RichTextLabel] = []

@onready var dialogue_box = $Control/DialogueBox
@onready var rich_text_label = $Control/DialogueBox/MarginContainer/RichTextLabel
@onready var typewriter_timer = $TypewriterTimer
@onready var choice_container = $Control/DialogueBox/ChoiceContainer


func _ready():
	dialogue_box.hide()
	typewriter_timer.timeout.connect(_on_typewriter_timeout)


func _input(event):
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if current_state == State.TYPING or current_state == State.WAITING_TIME:
			_skip_typing()
		elif current_state == State.WAITING_INPUT:
			current_state = State.TYPING
			typewriter_timer.start()
		elif current_state == State.WAITING_CHOICE:
			if choices_fully_appeared:
				_confirm_choice()
		elif current_state == State.FINISHED:
			if dialogue_box.visible:
				_show_next_dialogue()

	# 選項操作 (滾輪與鍵盤上下)
	if current_state == State.WAITING_CHOICE and choices_fully_appeared:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_move_choice(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_move_choice(1)
		elif event.is_action_pressed("move_up"):
			_move_choice(-1)
		elif event.is_action_pressed("move_down"):
			_move_choice(1)


func start_dialogue(texts: Array[String], choices: Array[String] = []):
	dialogue_queue = texts.duplicate()
	current_choices = choices.duplicate()
	dialogue_box.show()
	_clear_choices()
	_show_next_dialogue()


func _show_next_dialogue():
	if dialogue_queue.is_empty():
		if current_choices.size() > 0:
			_show_choices()
		else:
			current_state = State.IDLE
			dialogue_box.hide()
			_set_glitch(0.0)
			dialogue_finished.emit()
		return

	var raw_text = dialogue_queue.pop_front()
	var parsed_text = _parse_commands(raw_text)

	rich_text_label.text = "[center]" + parsed_text + "[/center]"
	rich_text_label.visible_characters = 0
	typewriter_timer.wait_time = DEFAULT_SPEED

	current_state = State.TYPING
	_process_commands(0)

	if current_state == State.TYPING:
		typewriter_timer.start()


func interrupt_dialogue():
	dialogue_queue.clear()
	current_choices.clear()
	typewriter_timer.stop()
	if wait_timer and wait_timer.timeout.is_connected(_on_wait_finished):
		wait_timer.timeout.disconnect(_on_wait_finished)
	current_state = State.IDLE
	dialogue_box.hide()
	_set_glitch(0.0)
	dialogue_finished.emit()


func _parse_commands(text: String) -> String:
	var clean_text = ""
	active_commands.clear()
	var current_vis_chars = 0
	var i = 0

	while i < text.length():
		if text[i] == "<":
			var end = text.find(">", i)
			if end != -1:
				var cmd_str = text.substr(i + 1, end - i - 1)
				if not active_commands.has(current_vis_chars):
					active_commands[current_vis_chars] = []
				active_commands[current_vis_chars].append(cmd_str)
				i = end + 1
				continue

		clean_text += text[i]

		if text[i] == "[":
			var end = text.find("]", i)
			if end != -1:
				clean_text += text.substr(i + 1, end - i)
				i = end + 1
				continue

		current_vis_chars += 1
		i += 1

	return clean_text


func _on_typewriter_timeout():
	if current_state != State.TYPING:
		return

	if rich_text_label.visible_characters < rich_text_label.get_total_character_count():
		rich_text_label.visible_characters += 1
		_process_commands(rich_text_label.visible_characters)
	else:
		_finish_typing()


func _finish_typing():
	typewriter_timer.stop()
	if dialogue_queue.is_empty() and current_choices.size() > 0:
		_show_choices()
	else:
		current_state = State.FINISHED


func _process_commands(vis_chars: int):
	if not active_commands.has(vis_chars):
		return

	var cmds = active_commands[vis_chars]
	for cmd in cmds:
		if cmd.begins_with("wait="):
			var time = cmd.trim_prefix("wait=").to_float()
			_start_wait(time)
		elif cmd == "input":
			current_state = State.WAITING_INPUT
			typewriter_timer.stop()
		elif cmd.begins_with("speed="):
			var speed = cmd.trim_prefix("speed=").to_float()
			typewriter_timer.wait_time = speed
		elif cmd.begins_with("glitch="):
			var val = cmd.trim_prefix("glitch=").to_float()
			_set_glitch(val)
		elif cmd.begins_with("event="):
			var event_name = cmd.trim_prefix("event=")
			custom_event_triggered.emit(event_name)

	active_commands.erase(vis_chars)


func _start_wait(time: float):
	current_state = State.WAITING_TIME
	typewriter_timer.stop()
	wait_timer = get_tree().create_timer(time)
	wait_timer.timeout.connect(_on_wait_finished)


func _on_wait_finished():
	if current_state == State.WAITING_TIME:
		current_state = State.TYPING
		typewriter_timer.start()


func _skip_typing():
	if wait_timer and wait_timer.timeout.is_connected(_on_wait_finished):
		wait_timer.timeout.disconnect(_on_wait_finished)

	var remaining_keys = active_commands.keys()
	remaining_keys.sort()
	for k in remaining_keys:
		_process_commands(k)

	rich_text_label.visible_characters = -1
	_finish_typing()


func _set_glitch(val: float):
	if dialogue_box and dialogue_box.material is ShaderMaterial:
		dialogue_box.material.set_shader_parameter("glitch_active", val)


# ==========================================
# Choice System
# ==========================================


func _clear_choices():
	for child in choice_container.get_children():
		child.queue_free()
	choice_labels.clear()
	selected_choice_index = 0
	choices_fully_appeared = false


func _show_choices():
	current_state = State.WAITING_CHOICE
	choices_fully_appeared = false
	selected_choice_index = 0

	for i in range(current_choices.size()):
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.clip_contents = false
		label.add_theme_font_size_override("normal_font_size", 28)
		# 設定中心點以便於播放彈出縮放動畫
		label.custom_minimum_size = Vector2(300, 40)
		label.pivot_offset = label.custom_minimum_size / 2.0
		choice_container.add_child(label)
		choice_labels.append(label)

		# 初始透明與縮小
		label.modulate.a = 0.0
		label.scale = Vector2.ZERO

	_update_choice_visuals()

	# 進場動畫 (Tweens)
	var tween = create_tween().set_parallel(true)
	for i in range(choice_labels.size()):
		var label = choice_labels[i]
		var delay = i * 0.1  # 每個選項延遲 0.1 秒出現 (Stagger effect)

		# 彈出動畫
		(
			tween
			. tween_property(label, "scale", Vector2.ONE, 0.4)
			. set_trans(Tween.TRANS_ELASTIC)
			. set_ease(Tween.EASE_OUT)
			. set_delay(delay)
		)
		# 漸變動畫
		tween.tween_property(label, "modulate:a", 1.0, 0.2).set_delay(delay)

	# 所有動畫結束後才允許輸入
	tween.chain().tween_callback(func(): choices_fully_appeared = true)


func _move_choice(dir: int):
	selected_choice_index = clampi(selected_choice_index + dir, 0, current_choices.size() - 1)
	_update_choice_visuals()


func _update_choice_visuals():
	for i in range(choice_labels.size()):
		var label = choice_labels[i]
		if i == selected_choice_index:
			label.text = "[wave]▶ " + current_choices[i] + "[/wave]"
			label.self_modulate = Color(1.0, 1.0, 0.5)  # 高亮黃色
		else:
			label.text = "   " + current_choices[i]
			label.self_modulate = Color(0.6, 0.6, 0.6)  # 黯淡灰色


func _confirm_choice():
	current_state = State.IDLE  # 鎖定輸入，防止連點
	choices_fully_appeared = false

	# 退場動畫 (Tweens)
	var tween = create_tween().set_parallel(true)
	for i in range(choice_labels.size()):
		var label = choice_labels[i]
		if i == selected_choice_index:
			# 選中項放大並漸隱
			tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_SINE)
			tween.tween_property(label, "modulate:a", 0.0, 0.2).set_delay(0.2)
		else:
			# 未選中項縮小並瞬間漸隱
			tween.tween_property(label, "scale", Vector2(0.5, 0.5), 0.2)
			tween.tween_property(label, "modulate:a", 0.0, 0.2)

	# 動畫播完後發送信號並清理
	tween.chain().tween_callback(
		func():
			_clear_choices()
			var chosen = current_choices[selected_choice_index]  # 可以傳字串，但傳 index 較保險
			current_choices.clear()
			dialogue_box.hide()
			_set_glitch(0.0)
			choice_selected.emit(selected_choice_index)
	)
