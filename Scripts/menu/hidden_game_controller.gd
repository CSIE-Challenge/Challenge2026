extends Control

const MENU_SCENE_PATH = "res://Scenes/menu.tscn"
const HIDDEN_SCENE_PATH = "res://Scenes/menu/hidden_game.tscn"

static var has_reached_fight: bool = false
static var has_reached_phase_2: bool = false
static var seen_dialogues: Dictionary = {}
static var has_shown_difficult_warning: bool = false
static var has_reached_difficult_phase_2: bool = false

@export var skip_to_fight: bool = false

var attack_ball_scene = preload("res://Scenes/menu/attack_ball.tscn")
var is_player_dead: bool = false
var is_aborted: bool = false  # 是否已經在 change scene

@onready var walls: Node2D = $Panel/Stage/Walls
@onready var timer: Timer = $Timer

# Boss related
@onready var stage = $Panel/Stage  # 用來做畫面震動
@onready var boss = $Panel/Stage/boss
@onready var player = $Panel/Stage/coconut

@onready var black_screen = $CanvasLayer/BlackScreen
@onready var warning_text = $CanvasLayer/BlackScreen/WarningText


static func reset_dialogue_state() -> void:
	seen_dialogues.clear()
	has_reached_fight = false
	has_reached_phase_2 = false
	has_shown_difficult_warning = false
	has_reached_difficult_phase_2 = false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not PlayerData.has_entered_hidden_game:
		PlayerData.has_entered_hidden_game = true
		PlayerData.save_data()

	if PlayerData.equipped_skin == "undertale_skin":
		Audio.set_bgm(Audio.BGM.HIDDEN_GAME_UNDERTALE)
	else:
		Audio.set_bgm(Audio.BGM.HIDDEN_GAME)
	if player:
		player.player_died.connect(_on_player_died)

	if walls:
		walls.reset_box(0.7)
	Dialogue.custom_event_triggered.connect(_on_dialogue_event)

	black_screen.visible = false
	warning_text.visible = false

	# 隱藏關卡開始時，先等待 0.8 秒讓黑幕轉場拉開
	if PlayerData.equipped_skin == "golden_skin":
		run_difficult_hidden_game_sequence()
	else:
		await get_tree().create_timer(0.8).timeout
		run_hidden_game_sequence()
	# await get_tree().create_timer(1.0).timeout
	# boss.rand_attack(5)


func _on_player_died() -> void:
	is_player_dead = true
	Audio.stop_all_sfx()
	# 若玩家死亡時對話正在進行，立刻打斷
	if Dialogue.current_state != Dialogue.State.IDLE:
		Dialogue.interrupt_dialogue()


func _on_dialogue_event(event_name: String):
	if event_name == "sneak_attack":
		boss.sneak_attack()


func wait_or_die(time: float) -> bool:
	var t = 0.0
	while t < time and not is_aborted:
		if not is_inside_tree():
			return true
		await get_tree().process_frame
		if is_player_dead or is_aborted:
			return true
		t += get_process_delta_time()
	return is_player_dead or is_aborted


func wait_for_boss_attack_or_die() -> bool:
	while boss.is_attacking and not is_aborted:
		if not is_inside_tree():
			return true
		await get_tree().process_frame
		if is_player_dead or is_aborted:
			return true
	return is_player_dead or is_aborted


func run_hidden_game_sequence() -> void:
	Dialogue.is_disabled = false
	player.auto_restart = false
	timer.stop()
	walls.reset_box(1.0)
	boss.boss_appear_animation()

	if not is_inside_tree():
		return
	is_aborted = false

	await get_tree().create_timer(3.2).timeout

	if has_reached_phase_2:
		boss.invincible = false
		boss.phase = 2
		boss.current_difficulty = 3
		boss.boss_hp = 250
		boss.boss_hp_bar.max_value = 250
		boss.boss_hp_bar.value = boss.boss_hp
		if await _run_phase_5_final():
			return
	elif skip_to_fight or has_reached_fight:
		boss.invincible = false
		boss.boss_hp = 100
		boss.boss_hp_bar.max_value = 100
		boss.boss_hp_bar.value = boss.boss_hp
		if await _run_phase_4_fight() or is_aborted:
			return
	else:
		if await _run_phase_1() or is_aborted:
			return
		if await _run_phase_2() or is_aborted:
			return
		if await _run_phase_3() or is_aborted:
			return
		if await _run_phase_4_intro() or is_aborted:
			return
		if await _run_phase_4_fight() or is_aborted:
			return


func _run_phase_1() -> bool:
	if is_aborted:
		return true

	if not seen_dialogues.has("intro_1"):
		seen_dialogues["intro_1"] = true
		Dialogue.start_dialogue(
			["呃，你誰？<input>", "怎麼找到這裡的？<input>", "喔，嫌這個遊戲太簡單是吧。<input>", "那就別怪我不客氣了！<input>"]
		)
		await Dialogue.dialogue_finished
	else:
		await get_tree().create_timer(1.0).timeout

	for i in range(3):
		boss.test_sword_attack(2)
		if await wait_or_die(1.5):
			break

	if not is_player_dead:
		await wait_or_die(1.5)

	if is_player_dead and not is_aborted:
		if not seen_dialogues.has("death_1"):
			seen_dialogues["death_1"] = true
			Dialogue.start_dialogue(["怎麼這就死了？"])
			await Dialogue.dialogue_finished
		else:
			await get_tree().create_timer(1.0).timeout
		SceneTransition.transition_to_distortion(HIDDEN_SCENE_PATH)
		return true

	return false


func _run_phase_2() -> bool:
	if is_aborted:
		return true

	if not seen_dialogues.has("intro_2"):
		seen_dialogues["intro_2"] = true
		Dialogue.start_dialogue(
			["哦？躲得不錯嘛。<input>", "但接下來這招，[wave]<speed=0.1>你還能如此從容嗎？<glitch=1>[/wave]"]
		)
		await Dialogue.dialogue_finished
	else:
		await get_tree().create_timer(1.0).timeout

	for mode in range(3, 6):
		boss.emit_boomerang(mode, 2)
		if await wait_for_boss_attack_or_die():
			break

	if is_player_dead and not is_aborted:
		if not seen_dialogues.has("death_2"):
			seen_dialogues["death_2"] = true
			Dialogue.start_dialogue(["看來你不喜歡迴力鏢。"])
			await Dialogue.dialogue_finished
		else:
			await get_tree().create_timer(1.0).timeout
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true

	return false


func _run_phase_3() -> bool:
	if is_aborted:
		return true

	# ----------------- 新增的流程 -----------------

	Dialogue.start_dialogue(["嘖，比想像中難纏呢。"])
	await Dialogue.dialogue_finished

	# 只釋放兩個火箭
	for i in range(2):
		boss.spawn_homing_rocket(randf_range(0, PI * 2), 200.0, 65.0, 1.5, 0.8)
		if await wait_or_die(0.5):
			break

	# 等待火箭爆炸 (1.5秒爆炸時間 + 稍作緩衝)
	if not is_player_dead:
		await wait_or_die(5.0)

	if is_player_dead and not is_aborted:
		if not seen_dialogues.has("death_3_rocket"):
			seen_dialogues["death_3_rocket"] = true
			Dialogue.start_dialogue(["哈！會追著你的就沒辦法了吧！"])
			await Dialogue.dialogue_finished
		else:
			await get_tree().create_timer(1.0).timeout
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true
	if not seen_dialogues.has("intro_3"):
		seen_dialogues["intro_3"] = true
		Dialogue.start_dialogue(
			["好吧，看來我們得談談。<input>", "今天是你突然闖進我的地盤。<input>", "那你來到這裡......所謂何事？"],
			["取你項上人頭", "我也不知道", "請跟我結婚"]
		)
		var choice = await Dialogue.choice_selected

		if choice == 0:
			Dialogue.start_dialogue(["我們不要一見面就動動手動腳的<event=sneak_attack>......這世界還有許多美好的事，對吧？"])
		elif choice == 1:
			Dialogue.start_dialogue(["那你來到我這兒，擾人清夢<event=sneak_attack>做甚？難不成是因為你覺得我好欺負？"])
		elif choice == 2:
			Dialogue.start_dialogue(["蛤？你這私闖民宅的小鬼頭<event=sneak_attack>，竟然突然就這樣連結婚戒指都沒有的情況下..."])

		# 等待對話結束 (若玩家死亡會在此被打斷，is_player_dead 變為 true)
		await Dialogue.dialogue_finished
	else:
		await get_tree().create_timer(1.0).timeout
		boss.sneak_attack()

	if boss.is_attacking:
		await wait_for_boss_attack_or_die()

	if is_player_dead and not is_aborted:
		if not seen_dialogues.has("death_3_1"):
			seen_dialogues["death_3_1"] = true
			Dialogue.start_dialogue(["嘿嘿，誰說說話時不能攻擊的？"])
			await Dialogue.dialogue_finished
		else:
			await get_tree().create_timer(1.0).timeout
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true
	else:
		if not seen_dialogues.has("death_3_2"):
			seen_dialogues["death_3_2"] = true
			Dialogue.start_dialogue(["可惡，竟然閃過了我的偷襲。<input>", "那你更加留不得了，受死吧！"])
			await Dialogue.dialogue_finished
		else:
			await get_tree().create_timer(1.0).timeout

	return false


func _run_phase_4_intro() -> bool:
	if is_aborted:
		return true
	# ----------------- 第三波流程 -----------------
	boss.rhythm_attack(2)
	# rhythm_attack 不會立刻結束，我們等待它執行完畢
	if await wait_for_boss_attack_or_die():
		if not seen_dialogues.has("death_4"):
			seen_dialogues["death_4"] = true
			Dialogue.start_dialogue(["原來你不玩pjsk啊。"])
			await Dialogue.dialogue_finished
		else:
			await get_tree().create_timer(1.0).timeout
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true

	# 沒死，開始碎碎念
	if not seen_dialogues.has("intro_4"):
		seen_dialogues["intro_4"] = true
		Dialogue.start_dialogue(
			[
				"其實一個人待在這邊挺寂寞的<input>",
				"成天守在光鮮亮麗的遊戲背後......<input>",
				"我也想跟那些主角一樣，有著自己的故事。<input>",
				"但現實總是殘酷的，沒人會記得一個隱藏關卡的boss。<input>",
				"你說對吧？......<input>",
				"反正你也聽不懂，我就隨便說說罷了。<input>",
				"這年頭當個反派還真是不容易啊。<input>"
			]
		)

	# 在場地中隨機生成一個攻擊球
	_random_generate_attack_ball()

	var initial_hp = boss.boss_hp

	# 卡住流程，直到玩家拿球砸到 boss (HP減少)，或是玩家中途死掉
	while boss.boss_hp >= initial_hp:
		if not is_inside_tree():
			return false
		await get_tree().process_frame
		if is_player_dead:
			break

	if is_player_dead:
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true

	# 如果 boss 被打到，打斷當前的碎碎念對話
	if Dialogue.current_state != Dialogue.State.IDLE:
		Dialogue.interrupt_dialogue()

	return false


func _run_phase_4_fight() -> bool:
	has_reached_fight = true

	if not seen_dialogues.has("fight_intro"):
		seen_dialogues["fight_intro"] = true
		# 立刻開始新的對話
		Dialogue.start_dialogue(["你...你竟然也偷襲我！<input>", "好啊，既然你不仁我不義，那麼戰個你死我活吧！<input>"])
		await Dialogue.dialogue_finished
	else:
		await get_tree().create_timer(1.0).timeout

	# 發動雷射攻擊
	boss.test_laser_attack(2)
	if await wait_for_boss_attack_or_die():
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true

	# 連續發動 squeeze_attack 4 次
	for i in range(4):
		boss.squeeze_attack(2)
		if await wait_for_boss_attack_or_die():
			SceneTransition.transition_to(HIDDEN_SCENE_PATH)
			return true

	# 最後進入隨機模式
	# 隨機生成能量球開啟
	timer.wait_time = 5.0
	timer.start()

	# 綁定第一階段死亡對話
	boss.boss_died_first_time.connect(
		func():
			has_reached_phase_2 = true
			if Dialogue.current_state != Dialogue.State.IDLE:
				Dialogue.interrupt_dialogue()

			# 暫停 Boss 的攻擊
			boss.is_paused = true

			# 確保場地 Box 回歸初始大小
			walls.reset_box(1.0)
			timer.stop()
			Dialogue.start_dialogue(["[color=red][wave]我真的生氣了！<speed=0.1>[/wave][/color]"])

			await Dialogue.dialogue_finished
			# 對話結束後，允許 Boss 繼續攻擊
			boss.is_paused = false
			timer.start()
	)

	return await _run_phase_5_final()


func _run_phase_5_final() -> bool:
	timer.wait_time = 5.0
	timer.start()
	boss.rand_attack()

	# 持續監控，如果在隨機模式中死亡則重置，如果 Boss 死亡則進行最終演出
	while not is_player_dead and not boss.is_dead:
		if not is_inside_tree():
			return false
		await get_tree().process_frame

	if is_player_dead:
		SceneTransition.transition_to(HIDDEN_SCENE_PATH)
		return true

	if boss.is_dead:
		timer.stop()
		if Dialogue.current_state != Dialogue.State.IDLE:
			Dialogue.interrupt_dialogue()
		Dialogue.start_dialogue(["我竟然落敗了......<wait=3.0>"])
		await Dialogue.dialogue_finished

		if not PlayerData.has_skin("golden_skin"):
			var code = Marshalls.base64_to_utf8("UTcxTjhNVFpYMjcySFBPRVZCOU8=")
			PlayerData.add_entered_code(code)
			PlayerData.skin_unlocked.emit("golden_skin")
			SceneTransition.show_achievement("獲得成就：黃金傳說！")

		# 播放死亡動畫
		boss.play_death_animation()

		# 等待死亡動畫完成 (約3.4秒)
		await get_tree().create_timer(3.5).timeout

		# 顯示 Complete!
		Audio.play_sfx(Audio.SFX.HIDDEN_GAME_COMPLETE)
		var complete_screen = $CanvasLayer/CompleteScreen
		complete_screen.show()
		var cr = complete_screen.get_node("ColorRect")
		var lbl = complete_screen.get_node("Label")
		lbl.text = "Complete!"
		var particles = complete_screen.get_node("CPUParticles2D")

		particles.emitting = true

		cr.modulate = Color(1, 1, 1, 0)
		lbl.scale = Vector2(0, 0)
		lbl.modulate = Color(2, 2, 2, 1)  # 高光亮起
		lbl.get_node("ShineRect").material.set_shader_parameter("shine_progress", 0.0)

		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(cr, "modulate", Color(1, 1, 1, 1), 0.5)
		tw.tween_property(lbl, "scale", Vector2(1, 1), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(
			Tween.EASE_OUT
		)
		tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 1.0)

		var tw_shine = create_tween()
		tw_shine.tween_interval(0.8)
		tw_shine.tween_property(
			lbl.get_node("ShineRect").material, "shader_parameter/shine_progress", 1.0, 1.5
		)

		# 強制顯示 5 秒
		await get_tree().create_timer(5.0).timeout

		# 五秒後，等待玩家按下空白鍵或確認鍵
		while true:
			if not is_inside_tree():
				return false
			await get_tree().process_frame
			if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
				break

		# 玩家按下後，呼叫 SceneTransition 的淡出轉場回主選單
		Dialogue.is_disabled = true
		Audio.stop_all_sfx()
		SceneTransition.transition_to_fade(MENU_SCENE_PATH)
		return true

	return false


func run_difficult_hidden_game_sequence() -> void:
	Dialogue.is_disabled = false
	player.auto_restart = false
	timer.stop()
	walls.reset_box(1.0)

	if not has_shown_difficult_warning and not has_reached_difficult_phase_2:
		has_shown_difficult_warning = true
		black_screen.visible = true
		await get_tree().create_timer(2.0).timeout
		warning_text.visible = true
		await get_tree().create_timer(3.0).timeout
		black_screen.visible = false
		warning_text.visible = false

	if is_player_dead or is_aborted:
		return

	if has_reached_difficult_phase_2:
		boss.boss_hp = 600
		boss.boss_hp_bar.max_value = 1200
		boss.boss_hp_bar.value = boss.boss_hp
		boss.invincible = false

		boss.boss_appear_animation_2()
		if not is_inside_tree():
			return
		is_aborted = false
		await get_tree().create_timer(3.2).timeout

		if is_player_dead or is_aborted:
			return

		timer.start(2.5)
		boss.difficult_rand_attack(5)

		while not is_player_dead and not is_aborted and not boss.is_dead:
			await get_tree().process_frame

		if is_player_dead:
			SceneTransition.transition_to(HIDDEN_SCENE_PATH)
			return
		if is_aborted:
			return
	else:
		boss.boss_hp = 1200
		boss.boss_hp_bar.max_value = 1200
		boss.boss_hp_bar.value = boss.boss_hp
		boss.invincible = false

		boss.boss_appear_animation_2()
		if not is_inside_tree():
			return
		is_aborted = false
		await get_tree().create_timer(3.2).timeout

		if is_player_dead or is_aborted:
			return

		timer.start(2.5)
		boss.rand_attack(4)

		while not is_player_dead and not is_aborted and boss.boss_hp > 600 and not boss.is_dead:
			await get_tree().process_frame

		if is_player_dead:
			SceneTransition.transition_to(HIDDEN_SCENE_PATH)
			return
		if is_aborted:
			return

		if boss.boss_hp <= 600 and not boss.is_dead:
			has_reached_difficult_phase_2 = true
			boss.is_change_stage = true
			boss._cleanup_attack()
			await get_tree().process_frame
			if is_player_dead or is_aborted:
				return
			boss.is_paused = true
			walls.reset_box(1.0)
			await get_tree().create_timer(2.0).timeout
			boss.is_paused = false

			boss.difficult_rand_attack(5)

			while not is_player_dead and not is_aborted and not boss.is_dead:
				await get_tree().process_frame

			if is_player_dead:
				SceneTransition.transition_to(HIDDEN_SCENE_PATH)
				return
			if is_aborted:
				return

	if boss.is_dead:
		timer.stop()
		await _run_difficult_boss_victory_sequence()


func _run_difficult_boss_victory_sequence() -> void:
	if Dialogue.current_state != Dialogue.State.IDLE:
		Dialogue.interrupt_dialogue()
	Dialogue.start_dialogue(["不可能！"])
	await Dialogue.dialogue_finished

	if not PlayerData.has_skin("sans_skin"):
		PlayerData.unlocked_skins.append("sans_skin")
		PlayerData.save_data()
		PlayerData.skin_unlocked.emit("sans_skin")
		SceneTransition.show_achievement("獲得成就：傳說之上！")

	boss.play_death_animation()

	await get_tree().create_timer(3.5).timeout

	Audio.play_sfx(Audio.SFX.HIDDEN_GAME_COMPLETE)
	var complete_screen = $CanvasLayer/CompleteScreen
	complete_screen.show()
	var cr = complete_screen.get_node("ColorRect")
	var lbl = complete_screen.get_node("Label")
	var particles = complete_screen.get_node("CPUParticles2D")

	particles.emitting = true

	cr.modulate = Color(1, 1, 1, 0)
	lbl.scale = Vector2(0, 0)
	lbl.modulate = Color(2, 2, 2, 1)
	lbl.text = "Victory!!"
	lbl.get_node("ShineRect").material.set_shader_parameter("shine_progress", 0.0)

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(cr, "modulate", Color(1, 1, 1, 1), 0.5)
	tw.tween_property(lbl, "scale", Vector2(1, 1), 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 1.0)

	var tw_shine = create_tween()
	tw_shine.tween_interval(0.8)
	tw_shine.tween_property(
		lbl.get_node("ShineRect").material, "shader_parameter/shine_progress", 1.0, 1.5
	)

	await get_tree().create_timer(5.0).timeout

	while true:
		if not is_inside_tree():
			return
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
			break

	Dialogue.is_disabled = true
	Audio.stop_all_sfx()
	SceneTransition.transition_to_fade(MENU_SCENE_PATH)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


# Exit scene
func _unhandled_input(event: InputEvent) -> void:
	if is_aborted:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		is_aborted = true
		if Dialogue.current_state != Dialogue.State.IDLE:
			Dialogue.interrupt_dialogue()
		Dialogue.is_disabled = true
		Dialogue.dialogue_box.hide()
		Dialogue.dialogue_queue.clear()
		Audio.stop_all_sfx()
		SceneTransition.transition_to_fade(MENU_SCENE_PATH)


func _random_generate_attack_ball():
	var ball = attack_ball_scene.instantiate()
	$Panel/Stage.add_child(ball)
	var half_size = walls.current_half_size
	var safe_limit_x = maxf(half_size.x - 25.0, 10.0)
	var safe_limit_y = maxf(half_size.y - 25.0, 10.0)
	ball.position = (
		walls.position
		+ Vector2(
			randf_range(-safe_limit_x, safe_limit_x), randf_range(-safe_limit_y, safe_limit_y)
		)
	)


func _on_timer_timeout() -> void:
	_random_generate_attack_ball()


func shake_screen(duration: float, intensity: float):
	var shake_tween = create_tween()
	var orig_stage_pos = stage.position

	var steps = int(duration / 0.04)
	for i in range(steps):
		var random_offset = Vector2(
			randf_range(-intensity, intensity), randf_range(-intensity, intensity)
		)
		intensity *= 0.85
		shake_tween.tween_property(stage, "position", orig_stage_pos + random_offset, 0.04)

	shake_tween.tween_property(stage, "position", orig_stage_pos, 0.04)
