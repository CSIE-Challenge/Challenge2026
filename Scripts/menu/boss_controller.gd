extends Node2D

signal boss_hit
signal boss_died_first_time
signal boss_defeated
const ATTACK_SWORD_SCENE = preload("res://Scenes/menu/attack_sword.tscn")
const FALLING_NOTE_SCENE = preload("res://Scenes/menu/falling_note.tscn")

const ROCKET_WARNING_SCENE = preload("res://Scenes/menu/rocket_warning.tscn")
const HOMING_ROCKET_SCENE = preload("res://Scenes/menu/homing_rocket.tscn")

const BOOMERANG_SCENE = preload("res://Scenes/menu/boomerang.tscn")

const LASER_TRAP_SCENE = preload("res://Scenes/menu/laser_trap.tscn")
const BOUNCING_SAW_SCENE = preload("res://Scenes/menu/bouncing_saw.tscn")

# 記錄 Boss 的初始待機位置，以便招式施展後歸位
var original_position: Vector2
var is_attacking: bool = false

# 紀路 Boss 血量
var boss_hp: int
var invincible: bool
var phase: int = 1
var is_dead: bool = false
var current_attack_interrupted: bool = false

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
				rhythm_attack()
			KEY_2:
				emit_rocket()
			KEY_3:
				emit_boomerang(1)
			KEY_4:
				test_sword_attack()
			KEY_5:
				squeeze_attack()
			KEY_6:
				pong_attack()
			KEY_7:
				road_attack()
			KEY_8:
				test_laser_attack()
			KEY_9:
				sweeper_attack()


func rand_attack():
	while true:
		if is_dead:
			break

		current_attack_interrupted = false

		if not is_attacking:
			var rand_val = randi_range(0, 8)
			match rand_val:
				0:
					rhythm_attack()
				1:
					test_sword_attack()
				2:
					emit_rocket()
				3:
					var rand_val2 = randi_range(1, 5)
					emit_boomerang(rand_val2)
				4:
					squeeze_attack()
				5:
					test_laser_attack()
				6:
					pong_attack()
				7:
					road_attack()
		await interruptible_wait(0.5)
		while is_attacking:
			await interruptible_wait(0.1)


func rhythm_attack() -> void:
	if not is_instance_valid(player):
		if has_node("../coconut"):
			player = get_node("../coconut")
		else:
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
	if await interruptible_wait(1.2):
		return

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
		if await interruptible_wait(0.35):
			return

	# 等待最後一波落鍵降落與紅色殘影完全消失
	if await interruptible_wait(1.8):
		return

	# 3. 招式結束，將牆壁還原到原本的大小與位置
	if walls:
		walls.reset_box(0.7)

	if await interruptible_wait(0.8):
		return
	is_attacking = false


func emit_rocket() -> void:
	if not player:
		return
	is_attacking = true

	var walls = get_node("../Walls")
	if walls:
		walls.tween_box(Vector2(500, 500), Vector2(0, -100), 1.0)

	for i in range(4):
		spawn_homing_rocket(randf_range(0, PI * 2), 200.0, 65.0, 1.5, 0.8)
		if await interruptible_wait(0.5):
			return
	if await interruptible_wait(3):
		return
	if walls:
		walls.reset_box(0.7)
	if await interruptible_wait(1.0):
		return
	is_attacking = false


# 🌟 迴旋鏢招式管理器 (共 5 種精緻的彈幕幾何模式) 感謝偉大的gemini
func emit_boomerang(mode: int) -> void:
	if not is_instance_valid(player):
		return

	is_attacking = true
	var walls = get_node_or_null("../Walls")
	if not walls:
		is_attacking = false
		return

	var half = walls.current_half_size
	var center = walls.position

	if mode == 1:
		# 🌀 【模式一：右側一排橫掃】
		# 均勻生成在右側牆外 60 像素處，向左飛越整個場地至左牆外，隨後折返飛回右側
		var count = 5
		var spawn_x = center.x + half.x + 60.0  # 🌟 推到右牆外側 60 像素
		var start_y = center.y - half.y + 35.0
		var end_y = center.y + half.y - 35.0

		for i in range(count):
			var spawn_y = start_y + (end_y - start_y) * (float(i) / (count - 1))
			var spawn_pos = Vector2(spawn_x, spawn_y)

			# 飛行長度為：場地寬度 + 120 像素，確保能穿牆飛到左側外再折返
			spawn_boomerang(
				spawn_pos, Vector2(2.0, 2.0), 15.0, 0.6, 300.0, Vector2.LEFT, half.x * 2.0 + 120.0
			)
			if await interruptible_wait(0.2):
				return

		if await interruptible_wait(2.6):
			return

	elif mode == 2:
		# 🎯 【模式二：邊緣隨機狙擊】
		# 每隔 0.8 秒，在場地外圍四面牆的外側 60 像素隨機選點生成，瞄準玩家當前位置射擊，共 8 個
		var total_count = 8

		for w in range(total_count):
			if not is_instance_valid(player) or boss_hp <= 0:
				break

			var side = randi_range(0, 3)  # 0=上, 1=下, 2=左, 3=右
			var spawn_pos = Vector2.ZERO
			match side:
				0:  # 上牆外側 60 像素
					spawn_pos = (
						center + Vector2(randf_range(-half.x + 30, half.x - 30), -half.y - 60)
					)
				1:  # 下牆外側 60 像素
					spawn_pos = (
						center + Vector2(randf_range(-half.x + 30, half.x - 30), half.y + 60)
					)
				2:  # 左牆外側 60 像素
					spawn_pos = (
						center + Vector2(-half.x - 60, randf_range(-half.y + 30, half.y - 30))
					)
				3:  # 右牆外側 60 像素
					spawn_pos = (
						center + Vector2(half.x + 60, randf_range(-half.y + 30, half.y - 30))
					)

			var target_dir = (player.position - spawn_pos).normalized()

			# 飛距 550 像素確保能完全貫穿場地至另一側外
			spawn_boomerang(spawn_pos, Vector2(2.0, 2.0), 18.0, 0.5, 250.0, target_dir, 550.0)
			if await interruptible_wait(0.8):
				return

		if await interruptible_wait(2.2):
			return

	elif mode == 3:
		# ⚔️ 【新模式三：四角狙擊交匯】 (全新動態鎖定)
		# 同時在四個角落的牆外 60 像素生成 4 顆迴旋鏢
		# 它們的發射方向全部鎖定「發射當下玩家的位置」，在其交點附近懸停，隨後折返
		var player_target = player.position  # 鎖定當前玩家的座標
		var corners = [
			Vector2(-half.x - 60, -half.y - 60),  # 左上
			Vector2(half.x + 60, -half.y - 60),  # 右上
			Vector2(-half.x - 60, half.y + 60),  # 左下
			Vector2(half.x + 60, half.y + 60)  # 右下
		]

		for i in range(4):
			var spawn_pos = center + corners[i]
			var dir = (player_target - spawn_pos).normalized()
			# 飛行距離：剛好是到玩家位置的距離 + 40 像素 (確保穿透交點)
			var dist = spawn_pos.distance_to(player_target) + 40.0

			spawn_boomerang(spawn_pos, Vector2(1.05, 1.05), 16.0, 0.65, 380.0, dir, dist)

		# 等待飛完並回收
		if await interruptible_wait(2.6):
			return

	elif mode == 4:
		# 🌀 【模式四：八方收縮圓形網】 (全新設計)
		# 在場地外圍大圓（半徑為最大半寬高+90像素）上，均勻分佈生成 8 顆迴旋鏢
		# 同時朝向場地中心合攏，在中心點聚集成一個旋轉圓環（絞肉機），隨後再向外折返散開
		var count = 8
		var radius = max(half.x, half.y) + 90.0  # 確保完全在牆外外側

		for i in range(count):
			var angle = (PI * 2.0 / count) * i
			var dir = Vector2.from_angle(angle)
			var spawn_pos = center + dir * radius

			# 方向指向中心，即 -dir
			var to_center_dir = -dir

			# 飛行距離剛好為半徑，使它們在中心點聚攏成圓環
			spawn_boomerang(spawn_pos, Vector2(1.0, 1.0), 18.0, 0.8, 320.0, to_center_dir, radius)

		if await interruptible_wait(2.8):
			return

	elif mode == 5:
		# 🌀 【新模式五：加特林螺旋風車】 (全新高頻螺旋)
		# 均勻在場外圓周上，每隔 0.16 秒順時針發射一顆指向場地中心的迴旋鏢，共 8 顆
		# 這會形成一條美麗的順時針螺旋向心收縮軌跡，在流光粒子下會像巨型旋轉風車一樣切割場地
		var count = 16
		var radius = max(half.x, half.y) + 90.0  # 確保完全在牆外

		for i in range(count):
			if not is_instance_valid(player) or boss_hp <= 0:
				break

			# 順時針計算生成角度與發射方向
			var angle = (PI * 2.0 / count) * i
			var spawn_dir = Vector2.from_angle(angle)
			var spawn_pos = center + spawn_dir * radius
			var to_center_dir = -spawn_dir

			# 發射狙擊
			var b_scale = Vector2(0.95, 0.95)
			spawn_boomerang(spawn_pos, b_scale, 18.0, 0.5, 350.0, to_center_dir, radius)

			# 高頻率極速連射
			if await interruptible_wait(0.16):
				return

		if await interruptible_wait(2.2):
			return

	is_attacking = false


func test_laser_attack() -> void:
	is_attacking = true
	var walls = get_node_or_null("../Walls")
	if not walls:
		is_attacking = false
		return

	var half = walls.current_half_size
	var center = walls.position

	# 計算貫穿場地邊界的四個端點
	var left_pt = center + Vector2(-half.x + 20.0, 0.0)
	var right_pt = center + Vector2(half.x - 20.0, 0.0)
	var top_pt = center + Vector2(0.0, -half.y + 20.0)
	var bottom_pt = center + Vector2(0.0, half.y - 20.0)

	for times in range(5):
		var bias = randf_range(-80.0, 80.0)
		for interval in [100.0, 0.0, -100.0]:
			spawn_laser_trap(
				left_pt - Vector2(0.0, interval + bias),
				right_pt - Vector2(0.0, interval + bias),
				0.5,
				0.3,
				30.0
			)
			spawn_laser_trap(
				top_pt - Vector2(interval + bias, 0.0),
				bottom_pt - Vector2(interval + bias, 0.0),
				0.5,
				0.3,
				30.0
			)
		if await interruptible_wait(1.0):
			return
	# 1. 發射橫向與縱向的十字雷射：起點, 終點, 預警 1.0 秒, 發射維持 0.8 秒, 寬度 30 像素
	# spawn_laser_trap(left_pt, right_pt, 1.0, 0.8, 30.0)
	# spawn_laser_trap(top_pt, bottom_pt, 1.0, 0.8, 30.0)

	# 等待預警 + 發射 + 淡出
	if await interruptible_wait(1.8):
		return
	is_attacking = false


# 🌟 擠壓雷射攻擊 (優化版)：極速壓縮後立刻在 0.5 秒內還原，同時雷射由外側生成，推進並覆蓋 80% 場地
func squeeze_attack() -> void:
	if not is_instance_valid(player):
		if has_node("../coconut"):
			player = get_node("../coconut")
		else:
			return
	is_attacking = true

	# 窄條尺寸參數
	var target_height = 45.0
	var target_width = 400.0
	var walls = get_node("../Walls")

	if not walls:
		is_attacking = false
		return

	# 原場地極限幾何邊界
	var original_min_y = -220.0
	var original_max_y = 180.0
	var original_min_x = -200.0
	var original_max_x = 200.0
	var center_y = -20.0
	var center_x = 0.0

	# 0=重力向上(壓在上邊), 1=重力向下(壓在下邊), 2=重力向左(壓在左邊), 3=重力向右(壓在右邊)
	var mode = randi_range(0, 3)

	var wall_size = Vector2.ZERO
	var wall_pos = Vector2.ZERO

	match mode:
		0:  # 逼玩家往上
			wall_size = Vector2(target_width, target_height)
			wall_pos = Vector2(0, original_min_y + target_height / 2.0)
		1:  # 逼玩家往下
			wall_size = Vector2(target_width, target_height)
			wall_pos = Vector2(0, original_max_y - target_height / 2.0)
		2:  # 逼玩家往左
			wall_size = Vector2(target_height, target_width)
			wall_pos = Vector2(original_min_x + target_height / 2.0, center_y)
		3:  # 逼玩家往右
			wall_size = Vector2(target_height, target_width)
			wall_pos = Vector2(original_max_x - target_height / 2.0, center_y)

	# 1. 重力下砸：極速壓縮牆壁 (0.1 秒)
	walls.tween_box(wall_size, wall_pos, 0.1)
	if await interruptible_wait(0.12):
		return

	# 🌟 2. 拍實後，牆壁立刻在 0.5 秒內平滑彈回還原
	walls.reset_box(0.5)

	# 🌟 3. 雷射陣列參數設定
	var laser_count = 10  # 【修改】數量減半為 10 條，減輕引擎瞬間運算負擔
	var spawn_interval = 0.07  # 維持間隔 0.01 秒
	var fire_interval = 0.1  # 維持間隔 0.02 秒

	# 第一條雷射開始爆炸的基準時間 (即最後一條預警線出現的時間)
	var t0 = float(laser_count - 1) * spawn_interval

	var fire_time = 0.25
	var laser_w = 30.0  # 【建議調整】因為數量減半，所以稍微加寬雷射以維持覆蓋率

	var arena_width = original_max_x - original_min_x  # 原場地寬度 400.0
	var arena_height = original_max_y - original_min_y  # 原場地高度 400.0
	var cover_ratio = 0.8  # 覆蓋 80%

	var last_warn_time = 0.0

	for i in range(laser_count):
		if boss_hp <= 0 or not is_instance_valid(player):
			break

		var start_pt = Vector2.ZERO
		var end_pt = Vector2.ZERO

		# 根據模式，計算雷射推進 80% 場地的座標
		match mode:
			0:  # 重力向上：向下推進 80% 場地
				var start_y = original_min_y - 20.0
				var target_y = original_min_y + (arena_height * cover_ratio)
				var curr_y = start_y + (target_y - start_y) * (float(i) / (laser_count - 1))
				start_pt = Vector2(original_min_x - 50.0, curr_y)
				end_pt = Vector2(original_max_x + 50.0, curr_y)

			1:  # 重力向下：向上推進 80% 場地
				var start_y = original_max_y + 20.0
				var target_y = original_max_y - (arena_height * cover_ratio)
				var curr_y = start_y - (start_y - target_y) * (float(i) / (laser_count - 1))
				start_pt = Vector2(original_min_x - 50.0, curr_y)
				end_pt = Vector2(original_max_x + 50.0, curr_y)

			2:  # 重力向左：向右推進 80% 場地
				var start_x = original_min_x - 20.0
				var target_x = original_min_x + (arena_width * cover_ratio)
				var curr_x = start_x + (target_x - start_x) * (float(i) / (laser_count - 1))
				start_pt = Vector2(curr_x, original_min_y - 50.0)
				end_pt = Vector2(curr_x, original_max_y + 50.0)

			3:  # 重力向右：向左推進 80% 場地
				var start_x = original_max_x + 20.0
				var target_x = original_max_x - (arena_width * cover_ratio)
				var curr_x = start_x - (start_x - target_x) * (float(i) / (laser_count - 1))
				start_pt = Vector2(curr_x, original_min_y - 50.0)
				end_pt = Vector2(curr_x, original_max_y + 50.0)

		# 【精準數學計算】動態計算每條雷射的預警時間
		# 預警時間 = 基準引爆時間 + 每條的額外引爆延遲 - 它自身較早生成的時間
		var current_warn_time = t0 + float(i) * (fire_interval - spawn_interval)
		last_warn_time = current_warn_time

		# 發射雷射
		spawn_laser_trap(start_pt, end_pt, current_warn_time, fire_time, laser_w)

		# 控制「生成預警線」的極快間隔
		if await interruptible_wait(spawn_interval):
			return

	# 4. 等待最後一發雷射發射與淡出結束
	if await interruptible_wait(last_warn_time + fire_time + 0.15):
		return

	is_attacking = false


# 🪚 死亡彈珠台：場地比例動態變化版
func pong_attack() -> void:
	if not is_instance_valid(player):
		return
	is_attacking = true
	var walls = get_node_or_null("../Walls")
	if not walls:
		is_attacking = false
		return

	# 1. 初始設定場地大小 (設定為一個正方形，讓後續的長寬變化更明顯)
	var arena_half = Vector2(200, 200)
	if "dynamic_base_half" in walls:
		walls.dynamic_base_half = arena_half  # 覆寫為這招的初始比例

	walls.tween_box(arena_half * 2.0, Vector2(0, -20), 0.5)
	if await interruptible_wait(0.6):
		return

	var saw_count = 1
	for i in range(saw_count):
		if boss_hp <= 0 or not is_instance_valid(player):
			break

		var saw = BOUNCING_SAW_SCENE.instantiate()
		var spawn_pos = walls.global_position
		var dir_x = randf_range(0.4, 1.0) * (1 if randf() > 0.5 else -1)
		var dir_y = randf_range(0.4, 1.0) * (1 if randf() > 0.5 else -1)
		var dir = Vector2(dir_x, dir_y).normalized()

		# 初始化 (不再傳入 arena_half)
		saw.init(spawn_pos, dir, 400.0, 8.0)
		damage_field.add_child(saw)

		saw.global_position = spawn_pos

		if await interruptible_wait(0.4):
			return

	if await interruptible_wait(8.2):
		return

	walls.reset_box(0.6)
	if await interruptible_wait(0.8):
		return
	is_attacking = false


func road_attack() -> void:
	is_attacking = true
	var walls = get_node_or_null("../Walls")
	if not walls:
		is_attacking = false
		return

	var half = walls.current_half_size
	var center = walls.position

	var left_pt = center + Vector2(-half.x + 20.0, 0.0)
	var right_pt = center + Vector2(half.x - 20.0, 0.0)
	var top_pt = center + Vector2(0.0, -half.y + 20.0)
	var bottom_pt = center + Vector2(0.0, half.y - 20.0)
	var width = 100.0
	var amp = 120.0

	spawn_laser_trap(
		left_pt - Vector2(0.0, width / 2), right_pt - Vector2(0.0, width / 2), 0.5, 0.3, 30.0
	)
	spawn_laser_trap(
		left_pt + Vector2(0.0, width / 2), right_pt + Vector2(0.0, width / 2), 0.5, 0.3, 30.0
	)

	walls.tween_box(Vector2(45.0, 400), walls.position, 5.0)

	for i in range(10):
		spawn_straight_arrow(left_pt + Vector2(-50.0, width / 2), Vector2.RIGHT, 500.0, 1.0)
		spawn_straight_arrow(left_pt + Vector2(-50.0, -width / 2), Vector2.RIGHT, 500.0, 1.0)
		if await interruptible_wait(0.1):
			return
	for i in range(30):
		spawn_straight_arrow(
			left_pt + Vector2(-50.0, width / 2 + sin(i * PI / 15.0) * amp),
			Vector2.RIGHT,
			500.0,
			1.0
		)
		spawn_straight_arrow(
			left_pt + Vector2(-50.0, -width / 2 + sin(i * PI / 15.0) * amp),
			Vector2.RIGHT,
			500.0,
			1.0
		)
		if await interruptible_wait(0.1):
			return
	for i in range(30):
		spawn_straight_arrow(
			right_pt + Vector2(50.0, width / 2 + sin(i * PI / 15.0) * amp), Vector2.LEFT, 500.0, 1.0
		)
		spawn_straight_arrow(
			right_pt + Vector2(50.0, -width / 2 + sin(i * PI / 15.0) * amp),
			Vector2.LEFT,
			500.0,
			1.0
		)
		if await interruptible_wait(0.1):
			return

	walls.reset_box(2.0)
	if await interruptible_wait(2.0):
		return
	is_attacking = false


func sweeper_attack() -> void:
	is_attacking = true
	var walls = get_node_or_null("../Walls")
	if not walls:
		is_attacking = false
		return

	var half = walls.current_half_size
	var center = walls.position
	var speed = PI / 20.0

	for i in range(40):
		spawn_laser_trap(
			center + Vector2(cos(i * speed), sin(i * speed)) * half * 1.414,
			center - Vector2(cos(i * speed), sin(i * speed)) * half * 1.414,
			0.5,
			0.3,
			60.0
		)
		if await interruptible_wait(0.05):
			return

	if await interruptible_wait(0.5):
		return

	for i in range(40):
		spawn_laser_trap(
			center + Vector2(cos(-i * speed), sin(-i * speed)) * half * 1.414,
			center - Vector2(cos(-i * speed), sin(-i * speed)) * half * 1.414,
			0.5,
			0.3,
			60.0
		)
		if await interruptible_wait(0.05):
			return

	if await interruptible_wait(1.0):
		return
	is_attacking = false


func sneak_attack() -> void:
	is_attacking = true
	var walls = get_node_or_null("../Walls")
	if not walls:
		is_attacking = false
		return

	var half = walls.current_half_size
	var center = walls.position

	# 計算貫穿場地邊界的四個端點
	var left_pt = center + Vector2(-half.x + 20.0, 0.0)
	var right_pt = center + Vector2(half.x - 20.0, 0.0)
	var top_pt = center + Vector2(0.0, -half.y + 20.0)
	var bottom_pt = center + Vector2(0.0, half.y - 20.0)

	spawn_laser_trap(
		Vector2(player.position.x, top_pt.y),
		Vector2(player.position.x, bottom_pt.y),
		0.8,
		0.7,
		50.0
	)

	spawn_laser_trap(
		Vector2(left_pt.x, player.position.y),
		Vector2(right_pt.x, player.position.y),
		0.8,
		0.7,
		50.0
	)

	if await interruptible_wait(1.0):
		return
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


func play_death_animation():
	var death_tween = create_tween()
	death_tween.set_parallel(true)

	# 劇烈震動與變紅
	var shake_duration = 3.0
	var original_pos = position
	sprites.modulate = Color(2, 0, 0, 1)  # 深紅色

	for i in range(30):
		var offset = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		death_tween.tween_property(self, "position", original_pos + offset, 0.1).set_delay(i * 0.1)

	# 逐漸膨脹
	death_tween.tween_property(sprites, "scale", Vector2(1.5, 1.5), shake_duration)

	# 最後爆炸消失
	death_tween.chain().tween_property(sprites, "scale", Vector2(2.5, 2.5), 0.2)
	death_tween.parallel().tween_property(sprites, "modulate", Color(10, 0, 0, 0), 0.2)
	death_tween.chain().tween_callback(func(): queue_free())


func interruptible_wait(time: float) -> bool:
	if not is_inside_tree():
		return true
	var t = get_tree().create_timer(time)
	while t.time_left > 0:
		if not is_inside_tree() or is_dead or current_attack_interrupted:
			is_attacking = false
			return true
		await get_tree().process_frame
	return false


func deal_damage(damage: int):
	if invincible or is_dead or boss_hp <= 0:
		return

	boss_hp -= damage
	if boss_hp <= 0:
		boss_hp = 0
		boss_hp_bar.value = boss_hp
		_play_hit_flash()

		if phase == 1:
			phase = 2
			boss_hp = 100
			boss_hp_bar.value = boss_hp

			# 打斷並清除場上所有攻擊
			current_attack_interrupted = true
			for child in damage_field.get_children():
				child.queue_free()

			boss_died_first_time.emit()

		elif phase == 2:
			is_dead = true

			# 打斷並清除場上所有攻擊
			current_attack_interrupted = true
			for child in damage_field.get_children():
				child.queue_free()

			boss_defeated.emit()
		return

	boss_hp_bar.value = boss_hp
	boss_hit.emit()
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


func spawn_straight_arrow(pos: Vector2, dir: Vector2, speed: float, wait: float) -> void:
	var center_pos = Vector2(0, 100)
	if has_node("../Walls"):
		center_pos = get_node("../Walls").position

	dir = dir.normalized()

	var start_pos = pos
	var target_pos = pos + dir * absf(center_pos.x - pos.x) * 2

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
		if await interruptible_wait(0.01):
			return
		spawn_arrow(300.0, angle, 1000.0, 1.0 - i * 0.015)

	# 等待飛劍全部飛完並銷毀（約等待 1.0 秒 + 飛行時間 600/550 ≈ 1.1 秒 + 淡出 0.1 秒）
	if await interruptible_wait(2.4):
		return
	is_attacking = false


func spawn_homing_rocket(
	angle: float,
	init_speed: float,
	explosion_radius: float,
	explosion_duration: float,
	warning_duration: float = 0.8,
	custom_rocket_accel: float = 220.0
) -> void:
	var center_pos = Vector2(0, 100)
	var radius = 320.0

	if has_node("../Walls"):
		var walls = get_node("../Walls")
		center_pos = walls.position  # 🌟 局部座標
		radius = max(walls.current_half_size.x, walls.current_half_size.y) + 120.0

	var dir = Vector2.from_angle(angle)
	var spawn_pos = center_pos + dir * radius  # 🌟 計算局部發射座標

	# 1. 生成警告區域 (先 init 設定 position，後 add_child)
	var warning = ROCKET_WARNING_SCENE.instantiate()
	warning.init(spawn_pos, warning_duration)
	get_parent().add_child(warning)

	# 等待警告期結束
	if await interruptible_wait(warning_duration):
		return

	# 安全性檢查
	if not is_instance_valid(player) or boss_hp <= 0:
		return

	# 2. 實例化火箭 (先 init 設定 position，後 add_child)
	var rocket = HOMING_ROCKET_SCENE.instantiate()
	rocket.acceleration = custom_rocket_accel
	rocket.init(spawn_pos, init_speed, explosion_radius, explosion_duration, player, damage_field)
	get_parent().add_child(rocket)


#
func spawn_boomerang(
	pos: Vector2,
	init_scale: Vector2,
	init_spin_velocity: float,
	wait_time: float,
	speed: float,
	direction: Vector2,
	init_range: float
) -> void:
	if not is_instance_valid(damage_field):
		return

	var boomerang = BOOMERANG_SCENE.instantiate()

	# 🌟 先 init 傳入局部座標，後 add_child 載入到 damage_field
	boomerang.init(pos, init_scale, init_spin_velocity, wait_time, speed, direction, init_range)
	damage_field.add_child(boomerang)


# 在起點 start_pos 與終點 end_pos 之間發射一條雷射陷阱
func spawn_laser_trap(
	start_p: Vector2, end_p: Vector2, wait_time: float, fire_time: float, custom_width: float = 24.0
) -> void:
	if not is_instance_valid(damage_field):
		return

	var laser = LASER_TRAP_SCENE.instantiate()

	# 🌟 先 init 傳入局部座標，後 add_child 加入傷害區
	laser.init(start_p, end_p, wait_time, fire_time, custom_width)
	damage_field.add_child(laser)
