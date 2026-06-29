class_name Trap6Scanline
extends Area2D

const LINE_SHIFT := 500  # 圖片中心和 Area2D 的中心的距離是 (500, 500)

var cooldown_times = TrapData.new().data["trap6-scanline"]["cooldown_times"]
var damage = TrapData.new().data["trap6-scanline"]["damage"]
var energy_costs = TrapData.new().data["trap6-scanline"]["energy_costs"]
var speed_lower_bound = TrapData.new().data["trap6-scanline"]["speed_lower_bound"]
var speed_upper_bound = TrapData.new().data["trap6-scanline"]["speed_upper_bound"]

var line_dir: Vector2
var velocity: Vector2
var speed: int
var line_pos: Vector2

@onready var visual_line = $ColorRect/Sprite2D
@onready var collision_shape = $CollisionShape2D


static func initialize(dir0: Vector2, speed0: float) -> Trap6Scanline:
	var trap := preload("res://Scenes/traps/trap6-scanline.tscn").instantiate()
	trap.line_dir = dir0.normalized()
	trap.speed = clamp(speed0, trap.speed_lower_bound, trap.speed_upper_bound)
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
