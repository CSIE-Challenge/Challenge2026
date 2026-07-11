class_name Trap5IceFloor
extends Area2D

const NORMAL_ACCELERATION: float = 100.0
const ICE_ACCELERATION_BASE: float = 5.0

static var _ice_overlap_count: Dictionary = {}

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap5-icefloor"]["cooldown_times"]
var damage = trap_data["trap5-icefloor"]["damage"]
var energy_costs = trap_data["trap5-icefloor"]["energy_costs"]
var lifetime = trap_data["trap5-icefloor"]["lifetime"]
var area_scale = trap_data["trap5-icefloor"]["scale"]
var is_demo := false

var _is_destroying: bool = false

@onready var juice_sprite: Sprite2D = $SpilledJuice
@onready var glass_sprite: Sprite2D = $JuiceGlass


static func initialize(pos: Vector2) -> Trap5IceFloor:
	var trap := preload("res://Scenes/traps/trap5-icefloor.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.start_animation()
	return trap


func _ready() -> void:
	$SpilledJuice.z_index = Util.LAYERS["Trap5IceFloor/SpilledJuice"]
	$JuiceGlass.z_index = Util.LAYERS["Trap5IceFloor/JuiceGlass"]
	if is_demo:
		return
	scale = Vector2(area_scale, area_scale)
	await get_tree().create_timer(lifetime).timeout
	_destroy_trap()


func _destroy_trap() -> void:
	if not is_inside_tree() or _is_destroying:
		return
	_is_destroying = true

	for body in get_overlapping_bodies():
		if body == Global.game_manager.player:
			_remove_ice_effect(body)

	var tween = create_tween()
	tween.tween_property(juice_sprite.material, "shader_parameter/master_alpha", 0.0, 0.2)
	await tween.finished

	queue_free()


func start_animation() -> void:
	juice_sprite.material.set_shader_parameter("master_alpha", 1.0)
	juice_sprite.material.set_shader_parameter("reveal_progress", 0.0)

	var tween = create_tween().set_parallel()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(glass_sprite, "rotation_degrees", -125, 1.2)
	tween.tween_property(glass_sprite, "self_modulate:a", 0, 0.4).set_delay(0.8).set_trans(
		Tween.TRANS_LINEAR
	)
	tween.tween_property(juice_sprite.material, "shader_parameter/reveal_progress", 1.0, 1.6)

	Audio.play_sfx(Audio.SFX.TRAP5_JUICE_SPLASH)


func _on_body_entered(body: Node2D) -> void:
	if body == Global.game_manager.player and not _is_destroying:
		_add_ice_effect(body)


func _on_body_exited(body: Node2D) -> void:
	if body == Global.game_manager.player and not _is_destroying:
		_remove_ice_effect(body)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		Global.game_manager.player.juice_count += 1
		Global.game_manager.player.adjust_particle()


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("player"):
		Global.game_manager.player.juice_count -= 1
		Global.game_manager.player.adjust_particle()


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


func serialize_state() -> Dictionary:
	return {
		"type": "trap5-icefloor",
		"position": global_position,
		"scale": scale,
		"glass_rotation": glass_sprite.rotation_degrees,
		"glass_alpha": glass_sprite.self_modulate.a,
		"juice_reveal": juice_sprite.material.get_shader_parameter("reveal_progress"),
		"juice_alpha": juice_sprite.material.get_shader_parameter("master_alpha"),
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	scale = data.get("scale", Vector2.ONE)
	glass_sprite.rotation_degrees = data.get("glass_rotation", 0.0)
	glass_sprite.self_modulate.a = data.get("glass_alpha", 1.0)
	juice_sprite.material.set_shader_parameter("reveal_progress", data.get("juice_reveal", 0.0))
	juice_sprite.material.set_shader_parameter("master_alpha", data.get("juice_alpha", 1.0))
