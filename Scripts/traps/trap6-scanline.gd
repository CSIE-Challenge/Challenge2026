class_name Trap6Scanline
extends Area2D

const LINE_SHIFT := 500  # 圖片中心和 Area2D 的中心的距離是 (500, 500)

@export var oscillate_frequency: float = 0.5
@export var oscillate_amplitude: float = 20

var cooldown_times = TrapData.new().data["trap6-scanline"]["cooldown_times"]
var damage = TrapData.new().data["trap6-scanline"]["damage"]
var energy_costs = TrapData.new().data["trap6-scanline"]["energy_costs"]

var line_dir := Vector2(0, 0)
var line_alive := 1
var velocity := Vector2(0, 0)
var speed := 5.0
var line_pos := Vector2(0, 0)
var time := 0.0

@onready var visual_line = $Hulas


static func initialize(dir0: Vector2, speed0: float) -> Trap6Scanline:
	var trap := preload("res://Scenes/traps/trap6-scanline.tscn").instantiate()
	trap.spawn(dir0, speed0)
	Global.stage.add_child(trap)
	return trap


func spawn(dir0: Vector2, speed0: float):
	line_dir = _clamp_to_four_directions(dir0).normalized()
	print(line_dir)
	speed = speed0
	velocity = line_dir * speed
	position = -line_dir * LINE_SHIFT
	visible = true


func _clamp_to_four_directions(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		return Vector2(dir.x, 0)
	return Vector2(0, dir.y)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = true
	visual_line.visible = true
	body_entered.connect(_on_body_entered)
	visual_line.modulate = Color.WHITE * randf_range(0.9, 1)
	visual_line.modulate.a = 1
	if abs(line_dir.x) > 0.1:
		rotation = PI / 2
		var hulas = visual_line.get_children()
		for hula in hulas:
			hula.rotation = -PI / 2


func _physics_process(delta: float) -> void:
	position += velocity * delta
	time += delta
	visual_line.position.x = sin(time * TAU * oscillate_frequency) * oscillate_amplitude
	visual_line.scale.x = sign(visual_line.position.x)
	if abs(line_dir.x) > 0.1:
		if visual_line.position.x > 0.1:
			visual_line.rotation = 0
		else:
			visual_line.rotation = PI


func _on_body_entered(_body: Node2D) -> void:
	print("player touched scan lines")
	Global.player_hit.emit(damage)
