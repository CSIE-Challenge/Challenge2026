extends Node2D
const SLIDING_RATE: float = 0.15
var swaying_speed: float = 3
var swaying_amplitude: float = 20
var assigned_position: Vector2
var assigned_scale: float = 0.36
var assigned_a: float = 1
var time: float
var on_tree: bool = true
var velocity: Vector2 = Vector2(0, 0)
var acceleration: Vector2 = Vector2(0, 0)
@onready var fruitstalk: Marker2D = $FruitStalk
@onready var brightness: Sprite2D = $FruitStalk/Brightness


func _ready() -> void:
	z_index = Util.LAYERS["CoconutBar/Coconut"]
	brightness.modulate.a = 1
	time = randf_range(0, PI)


func _process(delta: float) -> void:
	scale += (Vector2(assigned_scale, assigned_scale) - scale) * SLIDING_RATE
	brightness.modulate.a *= 1 - SLIDING_RATE
	modulate.a += (assigned_a - modulate.a) * SLIDING_RATE
	if on_tree:
		swaying(delta)
		position += (assigned_position - position) * SLIDING_RATE
	else:
		position += velocity * delta
		velocity += acceleration * delta
		if velocity.x > 0 and position.y > -76:
			velocity = Vector2(randi_range(-180, -120), randi_range(-300, -150))
			get_parent().congratulation._hit()


func swaying(delta: float) -> void:
	time += delta * randf_range(0.8, 1.2)
	fruitstalk.rotation_degrees += (
		(swaying_amplitude * sin(swaying_speed * time) - fruitstalk.rotation_degrees) * SLIDING_RATE
	)


func relocate(new_position: Vector2) -> void:
	assigned_position = new_position


func resize(new_scale: float) -> void:
	assigned_scale = new_scale


func fall() -> void:
	on_tree = false
	velocity.x = randi_range(50, 70)
	acceleration.y = 500
	await get_tree().create_timer(3.0).timeout
	queue_free()
