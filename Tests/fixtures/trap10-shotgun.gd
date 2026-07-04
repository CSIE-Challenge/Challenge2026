# Minimal test fixture for shotgun trap serialization tests.
extends Node2D

var directions: Array = []  # Array of Vector2
var aiming: bool = false
var firing: bool = false
var aiming_time: float = 1.5


func _init():
	var t := Timer.new()
	t.name = "Timer"
	t.wait_time = 1.5
	add_child(t)


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap10-shotgun",
		"position": global_position,
	}
