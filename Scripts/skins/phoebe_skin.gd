extends BaseSkin

# --- Visual Settings ---
const IDLE_WAVE_THRESHOLD: float = 3.0
const MAX_LEAN_ANGLE: float = 8.0  # How many degrees to tilt when running

# State flags
var is_dead: bool = false
var is_spawning: bool = false
var is_celebrating: bool = false
var is_jumping: bool = false
var is_idle_waving: bool = false

var idle_time: float = 0.0
var player: CharacterBody2D = null

# Active tweens for juice effects
var scale_tween: Tween
var rotation_tween: Tween
var current_visual_state: String = "none"

# Onready variables must be declared LAST, right before your methods!
@onready var sprite = $AnimatedSprite2D


func _ready() -> void:
	if has_meta("player"):
		player = get_meta("player")


func _process(delta: float) -> void:
	if is_dead:
		_set_visual_state("failed")
		return

	# 1. Grab inputs
	var horizontal_input = Input.get_axis("move_left", "move_right")
	var vertical_input = Input.is_action_pressed("move_up") or Input.is_action_pressed("move_down")
	var is_moving = (horizontal_input != 0) or vertical_input

	# 2. Inactivity tracking
	if is_moving or is_jumping:
		idle_time = 0.0
		is_idle_waving = false
		is_spawning = false
		is_celebrating = false
	else:
		if not is_spawning and not is_celebrating and not is_idle_waving:
			idle_time += delta
			if idle_time >= IDLE_WAVE_THRESHOLD:
				is_idle_waving = true

	# 3. Determine and assign current animation state
	if is_spawning or is_celebrating or is_idle_waving:
		_set_visual_state("waving")
	elif is_jumping:
		_set_visual_state("jumping")
	elif horizontal_input < 0:
		_set_visual_state("running_left")
	elif horizontal_input > 0:
		_set_visual_state("running_right")
	elif vertical_input:
		_set_visual_state("running_up_down")
	else:
		_set_visual_state("idle")


# --- Dynamic State Machine ---


func _set_visual_state(new_state: String) -> void:
	if current_visual_state == new_state:
		return

	current_visual_state = new_state

	match new_state:
		"idle", "waving":
			sprite.play(new_state)
			_start_breathing_loop()
			_apply_lean(0.0)

		"running_left":
			_stop_breathing_loop()
			sprite.play("running_left")
			_apply_lean(-MAX_LEAN_ANGLE)

		"running_right":
			_stop_breathing_loop()
			sprite.play("running_right")
			_apply_lean(MAX_LEAN_ANGLE)

		"running_up_down":
			_stop_breathing_loop()
			sprite.play("running")
			_apply_lean(0.0)

		"jumping":
			_stop_breathing_loop()
			sprite.play("jumping")
			_apply_lean(0.0)

		"failed":
			_stop_breathing_loop()
			if rotation_tween and rotation_tween.is_valid():
				rotation_tween.kill()

			# Reset visual changes so the failed loop looks completely natural
			sprite.scale = Vector2.ONE
			sprite.rotation_degrees = 0.0
			sprite.play("failed")


# --- Event-Driven Juice Effects ---


func play_spawn() -> void:
	is_spawning = true
	is_dead = false
	is_celebrating = false
	is_jumping = false
	is_idle_waving = false
	idle_time = 0.0

	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	sprite.scale = Vector2.ZERO
	scale_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(sprite, "scale", Vector2.ONE, 1.2)

	if is_inside_tree():
		get_tree().create_timer(1.5).timeout.connect(func(): is_spawning = false)


func play_die() -> void:
	is_dead = true
	_set_visual_state("failed")

	# Keep the game tree pause-timer happy
	if is_inside_tree():
		await get_tree().create_timer(1.0, true).timeout


func play_eat_ball() -> void:
	if not is_dead:
		is_celebrating = true
		idle_time = 0.0

		if scale_tween and scale_tween.is_valid():
			scale_tween.kill()
		sprite.scale = Vector2(1.3, 1.3)
		scale_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(sprite, "scale", Vector2.ONE, 0.4)

		if is_inside_tree():
			get_tree().create_timer(1.0).timeout.connect(func(): is_celebrating = false)


func play_jump() -> void:
	if not is_dead:
		is_jumping = true
		idle_time = 0.0

		if scale_tween and scale_tween.is_valid():
			scale_tween.kill()
		sprite.scale = Vector2(0.75, 1.35)
		scale_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(sprite, "scale", Vector2.ONE, 0.35)


func play_land() -> void:
	if not is_dead:
		is_jumping = false
		idle_time = 0.0

		if scale_tween and scale_tween.is_valid():
			scale_tween.kill()
		sprite.scale = Vector2(1.4, 0.65)
		scale_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(sprite, "scale", Vector2.ONE, 0.6)


# --- Tween Helper Engines ---


func _apply_lean(angle_degrees: float) -> void:
	if rotation_tween and rotation_tween.is_valid():
		rotation_tween.kill()
	rotation_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rotation_tween.tween_property(sprite, "rotation_degrees", angle_degrees, 0.15)


func _start_breathing_loop() -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	sprite.scale = Vector2.ONE

	scale_tween = create_tween().set_loops()
	(
		scale_tween
		. tween_property(sprite, "scale", Vector2(0.97, 1.03), 0.7)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		scale_tween
		. tween_property(sprite, "scale", Vector2(1.03, 0.97), 0.7)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)


func _stop_breathing_loop() -> void:
	if scale_tween and scale_tween.is_valid():
		scale_tween.kill()
	sprite.scale = Vector2.ONE
