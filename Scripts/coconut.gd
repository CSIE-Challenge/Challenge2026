extends Node2D
const SLIDING_RATE: float = 0.15
var swaying_speed: float = 3
var swaying_amplitude: float = 20
var assigned_position: Vector2
var assigned_scale: float
var time: float
@onready var fruitstalk: Marker2D = $FruitStalk
@onready var brightness: Sprite2D = $FruitStalk/Brightness


func _ready() -> void:
	brightness.modulate.a = 1
	time = randf_range(0, PI)


func _process(delta: float) -> void:
	swaying(delta)
	position += (assigned_position - position) * SLIDING_RATE
	scale += (Vector2(assigned_scale, assigned_scale) - scale) * SLIDING_RATE
	brightness.modulate.a *= 1 - SLIDING_RATE


func swaying(delta: float) -> void:
	time += delta * randf_range(0.8, 1.2)
	fruitstalk.rotation_degrees += (
		(swaying_amplitude * sin(swaying_speed * time) - fruitstalk.rotation_degrees) * SLIDING_RATE
	)


func relocate(new_position: Vector2) -> void:
	assigned_position = new_position


func resize(new_scale: float) -> void:
	assigned_scale = new_scale
