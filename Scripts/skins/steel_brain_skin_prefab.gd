extends BaseSkin

# 鋼鐵大腦造型（智慧鐵人挑戰獎勵）—— 主體是一顆金屬光澤的大腦，
# 待機時緩慢呼吸並閃爍智慧電流；走路時噴出思考的青色電花尾流。

const CYAN := Color(0.25, 0.9, 1.0, 1)  # 智慧電流的青色

# 血量 <= 此值時，鋼鐵大腦進化為黃金大腦
const GOLD_HEALTH_THRESHOLD := 3
const STEEL_TEX := preload("res://Shapes/steel_brain_icon.svg")
const GOLD_TEX := preload("res://Shapes/steel_brain_icon_gold.svg")

# 落地時在地面奔騰的電流顏色（鋼鐵＝藍、黃金＝金）
const ARC_GLOW_BLUE := Color(0.30, 0.68, 1.0, 0.30)
const ARC_CORE_BLUE := Color(0.72, 0.92, 1.0, 0.95)
const ARC_GLOW_GOLD := Color(1.0, 0.72, 0.18, 0.30)
const ARC_CORE_GOLD := Color(1.0, 0.95, 0.55, 0.95)

# 粒子特效（走路電花／生成／死亡）的色調：鋼鐵＝冷藍、黃金＝暖金
const TINT_BLUE := Color(0.75, 0.9, 1.0)
const TINT_GOLD := Color(1.0, 0.9, 0.6)

var is_dead: bool = false
var is_spawning: bool = false
var is_flying: bool = false
var is_golden: bool = false
var glow_time: float = 0.0

@onready var visual: Node2D = $Visual
@onready var icon: Sprite2D = $Visual/Icon
@onready var spark_trail: CPUParticles2D = $SparkTrail
@onready var spawn_particles: CPUParticles2D = $SpawnParticles
@onready var death_particles: CPUParticles2D = $DeathParticles
@onready var ground_arcs: Node2D = $GroundArcs


func _ready():
	scale = Vector2.ZERO


func _process(delta):
	if is_dead or is_spawning:
		return

	var parent = get_meta("player") if has_meta("player") else get_parent()
	var vel := Vector2.ZERO
	if parent and "velocity" in parent:
		vel = parent.velocity

	# 依血量在鋼鐵／黃金大腦之間切換
	if parent and "health" in parent:
		var want_gold: bool = parent.health <= GOLD_HEALTH_THRESHOLD
		if want_gold != is_golden:
			_set_golden(want_gold)

	glow_time += delta * 3.0

	# 智慧電流：大腦持續明滅的青色脈動
	var pulse := 1.0 + sin(glow_time * 2.0) * 0.25
	icon.modulate = Color(pulse, pulse, pulse, 1)

	if is_flying:
		# 飛行時輕微傾斜、不噴電花
		icon.rotation = lerp(icon.rotation, sin(glow_time) * 0.15, delta * 6.0)
		spark_trail.emitting = false
		return

	if vel.length() > 15.0:
		# 走路：上下彈跳、腦袋微晃、噴思考電花
		visual.position.y = -absf(sin(glow_time * 3.0)) * 3.0
		icon.rotation = sin(glow_time * 6.0) * 0.08
		spark_trail.emitting = true
	else:
		# 待機：緩慢呼吸浮動
		visual.position.y = sin(glow_time) * 1.5
		icon.rotation = lerp(icon.rotation, 0.0, delta * 4.0)
		spark_trail.emitting = false


func play_spawn():
	is_dead = false
	is_flying = false
	is_spawning = true
	visual.modulate = Color(1, 1, 1, 1)
	visual.position = Vector2.ZERO
	icon.rotation = 0.0
	icon.modulate = Color(1, 1, 1, 1)
	is_golden = false
	icon.texture = STEEL_TEX
	_apply_effect_theme()

	spawn_particles.restart()
	spawn_particles.emitting = true

	# 組裝登場：從零彈性放大
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame

	is_spawning = false


func play_jump():
	if is_dead:
		return
	is_flying = true
	spark_trail.emitting = false

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

	# 落地時電流沿地面奔騰竄開（鋼鐵藍／黃金金）
	_spawn_ground_arcs()

	var tween = create_tween()
	# 落地壓扁回彈
	tween.tween_property(visual, "scale", Vector2(1.25, 0.75), 0.05)
	tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.15)


func play_eat_ball():
	if is_dead:
		return
	# 吃球：靈光一閃（鋼鐵青／黃金金）+ 脈動放大
	var flash := (TINT_GOLD if is_golden else CYAN) * 1.6
	var tween = create_tween()
	tween.tween_property(icon, "modulate", flash, 0.08)
	tween.tween_property(icon, "modulate", Color(1, 1, 1, 1), 0.25)

	var pop = create_tween()
	pop.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.1)
	pop.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.15)


# ==========================================
# 落地地面電流：金色電弧從腳底往左右沿地面奔騰竄開
# ==========================================
func _spawn_ground_arcs() -> void:
	var count := randi_range(4, 6)
	for i in count:
		_make_ground_arc()


func _make_ground_arc() -> void:
	var dir: float = 1.0 if randf() < 0.5 else -1.0
	var length := randf_range(34.0, 62.0)  # 中等範圍
	# 依目前是鋼鐵還是黃金大腦決定電流顏色
	var glow_col := ARC_GLOW_GOLD if is_golden else ARC_GLOW_BLUE
	var core_col := ARC_CORE_GOLD if is_golden else ARC_CORE_BLUE
	var glow := _new_arc_line(6.0, glow_col)
	var core := _new_arc_line(2.2, core_col)
	ground_arcs.add_child(glow)
	ground_arcs.add_child(core)

	# reach 0→1 快速竄出後持續抖動，同時淡出，最後清除
	var tw := create_tween()
	tw.set_parallel(true)
	(
		tw
		. tween_method(_update_arc.bind(glow, core, dir, length), 0.0, 1.0, 0.34)
		. set_trans(Tween.TRANS_QUART)
		. set_ease(Tween.EASE_OUT)
	)
	tw.tween_property(glow, "modulate:a", 0.0, 0.28).set_delay(0.08)
	tw.tween_property(core, "modulate:a", 0.0, 0.28).set_delay(0.08)
	tw.chain().tween_callback(
		func():
			if is_instance_valid(glow):
				glow.queue_free()
			if is_instance_valid(core):
				core.queue_free()
	)


func _new_arc_line(w: float, col: Color) -> Line2D:
	var line := Line2D.new()
	line.width = w
	line.default_color = col
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	return line


func _update_arc(progress: float, glow: Line2D, core: Line2D, dir: float, length: float) -> void:
	if not is_instance_valid(core):
		return
	var seg := 9
	var reach := length * progress
	var pts := PackedVector2Array()
	for s in range(seg + 1):
		var t := float(s) / float(seg)
		var x := dir * reach * t
		# 頭尾貼地，中段隨機抖動製造電流竄動感（越往末端抖幅越小）
		var jitter := 0.0
		if s != 0 and s != seg:
			jitter = randf_range(-4.5, 4.5) * (1.0 - t * 0.35)
		pts.append(Vector2(x, jitter))
	core.points = pts
	if is_instance_valid(glow):
		glow.points = pts


func _set_golden(on: bool) -> void:
	is_golden = on
	icon.texture = GOLD_TEX if on else STEEL_TEX
	_apply_effect_theme()
	# 進化／退回瞬間彈一下並亮一閃
	var flash = create_tween()
	flash.tween_property(icon, "scale", Vector2(0.62, 0.62), 0.08).set_trans(Tween.TRANS_BACK)
	flash.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.12)


# 讓走路電花／生成／死亡等粒子特效跟著鋼鐵（藍）或黃金（金）切換色調與材質
func _apply_effect_theme() -> void:
	var tex := GOLD_TEX if is_golden else STEEL_TEX
	var tint := TINT_GOLD if is_golden else TINT_BLUE
	for p in [spark_trail, spawn_particles, death_particles]:
		p.texture = tex
		p.color = tint


func play_die():
	is_dead = true
	is_spawning = false
	spark_trail.emitting = false

	death_particles.restart()
	death_particles.emitting = true

	var tween = create_tween()
	# 短路過載：劇烈抖動後縮小消失
	(
		tween
		. parallel()
		. tween_property(visual, "scale", Vector2.ZERO, 0.4)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	tween.parallel().tween_property(icon, "rotation", 0.6, 0.4)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.5)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame
