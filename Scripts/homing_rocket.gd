extends Area2D

const ROCKET_EXPLOSION_SCENE = preload("res://Scenes/rocket_explosion.tscn")

# 🚀 追蹤物理參數
@export var acceleration: float = 440.0
@export var base_turn_speed: float = PI * 1.5
@export var turn_decay: float = 0.01
@export var min_turn_speed: float = PI * 0.08

var speed: float
var init_speed: float
var explosion_radius: float
var explosion_duration: float
var player: CharacterBody2D
var damage_field: Area2D

# 記錄碰撞牆壁的次數
var wall_hit_count: int = 0

# 火箭是否已經穿牆進到場地內
var is_inside_arena: bool = false


func init(
	pos: Vector2,
	start_speed: float,
	radius: float,
	duration: float,
	player_node: CharacterBody2D,
	damage_field_node: Area2D
):
	position = pos  # 🌟 直接在 init 中設定 position
	init_speed = start_speed
	speed = start_speed  # 確保速度初始化
	explosion_radius = radius
	explosion_duration = duration
	player = player_node
	damage_field = damage_field_node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	collision_mask = 3  # 確保動態修正 Mask
	body_entered.connect(_on_body_entered)

	if is_instance_valid(player):
		rotation = (player.position - position).angle()  # 🌟 使用局部座標計算角度


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return

	# 實時檢測火箭是否已經穿牆進入了場內
	var walls = get_node_or_null("../Walls")
	if walls and not is_inside_arena:
		var local_pos = walls.to_local(global_position)
		var half = walls.current_half_size
		# 當火箭完全進入牆壁內側（給予 10 像素的容差），標記為已入內
		if abs(local_pos.x) < half.x - 10.0 and abs(local_pos.y) < half.y - 10.0:
			is_inside_arena = true

	speed += acceleration * delta

	# 角速度衰減公式：速度越快，轉彎幅度越小
	var current_turn_speed = base_turn_speed / (1.0 + (speed - init_speed) * turn_decay)
	current_turn_speed = max(current_turn_speed, min_turn_speed)

	# 🌟 使用局部座標計算追蹤角度
	var target_angle = (player.position - position).angle()
	rotation = rotate_toward(rotation, target_angle, current_turn_speed * delta)

	var velocity = Vector2.from_angle(rotation) * speed
	position += velocity * delta


func _on_body_entered(body: Node2D) -> void:
	if body == player:
		# 碰到玩家：直接引爆
		explode()
	elif body.name == "Walls" or body is StaticBody2D or body is AnimatableBody2D:
		# 如果火箭尚未進到場內，直接忽略這次與牆壁的碰撞！
		if not is_inside_arena:
			return

		wall_hit_count += 1
		if wall_hit_count >= 2:
			explode()
		else:
			bounce_off_wall()


func bounce_off_wall() -> void:
	var walls = get_node_or_null("../Walls")
	if not walls:
		rotation += PI
		return

	var local_pos = walls.to_local(global_position)
	var half = walls.current_half_size

	var dist_left = abs(local_pos.x - (-half.x))
	var dist_right = abs(local_pos.x - half.x)
	var dist_top = abs(local_pos.y - (-half.y))
	var dist_bottom = abs(local_pos.y - half.y)

	var min_dist = min(min(dist_left, dist_right), min(dist_top, dist_bottom))

	if min_dist == dist_left or min_dist == dist_right:
		rotation = PI - rotation
	else:
		rotation = -rotation

	speed = init_speed

	var tween = create_tween()
	scale = Vector2(0.7, 0.7)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)


func explode() -> void:
	set_physics_process(false)

	if is_instance_valid(damage_field):
		var explosion = ROCKET_EXPLOSION_SCENE.instantiate()
		# 🌟 先 init 帶入局部座標，後 add_child！這能避免座標偏移
		explosion.init(position, explosion_radius, explosion_duration, player)
		damage_field.add_child(explosion)

	queue_free()
