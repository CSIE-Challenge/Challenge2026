extends Control

var attack_ball_scene = preload("res://Scenes/attack_ball.tscn")

@onready var walls: Node2D = $Panel/Stage/Walls
@onready var timer: Timer = $Timer

# Boss related
@onready var boss = $Panel/Stage/boss
@onready var boss_circle = $Panel/Stage/boss/Sprites/circle  # 圓形
@onready var boss_square = $Panel/Stage/boss/Sprites/square  # 方形
@onready var stage = $Panel/Stage  # 用來做畫面震動


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_boss_appear_animation()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _random_generate_attack_ball():
	var ball = attack_ball_scene.instantiate()
	$Panel/Stage.add_child(ball)
	ball.position = walls.position + Vector2(randf_range(-200.0, 200.0), randf_range(-200.0, 200.0))


func _on_timer_timeout() -> void:
	_random_generate_attack_ball()


# by gemini
func _boss_appear_animation():
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
			_shake_screen(shake_time, shake_power)

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
			# 顏色漸變回原本的標誌性紅色
			r_tween.tween_property(boss_circle, "modulate", Color(1, 0, 0, 1), 0.2)
			r_tween.tween_property(boss_square, "modulate", Color(1, 0, 0, 1), 0.2)
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
	for i in range(8):
		var offset = Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0))
		tween.tween_property(boss, "position", offset, 0.02)
	tween.tween_property(boss, "position", Vector2.ZERO, 0.05)


func _shake_screen(duration: float, intensity: float):
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
