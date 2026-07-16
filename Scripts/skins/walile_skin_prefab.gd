extends BaseSkin

const BASE_SCALE := Vector2(0.36, 0.36)
const WHEEL_ROTATION_SPEED = 20
const BODY_SWAY_MAGNITUDE = 10
const EYES_SWAY_MAGNITUDE = 4
const TIRES_SWAY_MAGNITUDE = 3
const SWAY_SPEED = 0.8
const DROP_TIME = 0.5
const GRAVITY = 5

var body_list: Array[Sprite2D]
var body_y = [18, 18, -6, -26, -48, -48]
var body_x = [-24, 24, 0, 0, 18, -18]
var time_passed = 0.0
var rotation_dir = 0
var moving = 0.0
var is_dead = false
var is_flying = false
var is_spawning = false

@onready var body = $Body
@onready var left_eye = $LeftEye
@onready var right_eye = $RightEye
@onready var neck = $Neck
@onready var left_tire = $LeftTire
@onready var right_tire = $RightTire
@onready var left_wheel = $LeftTire/LeftWheel
@onready var right_wheel = $RightTire/RightWheel


func _ready():
	scale = BASE_SCALE
	body_list = [left_tire, right_tire, body, neck, right_eye, left_eye]


func _process(delta):
	if is_dead or is_spawning:
		return

	if not is_flying:
		# 走路動畫
		var parent = get_meta("player") if has_meta("player") else get_parent()
		# 當它是 coconut 時才有 velocity 屬性
		if parent and "velocity" in parent:
			var vel = parent.velocity
			moving *= 0.92

			if vel.x > 10.0:
				rotation_dir = 1
			elif vel.x < -10.0:
				rotation_dir = -1

			if vel.length() > 10.0:
				time_passed += delta * 15.0
				moving += 0.1
				left_wheel.rotation_degrees += WHEEL_ROTATION_SPEED * rotation_dir
				right_wheel.rotation_degrees += WHEEL_ROTATION_SPEED * rotation_dir
			else:
				time_passed += delta * 4.0

			body.rotation_degrees = moving * BODY_SWAY_MAGNITUDE * sin(time_passed * SWAY_SPEED)
			left_eye.position.y = (
				body_y[5] + moving * EYES_SWAY_MAGNITUDE * sin(time_passed * SWAY_SPEED)
			)
			right_eye.position.y = (
				body_y[4] + moving * EYES_SWAY_MAGNITUDE * cos(time_passed * SWAY_SPEED)
			)
			left_tire.position.y = (
				body_y[0] + moving * TIRES_SWAY_MAGNITUDE * cos(time_passed * SWAY_SPEED)
			)
			right_tire.position.y = (
				body_y[1] + moving * TIRES_SWAY_MAGNITUDE * sin(time_passed * SWAY_SPEED)
			)


func play_spawn():
	is_spawning = true
	is_dead = false
	scale = BASE_SCALE
	modulate.a = 1.0
	var tween: Tween
	for i in body_list.size():
		body_list[i].position = Vector2(body_x[i], -500)
		body_list[i].rotation_degrees = 0
		body_list[i].modulate.a = 0.0
		tween = create_tween()
		(
			tween
			. tween_property(body_list[i], "position:y", body_y[i], DROP_TIME)
			. set_trans(Tween.TRANS_BOUNCE)
			. set_ease(Tween.EASE_OUT)
			. set_delay(0.1 * i)
		)
		tween.parallel().tween_property(body_list[i], "modulate:a", 1.0, DROP_TIME).set_delay(
			0.1 * i
		)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
	is_spawning = false


func play_die():
	is_dead = true
	var body_velocity = []
	var body_rotating = []
	for i in body_list.size():
		body_velocity.append(
			Vector2(body_x[i] * 0.4 + randf_range(-6, 6), body_y[i] * 0.2 + randf_range(-60, -30))
		)
		body_rotating.append(randf_range(3, 10) * sign(randi_range(0, 1) - 0.5))
	for i in 50:
		modulate.a -= 0.02
		for j in body_list.size():
			body_list[j].position += body_velocity[j]
			body_list[j].rotation_degrees += body_rotating[j]
			body_velocity[j] += Vector2.DOWN * GRAVITY
		await get_tree().create_timer(0.01).timeout
	is_dead = false


func play_eat_ball():
	var tween = create_tween()
	tween.tween_property(self, "scale", BASE_SCALE * 1.15, 0.09)
	tween.tween_property(self, "scale", BASE_SCALE, 0.18)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_jump():
	is_flying = true
	scale = BASE_SCALE
	var body_height = [0, 0, 15, 25, 35, 35]
	var tween: Tween
	for i in body_list.size():
		tween = create_tween()
		(
			tween
			. tween_property(body_list[i], "position:y", body_y[i] - body_height[i], DROP_TIME)
			. set_trans(Tween.TRANS_QUART)
			. set_ease(Tween.EASE_OUT)
			. set_delay(body_height[i] / 150)
		)
		(
			tween
			. tween_property(body_list[i], "position:y", body_y[i], DROP_TIME)
			. set_trans(Tween.TRANS_QUART)
			. set_ease(Tween.EASE_IN)
		)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
	is_flying = false


func play_land():
	is_flying = false
	scale = BASE_SCALE
	var body_list = [left_tire, right_tire, body, neck, right_eye, left_eye]
	var body_height = [0, 0, 2, 5, 8, 8]
	var tween: Tween
	for i in body_list.size():
		tween = create_tween()
		(
			tween
			. tween_property(body_list[i], "position:y", body_y[i] + body_height[i], DROP_TIME / 3)
			. set_trans(Tween.TRANS_QUART)
			. set_ease(Tween.EASE_OUT)
			. set_delay(body_height[i] / 30)
		)
		(
			tween
			. tween_property(body_list[i], "position:y", body_y[i], DROP_TIME / 3)
			. set_trans(Tween.TRANS_QUART)
			. set_ease(Tween.EASE_IN)
		)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
