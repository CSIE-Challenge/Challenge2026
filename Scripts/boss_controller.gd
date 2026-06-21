extends Node2D

const ATTACK_SWORD_SCENE = preload("res://Scenes/attack_sword.tscn")
const FALLING_NOTE_SCENE = preload("res://Scenes/falling_note.tscn")

# 記錄 Boss 的初始待機位置，以便招式施展後歸位
var original_position: Vector2
var is_attacking: bool = false

# 紀路 Boss 血量
var boss_hp: int
var invincible: bool

@onready var boss = self
@onready var boss_circle = $Sprites/circle
@onready var boss_square = $Sprites/square
@onready var hidden_game = $"../../.."

# 取得椰子玩家的參照
@onready var player = $"../coconut"

# 取得 Boss 的碰撞與視覺節點
@onready var damage_field = $"../damagefield"
@onready var sprites = $Sprites  # 注意：Sprites 在場景中必須是 Node2D 類型

# Boss 的血條
@onready var boss_hp_bar: ProgressBar = $"../../../CanvasLayer/BossHpBar"


func _ready() -> void:
	# 記錄初始位置
	original_position = position
	invincible = true
	boss_hp = 100
	boss_hp_bar.value = 100


func _unhandled_input(event: InputEvent) -> void:
	if is_attacking:
		return

	# 使用鍵盤的 1, 2, 3 鍵來測試不同的招式
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				print("觸發招式一：縮小場地")
				rhythm_attack()
			KEY_2:
				print("觸發招式二：跳躍壓擊")
				jump_slam_attack()
			KEY_3:
				print("觸發招式三：橫向掃擊")
				sweep_attack()
			KEY_4:
				print("觸發測試招式：環形飛劍攻擊")
				test_sword_attack()


func rand_attack():
	while true:
		if not is_attacking:
			var rand_val = randi_range(0, 1)
			match rand_val:
				0:
					rhythm_attack()
				1:
					test_sword_attack()
		await get_tree().create_timer(0.5).timeout
		while is_attacking:
			await get_tree().create_timer(0.1).timeout


func rhythm_attack() -> void:
	if not is_instance_valid(player):
		if has_node("../coconut"):
			player = get_node("../coconut")
		else:
			print("未能在場上找到有效的玩家椰子，中斷招式")
			return

	is_attacking = true

	var walls = get_node("../Walls")
	var target_y = 180.0
	var target_height = 45.0
	var target_width = 800.0

	# 1. 壓縮牆壁到 400x45 的超扁平判定線長條，移動到 (0, 180) 的下方位置
	if walls:
		walls.tween_box(Vector2(target_width, target_height), Vector2(0, target_y), 1.0)

	# 等待牆壁收縮與平移完成
	await get_tree().create_timer(1.2).timeout

	# 2. 開始降落落鍵 (發射 15 波，每波間隔 0.35 秒，節奏緊湊)
	var waves = 15
	for w in range(waves):
		# 如果 Boss 已經沒血了就停止攻擊
		if boss_hp <= 0:
			break

		# 🌟【安全防禦檢查】如果發射過程中玩家死掉了，就立刻中斷招式，避免後續拋錯
		if not is_instance_valid(player):
			break

		# 隨機產生落鍵的寬度 (60 到 110 像素)
		var width = randf_range(40.0, 200.0)

		# 隨機 X 軸落點 (確保落鍵的兩側邊緣不會超出 400 寬度的判定區範圍)
		var limit_x = (target_width / 2.0) - (width / 2.0)
		var spawn_x = randf_range(-limit_x, limit_x)

		# 計算 Stage 的世界 X 座標中心 (作為 3D 透視落下的遠處焦點)
		var center_world_x = global_position.x + (walls.position.x - position.x)

		# 計算落點與起點的世界座標
		var target_world_x = center_world_x + spawn_x
		var global_spawn_y = global_position.y + (-300.0 - position.y)  # 從上方螢幕外落下
		var global_target_y = global_position.y + (walls.position.y - position.y)  # 判定線世界 Y

		# 實例化落鍵並加到關卡 (加到 Stage 下作為 walls 的兄弟節點，這樣座標不受 walls 收縮影響)
		var note = FALLING_NOTE_SCENE.instantiate()
		get_parent().add_child(note)

		# 初始化落鍵：目標世界X, 起點世界Y, 判定線世界Y, 中心點世界X, 寬度, 判定區高度, 速度 450.0, 玩家
		note.init(
			target_world_x,
			global_spawn_y,
			global_target_y,
			center_world_x,
			width,
			target_height,
			450.0,
			player
		)

		# 每波下落的間隔時間為 0.35 秒
		await get_tree().create_timer(0.35).timeout

	# 等待最後一波落鍵降落與紅色殘影完全消失
	await get_tree().create_timer(1.8).timeout

	# 3. 招式結束，將牆壁還原到原本的大小與位置
	if walls:
		walls.reset_box(0.7)

	await get_tree().create_timer(0.8).timeout
	is_attacking = false


# ==================== 招式二：跳躍壓擊 (Jump Slam Attack) ====================
# Boss 向上飛出螢幕，鎖定玩家的 X 軸，接著從天而降砸向玩家，隨後回到原位。
func jump_slam_attack() -> void:
	if not player:
		return
	is_attacking = true

	var tween = create_tween()

	# 1. 躍起：往上飛出螢幕外 (-600 像素)
	(
		tween
		. tween_property(self, "position", position + Vector2(0, -600), 0.4)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)

	# 2. 鎖定：在空中隱形移動到玩家正上方，稍微停頓
	var target_x = player.position.x
	tween.tween_callback(func(): position = Vector2(target_x, original_position.y - 600))
	tween.tween_interval(0.25)

	# 3. 下砸：快速砸向地面的玩家位置
	var target_y = player.position.y
	(
		tween
		. tween_property(self, "position", Vector2(target_x, target_y), 0.25)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)

	# 4. 震地停頓
	tween.tween_interval(0.4)

	# 5. 歸位：飛回原本待機位置
	(
		tween
		. tween_property(self, "position", original_position, 0.6)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	await tween.finished
	is_attacking = false


# ==================== 招式三：橫向掃擊 (Sweep Attack) ====================
# Boss 移動到螢幕最左側外，然後平行橫掃到最右側外，最後回到原位。
func sweep_attack() -> void:
	is_attacking = true

	var tween = create_tween()
	# 假設戰鬥邊界大約在 -250 到 250 之間
	var left_start = Vector2(-350, original_position.y)
	var right_end = Vector2(350, original_position.y)

	# 1. 退場：移動到左側外準備
	tween.tween_property(self, "position", left_start, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)

	# 2. 橫掃：從左至右快速滑過螢幕
	tween.tween_property(self, "position", right_end, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN_OUT
	)

	# 3. 歸位：從右側游回原本中心點
	(
		tween
		. tween_property(self, "position", original_position, 0.5)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	await tween.finished
	is_attacking = false


# by gemini
func boss_appear_animation():
	if not boss or not boss_circle or not boss_square:
		return

	# ==================== 動態參數設定區 (方便您在此統一調整) ====================
	# 1. 圓形與方形的基礎尺寸 (取代原本的 Vector2(0.2, 0.2))
	var base_circle_scale := Vector2(1.0, 1.0)
	var base_square_scale := Vector2(1.0, 1.0)

	# 2. 各階段動畫的持續時間 (秒)
	var fly_in_duration: float = 0.6  # 飛入時間
	var squash_duration: float = 0.06  # 撞擊擠壓變形時間
	var stretch_duration: float = 0.1  # 彈開拉長變形時間
	var settle_duration: float = 0.15  # 回歸正常尺寸時間

	# 3. 變形倍率 (會自動與基礎尺寸相乘)
	var start_scale_mult: float = 4.0  # 出現時的放大倍數 (4.0 倍即原先的 0.8 比例)
	var squash_mult := Vector2(1.75, 0.4)  # 撞擊擠壓比例 (原先的 0.35, 0.08)
	var stretch_mult := Vector2(0.6, 1.4)  # 彈開拉長比例 (原先的 0.12, 0.28)

	# 4. 畫面震動強度與時間
	var shake_power: float = 20.0  # 震動強度
	var shake_time: float = 0.3  # 震動時長
	# ============================================================================

	# 1. 準備狀態：記錄原本位置，並將組件拉遠、變大、變透明
	var orig_circle_pos = boss_circle.position
	var orig_square_pos = boss_square.position

	boss_circle.position = orig_circle_pos + Vector2(0, -500)  # 圓形移到上方螢幕外
	boss_square.position = orig_square_pos + Vector2(0, 500)  # 方形移到下方螢幕外

	boss_circle.modulate.a = 0.0
	boss_square.modulate.a = 0.0

	# 放大元件，營造遠近立體感 (使用設定的變數)
	boss_circle.scale = base_circle_scale * start_scale_mult
	boss_square.scale = base_square_scale * start_scale_mult

	var tween = create_tween()

	# ===== 階段一：兩者相向高速旋轉墜入，並縮小至基準尺寸 =====
	(
		tween
		. tween_property(boss_circle, "position", orig_circle_pos, fly_in_duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.parallel().tween_property(boss_circle, "modulate:a", 1.0, fly_in_duration * 0.5)
	tween.parallel().tween_property(boss_circle, "rotation", PI * 2, fly_in_duration)
	tween.parallel().tween_property(boss_circle, "scale", base_circle_scale, fly_in_duration)

	(
		tween
		. parallel()
		. tween_property(boss_square, "position", orig_square_pos, fly_in_duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.parallel().tween_property(boss_square, "modulate:a", 1.0, fly_in_duration * 0.5)
	tween.parallel().tween_property(boss_square, "rotation", -PI * 2, fly_in_duration)
	tween.parallel().tween_property(boss_square, "scale", base_square_scale, fly_in_duration)

	# ===== 階段二：相撞瞬間 (Slam Impact) =====
	tween.tween_callback(
		func():
			# A. 播放極限擠壓變形 (基準尺寸 * 擠壓倍率)
			var s_tween = create_tween().set_parallel(true)
			s_tween.tween_property(
				boss_circle, "scale", base_circle_scale * squash_mult, squash_duration
			)
			s_tween.tween_property(
				boss_square, "scale", base_square_scale * squash_mult, squash_duration
			)

			# B. 畫面劇烈震動
			hidden_game.shake_screen(shake_time, shake_power)

			# C. 瞬間閃白光
			boss_circle.modulate = Color(2, 2, 2, 1)  # HDR 超白光
			boss_square.modulate = Color(2, 2, 2, 1)
	)
	tween.tween_interval(squash_duration)

	# ===== 階段三：反彈回縮 (基準尺寸 * 拉伸倍率) =====
	tween.tween_callback(
		func():
			var r_tween = create_tween().set_parallel(true)
			r_tween.tween_property(
				boss_circle, "scale", base_circle_scale * stretch_mult, stretch_duration
			)
			r_tween.tween_property(
				boss_square, "scale", base_square_scale * stretch_mult, stretch_duration
			)
			# 顏色漸變回原本顏色
			r_tween.tween_property(sprites, "modulate", Color(1, 0, 0, 1), 0.2)
			r_tween.tween_property(boss_circle, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
			r_tween.tween_property(boss_square, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
	)
	tween.tween_interval(stretch_duration)

	# ===== 階段四：平滑彈性回歸正常大小 =====
	tween.tween_property(boss_circle, "scale", base_circle_scale, settle_duration).set_trans(
		Tween.TRANS_SINE
	)
	(
		tween
		. parallel()
		. tween_property(boss_square, "scale", base_square_scale, settle_duration)
		. set_trans(Tween.TRANS_SINE)
	)

	# ===== 階段五：Boss 蓄力咆哮抖動 =====
	# ===== 階段五：Boss 蓄力咆哮抖動 =====
	for i in range(8):
		var offset = Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0))
		tween.tween_property(boss, "position", original_position + offset, 0.02)
	tween.tween_property(boss, "position", original_position, 0.05)

	invincible = false


func deal_damage(damage: int):
	if invincible or boss_hp <= 0:
		return
	boss_hp -= damage
	boss_hp_bar.value = boss_hp
	_play_hit_flash()


func _play_hit_flash():
	var flash_tween = create_tween()
	sprites.modulate = Color(1, 0, 0, 1)
	flash_tween.tween_property(sprites, "modulate", Color(1, 0, 0, 1), 0.008)
	flash_tween.tween_property(sprites, "modulate", Color(3, 3, 3, 1), 0.05)
	flash_tween.tween_property(sprites, "modulate", Color(1, 0, 0, 1), 0.05)


# 在場地半徑 radius 處，以 angle 角度（rad）生成飛劍，指向圓心，並在 wait 秒後以 speed 速度飛向對角
func spawn_arrow(radius: float, angle: float, speed: float, wait: float) -> void:
	var center_pos = Vector2(0, 100)
	if has_node("../Walls"):
		center_pos = get_node("../Walls").position

	var dir = Vector2.from_angle(angle)

	var start_pos = center_pos + dir * radius
	var target_pos = center_pos - dir * radius

	# 4. 實例化飛劍並將其生成在靜止的 damage_field 底下
	var sword = ATTACK_SWORD_SCENE.instantiate()
	damage_field.add_child(sword)

	sword.init(start_pos, target_pos, speed, wait)


# 測試用的環形飛劍攻擊招式
func test_sword_attack() -> void:
	is_attacking = true

	# 同時在環形發射 8 把飛劍，生成在半徑 300 處，等待 1.0 秒後以速度 550 射向對角
	var dir = PI * 2 * randf_range(0.0, 1.0)
	var sword_count = 30
	for i in range(sword_count):
		var angle = (PI * 0.8 / sword_count) * i + dir
		await get_tree().create_timer(0.01).timeout
		spawn_arrow(300.0, angle, 1000.0, 1.0 - i * 0.015)

	# 等待飛劍全部飛完並銷毀（約等待 1.0 秒 + 飛行時間 600/550 ≈ 1.1 秒 + 淡出 0.1 秒）
	await get_tree().create_timer(2.4).timeout
	is_attacking = false
