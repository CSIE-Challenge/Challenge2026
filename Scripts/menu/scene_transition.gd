extends CanvasLayer

var ach_max_width: float = 350.0
var ach_margin_x: float = 20.0
var ach_border_thickness: float = 4.0
var ach_display_time: float = 3.0

var ach_is_animating: bool = false
var ach_queue: Array = []

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
	fade_rect.color.a = 0.0
	var tween = create_tween()
	# 淡出至黑幕
	tween.tween_property(fade_rect, "color:a", 1.0, 1.0)
	# 切換場景
	tween.tween_callback(func(): get_tree().change_scene_to_file(target_scene))
	# 等待載入
	tween.tween_interval(0.1)
	# 淡入畫面
	tween.tween_property(fade_rect, "color:a", 0.0, 1.0)


func transition_shop(target_scene: String) -> void:
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

	tween.tween_callback(func(): get_tree().change_scene_to_file(target_scene))
	tween.tween_interval(0.1)

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


func transition_to(target_scene: String) -> void:
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
	tween.tween_callback(
		func():
			if target_scene == "":
				get_tree().reload_current_scene()
			else:
				get_tree().change_scene_to_file(target_scene)
	)

	# 讓新場景載入後有短暫時間載入資源
	# 將 append_interval 改為 tween_interval
	tween.tween_interval(0.1)

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
