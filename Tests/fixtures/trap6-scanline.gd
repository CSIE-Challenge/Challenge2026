# Minimal test fixture for scanline trap serialization tests.
extends Area2D

var line_dir := Vector2(0, 1)


func _init():
	var hulas := Node2D.new()
	hulas.name = "Hulas"
	hulas.position = Vector2.ZERO
	add_child(hulas)


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap6-scanline",
		"position": global_position,
	}
