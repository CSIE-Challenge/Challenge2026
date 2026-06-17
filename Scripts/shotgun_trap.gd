extends Node2D

const DAMAGE: float = 5.0
const AIMING_TIME: float = 1.2
const AIMING_LINE_COLOR: Color = Color(
	0.937,
	0.373,
	0.285,
)

var bullet_speed: float = 700.0
var directions: Array[Vector2] = []
var aiming: bool = false
var firing: bool = false
@onready var timer: Timer = $Timer
@onready var lines: Array = [$AimingLines/Line1, $AimingLines/Line2, $AimingLines/Line3]
@onready var bullets_container: Node2D = $Bullets
@onready var bullets: Array[Area2D] = [$Bullets/Bullet1, $Bullets/Bullet2, $Bullets/Bullet3]


func _ready() -> void:
	visible = false
	bullets_container.visible = false
	set_physics_process(false)

	# testing
	var pos = Vector2(250, 250)
	var dir1 = Vector2(1, 1)
	var dir2 = Vector2(1, -3)
	var dir3 = Vector2(1, 0)
	activate(pos, dir1, dir2, dir3)


func activate(pos: Vector2, dir1: Vector2, dir2: Vector2, dir3: Vector2) -> void:
	global_position = pos
	directions = [dir1.normalized(), dir2.normalized(), dir3.normalized()]
	$AimingLines.visible = true
	# initialize aiming lines and bullets
	for i in range(3):
		var line = lines[i]
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(directions[i] * 2000.0)
		line.default_color = AIMING_LINE_COLOR
		line.width = 8.0

		var bullet = bullets[i]
		bullet.position = Vector2(directions[i] * 20.0)  # safe distance to not spawn bullets in the wall
		bullet.rotation = directions[i].angle()
		bullet.visible = true
		if not bullet.body_entered.is_connected(_on_bullet_body_entered):
			bullet.body_entered.connect(_on_bullet_body_entered.bind(bullet))
		bullet.get_node("CollisionShape2D").set_deferred("disabled", false)

	aiming = true
	visible = true
	timer.start(AIMING_TIME)
	if not timer.timeout.is_connected(_on_aiming_timeout):
		timer.timeout.connect(_on_aiming_timeout)


func deactivate():
	visible = false
	firing = false
	aiming = false
	set_physics_process(false)


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
	$AimingLines.visible = false
	firing = true
	bullets_container.visible = true
	set_physics_process(true)


func _on_bullet_body_entered(body: Node2D, bullet_node: Area2D) -> void:
	if body.name == "Player":
		GlobalSignal.player_hit.emit(DAMAGE)
	bullet_node.visible = false
	# disable collision for this bullet
	bullet_node.get_node("CollisionShape2D").set_deferred("disabled", true)
