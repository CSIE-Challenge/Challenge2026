extends Node2D
const SLIDING_RATE: float = 0.15
var swaying_speed: float = 3
var swaying_amplitude: float = 6
var direction: float = 0
var assigned_position: Vector2
var assigned_scale: float
var time: float
@onready var leafstalk: Marker2D = $Leafstalk


func _ready() -> void:
	z_index = Util.LAYERS["CoconutBar/Leaf"]
	time = randf_range(0, PI)


func _process(delta: float) -> void:
	swaying(delta)
	position += (assigned_position - position) * SLIDING_RATE
	scale += (Vector2(assigned_scale, assigned_scale) - scale) * SLIDING_RATE


func swaying(delta: float) -> void:
	time += delta * randf_range(0.8, 1.2)
	leafstalk.rotation_degrees += (
		(direction + swaying_amplitude * sin(swaying_speed * time) - leafstalk.rotation_degrees)
		* SLIDING_RATE
	)


func set_direction(dir: float) -> void:
	while dir > 180:
		dir -= 360
	while dir < -180:
		dir += 360
	direction = dir
	if direction < 0:
		leafstalk.scale = Vector2(-1, 1)
	else:
		leafstalk.scale = Vector2(1, 1)


func set_type(type: int) -> void:
	$Leafstalk/TopLeaf.visible = (type == 0)
	$Leafstalk/LongLeaf.visible = (type == 1)
	$Leafstalk/ShortLeaf.visible = (type == 2)


func relocate(new_position: Vector2) -> void:
	assigned_position = new_position


func resize(new_scale: float) -> void:
	assigned_scale = new_scale
