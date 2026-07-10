# Minimal test fixture for tracing bullet trap serialization tests.
extends Node2D

var tracing := false
var target: Node2D = null


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap3-tracing_bullet",
		"position": global_position,
	}
