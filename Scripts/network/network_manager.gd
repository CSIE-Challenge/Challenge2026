# gdlint: disable=max-public-methods
## Autoload singleton that manages all ENet networking for this game.
## Supports up to two simultaneous clients connected to a single server.
## Can be started as a server ([code]--server[/code]) or client
## ([code]--connect <address>[/code]) via command-line arguments.
## Exposes signals for all connection lifecycle events.
extends Node

signal server_started(port: int)
signal server_start_failed(error: Error)
signal client_started(address: String, port: int)
signal client_start_failed(error: Error)
signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_succeeded
signal connection_failed
signal server_disconnected
signal room_full(peer_id: int)
signal energy_changed(peer_id: int, energy: int)
signal energy_rejected(peer_id: int, reason: String)
signal health_changed(peer_id: int, health: int)
signal health_rejected(peer_id: int, reason: String)
signal energy_ball_count_changed(peer_id: int, count: int)
signal demo_connected(peer_id: int)
signal demo_disconnected
signal demo_state_received(data: Dictionary)
signal countdown_start_released
signal multiplayer_finish(winner_peer_ids: Array, draw: bool, forfeit: bool)

const MAX_HEALTH := 5
const DEFAULT_MAX_ENERGY := 35
const DEFAULT_PORT := 7777
const DEFAULT_SERVER_ADDRESS := "127.0.0.1"
const MAX_CLIENTS := 3
const READY_TIMEOUT_SECONDS := 90.0

var max_energy: int = DEFAULT_MAX_ENERGY
var connected_peer_ids: Array[int] = []
var energy_by_peer_id: Dictionary = {}
var health_by_peer_id: Dictionary = {}
var energy_ball_count_by_peer_id: Dictionary = {}
var demo_peer_id: int = -1  # -1 when no demo is connected
var max_health: int = MAX_HEALTH
var game_finished: bool = false
var _game_data: Dictionary = {}
var _game_max_energy: Array = []
var _client_states: Dictionary = {}  # peer_id → state snapshot Dictionary
var _server_receive_count: int = 0
var _demo_push_count: int = 0
var _ready_timeout_timer: Timer = null
var _gameplay_loaded_peer_ids: Array[int] = []
var _countdown_start_released := false
var _time_up_peer_ids: Array[int] = []


## Called on startup. Connects multiplayer signals and handles command-line launch.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_multiplayer_signals()
	_load_game_data()
	var initial_caps: Array = _read_game_max_energy_caps()
	max_energy = int(initial_caps[0]) if initial_caps.size() > 0 else DEFAULT_MAX_ENERGY
	max_health = _load_max_health_from_game_json()
	_start_from_command_line(OS.get_cmdline_user_args())

	if multiplayer.is_server() and not _has_demo_flag(OS.get_cmdline_user_args()):
		var collector: Node = load("res://Scripts/network/state_collector.gd").new()
		add_child(collector)
	game_finished = false


## Creates an ENet server on [param port] and hands it to the multiplayer system.
## Emits [signal server_started] on success, [signal server_start_failed] on error.
func start_server(port := DEFAULT_PORT) -> Error:
	stop_network()
	_load_game_data()
	var initial_caps: Array = _read_game_max_energy_caps()
	max_energy = int(initial_caps[0]) if initial_caps.size() > 0 else DEFAULT_MAX_ENERGY

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		server_start_failed.emit(error)
		return error

	game_finished = false
	multiplayer.multiplayer_peer = peer
	connected_peer_ids.clear()
	energy_by_peer_id.clear()
	health_by_peer_id.clear()
	energy_ball_count_by_peer_id.clear()
	_time_up_peer_ids.clear()
	_client_states.clear()
	_reset_countdown_start_sync()
	server_started.emit(port)
	print("Network server started on UDP port %d, max clients: %d" % [port, MAX_CLIENTS])
	return OK


## Connects to a server at [param address]:[param port] as a client.
## Emits [signal client_started] on success, [signal client_start_failed] on error.
func join_server(address := DEFAULT_SERVER_ADDRESS, port := DEFAULT_PORT) -> Error:
	stop_network()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		client_start_failed.emit(error)
		return error

	multiplayer.multiplayer_peer = peer
	client_started.emit(address, port)
	print("Connecting to %s:%d" % [address, port])
	return OK


func update_max_energy(new_max_energy: int) -> void:
	var energy_caps: Array = _read_game_max_energy_caps()
	var ceiling_cap: int = int(energy_caps[-1]) if energy_caps.size() > 0 else DEFAULT_MAX_ENERGY
	max_energy = clampi(new_max_energy, 0, ceiling_cap)

	if multiplayer.is_server():
		return

	if not _can_process_local_network_request():
		return

	rpc_id(1, "_server_set_max_energy_cap", max_energy)


func update_energy_ball_count(count: int) -> void:
	var normalized_count: int = maxi(count, 0)
	if not _can_process_local_network_request():
		return

	if multiplayer.is_server():
		_ensure_local_peer_state()
		_server_set_energy_ball_count_for_peer(multiplayer.get_unique_id(), normalized_count)
	else:
		rpc_id(1, "_server_set_energy_ball_count", normalized_count)


## Closes the current connection and resets the multiplayer peer to offline mode.
func stop_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected_peer_ids.clear()
	energy_by_peer_id.clear()
	health_by_peer_id.clear()
	energy_ball_count_by_peer_id.clear()
	_client_states.clear()
	_reset_countdown_start_sync()
	_time_up_peer_ids.clear()
	game_finished = false
	_refresh_game_max_energy_caps()
	var initial_caps: Array = _read_game_max_energy_caps()
	max_energy = int(initial_caps[0]) if initial_caps.size() > 0 else DEFAULT_MAX_ENERGY


## Returns true if the server can accept more clients based on [param connected_client_count].
func can_accept_more_clients(connected_client_count: int) -> bool:
	return connected_client_count < MAX_CLIENTS


## Reads [param args] and returns the startup mode: "server", "client", or "offline".
func get_startup_mode(args: Array) -> String:
	if args.has("--server"):
		return "server"
	if _find_arg_value(args, "--connect") != "":
		return "client"
	return "offline"


## Reads [param args] and returns the server address from [code]--connect[/code], or the default.
func get_server_address(args: Array) -> String:
	var address := _find_arg_value(args, "--connect")
	if address == "":
		return DEFAULT_SERVER_ADDRESS
	return address


## Reads [param args] and returns the port from [code]--port[/code], or the default.
func get_server_port(args: Array) -> int:
	var port_text := _find_arg_value(args, "--port")
	if port_text == "":
		return DEFAULT_PORT
	return int(port_text)


## Returns true if this instance is currently running as the multiplayer server.
func is_running_server() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


## Returns the number of currently connected clients.
func get_connected_client_count() -> int:
	return connected_peer_ids.size()


## Returns the server-approved energy for [param peer_id].
func get_energy(peer_id: int) -> int:
	return int(energy_by_peer_id.get(peer_id, 0))


## Returns the server-approved health for [param peer_id].
func get_health(peer_id: int) -> int:
	return int(health_by_peer_id.get(peer_id, max_health))


## Returns the server-approved number of energy balls collected by [param peer_id].
func get_energy_ball_count(peer_id: int) -> int:
	return int(energy_ball_count_by_peer_id.get(peer_id, 0))


## Returns the configured gameplay health cap loaded from Data/game.json.
func get_max_health() -> int:
	return max_health


func _load_max_health_from_game_json() -> int:
	if typeof(_game_data) != TYPE_DICTIONARY:
		return MAX_HEALTH

	var player_data: Dictionary = _game_data.get("player", {})
	if typeof(player_data) != TYPE_DICTIONARY:
		return MAX_HEALTH

	var configured := int(player_data.get("max_health", MAX_HEALTH))
	return max(1, configured)


func _read_game_max_energy_caps() -> Array:
	return _game_max_energy if not _game_max_energy.is_empty() else [DEFAULT_MAX_ENERGY]


func _refresh_game_max_energy_caps() -> void:
	var normalized_caps: Array = []
	if typeof(_game_data) != TYPE_DICTIONARY:
		_game_max_energy = [DEFAULT_MAX_ENERGY]
		return

	var manager_data: Dictionary = _game_data.get("game_manager", {})
	if typeof(manager_data) != TYPE_DICTIONARY:
		_game_max_energy = [DEFAULT_MAX_ENERGY]
		return

	var raw_caps: Array = manager_data.get("max_energy", [])
	if typeof(raw_caps) != TYPE_ARRAY:
		_game_max_energy = [DEFAULT_MAX_ENERGY]
		return

	for value in raw_caps:
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			var parsed: int = int(value)
			if parsed > 0:
				normalized_caps.append(parsed)

	if normalized_caps.is_empty():
		_game_max_energy = [DEFAULT_MAX_ENERGY]
		return

	_game_max_energy = normalized_caps


## Returns every peer for which this client has authoritative status cache.
## This includes peers learned through either energy or health synchronization.
func get_tracked_peer_ids() -> Array[int]:
	var peer_ids: Array[int] = []
	for peer_id in health_by_peer_id:
		peer_ids.append(int(peer_id))
	for peer_id in energy_by_peer_id:
		if not peer_ids.has(int(peer_id)):
			peer_ids.append(int(peer_id))
	return peer_ids


## Returns the first non-local gameplay peer. In offline mode, opponent aliases self
## so agent scripts can call opponent APIs without single-player special cases.
func get_opponent_peer_id() -> int:
	if _is_offline_mode():
		return multiplayer.get_unique_id()

	var local_peer_id := multiplayer.get_unique_id()
	for peer_id in get_tracked_peer_ids():
		if peer_id != local_peer_id and peer_id != demo_peer_id:
			return peer_id
	return -1


## Multiplayer start barrier used after the gameplay scene finishes loading.
## Clients wait here so the pregame countdown starts at the same time on both machines.
func wait_for_countdown_start_after_scene_loaded() -> void:
	_countdown_start_released = false
	if _is_offline_mode():
		_countdown_start_released = true
		return
	if not _can_process_local_network_request():
		_countdown_start_released = true
		return

	if multiplayer.is_server():
		_server_mark_gameplay_loaded(multiplayer.get_unique_id())
	else:
		rpc_id(1, "_server_gameplay_loaded")

	if not _countdown_start_released:
		await countdown_start_released


## Parses command-line [param args] and starts the appropriate network mode automatically.
func _start_from_command_line(args: Array) -> void:
	var mode := get_startup_mode(args)
	var port := get_server_port(args)
	print("[NetworkManager] startup mode=%s port=%d args=%s" % [mode, port, args])

	if _has_demo_flag(args):
		var connect_addr := _extract_connect_address(args)
		if connect_addr.is_empty():
			connect_addr = DEFAULT_SERVER_ADDRESS
		_do_demo_start.call_deferred(connect_addr, port)
		return

	if mode == "server":
		start_server(port)
	elif mode == "client":
		join_server(get_server_address(args), port)


## Returns true if [param args] contains the --demo flag.
func _has_demo_flag(args: Array) -> bool:
	return args.has("--demo")


## Loads the demo scene and joins the server. Called deferred to avoid
## change_scene_to_file during _ready() tree setup.
func _do_demo_start(connect_addr: String, port := DEFAULT_PORT) -> void:
	get_tree().change_scene_to_file("res://Scenes/demo.tscn")
	join_server(connect_addr, port)


## Extracts the --connect address from [param args] that may also contain --demo.
func _extract_connect_address(args: Array) -> String:
	return _find_arg_value(args, "--connect")


## Connects all multiplayer API signals to their local handler functions.
## Guards against duplicate connections.
func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


## Handles a new peer connecting. On the server, rejects the peer if the room is full.
func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		player_connected.emit(peer_id)
		return

	if not can_accept_more_clients(connected_peer_ids.size()):
		room_full.emit(peer_id)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		print("Rejected peer %d because the room is full" % peer_id)
		return

	if not connected_peer_ids.has(peer_id):
		connected_peer_ids.append(peer_id)
	energy_by_peer_id[peer_id] = 0
	health_by_peer_id[peer_id] = max_health
	energy_ball_count_by_peer_id[peer_id] = 0
	_broadcast_energy(peer_id, 0)
	_broadcast_health(peer_id, max_health)
	_broadcast_energy_ball_count(peer_id, 0)
	_sync_energy_to_peer(peer_id)
	_sync_health_to_peer(peer_id)
	_sync_energy_ball_count_to_peer(peer_id)

	player_connected.emit(peer_id)
	print("Peer connected: %d (%d/%d)" % [peer_id, connected_peer_ids.size(), MAX_CLIENTS])

	if connected_peer_ids.size() == 2 and peer_id != demo_peer_id:
		if _ready_timeout_timer == null:
			_ready_timeout_timer = Timer.new()
			_ready_timeout_timer.name = "ReadyTimeoutTimer"
			_ready_timeout_timer.one_shot = true
			_ready_timeout_timer.wait_time = READY_TIMEOUT_SECONDS
			_ready_timeout_timer.timeout.connect(_on_ready_timeout)
			add_child(_ready_timeout_timer)
		_ready_timeout_timer.start()
		print("[NetworkManager] Ready timeout started (90s) — 2 players connected")


## Removes a disconnected peer from the tracked list and emits [signal player_disconnected].
func _on_peer_disconnected(peer_id: int) -> void:
	connected_peer_ids.erase(peer_id)
	energy_by_peer_id.erase(peer_id)
	health_by_peer_id.erase(peer_id)
	energy_ball_count_by_peer_id.erase(peer_id)
	_time_up_peer_ids.erase(peer_id)
	_client_states.erase(peer_id)
	_gameplay_loaded_peer_ids.erase(peer_id)

	if connected_peer_ids.size() < 2 and _ready_timeout_timer != null:
		_ready_timeout_timer.stop()
		print("[NetworkManager] Ready timeout cancelled — not enough players")

	if peer_id == demo_peer_id:
		_unregister_demo()

	player_disconnected.emit(peer_id)
	print("Peer disconnected: %d" % peer_id)

	if multiplayer.is_server() and connected_peer_ids.is_empty():
		print("[NetworkManager] All peers disconnected — exiting server")
		get_tree().quit(0)


func _on_ready_timeout() -> void:
	print("[NetworkManager] Ready timeout reached — exiting server")
	get_tree().quit(0)


@rpc("any_peer", "call_remote", "reliable")
func cancel_ready_timeout() -> void:
	if not multiplayer.is_server():
		return
	if _ready_timeout_timer != null:
		_ready_timeout_timer.stop()
		print("[NetworkManager] Ready timeout cancelled by player readiness")


## Called when this client successfully connects to a server.
func _on_connected_to_server() -> void:
	connection_succeeded.emit()
	print("Connected to server as peer %d" % multiplayer.get_unique_id())


## Called when this client fails to connect to a server.
func _on_connection_failed() -> void:
	connection_failed.emit()
	print("Connection failed")


## Called when the server closes the connection.
func _on_server_disconnected() -> void:
	server_disconnected.emit()
	print("Disconnected from server")


@rpc("any_peer", "call_remote", "reliable")
func _server_gameplay_loaded() -> void:
	if not multiplayer.is_server():
		return

	# Only gameplay players participate in the start barrier; demo spectators do not block start.
	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return
	if sender_id == demo_peer_id:
		return

	_server_mark_gameplay_loaded(sender_id)


func _server_mark_gameplay_loaded(peer_id: int) -> void:
	if _countdown_start_released:
		return
	if not _gameplay_loaded_peer_ids.has(peer_id):
		_gameplay_loaded_peer_ids.append(peer_id)

	var required_count := _get_required_gameplay_loaded_peer_count()
	print(
		(
			"[NetworkManager] Gameplay loaded: %d/%d"
			% [_gameplay_loaded_peer_ids.size(), required_count]
		)
	)
	if required_count > 0 and _gameplay_loaded_peer_ids.size() >= required_count:
		_server_release_countdown_start()


func _get_required_gameplay_loaded_peer_count() -> int:
	var player_count := 0
	for peer_id in connected_peer_ids:
		if peer_id != demo_peer_id:
			player_count += 1
	return min(2, max(1, player_count))


func _server_release_countdown_start() -> void:
	_countdown_start_released = true
	_gameplay_loaded_peer_ids.clear()
	countdown_start_released.emit()
	rpc("_client_release_countdown_start")
	print("[NetworkManager] Countdown start released")


@rpc("authority", "call_remote", "reliable")
func _client_release_countdown_start() -> void:
	if _countdown_start_released:
		return
	_countdown_start_released = true
	countdown_start_released.emit()


func _reset_countdown_start_sync() -> void:
	_gameplay_loaded_peer_ids.clear()
	_countdown_start_released = false


## Searches [param args] for a named argument and returns its value.
## Supports both [code]--key value[/code] and [code]--key=value[/code] formats.
func _find_arg_value(args: Array, arg_name: String) -> String:
	for i in args.size():
		var arg := str(args[i])
		if arg == arg_name and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with("%s=" % arg_name):
			return arg.substr(arg_name.length() + 1)

	return ""


func request_add_energy(amount: int) -> void:
	if amount <= 0:
		return
	if not _can_process_local_network_request():
		return

	if multiplayer.is_server():
		_ensure_local_peer_state()
		_server_add_energy(multiplayer.get_unique_id(), amount)
	else:
		rpc_id(1, "_server_request_add_energy", amount)


func request_spend_energy(amount: int) -> void:
	if amount <= 0:
		return
	if not _can_process_local_network_request():
		return

	if multiplayer.is_server():
		_ensure_local_peer_state()
		_server_spend_energy(multiplayer.get_unique_id(), amount)
	else:
		rpc_id(1, "_server_request_spend_energy", amount)


## Spends energy from an explicit peer. This is used when an agent runs on one
## machine but needs to spend the other player's server-authoritative energy.
func request_spend_peer_energy(peer_id: int, amount: int) -> void:
	if amount <= 0:
		return
	if not _can_process_local_network_request():
		return

	if multiplayer.is_server():
		_ensure_local_peer_state()
		_server_spend_energy(peer_id, amount, multiplayer.get_unique_id())
	else:
		rpc_id(1, "_server_request_spend_peer_energy", peer_id, amount)


## Spends energy from the opponent peer; aliases to self in offline mode.
func request_spend_opponent_energy(amount: int) -> void:
	var opponent_peer_id := get_opponent_peer_id()
	if opponent_peer_id == -1:
		energy_rejected.emit(multiplayer.get_unique_id(), "opponent peer not found")
		return
	request_spend_peer_energy(opponent_peer_id, amount)


## Applies damage to this client's own health through the same network path as remote updates.
func request_damage_health(amount: int) -> void:
	if amount <= 0:
		return
	request_change_peer_health(multiplayer.get_unique_id(), -amount)


## Heals this client's own health through the same network path as remote updates.
func request_heal_health(amount: int) -> void:
	if amount <= 0:
		return
	request_change_peer_health(multiplayer.get_unique_id(), amount)


func request_time_up_finish() -> bool:
	if game_finished:
		return false

	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null or peer is OfflineMultiplayerPeer:
		return false
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return false

	if multiplayer.is_server():
		_server_register_time_up_finish(multiplayer.get_unique_id())
	else:
		rpc_id(1, "_server_request_time_up_finish")
	return true


## Changes a specific peer's health. Positive [param delta] heals, negative damages.
func request_change_peer_health(peer_id: int, delta: int) -> void:
	if delta == 0:
		return
	if not _can_process_local_network_request():
		return

	if multiplayer.is_server():
		_ensure_local_peer_state()
		_server_change_health(peer_id, delta, multiplayer.get_unique_id())
	else:
		rpc_id(1, "_server_request_change_peer_health", peer_id, delta)


## Changes opponent health; aliases to self in offline mode.
func request_change_opponent_health(delta: int) -> void:
	var opponent_peer_id := get_opponent_peer_id()
	if opponent_peer_id == -1:
		health_rejected.emit(multiplayer.get_unique_id(), "opponent peer not found")
		return
	request_change_peer_health(opponent_peer_id, delta)


## Heals opponent health; aliases to self in offline mode.
func request_heal_opponent_health(amount: int) -> void:
	if amount <= 0:
		return
	request_change_opponent_health(amount)


## Damages opponent health; aliases to self in offline mode.
func request_damage_opponent_health(amount: int) -> void:
	if amount <= 0:
		return
	request_change_opponent_health(-amount)


@rpc("any_peer", "call_remote", "reliable")
func _server_request_add_energy(amount: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return
	_server_add_energy(sender_id, amount)


@rpc("any_peer", "call_remote", "reliable")
func _server_request_spend_energy(amount: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return
	_server_spend_energy(sender_id, amount)


@rpc("any_peer", "call_remote", "reliable")
func _server_request_spend_peer_energy(peer_id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return
	if not energy_by_peer_id.has(peer_id):
		_server_reject_energy(sender_id, "unknown peer: %d" % peer_id)
		return

	_server_spend_energy(peer_id, amount, sender_id)


## Server-side health mutation endpoint. The sender is only used as the rejection target;
## the mutation target can be any tracked peer.
@rpc("any_peer", "call_remote", "reliable")
func _server_request_change_peer_health(peer_id: int, delta: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return
	if not health_by_peer_id.has(peer_id):
		_server_reject_health(sender_id, "unknown peer: %d" % peer_id)
		return

	_server_change_health(peer_id, delta, sender_id)


@rpc("any_peer", "call_remote", "reliable")
func _server_request_time_up_finish() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	_server_register_time_up_finish(sender_id)


@rpc("any_peer", "call_remote", "reliable")
func _server_set_max_energy_cap(requested_cap: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not connected_peer_ids.has(sender_id):
		return

	var capped_cap := _clamp_reported_max_energy_cap(requested_cap)
	if capped_cap <= max_energy:
		return

	max_energy = capped_cap


@rpc("any_peer", "call_remote", "reliable")
func _server_set_energy_ball_count(count: int) -> void:
	if not multiplayer.is_server():
		return

	# Clients only report their own collected ball count; the server tags it by sender id.
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()
	if not connected_peer_ids.has(sender_id) and sender_id != multiplayer.get_unique_id():
		return

	_server_set_energy_ball_count_for_peer(sender_id, count)


func _sync_energy_to_peer(target_peer_id: int) -> void:
	for peer_id in energy_by_peer_id:
		if peer_id == target_peer_id:
			continue
		_client_set_energy.rpc_id(target_peer_id, peer_id, get_energy(peer_id))


func _sync_health_to_peer(target_peer_id: int) -> void:
	for peer_id in health_by_peer_id:
		if peer_id == target_peer_id:
			continue
		_client_set_health.rpc_id(target_peer_id, peer_id, get_health(peer_id))


func _sync_energy_ball_count_to_peer(target_peer_id: int) -> void:
	for peer_id in energy_ball_count_by_peer_id:
		if peer_id == target_peer_id:
			continue
		_client_set_energy_ball_count.rpc_id(
			target_peer_id, peer_id, get_energy_ball_count(peer_id)
		)


func _server_reject_energy(peer_id: int, reason: String) -> void:
	energy_rejected.emit(peer_id, reason)
	if peer_id != multiplayer.get_unique_id() and connected_peer_ids.has(peer_id):
		_client_reject_energy.rpc_id(peer_id, reason)


@rpc("authority", "call_remote", "reliable")
func _client_reject_energy(reason: String) -> void:
	energy_rejected.emit(multiplayer.get_unique_id(), reason)


func _server_reject_health(peer_id: int, reason: String) -> void:
	health_rejected.emit(peer_id, reason)
	if peer_id != multiplayer.get_unique_id() and connected_peer_ids.has(peer_id):
		_client_reject_health.rpc_id(peer_id, reason)


@rpc("authority", "call_remote", "reliable")
func _client_reject_health(reason: String) -> void:
	health_rejected.emit(multiplayer.get_unique_id(), reason)


func _server_add_energy(peer_id: int, amount: int) -> void:
	if amount <= 0:
		_server_reject_energy(peer_id, "add amount must be positive")
		return

	var old_energy := get_energy(peer_id)
	var new_energy := clampi(old_energy + amount, 0, max_energy)

	energy_by_peer_id[peer_id] = new_energy
	_broadcast_energy(peer_id, new_energy)


func _server_spend_energy(peer_id: int, amount: int, reject_peer_id := -1) -> bool:
	var rejection_peer_id := peer_id if reject_peer_id == -1 else reject_peer_id
	if amount <= 0:
		_server_reject_energy(rejection_peer_id, "spend amount must be positive")
		return false

	var old_energy := get_energy(peer_id)

	if old_energy < amount:
		_server_reject_energy(
			rejection_peer_id, "not enough energy: need %d, have %d" % [amount, old_energy]
		)
		return false

	var new_energy := old_energy - amount
	energy_by_peer_id[peer_id] = new_energy
	_broadcast_energy(peer_id, new_energy)

	# print(
	# 	(
	# 		"Energy spend peer=%d amount=%d old=%d new=%d"
	# 		% [peer_id, amount, old_energy, new_energy]
	# 	)
	# )

	return true


func _server_change_health(peer_id: int, delta: int, reject_peer_id := -1) -> bool:
	var rejection_peer_id := peer_id if reject_peer_id == -1 else reject_peer_id
	if delta == 0:
		_server_reject_health(rejection_peer_id, "health delta must be non-zero")
		return false
	if not health_by_peer_id.has(peer_id):
		_server_reject_health(rejection_peer_id, "unknown peer: %d" % peer_id)
		return false

	var old_health := get_health(peer_id)
	var new_health := clampi(old_health + delta, 0, max_health)

	health_by_peer_id[peer_id] = new_health
	_broadcast_health(peer_id, new_health)

	var player_peer_ids: Array
	for peer_id0 in connected_peer_ids:
		if peer_id0 != demo_peer_id:
			player_peer_ids.append(peer_id0)

	if new_health <= 0 and not game_finished:
		game_finished = true
		if len(player_peer_ids) == 0:
			return false
		elif len(player_peer_ids) == 1:
			_broadcast_multiplayer_finish(player_peer_ids, false, true)
		elif len(player_peer_ids) == 2:
			_broadcast_multiplayer_result(player_peer_ids)

	# print(
	# 	(
	# 		"Health change peer=%d delta=%d old=%d new=%d"
	# 		% [peer_id, delta, old_health, new_health]
	# 	)
	# )

	return true


func _server_set_energy_ball_count_for_peer(peer_id: int, count: int) -> void:
	var normalized_count: int = maxi(count, 0)
	if get_energy_ball_count(peer_id) == normalized_count:
		return

	# Keep the latest count in the same peer-keyed cache style as energy and health.
	energy_ball_count_by_peer_id[peer_id] = normalized_count
	_broadcast_energy_ball_count(peer_id, normalized_count)


func _server_register_time_up_finish(peer_id: int) -> void:
	if game_finished:
		return
	if peer_id == demo_peer_id or not connected_peer_ids.has(peer_id):
		return
	if not _time_up_peer_ids.has(peer_id):
		_time_up_peer_ids.append(peer_id)

	var player_peer_ids: Array = []
	for player_peer_id in connected_peer_ids:
		if player_peer_id != demo_peer_id:
			player_peer_ids.append(player_peer_id)

	if player_peer_ids.size() < 2:
		return
	for player_peer_id in player_peer_ids:
		if not _time_up_peer_ids.has(player_peer_id):
			return

	game_finished = true
	_broadcast_multiplayer_result(player_peer_ids)


func _broadcast_multiplayer_result(player_peer_ids: Array) -> void:
	var health0 = get_health(player_peer_ids[0])
	var health1 = get_health(player_peer_ids[1])
	var ball0 = get_energy_ball_count(player_peer_ids[0])
	var ball1 = get_energy_ball_count(player_peer_ids[1])
	if health0 <= 0 and health1 <= 0:
		_broadcast_multiplayer_finish(player_peer_ids, true, false)
	elif health0 != health1:
		var winner_id = player_peer_ids[0 if health0 > health1 else 1]
		_broadcast_multiplayer_finish([winner_id], false, false)
	elif ball0 != ball1:
		var winner_id = player_peer_ids[0 if ball0 > ball1 else 1]
		_broadcast_multiplayer_finish([winner_id], false, false)
	else:
		_broadcast_multiplayer_finish(player_peer_ids, true, false)


func _broadcast_multiplayer_finish(winner_peer_ids: Array, draw: bool, forfeit: bool) -> void:
	multiplayer_finish.emit(winner_peer_ids, draw, forfeit)
	rpc("_client_multiplayer_finish", winner_peer_ids, draw, forfeit)


@rpc("authority", "call_remote", "reliable")
func _client_multiplayer_finish(winner_peer_ids: Array, draw: bool, forfeit: bool) -> void:
	game_finished = true
	multiplayer_finish.emit(winner_peer_ids, draw, forfeit)


func _broadcast_energy(peer_id: int, energy: int) -> void:
	energy_changed.emit(peer_id, energy)
	rpc("_client_set_energy", peer_id, energy)


func _broadcast_health(peer_id: int, health: int) -> void:
	health_changed.emit(peer_id, health)
	rpc("_client_set_health", peer_id, health)


func _broadcast_energy_ball_count(peer_id: int, count: int) -> void:
	energy_ball_count_changed.emit(peer_id, count)
	rpc("_client_set_energy_ball_count", peer_id, count)


@rpc("authority", "call_remote", "reliable")
func _client_set_energy(peer_id: int, energy: int) -> void:
	energy_by_peer_id[peer_id] = energy
	energy_changed.emit(peer_id, energy)


@rpc("authority", "call_remote", "reliable")
func _client_set_health(peer_id: int, health: int) -> void:
	health_by_peer_id[peer_id] = health
	health_changed.emit(peer_id, health)


@rpc("authority", "call_remote", "reliable")
func _client_set_energy_ball_count(peer_id: int, count: int) -> void:
	energy_ball_count_by_peer_id[peer_id] = count
	energy_ball_count_changed.emit(peer_id, count)


## Public APIs should still work in single-player; offline mode is treated as local authority.
func _can_process_local_network_request() -> bool:
	if _is_offline_mode():
		return true

	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _is_offline_mode() -> bool:
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## Lazily initializes the offline/server local peer so single-player calls use the same caches.
func _ensure_local_peer_state() -> void:
	var peer_id := multiplayer.get_unique_id()
	if not energy_by_peer_id.has(peer_id):
		energy_by_peer_id[peer_id] = 0
	if not health_by_peer_id.has(peer_id):
		health_by_peer_id[peer_id] = max_health
	if not energy_ball_count_by_peer_id.has(peer_id):
		energy_ball_count_by_peer_id[peer_id] = 0


## Public: store a state snapshot for [param peer_id].
## Only stores state for peers that are currently in [member connected_peer_ids].
func _store_client_state(peer_id: int, state: Dictionary) -> void:
	if not connected_peer_ids.has(peer_id):
		return
	_client_states[peer_id] = state


## RPC: receive a state snapshot from a game client.
## Guards: server-only, ignores demo, validates sender is a connected peer.
@rpc("any_peer", "unreliable_ordered")
func _server_receive_state(state: Dictionary) -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id == demo_peer_id:
		return

	_store_client_state(sender_id, state)
	_update_server_max_energy_from_state(state)
	_server_receive_count += 1
	if _server_receive_count % 30 == 1:
		print(
			(
				"[Server] received state #%d from peer %d | tick=%d | traps=%d"
				% [
					_server_receive_count,
					sender_id,
					state.get("tick", 0),
					state.get("traps", []).size(),
				]
			)
		)


func _update_server_max_energy_from_state(state: Dictionary) -> void:
	if not state.has("max_energy_cap"):
		return

	var reported_cap := int(state.get("max_energy_cap"))
	var capped_cap := _clamp_reported_max_energy_cap(reported_cap)
	if capped_cap <= max_energy:
		return

	max_energy = capped_cap


func _clamp_reported_max_energy_cap(reported_cap: int) -> int:
	var energy_caps: Array = _read_game_max_energy_caps()
	if energy_caps.is_empty():
		return DEFAULT_MAX_ENERGY

	var floor_cap: int = int(energy_caps[0])
	var ceil_cap: int = int(energy_caps[energy_caps.size() - 1])
	return clampi(reported_cap, floor_cap, ceil_cap)


func _load_game_data() -> void:
	_game_data = GameData.new().data
	_refresh_game_max_energy_caps()


## Public: attempt to register [param peer_id] as the demo spectator.
## Returns true on success. Rejects if a demo is already connected.
func _register_demo(peer_id: int) -> bool:
	if demo_peer_id != -1:
		return false

	demo_peer_id = peer_id
	demo_connected.emit(peer_id)
	print("[Demo] Demo registered as peer %d" % peer_id)
	return true


## Public: unregister the current demo spectator. Safe to call when no demo.
func _unregister_demo() -> void:
	if demo_peer_id == -1:
		return

	var old_peer := demo_peer_id
	demo_peer_id = -1
	_client_states.clear()
	demo_disconnected.emit()
	print("[Demo] Demo disconnected (was peer %d)" % old_peer)


## RPC: a peer identifies itself as the demo spectator.
## Guarded: server-only. Rejects via disconnect if a demo is already registered.
@rpc("any_peer", "reliable")
func _server_identify_as_demo() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not _register_demo(sender_id):
		print("[Demo] Rejected duplicate demo from peer %d" % sender_id)
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)


## Public: build the combined state dictionary for the demo.
## Iterates all stored client states and packages them with a server tick.
func _build_demo_state() -> Dictionary:
	var screens: Array[Dictionary] = []
	for peer_id in _client_states:
		screens.append(_client_states[peer_id])

	return {
		"tick": Engine.get_physics_frames(),
		"screens": screens,
	}


## Public: push the current combined client state to the demo peer.
## No-op when no demo is connected.
func _push_state_to_demo() -> void:
	if demo_peer_id == -1:
		return

	var combined := _build_demo_state()
	rpc_id(demo_peer_id, "_demo_receive_state", combined)
	_demo_push_count += 1
	if _demo_push_count % 30 == 1:
		print(
			(
				"[Server] pushed demo state #%d to peer %d | screens=%d"
				% [
					_demo_push_count,
					demo_peer_id,
					combined.get("screens", []).size(),
				]
			)
		)


## RPC stub: receiver on the demo side. Emits signal for DemoRenderer.
@rpc("authority", "unreliable_ordered")
func _demo_receive_state(combined: Dictionary) -> void:
	demo_state_received.emit(combined)
	_demo_push_count += 1
	if _demo_push_count % 30 == 1:
		var screens: Array = combined.get("screens", [])
		var trap_count := 0
		if screens.size() > 0:
			trap_count = screens[0].get("traps", []).size()
		print(
			(
				"[Demo] received combined state #%d | screens=%d | traps=%d"
				% [_demo_push_count, screens.size(), trap_count]
			)
		)
