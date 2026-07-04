# Minimal test fixture for electric arc trap serialization tests.
extends Node2D

var activated: bool = false


func _init():
	var sp := Node2D.new()
	sp.name = "StartPoint"
	sp.position = Vector2.ZERO
	add_child(sp)
	var ep := Node2D.new()
	ep.name = "EndPoint"
	ep.position = Vector2(100, 0)
	add_child(ep)
	var cr := Sprite2D.new()
	cr.name = "Crack"
	add_child(cr)


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap8-electric_arc",
		"position": global_position,
	}
