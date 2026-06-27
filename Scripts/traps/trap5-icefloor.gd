class_name Trap5IceFloor
extends Area2D

const NORMAL_ACCELERATION: float = 100.0
const ICE_ACCELERATION_BASE: float = 5.0

static var _ice_overlap_count: Dictionary = {}

var cooldown_times = TrapData.new().data["trap5-icefloor"]["cooldown_times"]
var damage = TrapData.new().data["trap5-icefloor"]["damage"]
var energy_costs = TrapData.new().data["trap5-icefloor"]["energy_costs"]
var lifetime = TrapData.new().data["trap5-icefloor"]["lifetime"]

@onready var juice_sprite: Sprite2D = $SpilledJuice
@onready var glass_sprite: Sprite2D = $JuiceGlass


static func initialize(pos: Vector2) -> Trap5IceFloor:
	var trap := preload("res://Scenes/traps/trap5-icefloor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.start_animation()
	return trap


func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	_destroy_trap()


func _destroy_trap() -> void:
	if not is_inside_tree():
		return

	for body in get_overlapping_bodies():
		if body == Global.game_manager.player:
			_remove_ice_effect(body)
			print("icefloor disappear")

	queue_free()


func start_animation() -> void:
	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(glass_sprite, "rotation_degrees", -125, 1.2)
	tween.tween_property(glass_sprite, "self_modulate:a", 0, 0.4).set_delay(0.8).set_trans(
		Tween.TRANS_LINEAR
	)
	tween.tween_property(juice_sprite.material, "shader_parameter/reveal_progress", 1.0, 1.6)


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player entered icefloor")
		_add_ice_effect(body)


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player:
		print("player left icefloor")
		_remove_ice_effect(body)


func _add_ice_effect(body: Node2D) -> void:
	var n: int = _ice_overlap_count.get(body, 0) + 1
	_ice_overlap_count[body] = n
	_apply_acceleration(body, n)


func _remove_ice_effect(body: Node2D) -> void:
	var n: int = max(_ice_overlap_count.get(body, 0) - 1, 0)
	if n == 0:
		_ice_overlap_count.erase(body)
	else:
		_ice_overlap_count[body] = n
	_apply_acceleration(body, n)


func _apply_acceleration(body: Node2D, n: int) -> void:
	body.acceleration = ICE_ACCELERATION_BASE / n if n > 0 else NORMAL_ACCELERATION
