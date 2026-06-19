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

const DEFAULT_PORT := 7777
const DEFAULT_SERVER_ADDRESS := "127.0.0.1"
const MAX_CLIENTS := 2

var connected_peer_ids: Array[int] = []


## Called on startup. Connects multiplayer signals and handles command-line launch.
func _ready() -> void:
	_connect_multiplayer_signals()
	_start_from_command_line(OS.get_cmdline_user_args())


## Creates an ENet server on [param port] and hands it to the multiplayer system.
## Emits [signal server_started] on success, [signal server_start_failed] on error.
func start_server(port := DEFAULT_PORT) -> Error:
	stop_network()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error != OK:
		server_start_failed.emit(error)
		return error

	multiplayer.multiplayer_peer = peer
	connected_peer_ids.clear()
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


## Closes the current connection and resets the multiplayer peer to offline mode.
func stop_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected_peer_ids.clear()


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


## Parses command-line [param args] and starts the appropriate network mode automatically.
func _start_from_command_line(args: Array) -> void:
	var mode := get_startup_mode(args)
	var port := get_server_port(args)

	if mode == "server":
		start_server(port)
	elif mode == "client":
		join_server(get_server_address(args), port)


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

	player_connected.emit(peer_id)
	print("Peer connected: %d (%d/%d)" % [peer_id, connected_peer_ids.size(), MAX_CLIENTS])


## Removes a disconnected peer from the tracked list and emits [signal player_disconnected].
func _on_peer_disconnected(peer_id: int) -> void:
	connected_peer_ids.erase(peer_id)
	player_disconnected.emit(peer_id)
	print("Peer disconnected: %d" % peer_id)


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


## Searches [param args] for a named argument and returns its value.
## Supports both [code]--key value[/code] and [code]--key=value[/code] formats.
func _find_arg_value(args: Array, name: String) -> String:
	for i in args.size():
		var arg := str(args[i])
		if arg == name and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with("%s=" % name):
			return arg.substr(name.length() + 1)

	return ""
