class_name Trap6Scanline
extends Area2D

const LINE_SHIFT := 500
@export var damage: int = 5

var line_dir := Vector2(0, 0)
var line_alive := 1
var velocity := Vector2(0, 0)
var speed := 5
var line_pos := Vector2(0, 0)

@onready var visual_line = $ColorRect/Sprite2D
@onready var collision_shape = $CollisionShape2D


static func initialize(dir0: Vector2, speed0: float) -> Trap6Scanline:
	var trap := preload("res://Scenes/traps/trap6-scanline.tscn").instantiate()
	trap.line_dir = dir0.normalized()
	trap.speed = speed0
	trap.velocity = dir0.rotated(-PI / 2) * trap.speed
	trap.line_pos = Vector2(0, 0) - dir0.rotated(-PI / 2) * LINE_SHIFT
	trap.visible = true
	Global.stage.add_child(trap)
	return trap


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = true
	visual_line.visible = true
	visual_line.position = Vector2(LINE_SHIFT, LINE_SHIFT) + line_pos
	collision_shape.position = line_pos
	visual_line.rotation = line_dir.angle()
	collision_shape.rotation = line_dir.angle()
	body_entered.connect(_on_body_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	visual_line.position += velocity * delta
	collision_shape.position += velocity * delta


func _on_body_entered(_body: Node2D) -> void:
	print("player touched scan lines")
	Global.player_hit.emit(damage)
