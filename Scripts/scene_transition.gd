extends CanvasLayer

signal transition_finished

signal scene_transition_finished

var ach_max_width: float = 350.0
var ach_margin_x: float = 20.0
var ach_border_thickness: float = 4.0
var ach_display_time: float = 3.0

var ach_is_animating: bool = false
var ach_queue: Array = []

var wave_noise_tex: NoiseTexture2D

@onready var shader_rect = $ShaderRect
@onready var top_bar = $TopBar
@onready var bottom_bar = $BottomBar
@onready var fade_rect = $FadeRect

@onready var ach_control = $AchievementControl
@onready var ach_white_rect = $AchievementControl/WhiteRect
@onready var ach_black_rect = $AchievementControl/WhiteRect/BlackRect
@onready var ach_label = $AchievementControl/WhiteRect/BlackRect/Label


func _ready() -> void:
	# 初始重設狀態
	shader_rect.hide()
	top_bar.anchor_bottom = 0.0
	top_bar.anchor_top = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_bottom = 1.0
	fade_rect.color.a = 0.0

	# 生成海浪轉場用的無縫雜訊貼圖
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.015
	wave_noise_tex = NoiseTexture2D.new()
	wave_noise_tex.noise = noise
	wave_noise_tex.seamless = true
	wave_noise_tex.width = 512
	wave_noise_tex.height = 512

	# 成就顯示初始化
	ach_white_rect.hide()
	_ach_reset_rects()


func _ach_reset_rects():
	ach_white_rect.offset_right = -ach_margin_x
	ach_white_rect.offset_left = -ach_margin_x

	ach_black_rect.offset_right = -ach_border_thickness
	ach_black_rect.offset_left = -ach_border_thickness


func show_achievement(text: String):
	if ach_is_animating:
		ach_queue.append(text)
		return

	ach_is_animating = true
	Audio.play_sfx(Audio.SFX.HIDDEN_GAME_ACHIEVEMENT)
	ach_label.text = text
	_ach_reset_rects()
	ach_white_rect.show()

	var tween = create_tween()

	# Entry animation
	# 1. White rect expands
	(
		tween
		. tween_property(ach_white_rect, "offset_left", -ach_margin_x - ach_max_width, 0.4)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	# 2. Black rect expands (starts slightly before white fully expands)
	# Max width of black rect is slightly smaller so we have a white border on the left
	(
		tween
		. parallel()
		. tween_property(ach_black_rect, "offset_left", -ach_max_width + ach_border_thickness, 0.4)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
		. set_delay(0.15)
	)

	# 3. Wait 3 seconds
	tween.tween_interval(ach_display_time)

	# 4. Exit animation
	# First black rect shrinks
	(
		tween
		. tween_property(ach_black_rect, "offset_left", -ach_border_thickness, 0.3)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
	)
	# Then white rect shrinks
	(
		tween
		. parallel()
		. tween_property(ach_white_rect, "offset_left", -ach_margin_x, 0.3)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN)
		. set_delay(0.1)
	)

	tween.tween_callback(_ach_on_animation_finished)


func _ach_on_animation_finished():
	ach_white_rect.hide()
	ach_is_animating = false
	if ach_queue.size() > 0:
		var next_text = ach_queue.pop_front()
		show_achievement(next_text)


func transition_to_fade(target_scene: String) -> void:
	preload_scene_async(target_scene)
	get_tree().paused = true
	fade_rect.color.a = 0.0
	var tween = create_tween()
	# 淡出至黑幕
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	# 切換場景
	tween.tween_callback(func(): await _switch_scene(target_scene))
	# 等待載入
	await scene_transition_finished
	tween = create_tween()
	# 淡入畫面
	tween.tween_property(fade_rect, "color:a", 0.0, 1.0)
	tween.tween_callback(transition_finished.emit)
	get_tree().paused = false


func transition_to(target_scene: String) -> void:
	preload_scene_async(target_scene)
	get_tree().paused = true
	top_bar.anchor_bottom = 0.0
	bottom_bar.anchor_top = 1.0
	shader_rect.hide()
	var tween = create_tween()
	# 商店專屬：鐵捲門般重重關上 (Bounce)
	tween.tween_property(top_bar, "anchor_bottom", 0.5, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(
		Tween.EASE_OUT
	)
	(
		tween
		. parallel()
		. tween_property(bottom_bar, "anchor_top", 0.5, 0.4)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)

	tween.tween_callback(func(): await _switch_scene(target_scene))
	await scene_transition_finished
	tween = create_tween()

	# 快速拉開
	tween.tween_property(top_bar, "anchor_bottom", 0.0, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(
		Tween.EASE_OUT
	)
	(
		tween
		. parallel()
		. tween_property(bottom_bar, "anchor_top", 1.0, 0.3)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_callback(transition_finished.emit)
	get_tree().paused = false


func transition_to_wave(target_scene: String) -> void:
	preload_scene_async(target_scene)
	Audio.set_bgm(-1 as Audio.BGM)
	Audio.play_sfx(Audio.SFX.SCENE_TRANSITION_WAVE)
	get_tree().paused = true
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# 1. World Environment for Glow
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.0  # 會漸變淡入
	env.glow_strength = 1.2
	env.glow_bloom = 0.5
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	root.add_child(world_env)

	# 2. Wave Shader Rect
	var wave_rect = ColorRect.new()
	wave_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wave_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat = ShaderMaterial.new()
	mat.shader = load("res://Shaders/wave_transition.gdshader")
	mat.set_shader_parameter("cover_progress", -0.2)
	mat.set_shader_parameter("recede_progress", -0.2)
	mat.set_shader_parameter("noise_tex", wave_noise_tex)
	wave_rect.material = mat
	root.add_child(wave_rect)

	# 3. Foam Particles
	var vp_size = get_viewport().get_visible_rect().size
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 150
	particles.lifetime = 0.6
	particles.one_shot = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(20.0, vp_size.y / 2.0)
	particles.position = Vector2(-0.2 * vp_size.x, vp_size.y / 2.0)
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.direction = Vector2(-1, 0)
	particles.spread = 45.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 8.0
	particles.color = Color(1.2, 1.4, 2.0, 1.0)  # HDR Glow for particles

	var curve = Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = curve
	root.add_child(particles)

	var tween = create_tween().set_speed_scale(1)

	# 第一波海浪從左往右蓋滿，粒子跟隨波浪邊緣，同時泛光特效淡入
	tween.tween_property(env, "glow_intensity", 1.5, 0.4).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	(
		tween
		. parallel()
		. tween_property(mat, "shader_parameter/cover_progress", 1.2, 0.8)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		tween
		. parallel()
		. tween_property(particles, "position:x", 1.2 * vp_size.x, 0.8)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	tween.tween_callback(func(): await _switch_scene(target_scene))
	await scene_transition_finished
	tween = create_tween()

	# 退潮準備：粒子發射器回到左側
	tween.tween_callback(func(): particles.position.x = -0.2 * vp_size.x)
	tween.tween_callback(func(): particles.direction = Vector2(-1, 0))

	# 另一波海浪從左邊打過來，帶著退潮
	(
		tween
		. tween_property(mat, "shader_parameter/recede_progress", 1.2, 0.8)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		tween
		. parallel()
		. tween_property(particles, "position:x", 1.2 * vp_size.x, 0.8)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)

	# 退潮快結束時泛光特效淡出
	(
		tween
		. parallel()
		. tween_property(env, "glow_intensity", 0.0, 0.4)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
		. set_delay(0.4)
	)

	tween.tween_callback(root.queue_free)
	tween.tween_callback(transition_finished.emit)
	get_tree().paused = false


func transition_to_distortion(target_scene: String) -> void:
	preload_scene_async(target_scene)
	Audio.play_sfx(Audio.SFX.SCENE_TRANSITION)
	get_tree().paused = true
	shader_rect.show()

	# 重設 Shader 參數
	var mat = shader_rect.material as ShaderMaterial
	mat.set_shader_parameter("distortion", 0.0)
	mat.set_shader_parameter("aberration", 0.0)
	mat.set_shader_parameter("mix_amount", 0.0)

	var tween = create_tween()

	# ===== 階段一：次元裂隙拉伸與紅藍錯位 (0.8 秒) =====
	(
		tween
		. tween_property(mat, "shader_parameter/distortion", -4.0, 0.8)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. parallel()
		. tween_property(mat, "shader_parameter/aberration", 0.01, 0.8)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		tween
		. parallel()
		. tween_property(mat, "shader_parameter/mix_amount", 0.7, 0.8)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)

	# ===== 階段二：上下黑幕合體遮蔽整個畫面 (0.4 秒) =====
	# 將 append_property 改為 tween_property
	tween.tween_property(top_bar, "anchor_bottom", 0.5, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	(
		tween
		. parallel()
		. tween_property(bottom_bar, "anchor_top", 0.5, 0.4)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)

	# ===== 階段三：完全遮黑後，於背景更換場景 =====
	tween.tween_callback(func(): await _switch_scene(target_scene))

	# 讓新場景載入後有短暫時間載入資源
	# 將 append_interval 改為 tween_interval
	await scene_transition_finished
	tween = create_tween()

	# ===== 階段四：黑幕拉開，同時畫面漸變復原 (0.6 秒) =====
	# 將 append_property 改為 tween_property
	tween.tween_property(top_bar, "anchor_bottom", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	(
		tween
		. parallel()
		. tween_property(bottom_bar, "anchor_top", 1.0, 0.5)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_IN_OUT)
	)

	(
		tween
		. parallel()
		. tween_property(mat, "shader_parameter/distortion", 0.0, 0.6)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. parallel()
		. tween_property(mat, "shader_parameter/aberration", 0.0, 0.6)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		tween
		. parallel()
		. tween_property(mat, "shader_parameter/mix_amount", 0.0, 0.6)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)

	# 特效播放結束，隱藏著色器節點
	# 將 append_callback 改為 tween_callback
	tween.tween_callback(shader_rect.hide)
	tween.tween_callback(transition_finished.emit)
	get_tree().paused = false


## 立即發出 threaded loading request（不等待）。
## 如果你能提早知道目標場景路徑（例如玩家一走進傳送門範圍就知道），
## 可以在觸發轉場動畫「之前」就先呼叫這個函式，讓讀取時間完全被動畫遮蔽。
func preload_scene_async(path: String) -> void:
	if path == "":
		return
	var status = ResourceLoader.load_threaded_get_status(path)
	# 避免對同一個路徑重複發出 request
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)


## 等待場景背景讀取完成並回傳 PackedScene。
## 如果先前沒有呼叫過 preload_scene_async，這裡會自動補發 request。
func _await_scene_load(path: String) -> PackedScene:
	var status = ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(path)
		status = ResourceLoader.load_threaded_get_status(path)

	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# SceneTree.process_frame 不受 get_tree().paused 影響，每幀都會發出
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("場景背景讀取失敗: %s (status=%s)" % [path, status])
		return null

	return ResourceLoader.load_threaded_get(path) as PackedScene


## 統一的換場動作：優先用背景讀好的 PackedScene 換場，
## 避免走同步的 change_scene_to_file 造成的卡頓。
func _switch_scene(target_scene: String) -> void:
	if target_scene == "":
		get_tree().reload_current_scene()
		return

	var packed_scene := await _await_scene_load(target_scene)
	if packed_scene != null:
		get_tree().change_scene_to_packed(packed_scene)
	else:
		# 讀取失敗時 fallback 回同步讀取，至少能確保場景還是換得過去
		get_tree().change_scene_to_file(target_scene)
	scene_transition_finished.emit()
