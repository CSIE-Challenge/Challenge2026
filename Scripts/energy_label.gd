extends Node2D
var time: float = 0
@onready var marker: Marker2D = $Marker
@onready var coconut_water: Sprite2D = $Marker/CoconutWater
@onready var label: Label = $Label


func _ready() -> void:
	scale = Vector2(0.8, 0.8)
	global_position = Vector2(948, 120)
	label.text = "0"


func _process(delta: float) -> void:
	time += delta
	marker.rotation_degrees = 8 * sin(time * 6)


func _update_energy(energy_amount: int) -> void:
	label.text = str(energy_amount)
