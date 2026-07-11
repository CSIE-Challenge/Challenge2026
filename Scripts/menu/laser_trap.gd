extends CollisionShape2D

# ⚡ 雷射基礎屬性 (可在 Inspector 或發射時動態設定)
@export var max_width: float = 24.0  # 發射時的雷射寬度 (像素)
@export var warning_color: Color = Color(3.0, 0.2, 0.2, 0.4)  # 預警線顏色 (半透明 HDR 紅)
@export var firing_color: Color = Color(5.0, 0.3, 0.3, 1.0)  # 能量束發射顏色 (亮 HDR 紅)

var start_pos: Vector2
var end_pos: Vector2
var warning_duration: float
var firing_duration: float

@onready var laser_line = $LaserLine
@onready var particles = $ImpactParticles


func init(
	pos_start: Vector2,
	pos_end: Vector2,
	wait_time: float,
	fire_time: float,
	custom_width: float = 24.0
) -> void:
	start_pos = pos_start
	end_pos = pos_end
	warning_duration = wait_time
	firing_duration = fire_time
	max_width = custom_width


func _ready() -> void:
	laser_line.texture_mode = Line2D.LINE_TEXTURE_STRETCH
	# 1. 物理定位與旋轉 (以局部座標中點為中心)
	var length = start_pos.distance_to(end_pos)
	position = (start_pos + end_pos) / 2.0
	rotation = (end_pos - start_pos).angle()

	# 設定 RectangleShape2D 碰撞尺寸 (長度為兩點間距，寬度初始化為最大寬度)
	if shape is RectangleShape2D:
		shape = shape.duplicate()  # 確保唯一實例
		shape.size = Vector2(length, max_width / 2)

	# 預設關閉物理傷害判定 (蓄力預警中不傷人)
	disabled = true

	# 🌟 2. Line2D 視覺定位 (使用純幾何局部計算，徹底解決 to_local() 的偏移與延遲 Bug)
	# 因為中心點在 (0, 0) 且旋轉後 X 軸對齊雷射方向，所以起點必定在左側，終點在右側
	var local_start = Vector2(-length / 2.0, 0.0)
	var local_end = Vector2(length / 2.0, 0.0)

	laser_line.points = [local_start, local_end]

	# 🌟 3. 將粒子放置在雷射終點，並朝向起點 (即本地空間的左側 LEFT)
	if particles:
		particles.position = local_end
		particles.direction = Vector2.LEFT  # 朝向發射方向反彈噴射火花

	# 4. 實作雷射三階段 Tween 流程
	_run_laser_sequence()


func _run_laser_sequence() -> void:
	Audio.play_sfx(Audio.SFX.HIDDEN_GAME_LASER_READY)
	# 初始為預警狀態：細線、半透明
	laser_line.width = 1.5
	laser_line.modulate = warning_color

	var tween = create_tween()

	# 【階段一：蓄力預警】
	# 預警期間，讓細線產生輕微的微幅呼吸抖動，增加能量蓄積感
	var warning_tween = create_tween().set_loops()
	warning_tween.tween_property(laser_line, "width", 2.2, 0.08)
	warning_tween.tween_property(laser_line, "width", 1.2, 0.08)

	# 主 Tween 等待預警期結束
	tween.tween_interval(warning_duration)

	# 【階段二：能量爆發】 (接續在預警後)
	tween.tween_callback(
		func():
			Audio.play_sfx(Audio.SFX.HIDDEN_GAME_LASER_EMIT)
			warning_tween.kill()  # 停止抖動

			# A. 開啟物理傷害判定
			disabled = false

			# B. 噴發粒子火花
			if particles:
				particles.emitting = true

			# C. 瞬間橫向膨脹並變亮 (並行)
			var fire_tween = create_tween().set_parallel(true)
			(
				fire_tween
				. tween_property(laser_line, "width", max_width, 0.08)
				. set_trans(Tween.TRANS_CUBIC)
				. set_ease(Tween.EASE_OUT)
			)
			fire_tween.tween_property(laser_line, "modulate", firing_color, 0.08)
	)

	# 持續射擊一段時間
	tween.tween_interval(firing_duration)

	# 【階段三：收縮淡出】 (射擊結束)
	tween.tween_callback(
		func():
			# A. 立即關閉傷害判定 (優良手感)
			disabled = true

			# B. 停止粒子
			if particles:
				particles.emitting = false

			# C. 快速收細並淡出消失
			var fade_tween = create_tween().set_parallel(true)
			(
				fade_tween
				. tween_property(laser_line, "width", 0.0, 0.18)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN)
			)
			fade_tween.tween_property(laser_line, "modulate:a", 0.0, 0.18)
			fade_tween.chain().tween_callback(queue_free)
	)
