@tool
extends Node2D
@export var ring_radius: float
@export var player_radius: float


func _ready():
	set_process(true)


func _process(_delta):
	queue_redraw()


func _draw():
	if not Engine.is_editor_hint():
		return
	draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 64, Color.RED, 0.5)
	draw_arc(Vector2.ZERO, player_radius, 0, TAU, 64, Color.BLUE, 0.05)
