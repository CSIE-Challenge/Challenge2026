# Minimal test fixture for ice floor trap serialization tests.
extends Node2D


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap5-icefloor",
		"position": global_position,
	}
