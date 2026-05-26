extends Area2D

# Grabs a reference to the Sprite2D child node
@onready var sprite: Sprite2D = $Sprite2D
@export var arming_time: float = 3.0 # How long it takes to turn completely red
@export var expire_time: float = 10.0 # How long it takes to turn completely red

var is_armed := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	sprite.modulate = Color.WHITE
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
	tween.tween_callback(func(): is_armed = true)
	tween.tween_property(sprite, "modulate", Color.BLACK, expire_time)
	tween.tween_callback(queue_free)

func on_player_landed(body: Node2D) -> void:
	if not is_armed:
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if overlaps_body(body):
		explode()

func explode() -> void:
	print("BOOM! Player landed on the mine trap!")
	GlobalSignal.player_hit.emit(99999) #Replace this with the actual damage
	queue_free()
	
