extends Camera2D
@export var screen_center: Vector2
@export var shake_time: float
@export var shake_magnitude: float

var shaking := false

@onready var shake_timer = $ShakeTimer


func _ready() -> void:
	shake_timer.timeout.connect(_on_shake_timer_timeout)


func _physics_process(_delta: float) -> void:
	if shaking:
		offset = screen_center + Vector2.from_angle(randf_range(0, TAU)) * shake_magnitude


func shake_cam() -> void:
	shaking = true
	shake_timer.start(shake_time)


func _on_shake_timer_timeout() -> void:
	shaking = false
	offset = screen_center
