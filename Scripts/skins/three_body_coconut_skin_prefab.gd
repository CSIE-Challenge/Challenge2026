extends BaseSkin

# 三體椰（黑暗椰林法則）—— 三顆椰子固定 120° 均分繞著中央軌道環轉。
# 每隔隨機 20~40 秒在「恆紀元（優雅、椰子棕、綠環）」與「亂紀元（暗黑、黑環、
# 轉更快並上下擺動）」之間切換，切換瞬間浮現中文「恆」/「亂」大字。
enum Era { STABLE, CHAOS }  # 恆 / 亂

const COCO_TEX := preload("res://Shapes/coconut_body.svg")
const ERA_FONT := preload("res://Assets/fonts/Cubic_11.ttf")
const SOFT_TEX := preload("res://Shapes/soft_glow.svg")

# 亂紀元「黑暗森林」特效配色
const SMOKE_COLOR := Color(0.14, 0.08, 0.22)  # 虛空黑煙
const GLINT_COLOR := Color(0.45, 1.0, 0.6)  # 獵人之眼詭綠

const BODY_COUNT := 3
const COCO_SCALE := 0.2  # 椰子貼圖縮放（100px → 20px）
const SYSTEM_SCALE := 0.64  # 椰子繞轉（球的旋轉）視覺縮放

# ── 中央軌道環（大小同碰撞箱）──
const RING_RADIUS := 13.5  # = 玩家碰撞半徑（不動）
const RING_COLOR_STABLE := Color(0.2, 0.85, 0.35, 0.9)  # 恆紀元：綠
const RING_COLOR_CHAOS := Color(0.05, 0.05, 0.07, 0.95)  # 亂紀元：黑

# 椰子繞轉半徑（模擬空間），乘上 SYSTEM_SCALE 後正好貼在軌道環上
const ORBIT_RADIUS := RING_RADIUS / SYSTEM_SCALE

# ── 運動參數 ──
const ANG_SPEED_STABLE := 1.2  # 恆紀元轉速 (rad/s)
const ANG_SPEED_CHAOS := 2.6  # 亂紀元轉速 (rad/s，更快)
const WOBBLE_AMP := 4.0  # 亂紀元上下擺動幅度（模擬空間）
const WOBBLE_FREQ := 5.0  # 上下擺動頻率

# ── 恆紀元 / 亂紀元 ──
const ERA_PERIOD_MIN := 20.0  # 切換間隔隨機 20~40 秒
const ERA_PERIOD_MAX := 40.0

const TINT_STABLE := Color(0.68, 0.47, 0.28)  # 椰子棕
const TINT_CHAOS := Color(0.24, 0.20, 0.34)  # 暗冷黑
const TRAIL_STABLE := Color(0.85, 0.65, 0.40, 0.5)
const TRAIL_CHAOS := Color(0.55, 0.35, 0.85, 0.7)

var pos: Array = []  # 每顆椰子位置 Vector2（模擬空間）
var bodies: Array = []  # Sprite2D
var trails: Array = []  # Line2D
var ring_node: Line2D = null  # 中央軌道環

# 亂紀元黑暗森林特效
var smokes: Array = []  # 每顆椰子的虛空黑煙 CPUParticles2D
var glints: CPUParticles2D = null  # 獵人之眼微光

var era: int = Era.STABLE
var era_timer: float = 0.0
var era_period: float = 30.0  # 本輪的切換秒數（每次隨機重抽）
var base_angle: float = 0.0  # 目前旋轉角
var wobble_time: float = 0.0
var walk_boost: float = 1.0
var is_dead: bool = false

@onready var spawn_particles: CPUParticles2D = $SpawnParticles
@onready var death_particles: CPUParticles2D = $DeathParticles


func _ready():
	scale = Vector2.ZERO
	_init_bodies()


func _init_bodies() -> void:
	_create_ring()
	_create_dark_forest()

	var trail_root := Node2D.new()
	trail_root.name = "Trails"
	trail_root.scale = Vector2(SYSTEM_SCALE, SYSTEM_SCALE)
	add_child(trail_root)
	var body_root := Node2D.new()
	body_root.name = "Bodies"
	body_root.scale = Vector2(SYSTEM_SCALE, SYSTEM_SCALE)
	add_child(body_root)

	for i in BODY_COUNT:
		var ang := TAU * float(i) / float(BODY_COUNT)  # 120° 均分
		var p := Vector2(cos(ang), sin(ang)) * ORBIT_RADIUS
		pos.append(p)

		var tr := Line2D.new()
		tr.width = 3.0 - i * 0.4
		tr.default_color = TRAIL_STABLE
		tr.joint_mode = Line2D.LINE_JOINT_ROUND
		tr.begin_cap_mode = Line2D.LINE_CAP_ROUND
		tr.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail_root.add_child(tr)
		trails.append(tr)

		var s := Sprite2D.new()
		s.texture = COCO_TEX
		s.scale = Vector2(COCO_SCALE, COCO_SCALE)
		s.modulate = TINT_STABLE
		s.position = p
		body_root.add_child(s)
		bodies.append(s)


# 中央軌道環：大小與碰撞箱一致，恆紀元綠、亂紀元黑
func _create_ring() -> void:
	var ring := Line2D.new()
	ring.name = "OrbitRing"
	var seg := 48
	for k in seg + 1:
		var a := TAU * float(k) / float(seg)
		ring.add_point(Vector2(cos(a), sin(a)) * RING_RADIUS)
	ring.width = 2.0
	ring.default_color = RING_COLOR_STABLE
	ring.joint_mode = Line2D.LINE_JOINT_ROUND
	ring.z_index = -1
	add_child(ring)
	ring_node = ring


# 亂紀元的黑暗森林氛圍：獵人之眼 + 虛空黑煙尾流（預設關閉）
func _create_dark_forest() -> void:
	# 獵人之眼：環狀閃爍的詭綠微光
	var twinkle := Curve.new()
	twinkle.add_point(Vector2(0.0, 0.0))
	twinkle.add_point(Vector2(0.4, 1.0))
	twinkle.add_point(Vector2(1.0, 0.0))
	glints = CPUParticles2D.new()
	glints.texture = SOFT_TEX
	glints.emitting = false
	glints.amount = 8
	glints.lifetime = 1.1
	glints.randomness = 1.0
	glints.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	glints.emission_sphere_radius = RING_RADIUS + 4.0
	glints.gravity = Vector2.ZERO
	glints.initial_velocity_min = 0.0
	glints.initial_velocity_max = 0.0
	glints.scale_amount_min = 0.05
	glints.scale_amount_max = 0.11
	glints.scale_amount_curve = twinkle
	glints.color = GLINT_COLOR
	glints.z_index = -2
	add_child(glints)

	# 虛空黑煙：每顆椰子一組，位置每幀跟隨椰子
	var smoke_ramp := Gradient.new()
	smoke_ramp.offsets = PackedFloat32Array([0.0, 1.0])
	smoke_ramp.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.0))
	for i in BODY_COUNT:
		var sm := CPUParticles2D.new()
		sm.texture = SOFT_TEX
		sm.local_coords = false
		sm.emitting = false
		sm.amount = 10
		sm.lifetime = 0.7
		sm.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		sm.emission_sphere_radius = 2.0
		sm.direction = Vector2(0, -1)
		sm.spread = 180.0
		sm.gravity = Vector2(0, -12)
		sm.initial_velocity_min = 4.0
		sm.initial_velocity_max = 16.0
		sm.scale_amount_min = 0.12
		sm.scale_amount_max = 0.26
		sm.scale_amount_curve = grow
		sm.color = SMOKE_COLOR
		sm.color_ramp = smoke_ramp
		sm.z_index = -1
		add_child(sm)
		smokes.append(sm)


func _set_dark_forest(active: bool) -> void:
	for sm in smokes:
		sm.emitting = active
	if glints:
		glints.emitting = active


func _process(delta):
	if is_dead:
		return
	_update_era(delta)
	_step_motion(delta)
	_update_visuals(delta)


# ==========================================
# 受控繞轉：三顆固定 120° 均分繞圈；亂紀元加上下擺動且轉更快
# ==========================================
func _step_motion(delta: float) -> void:
	var parent = get_meta("player") if has_meta("player") else get_parent()
	var moving := false
	if parent and "velocity" in parent:
		moving = parent.velocity.length() > 15.0
	walk_boost = 1.25 if moving else 1.0

	var chaos := era == Era.CHAOS
	var ang_speed: float = ANG_SPEED_CHAOS if chaos else ANG_SPEED_STABLE
	base_angle += delta * ang_speed * walk_boost
	wobble_time += delta * WOBBLE_FREQ

	for i in BODY_COUNT:
		var a := base_angle + TAU * float(i) / float(BODY_COUNT)
		var p := Vector2(cos(a), sin(a)) * ORBIT_RADIUS
		if chaos:
			# 亂紀元：每顆錯開相位的上下擺動
			p.y += WOBBLE_AMP * sin(wobble_time + float(i) * 2.094)
		pos[i] = p


func _update_visuals(delta: float) -> void:
	var max_pts := 14 if era == Era.STABLE else 22
	for i in BODY_COUNT:
		var s: Sprite2D = bodies[i]
		s.position = pos[i]
		s.rotation += delta * (1.0 + i * 0.5)
		var tr: Line2D = trails[i]
		tr.add_point(pos[i])
		while tr.get_point_count() > max_pts:
			tr.remove_point(0)
		# 黑煙尾流跟隨椰子（顯示座標）
		if i < smokes.size():
			smokes[i].position = pos[i] * SYSTEM_SCALE


# ==========================================
# 恆紀元 / 亂紀元 切換
# ==========================================
func _update_era(delta: float) -> void:
	era_timer += delta
	if era_timer >= era_period:
		era_timer -= era_period
		era_period = randf_range(ERA_PERIOD_MIN, ERA_PERIOD_MAX)
		_switch_era()


func _switch_era() -> void:
	era = Era.CHAOS if era == Era.STABLE else Era.STABLE
	var to_chaos := era == Era.CHAOS

	var body_tint := TINT_CHAOS if to_chaos else TINT_STABLE
	var trail_col := TRAIL_CHAOS if to_chaos else TRAIL_STABLE
	var ring_col := RING_COLOR_CHAOS if to_chaos else RING_COLOR_STABLE
	for s in bodies:
		create_tween().tween_property(s, "modulate", body_tint, 0.5)
	for tr in trails:
		tr.default_color = trail_col
	if ring_node:
		create_tween().tween_property(ring_node, "default_color", ring_col, 0.5)

	# 亂紀元開啟黑暗森林氛圍
	_set_dark_forest(to_chaos)

	_show_era_text(to_chaos)


func _show_era_text(chaos: bool) -> void:
	var lbl := Label.new()
	lbl.text = "亂" if chaos else "恆"
	lbl.add_theme_font_override("font", ERA_FONT)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override(
		"font_color", Color(0.88, 0.18, 0.32) if chaos else Color(1.0, 0.92, 0.7)
	)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	lbl.z_index = 30
	lbl.pivot_offset = Vector2(32, 36)
	lbl.position = Vector2(-32, -92)
	add_child(lbl)

	lbl.modulate.a = 0.0
	lbl.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.parallel().tween_property(lbl, "modulate:a", 1.0, 0.15)
	(
		t
		. parallel()
		. tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.3)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	t.parallel().tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.9)
	t.chain().tween_property(lbl, "modulate:a", 0.0, 0.35)
	t.tween_callback(lbl.queue_free)


# ==========================================
# 標準特效介面
# ==========================================
func play_spawn():
	is_dead = false
	era = Era.STABLE
	era_timer = 0.0
	era_period = randf_range(ERA_PERIOD_MIN, ERA_PERIOD_MAX)
	base_angle = 0.0
	wobble_time = 0.0
	for i in BODY_COUNT:
		bodies[i].modulate = TINT_STABLE
		trails[i].modulate = Color(1, 1, 1, 1)
		trails[i].default_color = TRAIL_STABLE
		trails[i].clear_points()
	if ring_node:
		ring_node.default_color = RING_COLOR_STABLE
		ring_node.modulate.a = 1.0
	# 重生為恆紀元 → 關閉黑暗森林
	for sm in smokes:
		sm.emitting = false
	if glints:
		glints.emitting = false

	spawn_particles.restart()
	spawn_particles.emitting = true

	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_jump():
	if is_dead:
		return
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_land():
	if is_dead:
		return
	spawn_particles.restart()
	spawn_particles.emitting = true
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.2, 0.85), 0.05)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_eat_ball():
	if is_dead:
		return
	# 吃球：三顆椰子同時亮一下
	for s in bodies:
		var base: Color = s.modulate
		var t := create_tween()
		t.tween_property(s, "modulate", base * 1.7, 0.08)
		t.tween_property(s, "modulate", base, 0.25)


func play_die():
	is_dead = true
	death_particles.restart()
	death_particles.emitting = true

	# 關閉黑暗森林 + 中央軌道環潰散
	for sm in smokes:
		sm.emitting = false
	if glints:
		glints.emitting = false
	if ring_node:
		create_tween().tween_property(ring_node, "modulate:a", 0.0, 0.3)

	# 三顆椰子被甩飛四散
	for i in BODY_COUNT:
		var s: Sprite2D = bodies[i]
		var dir: Vector2 = pos[i].normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var t := create_tween()
		t.parallel().tween_property(s, "position", pos[i] + dir * 170.0, 0.5).set_ease(
			Tween.EASE_OUT
		)
		t.parallel().tween_property(s, "rotation", s.rotation + PI * 3.0, 0.5)
		t.parallel().tween_property(s, "modulate:a", 0.0, 0.5)
	for tr in trails:
		create_tween().tween_property(tr, "modulate:a", 0.0, 0.3)

	await get_tree().create_timer(0.5).timeout
