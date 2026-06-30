# Minimal test fixture for spreading ripples trap serialization tests.
extends Node2D

var is_expanding: bool = false
var max_radius: float = 1000.0
var current_expand_rate: float = 10.0


func _init():
	var shape := CircleShape2D.new()
	shape.radius = 0.0
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = shape
	add_child(col)
