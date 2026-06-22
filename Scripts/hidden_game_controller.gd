extends Control

var attack_ball_scene = preload("res://Scenes/attack_ball.tscn")

@onready var walls: Node2D = $Panel/Stage/Walls
@onready var timer: Timer = $Timer

# Boss related
@onready var stage = $Panel/Stage  # 用來做畫面震動
@onready var boss = $Panel/Stage/boss


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	walls.tween_box(Vector2(400, 400), Vector2(0, 20), 1.0)
	boss.boss_appear_animation()
	await get_tree().create_timer(1.0).timeout
	boss.rand_attack()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _random_generate_attack_ball():
	var ball = attack_ball_scene.instantiate()
	$Panel/Stage.add_child(ball)
	var half_size = walls.current_half_size
	var safe_limit_x = maxf(half_size.x - 25.0, 10.0)
	var safe_limit_y = maxf(half_size.y - 25.0, 10.0)
	ball.position = (
		walls.position
		+ Vector2(
			randf_range(-safe_limit_x, safe_limit_x), randf_range(-safe_limit_y, safe_limit_y)
		)
	)


func _on_timer_timeout() -> void:
	_random_generate_attack_ball()


func shake_screen(duration: float, intensity: float):
	var shake_tween = create_tween()
	var orig_stage_pos = stage.position

	var steps = int(duration / 0.04)
	for i in range(steps):
		var random_offset = Vector2(
			randf_range(-intensity, intensity), randf_range(-intensity, intensity)
		)
		intensity *= 0.85
		shake_tween.tween_property(stage, "position", orig_stage_pos + random_offset, 0.04)

	shake_tween.tween_property(stage, "position", orig_stage_pos, 0.04)
