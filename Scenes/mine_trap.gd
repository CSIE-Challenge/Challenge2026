extends Node2D

@export var arming_time: float = 3.0  # How long it takes to turn completely red

var is_armed := false
var player_just_landed := false

# Grabs a reference to the Sprite2D child node
@onready var sprite: Sprite2D = $Sprite2D
@onready var sprite2: Sprite2D = $Sprite2D2
@onready var explosion_area: Area2D = $ExplosionArea


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite.modulate = Color.WHITE
	explosion_area.body_entered.connect(on_body_entered)
	var player = get_tree().root.find_child("Player", true, false)
	if player:
		player.player_landed.connect(on_player_landed)
	else:
		print("Can't find player")
	start_arming_sequence()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func start_arming_sequence() -> void:
	var tween = create_tween()

	# Transition the sprite's color to Red over our arming_time duration
	tween.tween_property(sprite, "modulate", Color.RED, arming_time)
	tween.tween_callback(on_arming_complete)


func on_arming_complete() -> void:
	is_armed = true

	# Check if the player is already standing inside the hitbox when arming finishes
	for body in explosion_area.get_overlapping_bodies():
		if body.name == "Player":
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
	if body.name == "Player":
		if player_just_landed:
			explode()
			return
		else:
			disarm()
			return


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
	GlobalSignal.player_hit.emit.call_deferred(99999)  #Replace this with the actual damage
	queue_free()


func disarm() -> void:
	print("Player disarmed the mine trap!")
	queue_free()
