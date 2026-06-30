extends Node2D
const SLIDING_RATE: float = 10
var assigned_position: Vector2
var assigned_scale: float


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	rearrange(delta)


func rearrange(delta: float) -> void:
	position += (assigned_position - position) * SLIDING_RATE * delta
	scale += (Vector2(assigned_scale, assigned_scale) - scale) * SLIDING_RATE * delta


func relocate(new_position: Vector2) -> void:
	assigned_position = new_position


func resize(new_scale: float) -> void:
	assigned_scale = new_scale
