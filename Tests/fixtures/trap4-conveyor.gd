# Minimal test fixture for conveyor trap serialization tests.
extends Node2D

var direction: Vector2 = Vector2.ZERO


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap4-conveyor",
		"position": global_position,
	}
