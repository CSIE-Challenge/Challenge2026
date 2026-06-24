class_name Trap10Shotgun
extends Node2D

@export var damage: float = 5.0
@export var bullet_speed: float = 700.0
@export var aiing_time: float = 1.5
@export var aiming_line_color: Color = Color(
	0.937,
	0.373,
	0.285,
)

var directions: Array[Vector2] = []
var hit_spawn_wall: Array[bool]
var aiming: bool = false
var firing: bool = false
var _data: Dictionary = Global.trap_data["trap10-shotgun"]
@onready var timer: Timer = $Timer
@onready var lines_container: Node2D = $AimingLines
@onready var lines: Array = [$AimingLines/Line1, $AimingLines/Line2, $AimingLines/Line3]
@onready var bullets_container: Node2D = $Bullets
@onready var bullets: Array[Area2D] = [$Bullets/Bullet1, $Bullets/Bullet2, $Bullets/Bullet3]


static func initialize(pos: Vector2, dir1: Vector2, dir2: Vector2, dir3: Vector2) -> Trap10Shotgun:
	var trap := preload("res://Scenes/traps/trap10-shotgun.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(pos, dir1, dir2, dir3)
	return trap


func _ready() -> void:
	visible = false
	bullets_container.visible = false
	set_physics_process(false)
	hit_spawn_wall.resize(3)
	hit_spawn_wall.fill(false)

	# testing
	var pos = Vector2(250, 250)
	var dir1 = Vector2(1, 1)
	var dir2 = Vector2(1, -3)
	var dir3 = Vector2(1, 0)
	activate(pos, dir1, dir2, dir3)


func activate(pos: Vector2, dir1: Vector2, dir2: Vector2, dir3: Vector2) -> void:
	position = pos
	directions = [dir1.normalized(), dir2.normalized(), dir3.normalized()]
	lines_container.visible = true
	# initialize aiming lines and bullets
	for i in range(3):
		var intersect = _calculate_aiming_line_end_point(position, directions[i])
		var local_intersect = to_local(intersect)
		var line = lines[i]
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(local_intersect)
		line.default_color = aiming_line_color
		line.width = 8.0

		var bullet = bullets[i]
		hit_spawn_wall[i] = false
		bullet.position = Vector2.ZERO
		bullet.rotation = directions[i].angle()
		bullet.visible = true
		if not bullet.body_entered.is_connected(_on_bullet_body_entered):
			bullet.body_entered.connect(_on_bullet_body_entered.bind(bullet))
		bullet.get_node("CollisionShape2D").set_deferred("disabled", false)

	aiming = true
	visible = true
	timer.start(aiing_time)
	if not timer.timeout.is_connected(_on_aiming_timeout):
		timer.timeout.connect(_on_aiming_timeout)


func deactivate():
	queue_free()


func _physics_process(delta: float) -> void:
	if firing:
		var bullets_still_moving = false
		for i in range(3):
			var bullet = bullets[i]
			if bullet.visible:
				bullet.position += directions[i] * bullet_speed * delta
				bullets_still_moving = true

				if bullet.position.length() > 5000.0:
					bullet.visible = false
					bullet.get_node("CollisionShape2D").set_deferred("disabled", true)

		if not bullets_still_moving:
			deactivate()


func _on_aiming_timeout() -> void:
	aiming = false
	lines_container.visible = false
	firing = true
	bullets_container.visible = true
	set_physics_process(true)


func _on_bullet_body_entered(body: Node2D, bullet_node: Area2D) -> void:
	if body == Global.game_manager.player:
		Global.player_hit.emit(damage)
		bullet_node.visible = false
		# disable collision for this bullet
		bullet_node.get_node("CollisionShape2D").set_deferred("disabled", true)
	else:
		var idx = bullets.find(bullet_node)
		if not hit_spawn_wall[idx]:
			hit_spawn_wall[idx] = true
		else:
			bullet_node.visible = false
			bullet_node.get_node("CollisionShape2D").set_deferred("disabled", true)


func _calculate_aiming_line_end_point(origin: Vector2, dir: Vector2) -> Vector2:
	var border = Rect2(326, 74, 500, 500)
	if dir.x == 0:
		dir.x = 0.00001
	if dir.y == 0:
		dir.y = 0.00001

	# aabb ray collision
	var t_min_x = (border.position.x - origin.x) / dir.x
	var t_max_x = (border.end.x - origin.x) / dir.x
	var t_min_y = (border.position.y - origin.y) / dir.y
	var t_max_y = (border.end.y - origin.y) / dir.y

	var t_exit_x = max(t_min_x, t_max_x)
	var t_exit_y = max(t_min_y, t_max_y)
	var t_exit = min(t_exit_x, t_exit_y)

	return origin + dir * t_exit
