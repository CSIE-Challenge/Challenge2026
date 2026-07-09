extends Node2D
var time: float = 0
@onready var marker: Marker2D = $Marker
@onready var coconut_water: Sprite2D = $Marker/CoconutWater
@onready var energy_label: Label = $EnergyLabel
@onready var limitation_label: Label = $LimitationLabel


func _ready() -> void:
	scale = Vector2(0.8, 0.8)
	global_position = Vector2(936, 120)
	energy_label.text = "0"
	limitation_label.text = "/50"


func _process(delta: float) -> void:
	time += delta
	marker.rotation_degrees = 8 * sin(time * 6)


func _update_energy(energy_amount: int) -> void:
	energy_label.text = str(energy_amount)
	limitation_label.position = Vector2(energy_label.text.length() * 32 + 52, 0)


func _update_max_energy(max_energy: int) -> void:
	limitation_label.text = "/%d" % max_energy
