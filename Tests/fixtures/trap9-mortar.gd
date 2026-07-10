# Minimal test fixture for mortar trap serialization tests.
extends Node2D

var flying: bool = false
var exploding: bool = false


func _init():
	var sh := Node2D.new()
	sh.name = "ShellShadow"
	sh.position = Vector2.ZERO
	add_child(sh)
	var shell := Sprite2D.new()
	shell.name = "Shell"
	shell.position = Vector2.ZERO
	sh.add_child(shell)
	var exp := Sprite2D.new()
	exp.name = "Explosion"
	exp.visible = false
	add_child(exp)


func serialize_state() -> Dictionary:
	return {
		"_v2": true,
		"type": "trap9-mortar",
		"position": global_position,
	}
