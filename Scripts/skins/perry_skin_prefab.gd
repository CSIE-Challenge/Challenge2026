extends BaseSkin

# 鴨嘴獸泰瑞 (Agent P) —— 直立版，用基本色塊圖形程序化組成
# 面向：預設朝右（嘴喙朝畫面前方，靠 velocity 左右翻面）

# 各部位待機時的基準值（動畫結束後歸位用）
const FOOT_BASE_Y := 19.0
const ARM_BASE_ROT := 0.0
# 身體本體色（靠 modulate 上色，閃光後要還原成這個顏色，否則會變白）
const BODY_COLOR := Color(0.16, 0.66, 0.62, 1)

var is_dead: bool = false
var is_spawning: bool = false
var is_flying: bool = false
var walk_time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var arm_l: Sprite2D = $Visual/ArmL
@onready var arm_r: Sprite2D = $Visual/ArmR
@onready var foot_l: Sprite2D = $Visual/FootL
@onready var foot_r: Sprite2D = $Visual/FootR
@onready var hat_crown: Sprite2D = $Visual/HatCrown
@onready var pupil_l: Sprite2D = $Visual/PupilL
@onready var pupil_r: Sprite2D = $Visual/PupilR
@onready var spawn_particles: CPUParticles2D = $SpawnParticles
@onready var death_particles: CPUParticles2D = $DeathParticles
@onready var walk_particles: CPUParticles2D = $WalkParticles
@onready var jump_particles: CPUParticles2D = $JumpParticles
@onready var star_trail: CPUParticles2D = $StarTrail


func _ready():
	scale = Vector2.ZERO


func _process(delta):
	if is_dead or is_spawning:
		return

	var parent = get_meta("player") if has_meta("player") else get_parent()
	var vel := Vector2.ZERO
	if parent and "velocity" in parent:
		vel = parent.velocity

	# 轉向（嘴喙預設朝右）
	if vel.x > 10.0:
		visual.scale.x = abs(visual.scale.x)
	elif vel.x < -10.0:
		visual.scale.x = -abs(visual.scale.x)

	if is_flying:
		# 飛行姿勢：身體上仰、雙手上舉、收腳，不揚塵
		visual.rotation = lerp(visual.rotation, -0.12, delta * 8.0)
		arm_l.rotation = lerp(arm_l.rotation, -2.2, delta * 10.0)
		arm_r.rotation = lerp(arm_r.rotation, 2.2, delta * 10.0)
		walk_particles.emitting = false
		star_trail.emitting = false
		return

	if vel.length() > 15.0:
		# 走路：擺手、交替抬腳、身體上下律動 + 揚塵
		walk_time += delta * 14.0
		var swing = sin(walk_time)
		arm_l.rotation = swing * 0.7
		arm_r.rotation = -swing * 0.7
		foot_l.position.y = FOOT_BASE_Y - maxf(0.0, swing) * 3.5
		foot_r.position.y = FOOT_BASE_Y - maxf(0.0, -swing) * 3.5
		visual.rotation = swing * 0.05
		visual.position.y = -absf(swing) * 2.5
		walk_particles.emitting = true
		star_trail.emitting = true
	else:
		# 待機呼吸，手腳歸位、停止揚塵
		walk_time += delta * 3.0
		arm_l.rotation = lerp(arm_l.rotation, ARM_BASE_ROT, delta * 8.0)
		arm_r.rotation = lerp(arm_r.rotation, ARM_BASE_ROT, delta * 8.0)
		foot_l.position.y = lerp(foot_l.position.y, FOOT_BASE_Y, delta * 8.0)
		foot_r.position.y = lerp(foot_r.position.y, FOOT_BASE_Y, delta * 8.0)
		visual.rotation = lerp(visual.rotation, 0.0, delta * 8.0)
		visual.position.y = sin(walk_time) * 1.2
		walk_particles.emitting = false
		star_trail.emitting = false


func play_spawn():
	is_dead = false
	is_flying = false
	is_spawning = true
	visual.modulate = Color(1, 1, 1, 1)
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	body.modulate = BODY_COLOR
	arm_l.rotation = ARM_BASE_ROT
	arm_r.rotation = ARM_BASE_ROT

	spawn_particles.restart()
	spawn_particles.emitting = true

	# 從零彈跳登場
	scale = Vector2.ZERO
	var tween = create_tween()
	(
		tween
		. tween_property(self, "scale", Vector2.ONE * 1.15, 0.2)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame

	# 抬帽致意
	var hat_tween = create_tween()
	hat_tween.tween_property(hat_crown, "position:y", hat_crown.position.y - 6.0, 0.12)
	hat_tween.tween_property(hat_crown, "position:y", hat_crown.position.y, 0.12)

	is_spawning = false


func play_jump():
	if is_dead:
		return
	is_flying = true
	walk_particles.emitting = false

	# 跳躍推進特效
	jump_particles.restart()
	jump_particles.emitting = true

	var tween = create_tween()
	# 起跳伸展
	tween.tween_property(visual, "scale:y", abs(visual.scale.y) * 1.2, 0.1)
	tween.tween_property(visual, "scale:y", abs(visual.scale.y), 0.15)


func play_land():
	if is_dead:
		return
	is_flying = false
	visual.rotation = 0.0

	# 著地揚塵
	spawn_particles.restart()
	spawn_particles.emitting = true

	# 鎖定目前面向（±1），整段壓扁都用同一個符號，避免 scale.x 變號造成翻轉
	var sx := signf(visual.scale.x)
	if sx == 0.0:
		sx = 1.0

	var tween = create_tween()
	# 落地壓扁回彈（x 保持面向符號，只改大小）
	tween.tween_property(visual, "scale", Vector2(sx * 1.2, 0.7), 0.05)
	tween.tween_property(visual, "scale", Vector2(sx * 1.0, 1.0), 0.15)


func play_eat_ball():
	if is_dead:
		return
	# 吃球：眨眼 + 身體閃光
	var blink = create_tween()
	blink.tween_property(pupil_l, "scale:y", 0.005, 0.06)
	blink.parallel().tween_property(pupil_r, "scale:y", 0.005, 0.06)
	blink.tween_property(pupil_l, "scale:y", pupil_l.scale.y, 0.08)
	blink.parallel().tween_property(pupil_r, "scale:y", pupil_r.scale.y, 0.08)

	var pulse = create_tween()
	pulse.tween_property(body, "modulate", BODY_COLOR * 1.6, 0.08)
	pulse.tween_property(body, "modulate", BODY_COLOR, 0.2)


func play_die():
	is_dead = true
	is_spawning = false
	walk_particles.emitting = false
	star_trail.emitting = false

	death_particles.restart()
	death_particles.emitting = true

	var tween = create_tween()
	# 旋轉倒下並淡出
	tween.tween_property(visual, "rotation", PI, 0.4).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(visual, "position:y", 20.0, 0.4)
	tween.tween_property(visual, "modulate:a", 0.0, 0.2)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
