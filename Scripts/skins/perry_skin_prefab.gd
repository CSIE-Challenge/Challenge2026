extends BaseSkin

# 鴨嘴獸泰瑞 (Agent P) —— 直立版，用基本色塊圖形程序化組成
# 面向：預設朝右（嘴喙朝畫面前方，靠 velocity 左右翻面）

# 各部位待機時的基準值（動畫結束後歸位用）
const FOOT_BASE_Y := 19.0
const ARM_BASE_ROT := 0.0
# 身體本體色（靠 modulate 上色，閃光後要還原成這個顏色，否則會變白）
const BODY_COLOR := Color(0.16, 0.66, 0.62, 1)

# —— 冰面陷阱：變回「爬行狀態」的寵物泰瑞用的基準值 ——
# 直立特務姿勢下各部位的原始位置／大小（場景檔內設定值），離開冰面時歸位用
const BODY_BASE_SCALE := Vector2(0.24, 0.24)
const ARM_L_BASE := Vector2(-12, 2)
const ARM_R_BASE := Vector2(12, 2)
const FOOT_L_BASE_X := -5.0
const FOOT_R_BASE_X := 5.0
const BILL_BASE := Vector2(0, 2)
const TAIL_BASE := Vector2(-11, 10)
const TAIL_BASE_ROT := 0.5
const EYE_WHITE_L_BASE := Vector2(-4, -9)
const EYE_WHITE_R_BASE := Vector2(4, -9)
const PUPIL_L_BASE := Vector2(-4, -9)
const PUPIL_R_BASE := Vector2(4, -9)
const HAT_BRIM_BASE := Vector2(0, -16)
const HAT_CROWN_BASE := Vector2(0, -22)
const HAT_BAND_BASE := Vector2(0, -18.5)
# 帽子被甩飛的落點（往後上方彈開並淡出）
const HAT_BRIM_OFF := Vector2(3, -30)
const HAT_CROWN_OFF := Vector2(5, -34)
const HAT_BAND_OFF := Vector2(4, -32)

# —— 寵物泰瑞（側面橫向四腳）各部位目標值，面向預設朝右（+x 為前方）——
# 身體壓成橫躺的扁橢圓、往下沉貼近地面
const CRAWL_BODY_POS := Vector2(0, 8)
const CRAWL_BODY_SCALE := Vector2(0.32, 0.19)
# 嘴喙往正前方伸出
const CRAWL_BILL_POS := Vector2(19, 9)
# 呆滯的鬥雞眼：兩眼往前上方、瞳孔各自看不同方向
const CRAWL_EYE_WHITE_L := Vector2(9, -1)
const CRAWL_EYE_WHITE_R := Vector2(14, 1)
const CRAWL_PUPIL_L := Vector2(8, -3)
const CRAWL_PUPIL_R := Vector2(15, 3)
# 河狸尾巴平貼在後方
const CRAWL_TAIL_POS := Vector2(-19, 7)
const CRAWL_TAIL_ROT := -0.15
# 四隻短腳：前腳用雙手、後腳用雙腳，都撐在身體下方
const CRAWL_ARM_L := Vector2(8, 17)
const CRAWL_ARM_R := Vector2(13, 17)
const CRAWL_FOOT_L := Vector2(-14, 17)
const CRAWL_FOOT_R := Vector2(-8, 17)

# 玩家在冰面上時 acceleration 會被壓到極低（正常 100，冰面 ≤5）
const ICE_ACC_THRESHOLD := 50.0

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
@onready var bill: Sprite2D = $Visual/Bill
@onready var tail: Sprite2D = $Visual/Tail
@onready var eye_white_l: Sprite2D = $Visual/EyeWhiteL
@onready var eye_white_r: Sprite2D = $Visual/EyeWhiteR
@onready var hat_brim: Sprite2D = $Visual/HatBrim
@onready var hat_crown: Sprite2D = $Visual/HatCrown
@onready var hat_band: Sprite2D = $Visual/HatBand
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

	# 冰面陷阱偵測：玩家踩到果汁冰面時 acceleration 會被壓到極低
	var on_ice := false
	if parent and "acceleration" in parent:
		on_ice = parent.acceleration < ICE_ACC_THRESHOLD

	if is_flying:
		# 飛行姿勢：身體上仰、雙手上舉、收腳，不揚塵（空中時戴回帽子）
		_restore_agent_form(delta)
		visual.rotation = lerp(visual.rotation, -0.12, delta * 8.0)
		arm_l.rotation = lerp(arm_l.rotation, -2.2, delta * 10.0)
		arm_r.rotation = lerp(arm_r.rotation, 2.2, delta * 10.0)
		walk_particles.emitting = false
		star_trail.emitting = false
		return

	if on_ice:
		# 站上冰面：特務泰瑞失去平衡，變回四腳趴地爬行的寵物泰瑞
		_animate_crawl(delta, vel)
		return

	# 一般地面：先把帽子與各部位歸回直立特務姿態
	_restore_agent_form(delta)
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


# 冰面：變回側面橫向、四腳貼地的寵物泰瑞
# （帽子甩飛、身體壓成橫躺橢圓、嘴喙朝前、尾巴平貼、四腳撐在下方、鬥雞眼呆滯）
func _animate_crawl(delta: float, vel: Vector2) -> void:
	var w := delta * 8.0

	# 帽子甩飛並淡出（不再是特務 P）
	_set_hat(HAT_BRIM_OFF, HAT_CROWN_OFF, HAT_BAND_OFF, 0.6, 0.0, w)

	# 身體壓成橫躺的扁橢圓、整體下沉貼地，並隨冰面輕輕左右滑動
	walk_time += delta * 6.0
	visual.rotation = lerp(visual.rotation, 0.0, w)
	visual.position.y = lerp(visual.position.y, 3.0, w)
	visual.position.x = lerp(visual.position.x, sin(walk_time) * 2.0, w)
	body.position = body.position.lerp(CRAWL_BODY_POS, w)
	body.scale = body.scale.lerp(CRAWL_BODY_SCALE, w)

	# 嘴喙往正前方伸出、尾巴平貼在後方
	bill.position = bill.position.lerp(CRAWL_BILL_POS, w)
	tail.position = tail.position.lerp(CRAWL_TAIL_POS, w)
	tail.rotation = lerp(tail.rotation, CRAWL_TAIL_ROT, w)

	# 鬥雞眼呆樣：兩眼移到前上方、瞳孔各自看不同方向
	eye_white_l.position = eye_white_l.position.lerp(CRAWL_EYE_WHITE_L, w)
	eye_white_r.position = eye_white_r.position.lerp(CRAWL_EYE_WHITE_R, w)
	pupil_l.position = pupil_l.position.lerp(CRAWL_PUPIL_L, w)
	pupil_r.position = pupil_r.position.lerp(CRAWL_PUPIL_R, w)

	# 四隻短腳撐在身體下方（前腳用雙手、後腳用雙腳），直直朝下
	arm_l.position = arm_l.position.lerp(CRAWL_ARM_L, w)
	arm_r.position = arm_r.position.lerp(CRAWL_ARM_R, w)
	arm_l.rotation = lerp(arm_l.rotation, 0.0, w)
	arm_r.rotation = lerp(arm_r.rotation, 0.0, w)
	foot_l.position = foot_l.position.lerp(CRAWL_FOOT_L, w)
	foot_r.position = foot_r.position.lerp(CRAWL_FOOT_R, w)

	# 滑動時揚起冰屑，但不留星光尾跡
	walk_particles.emitting = vel.length() > 15.0
	star_trail.emitting = false


# 瞬間把身體、四肢、五官、帽子全部歸回直立特務泰瑞（重生時用，不做補間）
func _snap_agent_form() -> void:
	_set_hat(HAT_BRIM_BASE, HAT_CROWN_BASE, HAT_BAND_BASE, 0.0, 1.0, 1.0)
	body.position = Vector2.ZERO
	body.scale = BODY_BASE_SCALE
	arm_l.position = ARM_L_BASE
	arm_r.position = ARM_R_BASE
	foot_l.position = Vector2(FOOT_L_BASE_X, FOOT_BASE_Y)
	foot_r.position = Vector2(FOOT_R_BASE_X, FOOT_BASE_Y)
	bill.position = BILL_BASE
	tail.position = TAIL_BASE
	tail.rotation = TAIL_BASE_ROT
	eye_white_l.position = EYE_WHITE_L_BASE
	eye_white_r.position = EYE_WHITE_R_BASE
	pupil_l.position = PUPIL_L_BASE
	pupil_r.position = PUPIL_R_BASE
	visual.position.x = 0.0


# 把身體、四肢、五官、帽子歸回直立特務泰瑞（走路／待機／飛行共用）
func _restore_agent_form(delta: float) -> void:
	var w := delta * 8.0
	_set_hat(HAT_BRIM_BASE, HAT_CROWN_BASE, HAT_BAND_BASE, 0.0, 1.0, w)
	body.position = body.position.lerp(Vector2.ZERO, w)
	body.scale = body.scale.lerp(BODY_BASE_SCALE, w)
	arm_l.position = arm_l.position.lerp(ARM_L_BASE, w)
	arm_r.position = arm_r.position.lerp(ARM_R_BASE, w)
	foot_l.position.x = lerp(foot_l.position.x, FOOT_L_BASE_X, w)
	foot_r.position.x = lerp(foot_r.position.x, FOOT_R_BASE_X, w)
	bill.position = bill.position.lerp(BILL_BASE, w)
	tail.position = tail.position.lerp(TAIL_BASE, w)
	tail.rotation = lerp(tail.rotation, TAIL_BASE_ROT, w)
	eye_white_l.position = eye_white_l.position.lerp(EYE_WHITE_L_BASE, w)
	eye_white_r.position = eye_white_r.position.lerp(EYE_WHITE_R_BASE, w)
	pupil_l.position = pupil_l.position.lerp(PUPIL_L_BASE, w)
	pupil_r.position = pupil_r.position.lerp(PUPIL_R_BASE, w)
	visual.position.x = lerp(visual.position.x, 0.0, w)


# 帽簷、帽冠、帽帶一起補間到指定位置／旋轉／透明度
func _set_hat(
	brim_target: Vector2,
	crown_target: Vector2,
	band_target: Vector2,
	rot_target: float,
	alpha_target: float,
	w: float
) -> void:
	hat_brim.position = hat_brim.position.lerp(brim_target, w)
	hat_crown.position = hat_crown.position.lerp(crown_target, w)
	hat_band.position = hat_band.position.lerp(band_target, w)
	hat_brim.rotation = lerp(hat_brim.rotation, rot_target, w)
	hat_crown.rotation = lerp(hat_crown.rotation, rot_target, w)
	hat_band.rotation = lerp(hat_band.rotation, rot_target, w)
	var a: float = lerpf(hat_brim.modulate.a, alpha_target, w)
	hat_brim.modulate.a = a
	hat_crown.modulate.a = a
	hat_band.modulate.a = a


func play_spawn():
	is_dead = false
	is_flying = false
	is_spawning = true
	# 重生時把帽子與寵物爬行姿態全部瞬間歸位，避免殘留上一輪的冰面狀態
	_snap_agent_form()
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
