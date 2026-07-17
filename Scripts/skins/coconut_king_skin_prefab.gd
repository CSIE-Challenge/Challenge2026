extends BaseSkin

const BASE_SCALE := Vector2(0.5, 0.5)
const LEAN_REF_SPEED := 300.0
const LEAN_MAX_TILT := 0.22
const LEAN_MAX_SHIFT := 6.0
const LEAN_FOLLOW := 9.0
const TRAIL_MOVE_SPEED := 30.0

# 招牌金色（皇冠、金幣、衝擊波共用同一支金）
const GOLD := Color(1, 0.84, 0.24)

# 落地金色衝擊波：一圈金環由小擴大並淡出（顯示座標，約在腳下）
const SHOCK_RADIUS := 9.0  # 金環初始半徑（local px）
const SHOCK_FOOT_Y := 22.0  # 腳下 y（與金幣爆散同高）

# 受擊暈眩：被陷阱打到時，眼睛螺旋、皇冠歪掉，三隻拿刀小海盜椰子跑出來護航，持續 3 秒
const HIT_DURATION := 3.0  # 演出總長（秒）
const DIZZY_SPIN := 7.0  # 螺旋眼每秒轉幾弧度
const CROWN_TILT := 0.45  # 皇冠歪掉角度（弧度）
const EYE_CENTER := Vector2(-9, -1)  # 睜著那隻眼的中心（Face 局部座標）
const ESCORT_COUNT := 3  # 小兵數量
const ESCORT_SCALE := 0.5  # 小海盜椰子相對本體的縮放
const ORBIT_CENTER := Vector2(0, 16)  # 繞圈中心（王腳下）
const ORBIT_RX := 42.0  # 繞圈橢圓長軸（左右）
const ORBIT_RY := 15.0  # 繞圈橢圓短軸（前後，壓扁成地面透視）
const ORBIT_SPEED := 7.5  # 繞圈角速度（rad/s，火急火燎）
const ESCORT_WADDLE := 0.3  # 奔跑時左右擺動幅度
const DASH_DIST := 200.0  # 衝出去的距離
const DASH_TIME := 0.4  # 衝出去所需時間

const COIN_TEX := preload("res://Shapes/Circle.svg")
const GLOW_TEX := preload("res://Shapes/soft_glow.svg")
const COCO_TEX := preload("res://Shapes/coconut_tree/Coconut.png")

var _last_pos: Vector2
var _vel := Vector2.ZERO

var _dizzy := false
var _hit_seq := 0  # 每次受擊 +1；復原時比對，避免舊的演出把新的截斷
var _hat_home_pos: Vector2
var _hat_home_rot: float
var _spiral: Line2D = null  # 螺旋眼（平時隱藏）
var _escorts: Array = []  # 護航中的小海盜椰子
var _orbit_angle := 0.0  # 小兵繞圈的共用角度

var _dust: CPUParticles2D = null  # 落地塵

@onready var body = $Body
@onready var face = $Body/Face
@onready var hat = $Body/Hat
@onready var pupil = $Body/Face/Pupil
@onready var catchlight = $Body/Face/Catchlight
@onready var jump_particles = $CoinParticlesJump
@onready var land_particles = $CoinParticlesLand
@onready var death_particles = $DeathParticles
@onready var wake_left = $WakeLeft
@onready var wake_right = $WakeRight


func _ready():
	scale = BASE_SCALE
	_last_pos = global_position
	_hat_home_pos = hat.position
	_hat_home_rot = hat.rotation
	_dust = _create_dust()
	_spiral = _create_spiral()


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

	# 暈眩時：螺旋眼持續轉，小兵繞著腳下火急火燎地跑（衝出去中的就不管，交給 tween）
	if _dizzy:
		if _spiral:
			_spiral.rotation += dt * DIZZY_SPIN
		_orbit_angle += dt * ORBIT_SPEED
		for e in _escorts:
			if not is_instance_valid(e) or e.get_meta("dashing", false):
				continue
			var a: float = _orbit_angle + float(e.get_meta("ang", 0.0))
			e.position = ORBIT_CENTER + Vector2(cos(a) * ORBIT_RX, sin(a) * ORBIT_RY)
			e.rotation = sin(_orbit_angle * 3.0 + float(e.get_meta("ang", 0.0))) * ESCORT_WADDLE


func play_spawn():
	_reset_hit()
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
	_reset_hit()
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
	jump_particles.restart()
	jump_particles.emitting = true


func play_land():
	var tween = create_tween()
	tween.tween_property(body, "scale", Vector2(1.25, 0.75), 0.1)
	tween.tween_property(body, "scale", Vector2.ONE, 0.15)
	land_particles.restart()
	land_particles.emitting = true
	_dust.restart()
	_dust.emitting = true
	_spawn_shockwave()


# ==========================================
# 受擊暈眩：眼睛螺旋 + 皇冠歪掉 + 三隻拿刀小海盜椰子護航，持續 HIT_DURATION 秒
# ==========================================
func play_hit():
	_hit_seq += 1
	var seq := _hit_seq
	_begin_hit()
	await get_tree().create_timer(HIT_DURATION).timeout
	# 期間又被打到就交給新的演出收尾，這裡不動
	if seq == _hit_seq and is_inside_tree():
		_end_hit()


func _begin_hit():
	_dizzy = true
	# 眼睛換成螺旋
	pupil.visible = false
	catchlight.visible = false
	_spiral.rotation = 0.0
	_spiral.visible = true
	# 皇冠歪掉
	var ht := create_tween()
	ht.tween_property(hat, "rotation", _hat_home_rot + CROWN_TILT, 0.18).set_trans(Tween.TRANS_BACK)
	ht.parallel().tween_property(hat, "position", _hat_home_pos + Vector2(3, 1), 0.18)
	# 護航小弟跑出來
	_spawn_escorts()


func _end_hit():
	_dizzy = false
	pupil.visible = true
	catchlight.visible = true
	if _spiral:
		_spiral.visible = false
	# 皇冠扶正
	var ht := create_tween()
	ht.tween_property(hat, "rotation", _hat_home_rot, 0.25).set_trans(Tween.TRANS_BACK)
	ht.parallel().tween_property(hat, "position", _hat_home_pos, 0.25)
	# 小弟一起往同一個方向衝出去（隨機左右、微微朝上）再消失
	var dash_sign := 1.0 if randf() < 0.5 else -1.0
	var dir := Vector2(dash_sign, -0.4).normalized()
	for i in _escorts.size():
		var e = _escorts[i]
		if not is_instance_valid(e):
			continue
		e.set_meta("dashing", true)  # 停止繞圈，改由 tween 接手
		var t := create_tween()
		t.tween_interval(i * 0.05)  # 前後錯開一點，像一列衝出去
		t.tween_property(e, "position", e.position + dir * DASH_DIST, DASH_TIME).set_ease(
			Tween.EASE_IN
		)
		t.parallel().tween_property(e, "rotation", e.rotation + dash_sign * TAU, DASH_TIME)
		t.parallel().tween_property(e, "scale", Vector2.ZERO, DASH_TIME)
		t.tween_callback(e.queue_free)
	_escorts.clear()


# 立刻歸位（重生／死亡時清乾淨，不做動畫）
func _reset_hit():
	_hit_seq += 1
	_dizzy = false
	if is_instance_valid(pupil):
		pupil.visible = true
	if is_instance_valid(catchlight):
		catchlight.visible = true
	if _spiral:
		_spiral.visible = false
	if is_instance_valid(hat):
		hat.rotation = _hat_home_rot
		hat.position = _hat_home_pos
	_clear_escorts()


func _spawn_escorts():
	_clear_escorts()
	_orbit_angle = 0.0
	for i in ESCORT_COUNT:
		var e := _make_escort()
		var off := TAU * float(i) / float(ESCORT_COUNT)  # 三隻均分在圈上
		e.set_meta("ang", off)
		e.set_meta("dashing", false)
		e.position = ORBIT_CENTER + Vector2(cos(off) * ORBIT_RX, sin(off) * ORBIT_RY)
		e.scale = Vector2.ZERO
		add_child(e)
		_escorts.append(e)
		# 蹦出來（位置交給 _process 繞圈，這裡只彈縮放）
		var t := create_tween()
		(
			t
			. tween_property(e, "scale", Vector2(ESCORT_SCALE, ESCORT_SCALE), 0.2)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)


func _clear_escorts():
	for e in _escorts:
		if is_instance_valid(e):
			e.queue_free()
	_escorts.clear()


# 一隻小海盜椰子：小椰子 + 紅頭巾 + 兩顆眼 + 一把彎刀
func _make_escort() -> Node2D:
	var e := Node2D.new()

	var coco := Sprite2D.new()
	coco.texture = COCO_TEX
	coco.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	coco.scale = Vector2(0.58, 0.58)
	e.add_child(coco)

	var bandana := Line2D.new()
	bandana.points = PackedVector2Array([Vector2(-13, -9), Vector2(13, -10)])
	bandana.width = 6.0
	bandana.default_color = Color(0.78, 0.16, 0.18)
	e.add_child(bandana)

	var eye_l := Polygon2D.new()
	eye_l.color = Color(0.1, 0.08, 0.07)
	eye_l.polygon = PackedVector2Array(
		[Vector2(-6, -1), Vector2(-4.5, -1), Vector2(-4.5, 2), Vector2(-6, 2)]
	)
	e.add_child(eye_l)
	var eye_r := Polygon2D.new()
	eye_r.color = Color(0.1, 0.08, 0.07)
	eye_r.polygon = PackedVector2Array(
		[Vector2(4.5, -1), Vector2(6, -1), Vector2(6, 2), Vector2(4.5, 2)]
	)
	e.add_child(eye_r)

	var blade := Line2D.new()
	blade.name = "Blade"
	blade.points = PackedVector2Array([Vector2(0, 0), Vector2(9, -12), Vector2(16, -20)])
	blade.width = 3.0
	blade.default_color = Color(0.86, 0.88, 0.92)
	blade.joint_mode = Line2D.LINE_JOINT_ROUND
	blade.begin_cap_mode = Line2D.LINE_CAP_ROUND
	blade.end_cap_mode = Line2D.LINE_CAP_ROUND
	blade.position = Vector2(11, 2)
	e.add_child(blade)
	var hilt := Line2D.new()
	hilt.points = PackedVector2Array([Vector2(5, 2), Vector2(17, 2)])
	hilt.width = 2.5
	hilt.default_color = Color(0.5, 0.34, 0.15)
	e.add_child(hilt)

	# 腳下生煙：邊跑邊冒淡煙，用世界座標讓煙留在跑過的路徑上
	var smoke := CPUParticles2D.new()
	smoke.texture = GLOW_TEX
	smoke.local_coords = false
	smoke.amount = 12
	smoke.lifetime = 0.5
	smoke.position = Vector2(0, 22)  # 腳下
	smoke.direction = Vector2(0, -1)
	smoke.spread = 55.0
	smoke.gravity = Vector2(0, -18)
	smoke.initial_velocity_min = 5.0
	smoke.initial_velocity_max = 22.0
	smoke.scale_amount_min = 0.05
	smoke.scale_amount_max = 0.13
	smoke.color = Color(0.92, 0.9, 0.84, 0.45)
	smoke.z_index = -1
	smoke.emitting = true
	e.add_child(smoke)

	return e


# ==========================================
# 落地金色衝擊波：一次性金環，由小擴大、變細、淡出後自毀
# ==========================================
func _spawn_shockwave():
	var ring := Line2D.new()
	var seg := 40
	for k in seg + 1:
		var a := TAU * float(k) / float(seg)
		ring.add_point(Vector2(cos(a), sin(a)) * SHOCK_RADIUS)
	ring.width = 3.0
	ring.default_color = GOLD
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.position = Vector2(0, SHOCK_FOOT_Y)
	ring.scale = Vector2(0.35, 0.2)  # 壓扁成地面上的橢圓
	ring.z_index = -1
	add_child(ring)

	var t := create_tween()
	t.tween_property(ring, "scale", Vector2(1.8, 1.0), 0.35).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "width", 0.5, 0.35)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	t.tween_callback(ring.queue_free)


func _create_dust() -> CPUParticles2D:
	var d := CPUParticles2D.new()
	d.texture = GLOW_TEX
	d.emitting = false
	d.amount = 8
	d.lifetime = 0.4
	d.one_shot = true
	d.explosiveness = 0.9
	d.position = Vector2(0, SHOCK_FOOT_Y)
	d.direction = Vector2(0, -0.2)
	d.spread = 90.0
	d.gravity = Vector2(0, -30)
	d.initial_velocity_min = 60.0
	d.initial_velocity_max = 130.0
	d.scale_amount_min = 0.06
	d.scale_amount_max = 0.14
	d.color = Color(1, 0.93, 0.7, 0.5)
	d.z_index = -1
	add_child(d)
	return d


# 螺旋眼：一條阿基米德螺線，覆在睜著的那隻眼上（平時隱藏，暈眩時顯示並旋轉）
func _create_spiral() -> Line2D:
	var sp := Line2D.new()
	var pts := 34
	var turns := 2.6
	var rmax := 4.6
	for i in pts:
		var f := float(i) / float(pts - 1)
		var ang := f * TAU * turns
		sp.add_point(Vector2(cos(ang), sin(ang)) * (f * rmax))
	sp.width = 1.2
	sp.default_color = Color(0.1, 0.08, 0.07)
	sp.joint_mode = Line2D.LINE_JOINT_ROUND
	sp.begin_cap_mode = Line2D.LINE_CAP_ROUND
	sp.end_cap_mode = Line2D.LINE_CAP_ROUND
	sp.position = EYE_CENTER
	sp.z_index = 5
	sp.visible = false
	face.add_child(sp)
	return sp
