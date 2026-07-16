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
	# print("[StateSerializer] _ready() — game_manager=%s stage=%s" % [game_manager, stage])
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
	var nm: Node = get_node_or_null("/root/NetworkManager")
	if nm and nm.has_method("rpc_id"):
		nm.rpc_id(1, "_server_receive_state", state)
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
		"max_energy_cap": _collect_max_energy_cap(),
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
		"skin_id": p.get("skin_id") if "skin_id" in p else "",
	}


func _collect_max_energy_cap() -> int:
	if not game_manager:
		return 0
	if game_manager.has_method("get_current_max_energy_cap"):
		return int(game_manager.get_current_max_energy_cap())

	if not ("max_energy" in game_manager) or not ("current_phase" in game_manager):
		return 0

	var caps: Array = game_manager.max_energy
	if typeof(caps) != TYPE_ARRAY or caps.is_empty():
		return 0

	var phase: int = int(game_manager.current_phase)
	var index: int = min(phase, caps.size() - 1)
	return int(caps[index])


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
## v2: delegates to the trap's own serialize_state() method.
func _serialize_single_trap(node: Node) -> Dictionary:
	if node.has_method("serialize_state"):
		var data: Dictionary = node.serialize_state()
		data["id"] = _get_trap_id(node)
		return data
	return {}


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
