class_name Trap1Mine
extends Node2D

@export var arming_time: float = 3.0  # How long it takes to turn completely red

var is_armed := false
var player_just_landed := false
var _data: Dictionary = Global.trap_data["trap1-mine"]

@onready var mine_body: Sprite2D = $MineBody
@onready var explosion_area: Area2D = $ExplosionArea


static func initialize(pos: Vector2) -> Trap1Mine:
	var trap := preload("res://Scenes/traps/trap1-mine.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.position = pos
	trap.explosion_area.body_entered.connect(trap.on_body_entered)
	trap.start_arming_sequence()
	return trap


func start_arming_sequence() -> void:
	var tween = create_tween()

	# Transition the mine body's color to Red over our arming_time duration
	tween.tween_property(mine_body, "modulate", Color.RED, arming_time)
	tween.tween_callback(on_arming_complete)


func on_arming_complete() -> void:
	is_armed = true

	# Check if the player is already standing inside the hitbox when arming finishes
	for body in explosion_area.get_overlapping_bodies():
		if body != Global.game_manager.player:
			if player_just_landed:
				explode()
				return
			else:
				disarm()
				return


func on_body_entered(body: Node2D) -> void:
	if not is_armed:
		return

	# Catches players walking in AFTER the mine is already armed, or landing in it
	if body == Global.game_manager.player:
		if player_just_landed:
			explode()
			return
		else:
			disarm()
			return


# TODO: How to trigger this function? Or player_just_landed will always be false.
func on_player_landed(body: Node2D) -> void:
	if not is_armed:
		return
	player_just_landed = true
	await get_tree().physics_frame
	await get_tree().physics_frame
	if explosion_area.overlaps_body(body):
		explode()
	player_just_landed = false


func explode() -> void:
	print("BOOM! Player landed on the mine trap!")
	Global.player_hit.emit.call_deferred(10)  #Replace this with the actual damage
	queue_free()


func disarm() -> void:
	print("Player disarmed the mine trap!")
	queue_free()
