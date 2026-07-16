extends BaseSkin

const EYE_DISPLACEMENT = Vector2(6, 0)
const RING_SHADER = preload("res://Shaders/golden_ring.gdshader")
const EYE_GRADIENT_BLUE: Gradient = preload("res://sans_eye_gradient_blue.tres")
const EYE_GRADIENT_YELLOW: Gradient = preload("res://sans_eye_gradient_yellow.tres")

@export var add_max_point_per_coconut := 10
@export var max_point_decrease_period := 0.2
@export var max_point := 30

var game_data: Dictionary = GameData.new().data
var player_jump_velocity: float = game_data["player"]["jump_velocity"]
var player_jump_gravity: float = game_data["player"]["jump_gravity"]
var player_jump_gravity_multiplier: float = game_data["player"]["jump_fall_multiplier"]
var max_trail_points = 0
var player_rise_time: float
var player_rise_length: float
var mult := 0.96
var is_active := true
var eye_is_blue := true

@onready var eye_effect: Line2D = $EyeEffect
@onready var jump_bone: NinePatchRect = $JumpBone
@onready var sprite: Sprite2D = $Sprite
@onready var max_point_timer: Timer = $MaxPointTimer
@onready var spawn_anim: AnimationPlayer = $SpawnBones/AnimationPlayer


func _ready() -> void:
	jump_bone.visible = false
	is_active = true
	player_rise_time = player_jump_velocity / player_jump_gravity
	player_rise_length = player_jump_velocity * player_rise_time / 2 * mult
	max_point_timer.start(max_point_decrease_period)
	max_point_timer.timeout.connect(_on_max_point_timer_timeout)


func play_spawn():
	spawn_anim.play("Spawn")
	sprite.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.15).set_delay(0.2)


func _process(_delta):
	if is_active:
		eye_effect.add_point(sprite.global_position + EYE_DISPLACEMENT)
		if eye_effect.get_point_count() > max_trail_points:
			eye_effect.remove_point(0)
			eye_effect.remove_point(0)
	elif eye_effect.get_point_count() > 0:
		eye_effect.remove_point(0)


func play_land() -> void:
	var land_effect = preload("res://Scenes/skins/land_bones.tscn").instantiate() as Node2D
	add_child(land_effect)
	land_effect.reparent($"..")
	land_effect.global_position = global_position


func play_die() -> void:
	is_active = false
	$DieEffect.emitting = true


func play_jump() -> void:
	jump_bone.visible = true
	jump_bone.self_modulate = Color(1, 1, 1, 1)
	jump_bone.size = Vector2(40, 22)
	var tween = create_tween()
	(
		tween
		. tween_method(_update_physics, 0.0, player_rise_time, player_rise_time)
		. set_trans(Tween.TRANS_LINEAR)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await tween.finished
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_method(_update_fall_physics, 0.0, 0.1, 0.1).set_trans(Tween.TRANS_LINEAR).set_ease(
		Tween.EASE_IN_OUT
	)
	tween2.tween_property(jump_bone, "self_modulate", Color.TRANSPARENT, 0.1)
	await tween2.finished
	jump_bone.visible = false


func play_eat_ball():
	eye_is_blue = !eye_is_blue
	if eye_is_blue:
		eye_effect.gradient = EYE_GRADIENT_BLUE
	else:
		eye_effect.gradient = EYE_GRADIENT_YELLOW
	max_trail_points = clampi(max_trail_points + add_max_point_per_coconut, 0, max_point)
	eye_effect.width = 3.0
	var tween = create_tween()
	tween.tween_property(eye_effect, "width", 6.0, 0.2)
	tween.tween_property(eye_effect, "width", 3.0, 1.0)
	_spawn_ring()


func _update_physics(t: float) -> void:
	var displacement = (player_jump_velocity * t) - (0.5 * player_jump_gravity * t * t)
	jump_bone.size = Vector2(40, displacement * mult)


func _update_fall_physics(t: float) -> void:
	var displacement = (
		player_rise_length - 0.5 * player_jump_gravity * player_jump_gravity_multiplier * t * t
	)
	jump_bone.size = Vector2(40, displacement * mult)


func _on_max_point_timer_timeout() -> void:
	max_trail_points = clampi(max_trail_points - 1, 0, max_point)
	print(max_trail_points)


func _spawn_ring():
	var ring = ColorRect.new()
	ring.size = Vector2(150, 150)  # 擴大衝擊波最大尺寸
	ring.top_level = true

	var mat = ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter("outer_radius", 0.0)
	mat.set_shader_parameter("inner_radius", 0.0)
	if eye_is_blue:
		mat.set_shader_parameter("ring_color", Color(0.6, 0.902, 1.0, 0.3))  # 降低透明度，使其更為柔和
	else:
		mat.set_shader_parameter("ring_color", Color(1.0, 0.85, 0.2, 0.15))  # 降低透明度，使其更為柔和
	ring.material = mat
	add_child(ring)
	ring.global_position = self.global_position - ring.size / 2.0

	# 1. 外圈：在 0.35 秒內快速向外擴散到最大半徑 0.5（使用 TRANS_EXPO 爆發性擴張）
	var r_tween = create_tween()
	(
		r_tween
		. tween_property(mat, "shader_parameter/outer_radius", 0.5, 0.25)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)

	# 2. 內圈：延遲 0.07 秒才開始擴散，使用不同的二次方曲線 (TRANS_QUAD) 在 0.28 秒內追上外圈 (目標值為 0.5)
	# 這樣在動畫結束時，內圈會完全追上外圈，使環的厚度歸零並自然消失
	var r_inner_tween = create_tween()
	(
		r_inner_tween
		. tween_property(mat, "shader_parameter/inner_radius", 0.5, 0.18)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
		. set_delay(0.07)
	)

	# 3. 衝擊波本體淡出（採用 Ease out 曲線使淡出更平滑自然）
	var fade_tween = create_tween()
	fade_tween.tween_property(ring, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN
	)

	# 完成後銷毀
	var free_tween = create_tween()
	free_tween.tween_interval(0.4)
	free_tween.tween_callback(ring.queue_free)
