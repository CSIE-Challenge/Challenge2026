extends Sprite2D

enum State { SCATTER, HOMING }
var current_state = State.SCATTER

# 物理參數
var velocity: Vector2
var damping: float = 0.92  # 減速度阻尼（越接近 1 減速越慢）
var switch_speed_threshold = 20.0  # 低於此速度時切換至追蹤階段

var boss_node: Node2D
var acceleration: float = 4000.0  # 衝向 Boss 的加速度
var max_speed: float = 1800.0

# 縮放與拉伸參數
var base_scale: Vector2 = Vector2(0.1, 0.1)
var stretch_factor: float = 0.0015  # 拉伸強度


func _ready() -> void:
	scale = base_scale


# 外部初始化方法
func init(start_pos: Vector2, dir: Vector2, speed: float, target_boss: Node2D) -> void:
	global_position = start_pos
	velocity = dir * speed
	boss_node = target_boss


func _process(delta: float) -> void:
	match current_state:
		State.SCATTER:
			# 1. 減速散開
			velocity *= damping
			global_position += velocity * delta

			# 當速度極慢時，切換到追蹤模式
			if velocity.length() < switch_speed_threshold:
				current_state = State.HOMING

		State.HOMING:
			if is_instance_valid(boss_node):
				# 2. 朝向 Boss 加速
				var target_pos = boss_node.global_position
				# 若 Boss 有指定受擊點偏移，可在此調整，例如 target_pos += Vector2(0, -50)

				var dir = (target_pos - global_position).normalized()
				velocity += dir * acceleration * delta
				velocity = velocity.limit_length(max_speed)
				global_position += velocity * delta

				# 3. 速度拉伸與旋轉
				rotation = velocity.angle()
				var current_speed = velocity.length()
				scale.x = base_scale.x * (1.0 + current_speed * stretch_factor)
				scale.y = base_scale.y / (1.0 + current_speed * stretch_factor * 0.5)  # 壓扁維持視覺體積

				# 4. 判定撞擊 Boss
				if global_position.distance_to(target_pos) < 30.0:
					_create_slash_effect(target_pos)
			else:
				# 若 Boss 被消滅了，圓點就淡出銷毀
				var tween = create_tween()
				tween.tween_property(self, "modulate:a", 0.0, 0.2)
				tween.tween_callback(queue_free)
				set_process(false)


# 產生切線方向的斬擊閃光
func _create_slash_effect(hit_pos: Vector2) -> void:
	# 隱藏圓點並停止移動，避免在播放動畫期間繼續移動或重複觸發
	hide()
	set_process(false)

	# 切線角度為運動方向加 90 度
	var tangent_angle = velocity.angle()

	# 隨機長度與時長設定
	var max_half_len = randf_range(150.0, 350.0)  # 長度隨機
	var grow_time = randf_range(0.04, 0.07)  # 伸長時長隨機
	var fade_time = randf_range(0.12, 0.20)  # 淡出時長隨機

	# 建立寬度曲線（兩端為 0，中間為 1.0），實現「兩端細、中間粗」的針狀外觀
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))

	# 1. 建立外圍發光線段 (Glow Line) - 較寬且半透明
	var glow = Line2D.new()
	glow.width = 18.0
	glow.default_color = Color(1.0, 1.0, 1.0, 0.25)
	glow.width_curve = curve
	glow.z_index = 10  # 確保畫在最上層
	get_parent().add_child(glow)
	glow.global_position = hit_pos
	# 需要三個點：起點、中點、終點，寬度曲線才能正確在中間呈現粗度
	glow.add_point(Vector2.ZERO)
	glow.add_point(Vector2.ZERO)
	glow.add_point(Vector2.ZERO)

	# 2. 建立內層核心線段 (Core Line) - 較窄且實心白
	var core = Line2D.new()
	core.width = 6.0
	core.default_color = Color.WHITE
	core.width_curve = curve
	core.z_index = 10  # 確保畫在最上層
	get_parent().add_child(core)
	core.global_position = hit_pos
	core.add_point(Vector2.ZERO)
	core.add_point(Vector2.ZERO)
	core.add_point(Vector2.ZERO)

	# 使用 Tween 進行動畫 (將 Tween 繫結在 self 上，此時 self 尚未銷毀，可以安全運作)
	var tween = create_tween()
	boss_node.deal_damage(2)

	# 階段一：兩條線同步從長度 0 快速延伸到目標長度
	(
		tween
		. tween_method(
			func(current_len: float):
				var offset = Vector2.from_angle(tangent_angle) * current_len

				glow.clear_points()
				glow.add_point(-offset)
				glow.add_point(Vector2.ZERO)  # 中間點，寬度為 1.0
				glow.add_point(offset)

				core.clear_points()
				core.add_point(-offset)
				core.add_point(Vector2.ZERO)  # 中間點，寬度為 1.0
				core.add_point(offset),
			0.0,
			max_half_len,
			grow_time
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	# 階段二：同步淡出並將線段寬度收縮至 0
	tween.tween_property(core, "width", 0.0, fade_time)
	tween.parallel().tween_property(core, "modulate:a", 0.0, fade_time)

	tween.parallel().tween_property(glow, "width", 0.0, fade_time)
	tween.parallel().tween_property(glow, "modulate:a", 0.0, fade_time)

	# 階段三：動畫結束後銷毀線段與圓點本體
	tween.tween_callback(core.queue_free)
	tween.tween_callback(glow.queue_free)
	tween.tween_callback(queue_free)
