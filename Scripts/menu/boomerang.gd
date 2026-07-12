extends CollisionShape2D  # 🌟 變更為 CollisionShape2D 以便掛載於 damage_field

var spin_velocity: float
var duration: float
var velocity: Vector2
var travel_range: float  # 重新命名避免與內建關鍵字 range 衝突
var target_scale: Vector2

var start_pos: Vector2
var current_spin_speed: float = 0.0  # 用於動態自轉加速
var boomerang_audio: AudioStreamPlayer

@onready var sprite = $Sprite2D
@onready var sprite2 = $Sprite2D2
@onready var particles = $TrailParticles1
@onready var particles2 = $TrailParticles2


func init(
	pos: Vector2,
	init_scale: Vector2,
	init_spin_velocity: float,
	wait_time: float,
	speed: float,
	direction: Vector2,
	init_range: float
):
	position = pos
	start_pos = pos
	target_scale = init_scale
	spin_velocity = init_spin_velocity
	duration = wait_time  # 原地起步預備時間
	velocity = direction.normalized() * speed
	travel_range = init_range


func _ready() -> void:
	# 1. 預備狀態：隱形且尺寸為 0
	scale = Vector2.ZERO
	modulate.a = 0.0

	if particles:
		particles.emitting = true
	if particles2:
		particles.emitting = true

	# 計算目標點位置 (依方向與距離) 與 移動時間 (距離 / 速度)
	var target_pos = start_pos + velocity.normalized() * travel_range
	var travel_time = travel_range / velocity.length() if velocity.length() > 0 else 1.0

	# 設定中途停留(懸停)時間，預設為 wait_time 的 0.8 倍 (也可以直接寫死如 0.6 秒)
	var hover_time = duration * 0.8

	# 2. 🌟 實作鏈式 Tween 動畫控制 4 階段運動
	var tween = create_tween()

	# 【階段一：原地出現，旋轉加速】 (並行設定，在 wait_time 內逐漸變大、淡入並自轉加速)
	var prep = tween.set_parallel(true)
	prep.tween_property(self, "scale", target_scale, duration)
	prep.tween_property(self, "modulate:a", 1.0, duration)
	prep.tween_property(self, "current_spin_speed", spin_velocity, duration)  # 自轉角速度從 0 加速到目標值

	# 【階段二：朝向目標移動】 (串接，使用 TRANS_QUAD 做出慢出慢停的飄逸感)
	tween.chain().tween_callback(
		func(): boomerang_audio = Audio.play_sfx(Audio.SFX.HIDDEN_GAME_BOOMERANG)
	)
	(
		tween
		. tween_property(self, "position", target_pos, travel_time)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)

	# 【階段三：在指定位置停留一會兒】 (在原地保持快速自轉懸停)
	tween.chain().tween_interval(hover_time)

	# 【階段四：回到原位】 (使用 TRANS_QUAD 與 EASE_IN 做出回程加速折返的打擊感)
	(
		tween
		. chain()
		. tween_property(self, "position", start_pos, travel_time)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)

	# 【階段五：收回淡出銷毀】 (回到起點後，迅速淡出縮小並停止自轉)
	tween.chain().tween_callback(
		func():
			var fade_tween = create_tween().set_parallel(true)
			fade_tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
			fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
			fade_tween.tween_property(self, "current_spin_speed", 0.0, 0.15)
			fade_tween.chain().tween_callback(queue_free)
	)


func _physics_process(delta: float) -> void:
	# 每幀自轉：角速度 current_spin_speed 會隨 Tween 的加速而同步加速
	rotation += current_spin_speed * delta


func _exit_tree() -> void:
	if boomerang_audio and is_instance_valid(boomerang_audio):
		boomerang_audio.stop()
