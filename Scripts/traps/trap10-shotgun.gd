class_name Trap10Shotgun
extends Node2D

var trap_data = TrapData.new().data
var cooldown_times = trap_data["trap10-shotgun"]["cooldown_times"]
var damage = trap_data["trap10-shotgun"]["damage"]
var energy_costs = trap_data["trap10-shotgun"]["energy_costs"]
var bullet_speed = trap_data["trap10-shotgun"]["bullet_speed"]
var aiming_time = trap_data["trap10-shotgun"]["aiming_time"]
var aiming_line_color = Color(trap_data["trap10-shotgun"]["aiming_line_color"])
# ▲[0.937, 0.373, 0.285] in HEX is #F05F49
var particles_reparented = false
var directions: Array[Vector2] = []
var aiming: bool = false
var firing: bool = false
var bullet_in_wall_counter: Array[int] = [0, 0, 0]
var is_demo := false
@onready var timer: Timer = $Timer
@onready var lines_container: Node2D = $AimingLines
@onready var lines: Array = [$AimingLines/Line1, $AimingLines/Line2, $AimingLines/Line3]
@onready var bullets_container: Node2D = $Bullets
@onready var bullets: Array[Area2D] = [$Bullets/Bullet1, $Bullets/Bullet2, $Bullets/Bullet3]
@onready var baskets_animation = $"Baskets/MoveBasket/AnimationPlayer"
@onready var baskets = $Baskets
@onready var move_basket = $Baskets/MoveBasket
@onready var full_basket = $Baskets/MoveBasket/Basket
@onready var empty_basket = $Baskets/MoveBasket/EmptyBasket


static func initialize(pos: Vector2, dir1: Vector2, dir2: Vector2, dir3: Vector2) -> Trap10Shotgun:
	var trap := preload("res://Scenes/traps/trap10-shotgun.tscn").instantiate()
	Global.stage.add_child(trap)
	trap.activate(pos, dir1, dir2, dir3)
	return trap


func _ready() -> void:
	$AimingLines.z_index = Util.LAYERS["Trap10Shotgun/AimingLines"]
	$Bullets.z_index = Util.LAYERS["Trap10Shotgun/Bullets"]
	$Baskets.z_index = Util.LAYERS["Trap10Shotgun/Baskets"]
	if is_demo:
		return
	visible = false
	bullets_container.visible = false
	set_physics_process(false)


func activate(pos: Vector2, dir1: Vector2, dir2: Vector2, dir3: Vector2) -> void:
	position = pos
	bullets_container.visible = false
	baskets_animation.play("ready")
	var average_angle = (dir1.normalized() + dir2.normalized() + dir3.normalized()).angle()
	baskets.rotation = average_angle
	directions = [dir1.normalized(), dir2.normalized(), dir3.normalized()]
	lines_container.visible = true
	# initialize aiming lines and bullets
	for i in range(3):
		var intersect = _calculate_aiming_line_end_point(global_position, directions[i])
		var local_intersect = to_local(intersect)
		var line = lines[i]
		line.set_point_position(0, Vector2.ZERO)
		line.set_point_position(1, Vector2.ZERO)
		animate_line(line, local_intersect)

		var bullet = bullets[i]
		bullet.position = Vector2.ZERO
		bullet.rotation = directions[i].angle()
		bullet.visible = false

		bullet.body_entered.connect(_on_bullet_body_entered.bind(bullet))
		bullet.collision_shape.set_deferred("disabled", false)
		var wall_detector = bullet.wall_exit_detector as Area2D
	aiming = true
	visible = true
	timer.start(aiming_time)
	if not timer.timeout.is_connected(_on_aiming_timeout):
		timer.timeout.connect(_on_aiming_timeout)


func animate_line(line: Line2D, pos: Vector2) -> void:
	var tween = create_tween()
	(
		tween
		. tween_method(
			func(current_pos: Vector2): line.set_point_position(1, current_pos),
			Vector2.ZERO,
			pos,
			0.5
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func deactivate():
	await get_tree().create_timer(0.1).timeout
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
					bullet.collision_shape.set_deferred("disabled", true)

		if not bullets_still_moving:
			deactivate()


func _on_aiming_timeout() -> void:
	for b in bullets:
		b.visible = true
	aiming = false
	lines_container.visible = false
	firing = true
	bullets_container.visible = true
	baskets_animation.play("fire")
	set_physics_process(true)


func _on_bullet_body_entered(body: Node2D, bullet_node: Area2D) -> void:
	var effect = bullet_node.effect as GPUParticles2D
	if effect and firing:
		effect.reparent(Global.stage)
		if not effect.finished.is_connected(effect.queue_free):
			effect.finished.connect(effect.queue_free)
		effect.emitting = true

	if body == Global.game_manager.player:
		Global.player_hit.emit(damage)
		bullet_node.visible = false
		# disable collision for this bullet
		bullet_node.collision_shape.set_deferred("disabled", true)
	else:
		# var idx = bullets.find(bullet_node)
		bullet_node.visible = false
		bullet_node.collision_shape.set_deferred("disabled", true)


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


#------------------------------------------------
func serialize_state() -> Dictionary:
	return {
		"type": "trap10-shotgun",
		"position": global_position,
		"basket_rotation": baskets.rotation,
		"move_basket_position_x": move_basket.position.x,
		"move_basket_scale": move_basket.scale,
		"empty_basket_scale": empty_basket.scale,
		"full_basket_scale": full_basket.scale,
		"bullet0_position": bullets[0].position,
		"bullet1_position": bullets[1].position,
		"bullet2_position": bullets[2].position,
		"bullet_rotation": bullets[0].rotation,
		"lines_visibility": lines_container.visible,
		"line0_end": lines[0].get_point_position(1),
		"line1_end": lines[1].get_point_position(1),
		"line2_end": lines[2].get_point_position(1),
		"bullet0_emitting": bullets[0].effect.emitting if bullets[0].effect else false,
		"bullet1_emitting": bullets[1].effect.emitting if bullets[1].effect else false,
		"bullet2_emitting": bullets[2].effect.emitting if bullets[2].effect else false,
		"bullet0_visibility": bullets[0].visible,
		"bullet1_visibility": bullets[1].visible,
		"bullet2_visibility": bullets[2].visible,
	}


func apply_demo_state(data: Dictionary) -> void:
	global_position = data.get("position", Vector2.ZERO)
	baskets.rotation = data.get("basket_rotation", 0.0)
	move_basket.position.x = data.get("move_basket_position_x", 0.0)
	move_basket.scale = data.get("move_basket_scale", Vector2.ZERO)
	empty_basket.scale = data.get("empty_basket_scale", Vector2.ZERO)
	full_basket.scale = data.get("full_basket_scale", Vector2.ZERO)

	bullets[0].position = data.get("bullet0_position", Vector2.ZERO)
	bullets[1].position = data.get("bullet1_position", Vector2.ZERO)
	bullets[2].position = data.get("bullet2_position", Vector2.ZERO)

	bullets[0].visible = data.get("bullet0_visibility", false)
	bullets[1].visible = data.get("bullet1_visibility", false)
	bullets[2].visible = data.get("bullet2_visibility", false)

	for b in bullets:
		b.effect.global_position = b.global_position
	for b in bullets:
		b.rotation = data.get("bullet_rotation", 0.0)
	lines_container.visible = data.get("lines_visibility", false)
	if lines_container.visible:
		lines[0].set_point_position(1, data.get("line0_end", Vector2.ZERO))
		lines[1].set_point_position(1, data.get("line1_end", Vector2.ZERO))
		lines[2].set_point_position(1, data.get("line2_end", Vector2.ZERO))
	if !particles_reparented:
		particles_reparented = true
		for b in bullets:
			b.effect.reparent($"../..")
	if bullets[0].effect:
		bullets[0].effect.emitting = data.get("bullet0_emitting", false)
	if bullets[1].effect:
		bullets[1].effect.emitting = data.get("bullet1_emitting", false)
	if bullets[2].effect:
		bullets[2].effect.emitting = data.get("bullet2_emitting", false)
