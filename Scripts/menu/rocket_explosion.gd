#by Gemini
extends CollisionShape2D

@export var active_damage_ratio: float = 0.7  # 傷害持續時間比例

var explosion_radius: float
var duration: float
var player: CharacterBody2D
var explosion_pos: Vector2

@onready var sprite = $Sprite2D
@onready var particles = $CPUParticles2D


func init(
	pos: Vector2, radius: float, exp_duration: float, player_node: CharacterBody2D = null
) -> void:
	explosion_pos = pos
	explosion_radius = radius
	duration = exp_duration
	player = player_node


func _ready() -> void:
	global_position = explosion_pos

	# 1. 複製並套用爆炸半徑至物理 CollisionShape2D
	if shape:
		shape = shape.duplicate()
		shape.radius = explosion_radius

	# 2. 根據編輯器預設比例 (半徑 67.74216 對應 scale 1.0) 來完美縮放視覺大小
	var base_scale = explosion_radius / 67.74216
	sprite.scale = Vector2.ZERO

	# 3. 動態配置 CPUParticles2D 粒子，使粒子與半徑成正比且清晰可見
	particles.amount = 45
	particles.initial_velocity_min = explosion_radius * 1.5
	particles.initial_velocity_max = explosion_radius * 3.5
	particles.scale_amount_min = max(3.0, explosion_radius * 0.1)
	particles.scale_amount_max = max(6.0, explosion_radius * 0.22)
	particles.emitting = true

	# 4. 爆炸膨脹與漸變動畫
	var tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(sprite, "scale", Vector2(base_scale, base_scale), 0.10)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(sprite, "modulate:a", 0.8, 0.10)

	# 5. 🌟 距離檢測主動傷害 (使用局部座標判定，防物理引擎動態加載延遲)
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist <= explosion_radius:
			player.die()

	# 6. 時間到動態關閉物理碰撞
	var seq_tween = create_tween()
	seq_tween.tween_interval(duration * active_damage_ratio)
	seq_tween.tween_callback(func(): set_deferred("disabled", true))

	# 7. 漸變淡出銷毀
	var fade_tween = create_tween().set_parallel(true)
	fade_tween.tween_interval(duration * 0.8)
	(
		fade_tween
		. chain()
		. tween_property(sprite, "scale", Vector2(base_scale * 1.25, base_scale * 1.25), 0.25)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	fade_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 0.0, 0.0, 0.0), 0.25)

	fade_tween.chain().tween_callback(queue_free)
