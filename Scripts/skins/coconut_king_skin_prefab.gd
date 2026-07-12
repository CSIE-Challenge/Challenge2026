extends BaseSkin

const BASE_SCALE := Vector2(0.5, 0.5)
const LEAN_REF_SPEED := 300.0
const LEAN_MAX_TILT := 0.22
const LEAN_MAX_SHIFT := 6.0
const LEAN_FOLLOW := 9.0
const TRAIL_MOVE_SPEED := 30.0

var _last_pos: Vector2
var _vel := Vector2.ZERO

@onready var body = $Body
@onready var face = $Body/Face
@onready var coin_particles = $CoinParticles
@onready var death_particles = $DeathParticles
@onready var wake_left = $WakeLeft
@onready var wake_right = $WakeRight


func _ready():
	scale = BASE_SCALE
	_last_pos = global_position


func _process(delta):
	var dt := maxf(delta, 0.0001)
	var raw_vel := (global_position - _last_pos) / dt
	_last_pos = global_position
	_vel = _vel.lerp(raw_vel, clampf(dt * 15.0, 0.0, 1.0))

	var speed := _vel.length()

	var moving := speed > TRAIL_MOVE_SPEED
	if wake_left.emitting != moving:
		wake_left.emitting = moving
		wake_right.emitting = moving

	var follow := clampf(dt * LEAN_FOLLOW, 0.0, 1.0)
	var drag := -_vel.limit_length(LEAN_REF_SPEED) / LEAN_REF_SPEED * LEAN_MAX_SHIFT
	body.position = body.position.lerp(drag, follow)
	var target_tilt := clampf(_vel.x / LEAN_REF_SPEED, -1.0, 1.0) * LEAN_MAX_TILT
	body.rotation = lerp_angle(body.rotation, target_tilt, follow)


func play_spawn():
	scale = Vector2.ZERO
	modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(self, "scale", BASE_SCALE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_die():
	wake_left.emitting = false
	wake_right.emitting = false
	death_particles.restart()
	death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_eat_ball():
	var face_tween = create_tween()
	face_tween.tween_property(face, "scale", Vector2(1.0, 0.15), 0.06)
	face_tween.tween_property(face, "scale", Vector2.ONE, 0.12)
	var body_tween = create_tween()
	body_tween.tween_property(body, "scale", Vector2(1.15, 1.15), 0.09)
	body_tween.tween_property(body, "scale", Vector2.ONE, 0.18)


func play_jump():
	var tween = create_tween()
	tween.tween_property(body, "scale", Vector2(0.8, 1.25), 0.1)
	tween.tween_property(body, "scale", Vector2.ONE, 0.15)
	_burst_coins()


func play_land():
	var tween = create_tween()
	tween.tween_property(body, "scale", Vector2(1.25, 0.75), 0.1)
	tween.tween_property(body, "scale", Vector2.ONE, 0.15)
	_burst_coins()


func _burst_coins():
	coin_particles.restart()
	coin_particles.emitting = true
