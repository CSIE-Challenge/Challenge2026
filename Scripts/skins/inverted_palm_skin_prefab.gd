extends BaseSkin

# 椰子樹倒著長的小島 —— 一座漂浮的小沙島（主角），椰子樹從島底倒著往下長。
# 吃椰子會讓島底的樹成長：樹苗 → 小樹（5 顆）→ 椰子樹（20 顆）。
# 島本體會緩緩上下漂浮；移動時倒吊的樹像鐘擺一樣晃動。

const HOVER_AMP := 1.6      # 漂浮上下振幅（prefab 座標）
const HOVER_FREQ := 1.6     # 漂浮頻率
const PENDULUM_MAX := 0.3   # 鐘擺最大傾角（弧度）

const STAGE_SAPLING := 0    # 樹苗
const STAGE_SMALL := 1      # 小樹
const STAGE_FULL := 2       # 椰子樹
const EVOLVE_EAT_COUNTS := [5, 20]  # 吃到第幾顆椰子時進化

const STAGE_TEXTURES: Array[Texture2D] = [
	preload("res://Shapes/inverted_palm_stage1.svg"),
	preload("res://Shapes/inverted_palm_stage2.svg"),
	preload("res://Shapes/inverted_palm.svg"),
]
const LEVEL_UP_FONT := preload("res://Assets/fonts/PixelMplus12-Bold.ttf")

var t: float = 0.0
var is_dead: bool = false
var eat_count: int = 0
var stage: int = STAGE_SAPLING

@onready var plant: Node2D = $Plant
@onready var body: Sprite2D = $Plant/Body
@onready var leaves: CPUParticles2D = $Leaves
@onready var evolve_burst: CPUParticles2D = $EvolveBurst
@onready var coconut_drop: CPUParticles2D = $CoconutDrop
@onready var spawn_particles: CPUParticles2D = $SpawnParticles


func _ready():
	scale = Vector2.ZERO


func _process(delta):
	if is_dead:
		return
	t += delta

	var parent = get_meta("player") if has_meta("player") else get_parent()
	var vx := 0.0
	var moving := false
	if parent and "velocity" in parent:
		vx = parent.velocity.x
		moving = parent.velocity.length() > 15.0

	# 倒吊的樹像鐘擺：往右移動時樹梢（下方）往左拖、並隨速度加大擺盪
	var sway_amp: float = 0.12 if moving else 0.04
	var sway_freq: float = 5.0 if moving else 1.8
	var pendulum: float = clampf(vx * 0.0025, -PENDULUM_MAX, PENDULUM_MAX)
	plant.rotation = pendulum + sin(t * sway_freq) * sway_amp

	# 漂浮小島：整座島緩緩上下浮動
	plant.position.y = sin(t * HOVER_FREQ) * HOVER_AMP


func _set_stage(new_stage: int) -> void:
	stage = clampi(new_stage, STAGE_SAPLING, STAGE_FULL)
	body.texture = STAGE_TEXTURES[stage]
	# 樹苗還沒有葉子可以掉，小樹之後才會飄落葉
	leaves.emitting = stage >= STAGE_SMALL and not is_dead


func _evolve(new_stage: int) -> void:
	_set_stage(new_stage)

	# 進化演出：金色光環擴散 + 雙重閃光 + 大彈跳 + 椰葉椰子齊發
	spawn_particles.restart()
	spawn_particles.emitting = true
	evolve_burst.restart()
	evolve_burst.emitting = true

	_spawn_evolve_ring(0.0)
	_spawn_evolve_ring(0.15)
	_spawn_level_up_text()

	var flash := create_tween()
	flash.tween_property(body, "modulate", Color(2.6, 2.6, 2.2, 1), 0.08)
	flash.tween_property(body, "modulate", Color(1, 1, 1, 1), 0.12)
	flash.tween_property(body, "modulate", Color(2.0, 2.0, 1.7, 1), 0.08)
	flash.tween_property(body, "modulate", Color(1, 1, 1, 1), 0.3)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.45, 1.45), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var spin := create_tween()
	spin.tween_property(plant, "rotation", 0.18, 0.1)
	spin.tween_property(plant, "rotation", -0.14, 0.12)
	spin.tween_property(plant, "rotation", 0.0, 0.15)


func _spawn_level_up_text() -> void:
	var label := Label.new()
	label.text = "LEVEL UP!"
	label.add_theme_font_override("font", LEVEL_UP_FONT)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.05))
	label.add_theme_constant_override("outline_size", 3)
	label.z_index = 10
	add_child(label)
	label.reset_size()
	# 置中在星球正上方，往上浮出並淡出
	label.position = Vector2(-label.size.x / 2.0, -32.0)
	var tw := label.create_tween()
	tw.parallel().tween_property(label, "position:y", label.position.y - 14.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(label.queue_free)


func _spawn_evolve_ring(delay: float) -> void:
	var ring := EvolveRing.new()
	add_child(ring)
	ring.start(delay)


# 進化時往外擴散的金色光環
class EvolveRing:
	extends Node2D

	var radius: float = 7.0
	var alpha: float = 0.9

	func _draw():
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(1.0, 0.95, 0.55, alpha), 3.0)

	func start(delay: float) -> void:
		var tw := create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_method(_step, 0.0, 1.0, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_callback(queue_free)

	func _step(f: float) -> void:
		radius = 7.0 + 34.0 * f
		alpha = 0.9 * (1.0 - f)
		queue_redraw()


# ==========================================
# 標準特效介面
# ==========================================
func play_spawn():
	is_dead = false
	t = 0.0
	eat_count = 0
	plant.rotation = 0.0
	plant.position = Vector2.ZERO
	body.modulate = Color(1, 1, 1, 1)
	_set_stage(STAGE_SAPLING)

	spawn_particles.restart()
	spawn_particles.emitting = true

	# 小島從天而降般彈性浮現
	scale = Vector2.ZERO
	var tween = create_tween()
	(
		tween
		. tween_property(self, "scale", Vector2.ONE, 0.5)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	if tween:
		await tween.finished
	else:
		await get_tree().process_frame


func play_jump():
	if is_dead:
		return
	# 起跳：島往上帶、樹被搖了一下，椰子被甩下來
	coconut_drop.restart()
	coconut_drop.emitting = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.9, 1.18), 0.1)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_land():
	if is_dead:
		return
	spawn_particles.restart()
	spawn_particles.emitting = true
	# 落地：整座島壓扁回彈
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 0.8), 0.05)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_eat_ball():
	if is_dead:
		return

	eat_count += 1
	if stage == STAGE_SAPLING and eat_count >= EVOLVE_EAT_COUNTS[0]:
		_evolve(STAGE_SMALL)
		return
	if stage == STAGE_SMALL and eat_count >= EVOLVE_EAT_COUNTS[1]:
		_evolve(STAGE_FULL)
		return

	# 一般吃球：整座島閃一下綠光 + 脈動
	var tw := create_tween()
	tw.tween_property(body, "modulate", Color(1.5, 1.9, 1.4, 1), 0.08)
	tw.tween_property(body, "modulate", Color(1, 1, 1, 1), 0.25)
	var pop := create_tween()
	pop.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)


func play_die():
	is_dead = true
	leaves.emitting = false
	spawn_particles.restart()
	spawn_particles.emitting = true

	# 反重力失效：整座島終於被正常重力抓住，往下墜、旋轉縮小消失
	var tw := create_tween()
	tw.parallel().tween_property(plant, "position:y", plant.position.y + 34.0, 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(plant, "rotation", plant.rotation + PI * 2.0, 0.5)
	(
		tw
		. parallel()
		. tween_property(self, "scale", Vector2.ZERO, 0.45)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	if tw:
		await tw.finished
	else:
		await get_tree().process_frame
