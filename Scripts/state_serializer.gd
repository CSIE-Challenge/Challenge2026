## Client-side state serializer that collects render-relevant game state
## and pushes it to the server at ~30fps via unreliable_ordered RPC.
##
## Attach this node to the gameplay scene on game clients (not server, not demo).
## Requires [member game_manager] and [member stage] references to be set.
class_name StateSerializer
extends Node

const PUSH_INTERVAL := 1.0 / 30.0

@export var game_manager: Node
@export var stage: Node2D

var _timer: Timer
var _trap_id_counter: int = 0
var _trap_id_map: Dictionary = {}  # {Node: int}
var _push_count: int = 0


func _ready() -> void:
	print("[StateSerializer] _ready() — game_manager=%s stage=%s" % [game_manager, stage])
	_timer = Timer.new()
	_timer.name = "StatePushTimer"
	_timer.wait_time = PUSH_INTERVAL
	_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	_timer.autostart = true
	_timer.timeout.connect(_push_state)
	add_child(_timer)


func _push_state() -> void:
	# Guard: only push when connected to a real multiplayer server
	var peer := multiplayer.multiplayer_peer
	if not peer or peer is OfflineMultiplayerPeer:
		return
	# Guard: connection must be fully established (get_unique_id not ready yet)
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	var state := _collect_state()
	NetworkManager.rpc_id(1, "_server_receive_state", state)
	_push_count += 1
	if _push_count % 30 == 1:
		print(
			(
				"[StateSerializer] pushed state #%d | tick=%d | peer=%d | pos=(%.0f,%.0f)"
				% [
					_push_count,
					state["tick"],
					state["peer_id"],
					state["player"].get("position", Vector2.ZERO).x,
					state["player"].get("position", Vector2.ZERO).y,
				]
			)
		)


## Assembles the complete state dictionary for this client.
func _collect_state() -> Dictionary:
	var player_node: Node = (
		game_manager.player if game_manager and "player" in game_manager else null
	)
	return {
		"peer_id": multiplayer.get_unique_id(),
		"tick": Engine.get_physics_frames(),
		"player": _serialize_player(player_node),
		"traps": _serialize_traps(),
		"energy_balls": _serialize_energy_balls(),
	}


## Serializes the player character into a state dictionary.
func _serialize_player(p: Node) -> Dictionary:
	if not is_instance_valid(p):
		return {}

	var energy := 0
	var ball_count := 0
	if game_manager:
		energy = game_manager.get("energy_amount") if "energy_amount" in game_manager else 0
		ball_count = (
			game_manager.get("energy_ball_count") if "energy_ball_count" in game_manager else 0
		)

	return {
		"position": p.global_position if p is Node2D else Vector2.ZERO,
		"velocity": p.get("velocity") if "velocity" in p else Vector2.ZERO,
		"is_jumping": p.get("isjumping") if "isjumping" in p else false,
		"sprite_y": p.get("current_sprite_y") if "current_sprite_y" in p else 0.0,
		"health": p.get("health") if "health" in p else 0.0,
		"is_invincible": p.get("isinvincible") if "isinvincible" in p else false,
		"modulate_alpha": p.modulate.a if "modulate" in p else 1.0,
		"energy": energy,
		"energy_ball_count": ball_count,
	}


## Collects all trap state from stage children.
func _serialize_traps() -> Array[Dictionary]:
	var traps: Array[Dictionary] = []
	if not stage:
		return traps

	for child in stage.get_children():
		var trap_data := _serialize_single_trap(child)
		if not trap_data.is_empty():
			traps.append(trap_data)
	return traps


## Serializes a single node into a trap state dictionary.
## Returns an empty Dictionary if the node is not a recognized trap.
func _serialize_single_trap(node: Node) -> Dictionary:
	var script := node.get_script() as Script
	if not script:
		return {}

	var script_path: String = script.resource_path

	# Base fields
	var data := {
		"id": _get_trap_id(node),
		"position": node.global_position if node is Node2D else Vector2.ZERO,
		"visible": node.visible if "visible" in node else true,
	}

	# Type-specific fields — matched by script filename suffix.
	# Each trap emits a "phase" string + 0~1 progress fields so the demo
	# renderer can drive visuals without knowing internal variable names.
	if script_path.ends_with("trap1-mine.gd"):
		data["type"] = "mine"
		data["is_armed"] = node.get("is_armed") if "is_armed" in node else false
		data["phase"] = "armed" if data["is_armed"] else "arming"
		var mine_body: Node = node.get_node_or_null("MineBody")
		if mine_body and "modulate" in mine_body:
			var col: Color = mine_body.modulate
			data["modulate_r"] = col.r
			data["modulate_g"] = col.g
			data["modulate_b"] = col.b
			data["modulate_a"] = col.a
		else:
			data["modulate_r"] = 1.0
			data["modulate_g"] = 1.0
			data["modulate_b"] = 1.0
			data["modulate_a"] = 1.0

	elif script_path.ends_with("trap2-electric_ring.gd"):
		data["type"] = "electric_ring"
		data["radius"] = node.get("radius") if "radius" in node else 0.0
		data["current_fill"] = node.get("current_fill") if "current_fill" in node else 0.0
		data["electric_on"] = node.get("electric_on") if "electric_on" in node else false
		data["current_stay_time"] = (
			node.get("current_stay_time") if "current_stay_time" in node else 0.0
		)
		if data["electric_on"]:
			data["phase"] = "active"
		elif data["current_fill"] > 0.0:
			data["phase"] = "warning"
		else:
			data["phase"] = "idle"
		var ring: Node2D = node.get_node_or_null("ElectricRing") as Node2D
		var warn: Node2D = node.get_node_or_null("ElectricRingWarning") as Node2D
		data["scale_x"] = ring.scale.x if ring else 1.0
		data["scale_y"] = ring.scale.y if ring else 1.0
		data["warning_visible"] = warn.visible if warn and "visible" in warn else false
		data["ring_visible"] = ring.visible if ring and "visible" in ring else false
		var anim: AnimationPlayer = node.get_node_or_null("AnimationPlayer") as AnimationPlayer
		data["animation_name"] = anim.current_animation if anim and anim.is_playing() else ""

	elif script_path.ends_with("trap3-tracing_bullet.gd"):
		data["type"] = "tracing_bullet"
		data["rotation"] = node.rotation if "rotation" in node else 0.0
		var tracing: bool = node.get("tracing") if "tracing" in node else false
		var target: Node = node.get("target") if "target" in node else null
		data["tracing"] = tracing
		if tracing:
			data["phase"] = "homing"
		elif target != null:
			data["phase"] = "straight"
		else:
			data["phase"] = "done"

	elif script_path.ends_with("trap4-conveyor.gd"):
		data["type"] = "conveyor"
		data["direction"] = node.get("direction") if "direction" in node else Vector2.ZERO

	elif script_path.ends_with("trap5-icefloor.gd"):
		data["type"] = "ice_floor"

	elif script_path.ends_with("trap6-scanline.gd"):
		data["type"] = "scanline"
		data["phase"] = "active"
		data["line_dir"] = node.get("line_dir") if "line_dir" in node else Vector2.ZERO
		var visual_line: Node2D = node.get_node_or_null("Hulas") as Node2D
		data["oscillation_offset"] = (
			visual_line.position.x if visual_line and "position" in visual_line else 0.0
		)

	elif script_path.ends_with("trap7-spreading_ripples.gd"):
		data["type"] = "spreading_ripples"
		var is_expanding: bool = node.get("is_expanding") if "is_expanding" in node else false
		var collision_shape: CollisionShape2D = (
			node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		)
		var current_radius: float = 0.0
		if collision_shape and collision_shape.shape is CircleShape2D:
			current_radius = (collision_shape.shape as CircleShape2D).radius
		var max_radius: float = node.get("max_radius") if "max_radius" in node else 1000.0
		data["expand_progress"] = (
			clamp(current_radius / max_radius, 0.0, 1.0) if max_radius > 0.0 else 0.0
		)
		if not is_expanding and current_radius <= 0.0:
			data["phase"] = "warning"
		elif is_expanding:
			data["phase"] = "expanding"
		else:
			data["phase"] = "done"

	elif script_path.ends_with("trap8-electric_arc.gd"):
		data["type"] = "electric_arc"
		var activated: bool = node.get("activated") if "activated" in node else false
		if activated:
			data["phase"] = "active"
		elif node.visible:
			data["phase"] = "warning"
		else:
			data["phase"] = "despawn"
		var start_point: Node2D = node.get_node_or_null("StartPoint") as Node2D
		var end_point: Node2D = node.get_node_or_null("EndPoint") as Node2D
		data["start_pos"] = start_point.position if start_point else Vector2.ZERO
		data["end_pos"] = end_point.position if end_point else Vector2.ZERO
		var crack: Sprite2D = node.get_node_or_null("Crack") as Sprite2D
		if crack and crack.material:
			data["crack_progress"] = crack.material.get_shader_parameter("progress")
		else:
			data["crack_progress"] = 0.0

	elif script_path.ends_with("trap9-mortar.gd"):
		data["type"] = "mortar"
		var flying: bool = node.get("flying") if "flying" in node else false
		var exploding: bool = node.get("exploding") if "exploding" in node else false
		if flying:
			data["phase"] = "flying"
		elif exploding:
			data["phase"] = "exploding"
		else:
			data["phase"] = "done"
		var shell_shadow: Node2D = node.get_node_or_null("ShellShadow") as Node2D
		data["shell_position"] = (
			shell_shadow.position if shell_shadow and "position" in shell_shadow else Vector2.ZERO
		)
		var shell: Sprite2D = node.get_node_or_null("ShellShadow/Shell") as Sprite2D
		data["shell_y_offset"] = shell.position.y if shell and "position" in shell else 0.0
		data["shell_rotation"] = shell.rotation if shell and "rotation" in shell else 0.0
		var explosion: Sprite2D = node.get_node_or_null("Explosion") as Sprite2D
		data["explosion_visible"] = (
			explosion.visible if explosion and "visible" in explosion else false
		)

	elif script_path.ends_with("trap10-shotgun.gd"):
		data["type"] = "shotgun"
		data["directions"] = node.get("directions") if "directions" in node else []
		var aiming: bool = node.get("aiming") if "aiming" in node else false
		var firing: bool = node.get("firing") if "firing" in node else false
		if aiming:
			data["phase"] = "warning"
		elif firing:
			data["phase"] = "firing"
		else:
			data["phase"] = "done"
		# warning_progress: time elapsed / aiming_time
		var timer: Timer = node.get_node_or_null("Timer") as Timer
		var aiming_time: float = node.get("aiming_time") if "aiming_time" in node else 1.0
		if aiming and timer and aiming_time > 0.0:
			data["warning_progress"] = clamp(1.0 - (timer.time_left / aiming_time), 0.0, 1.0)
		else:
			data["warning_progress"] = 0.0

	else:
		# Not a recognized trap type
		return {}

	return data


## Collects energy ball state from stage children.
func _serialize_energy_balls() -> Array[Dictionary]:
	var balls: Array[Dictionary] = []
	if not stage:
		return balls

	for child in stage.get_children():
		if _is_energy_ball(child):
			(
				balls
				. append(
					{
						"id": child.get_instance_id(),
						"position": child.global_position if child is Node2D else Vector2.ZERO,
						"collected": not child.visible if "visible" in child else false,
					}
				)
			)
	return balls


## Returns true if [param node] is an energy ball (has energy_ball.gd script).
func _is_energy_ball(node: Node) -> bool:
	var script := node.get_script() as Script
	if not script:
		return false
	return script.resource_path.ends_with("energy_ball.gd")


## Assigns and returns a stable integer ID for [param node].
func _get_trap_id(node: Node) -> int:
	if not _trap_id_map.has(node):
		_trap_id_counter += 1
		_trap_id_map[node] = _trap_id_counter
	return _trap_id_map[node]
