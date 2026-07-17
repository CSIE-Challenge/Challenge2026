extends BaseSkin

# 漂流木 —— 一座掛著三角帆的漂流木筏。腳下永遠帶著一灘水，
# 像浮在海面上一樣上下起伏；漂進海浪（輸送帶）裡會升起信號旗、
# 濺起破浪水花並乘風前傾，出生從水面浮出，死亡時緩緩下沉冒泡。

const PUDDLE_BASE_SCALE := 0.4

var t: float = 0.0
var is_dead: bool = false
var in_wave: bool = false
var facing: float = 1.0  # 1 = 朝右（美術預設方向）；在海浪裡會轉成逆著水流

@onready var wood: Node2D = $Wood
@onready var body: Sprite2D = $Wood/Body
@onready var pennant: Polygon2D = $Wood/Pennant
@onready var puddle: Sprite2D = $Puddle
@onready var ripples: CPUParticles2D = $Ripples
@onready var splash_particles: CPUParticles2D = $SplashParticles
@onready var wave_splash: CPUParticles2D = $WaveSplash
@onready var wake_spray: CPUParticles2D = $WakeSpray
@onready var bubble_particles: CPUParticles2D = $BubbleParticles


func _ready():
	scale = Vector2.ZERO


func _process(delta):
	if is_dead:
		return
	t += delta

	var parent = get_meta("player") if has_meta("player") else get_parent()
	var vx := 0.0
	var moving := false
	var in_water := false
	if parent and "velocity" in parent:
		vx = parent.velocity.x
		moving = parent.velocity.length() > 15.0
	if parent and "is_in_water" in parent:
		in_water = parent.is_in_water

	# 取得海浪水流方向（不在浪裡為 0）
	var flow_x := 0.0
	if (
		in_water
		and Trap4Conveyor.current_conveyor
		and is_instance_valid(Trap4Conveyor.current_conveyor)
	):
		flow_x = Trap4Conveyor.current_conveyor.direction.x

	# 帆的朝向：平常固定不翻面，在海浪裡帆面轉成逆著水流的方向
	if absf(flow_x) > 0.1:
		facing = -signf(flow_x)
	else:
		facing = 1.0
	wood.scale.x = move_toward(wood.scale.x, facing, delta * 10.0)

	# 海面漂浮：上下起伏 + 緩慢搖擺，移動時像被浪推著跑
	var bob_amp: float = 2.6 if moving else 1.6
	var bob_freq: float = 4.5 if moving else 1.8
	var sway_amp: float = 0.09 if moving else 0.05
	var lean: float = clampf(-vx * 0.002, -0.22, 0.22)
	if in_water:
		# 乘浪：起伏更大、被浪推著往水流方向傾
		bob_amp *= 1.35
		if absf(flow_x) > 0.1:
			lean += signf(flow_x) * 0.07
	wood.position.y = sin(t * bob_freq) * bob_amp
	wood.rotation = lean + sin(t * bob_freq * 0.7 + 0.8) * sway_amp

	# 腳下那灘水：緩緩漾動
	puddle.scale.x = PUDDLE_BASE_SCALE * (1.0 + sin(t * 2.2) * 0.07)

	# 漂進海浪：升信號旗 + 破浪水花
	if in_water != in_wave:
		in_wave = in_water
		_set_wave_mode(in_wave)
	if in_wave:
		pennant.rotation = sin(t * 9.0) * 0.12  # 信號旗飄動


func _set_wave_mode(on: bool) -> void:
	var tw := create_tween()
	if on:
		pennant.visible = true
		wave_splash.restart()
		wave_splash.emitting = true
		wake_spray.emitting = true
		tw.tween_property(pennant, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
	else:
		wake_spray.emitting = false
		tw.tween_property(pennant, "scale", Vector2(1, 0), 0.25).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): pennant.visible = false)


func _reset_wave_mode() -> void:
	in_wave = false
	pennant.visible = false
	pennant.scale = Vector2(1, 0)
	pennant.rotation = 0.0
	wake_spray.emitting = false


# ==========================================
# 標準特效介面
# ==========================================
func play_spawn():
	is_dead = false
	t = 0.0
	wood.rotation = 0.0
	wood.position = Vector2(0, 14)
	wood.modulate = Color(1, 1, 1, 0)
	body.modulate = Color(1, 1, 1, 1)
	puddle.modulate = Color(1, 1, 1, 1)
	_reset_wave_mode()
	ripples.emitting = true

	splash_particles.restart()
	splash_particles.emitting = true

	# 從水面下浮出：上浮 + 淡入 + 彈性放大
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	tween.parallel().tween_property(wood, "position:y", 0.0, 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(wood, "modulate:a", 1.0, 0.3)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_jump():
	if is_dead:
		return
	# 躍出水面：甩出幾滴水珠 + 縱向拉伸
	splash_particles.restart()
	splash_particles.emitting = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.92, 1.12), 0.1)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_land():
	if is_dead:
		return
	# 落回水面：濺起水花 + 壓扁回彈
	splash_particles.restart()
	splash_particles.emitting = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 0.82), 0.05)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_eat_ball():
	if is_dead:
		return
	# 吃球：泛起一層水藍色光 + Q 彈脈動
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(1.2, 1.6, 1.9, 1), 0.08)
	tw.tween_property(body, "modulate", Color(1, 1, 1, 1), 0.25)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_die():
	is_dead = true
	ripples.emitting = false
	wake_spray.emitting = false
	bubble_particles.restart()
	bubble_particles.emitting = true

	# 沉沒：緩緩下沉、側翻、淡出，腳下的水也一起散去
	var tw := create_tween()
	tw.parallel().tween_property(wood, "position:y", wood.position.y + 30.0, 0.6).set_ease(
		Tween.EASE_IN
	)
	tw.parallel().tween_property(wood, "rotation", wood.rotation + 0.7, 0.6)
	tw.parallel().tween_property(wood, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(puddle, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2(0.85, 0.85), 0.6).set_ease(Tween.EASE_IN)
	if tw:
		await tw.finished
	else:
		await get_tree().process_frame
