class_name Trap6Scanline
extends Area2D

const LINE_SHIFT := 300  # 生成時偏移位置

@export var oscillate_frequency: float = 0.5
@export var oscillate_amplitude: float = 20

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap6-scanline"]["cooldown_times"]
var damage = trap_data["trap6-scanline"]["damage"]
var energy_costs = trap_data["trap6-scanline"]["energy_costs"]

var line_dir := Vector2(0, 0)
var line_alive := 1
var velocity := Vector2(0, 0)
var speed := 5.0
var line_pos := Vector2(0, 0)
var time := 0.0
var is_demo := false
var hula_rotate := false
var start_moving := false

@onready var visual_line = $Hulas


static func initialize(dir0: Vector2, speed0: float) -> Trap6Scanline:
	var trap := preload("res://Scenes/traps/trap6-scanline.tscn").instantiate()
	trap.spawn(dir0, speed0)
	Global.stage.add_child(trap)
	return trap


func spawn(dir0: Vector2, speed0: float):
	line_dir = _clamp_to_four_directions(dir0).normalized()
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
	$Hulas.z_index = Util.LAYERS["Trap6Scanline/Hulas"]
	if is_demo:
		return
	visible = true
	visual_line.visible = true
	body_entered.connect(_on_body_entered)
	visual_line.modulate = Color.WHITE * randf_range(0.9, 1)
	visual_line.modulate.a = 1
	if abs(line_dir.x) > 0.1:
		rotation = PI / 2
		var hulas = visual_line.get_children()
		hula_rotate = true
		for hula in hulas:
			hula.rotation = -PI / 2
	scale = Vector2(0, 1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.3)
	await tween.finished
	start_moving = true


func _physics_process(delta: float) -> void:
	if start_moving:
		position += velocity * delta
		time += delta
		visual_line.position.x = sin(time * TAU * oscillate_frequency) * oscillate_amplitude
		visual_line.scale.x = sign(visual_line.position.x)
		if abs(line_dir.x) > 0.1:
			if visual_line.position.x > 0.1:
				visual_line.rotation = 0
			else:
				visual_line.rotation = PI

		if abs(position.x) > 1000 or abs(position.y) > 1000:
			queue_free()


func _on_body_entered(_body: Node2D) -> void:
	Global.player_hit.emit(damage)


#-----------------------------------------
func serialize_state() -> Dictionary:
	return {
		"type": "trap6-scanline",
		"scale_x": scale.x,
		"position": global_position,
		"rotation": rotation,
		"visual_line_modulate": visual_line.modulate,
		"visual_line_position": visual_line.position,
		"visual_line_scale": visual_line.scale,
		"visual_line_rotation": visual_line.rotation,
		"hula_rotate": hula_rotate
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	scale.x = data.get("scale_x", 1.0)
	rotation = data.get("rotation", 0.0)
	visual_line.modulate = data.get("visual_line_modulate", Color.WHITE)
	visual_line.position = data.get("visual_line_position", Vector2.ZERO)
	visual_line.scale = data.get("visual_line_scale", Vector2.ONE)
	visual_line.rotation = data.get("visual_line_rotation", 0.0)
	if !hula_rotate and data.get("hula_rotate", false):
		hula_rotate = true
		var hulas = visual_line.get_children()
		for hula in hulas:
			hula.rotation = -PI / 2
