extends Node2D
const SLIDING_RATE: float = 15
@export var target_position: Vector2
@onready var bright_sprite: Sprite2D = $BrightSprite


func _ready() -> void:
	z_index = Util.LAYERS["CoconutBar/EatenCoconut"]
	$Particles.z_index = Util.LAYERS["CoconutBar/EatenCoconut/Particles"]
	bright_sprite.modulate.a = 0.5
	scale = Vector2(0.1, 0.1)


func _process(delta: float) -> void:
	global_position += (target_position - global_position) * SLIDING_RATE * delta
	bright_sprite.modulate.a += (1 - bright_sprite.modulate.a) * SLIDING_RATE * delta
	scale += (Vector2(0.03, 0.03) - scale) * SLIDING_RATE * delta


func set_target_position(pos: Vector2) -> void:
	target_position = pos


func delete() -> void:
	$Particles.emitting = false
	await get_tree().create_timer(0.5).timeout
	queue_free()
