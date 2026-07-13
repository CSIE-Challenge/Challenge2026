extends BaseSkin

# Claude 造型（AI 活動獎勵）—— 主體是會旋轉的 Claude 星芒標誌，
# 走路時噴出小小的 Gemini 四角星尾流。

const ICON_COLOR := Color(1, 1, 1, 1)  # Icon 貼圖本身已是橘色，這裡不額外染色

var is_dead: bool = false
var is_spawning: bool = false
var is_flying: bool = false
var spin: float = 0.0
var glow_time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var icon: Sprite2D = $Visual/Icon
@onready var gemini_trail: CPUParticles2D = $GeminiTrail
@onready var spawn_particles: CPUParticles2D = $SpawnParticles
@onready var death_particles: CPUParticles2D = $DeathParticles


func _ready():
	scale = Vector2.ZERO


func _process(delta):
	if is_dead or is_spawning:
		return

	var parent = get_meta("player") if has_meta("player") else get_parent()
	var vel := Vector2.ZERO
	if parent and "velocity" in parent:
		vel = parent.velocity

	# 計時器（供走路/待機的上下浮動使用）
	glow_time += delta * 3.0

	if is_flying:
		# 飛行時高速自轉、不噴尾流
		spin += delta * 12.0
		icon.rotation = spin
		gemini_trail.emitting = false
		return

	if vel.length() > 15.0:
		# 走路：加速自轉、上下彈跳、噴 Gemini 尾流
		spin += delta * 7.0
		visual.position.y = -absf(sin(glow_time * 3.0)) * 3.0
		gemini_trail.emitting = true
	else:
		# 待機：緩慢自轉、輕微浮動
		spin += delta * 1.5
		visual.position.y = sin(glow_time) * 1.5
		gemini_trail.emitting = false

	icon.rotation = spin


func play_spawn():
	is_dead = false
	is_flying = false
	is_spawning = true
	visual.modulate = Color(1, 1, 1, 1)
	visual.position = Vector2.ZERO
	icon.modulate = ICON_COLOR

	spawn_particles.restart()
	spawn_particles.emitting = true

	# 從零旋轉放大登場
	scale = Vector2.ZERO
	spin = -PI
	var tween = create_tween()
	(
		tween
		. parallel()
		. tween_property(self, "scale", Vector2.ONE, 0.35)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.parallel().tween_property(icon, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame

	spin = 0.0
	is_spawning = false


func play_jump():
	if is_dead:
		return
	is_flying = true
	gemini_trail.emitting = false

	spawn_particles.restart()
	spawn_particles.emitting = true

	var tween = create_tween()
	# 起跳彈一下
	tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.15)


func play_land():
	if is_dead:
		return
	is_flying = false

	spawn_particles.restart()
	spawn_particles.emitting = true

	var tween = create_tween()
	# 落地壓扁回彈
	tween.tween_property(visual, "scale", Vector2(1.25, 0.75), 0.05)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.15)


func play_eat_ball():
	if is_dead:
		return
	# 吃球：閃亮 + 脈動放大
	var tween = create_tween()
	tween.tween_property(icon, "modulate", Color(1.6, 1.6, 1.6, 1), 0.08)
	tween.tween_property(icon, "modulate", ICON_COLOR, 0.25)

	var pop = create_tween()
	pop.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1)
	pop.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.15)


func play_die():
	is_dead = true
	is_spawning = false
	gemini_trail.emitting = false

	death_particles.restart()
	death_particles.emitting = true

	var tween = create_tween()
	# 高速旋轉縮小消失
	tween.parallel().tween_property(icon, "rotation", spin + PI * 4.0, 0.5)
	(
		tween
		. parallel()
		. tween_property(visual, "scale", Vector2.ZERO, 0.4)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.5)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
