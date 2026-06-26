extends Control

const MENU_SCENE_PATH = "res://Scenes/Menu/menu.tscn"

var attack_ball_scene = preload("res://Scenes/Menu/attack_ball.tscn")
var is_player_dead: bool = false

@onready var walls: Node2D = $Panel/Stage/Walls
@onready var timer: Timer = $Timer

# Boss related
@onready var stage = $Panel/Stage  # 用來做畫面震動
@onready var boss = $Panel/Stage/boss
@onready var player = $Panel/Stage/coconut


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if player:
		player.auto_restart = false
		player.player_died.connect(_on_player_died)

	Dialogue.custom_event_triggered.connect(_on_dialogue_event)

	# 隱藏關卡開始時，立刻執行情節序列
	run_hidden_game_sequence()


func _on_player_died() -> void:
	is_player_dead = true
	# 若玩家死亡時對話正在進行，立刻打斷
	if Dialogue.current_state != Dialogue.State.IDLE:
		Dialogue.interrupt_dialogue()


func _on_dialogue_event(event_name: String):
	if event_name == "sneak_attack":
		boss.sneak_attack()


func wait_or_die(time: float) -> bool:
	var t = 0.0
	while t < time:
		await get_tree().process_frame
		if is_player_dead:
			return true
		t += get_process_delta_time()
	return is_player_dead


func wait_for_boss_attack_or_die() -> bool:
	while boss.is_attacking:
		await get_tree().process_frame
		if is_player_dead:
			return true
	return is_player_dead


func run_hidden_game_sequence() -> void:
	timer.stop()
	walls.tween_box(Vector2(400, 400), Vector2(0, 20), 1.0)
	boss.boss_appear_animation()
	await get_tree().create_timer(1.0).timeout

	if await _run_phase_1():
		return
	if await _run_phase_2():
		return
	if await _run_phase_3():
		return
	if await _run_phase_4():
		return


func _run_phase_1() -> bool:
	Dialogue.start_dialogue(
		["呃，你誰？<input>", "怎麼找到這裡的？<input>", "喔，嫌這個遊戲太簡單是吧。<input>", "那就別怪我不客氣了！<input>"]
	)
	await Dialogue.dialogue_finished

	for i in range(3):
		boss.test_sword_attack()
		if await wait_or_die(1.0):
			break

	if not is_player_dead:
		await wait_or_die(1.5)

	if is_player_dead:
		Dialogue.start_dialogue(["怎麼這就死了？"])
		await Dialogue.dialogue_finished
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true

	return false


func _run_phase_2() -> bool:
	Dialogue.start_dialogue(
		["哦？躲得不錯嘛。<input>", "但接下來這招，[wave]<speed=0.1>你還能如此從容嗎？<glitch=1>[/wave]"]
	)
	await Dialogue.dialogue_finished

	for mode in range(3, 6):
		boss.emit_boomerang(mode)
		if await wait_for_boss_attack_or_die():
			break

	if is_player_dead:
		Dialogue.start_dialogue(["看來你不喜歡迴力鏢。"])
		await Dialogue.dialogue_finished
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true

	return false


func _run_phase_3() -> bool:
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

	if is_player_dead:
		Dialogue.start_dialogue(["哈！會追著你的就沒辦法了吧！"])
		await Dialogue.dialogue_finished
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true

	# 沒死，進行談判選項
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

	if boss.is_attacking:
		await wait_for_boss_attack_or_die()

	if is_player_dead:
		Dialogue.start_dialogue(["嘿嘿，誰說說話時不能攻擊的？"])
		await Dialogue.dialogue_finished
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true
	else:
		Dialogue.start_dialogue(["可惡，竟然閃過了我的偷襲。<input>", "那你更加留不得了，受死吧！"])
		await Dialogue.dialogue_finished

	return false


func _run_phase_4() -> bool:
	# ----------------- 第三波流程 -----------------
	boss.rhythm_attack()
	# rhythm_attack 不會立刻結束，我們等待它執行完畢
	if await wait_for_boss_attack_or_die():
		Dialogue.start_dialogue(["原來你不玩pjsk啊。"])
		await Dialogue.dialogue_finished
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true

	# 沒死，開始碎碎念
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
		await get_tree().process_frame
		if is_player_dead:
			break

	if is_player_dead:
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true

	# 如果 boss 被打到，打斷當前的碎碎念對話
	if Dialogue.current_state != Dialogue.State.IDLE:
		Dialogue.interrupt_dialogue()

	# 立刻開始新的對話
	Dialogue.start_dialogue(["你...你竟然也偷襲我！<input>", "好啊，既然你不仁我不義，那麼戰個你死我活吧！<input>"])
	await Dialogue.dialogue_finished

	# 發動雷射攻擊
	boss.test_laser_attack()
	if await wait_for_boss_attack_or_die():
		SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
		return true

	# 連續發動 squeeze_attack 4 次
	for i in range(4):
		boss.squeeze_attack()
		if await wait_for_boss_attack_or_die():
			SceneTransition.transition_to("res://Scenes/hidden_game.tscn")
			return true

	# 最後進入隨機模式
	# 隨機生成能量球開啟
	timer.wait_time = 5.0
	timer.start()
	boss.rand_attack()
	return false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file(MENU_SCENE_PATH)


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
