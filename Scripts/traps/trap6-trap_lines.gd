extends Area2D

@export var line_dir = PI / 180 * 15
var line_alive = 1
var velocity = Vector2(-sin(line_dir), cos(line_dir)) * 2.5
var line_pos = Vector2(0, 0) - velocity * 500

@onready var visual_line = $ColorRect/Sprite2D
@onready var collision_shape = $CollisionShape2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = true
	visual_line.visible = true
	visual_line.position = Vector2(500, 500) + line_pos
	collision_shape.position = line_pos
	collision_shape.rotation = line_dir
	visual_line.rotation = line_dir
	body_entered.connect(_on_body_entered)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_body_entered(_body: Node2D) -> void:
	print("player touched trap lines")
	Global.player_hit.emit(randi_range(0, 10))
	#line_alive = false
	#visible = false


func _physics_process(_delta):
	visual_line.position += velocity
	collision_shape.position += velocity
