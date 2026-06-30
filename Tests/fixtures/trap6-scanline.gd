# Minimal test fixture for scanline trap serialization tests.
extends Area2D

var line_dir := Vector2(0, 1)


func _init():
	var hulas := Node2D.new()
	hulas.name = "Hulas"
	hulas.position = Vector2.ZERO
	add_child(hulas)
