class_name APIServer
extends Node

enum { CONNECT_FAILED, CONNECT_PENDING, CONNECT_OK }

@export var handshake_timeout_msec: int = 3000
@export var port: int = 7749
var tcp_server: TCPServer = TCPServer.new()
var pending_peers: Array[PendingPeer] = []
var authing_peers: Array[WebSocketPeer] = []
var used_token: Dictionary[String, WebSocketConnection] = {}

var _command_handlers: Dictionary[String, Callable] = {}

#region Initialization


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var server_listen_ret = listen()
	assert(server_listen_ret == OK)
	print("[API Server] Listening to port: ", port)

	# A connectivity health-check.
	register_command("ping", _cmd_ping)

	var conn := register_connection()
	add_child(conn)
	conn.received_text.connect(_on_received_text.bind(conn))
	print("[API Server] token: ", conn.get_token())


func _cmd_ping(_args: Dictionary) -> Dictionary:
	return ok("pong")


#endregion


class PendingPeer:
	var connect_time: int
	var tcp: StreamPeerTCP
	var connection: StreamPeer
	var ws: WebSocketPeer

	func _init(p_tcp: StreamPeerTCP) -> void:
		connect_time = Time.get_ticks_msec()
		tcp = p_tcp
		connection = p_tcp
		ws = null


#region Websocket
func listen() -> int:
	assert(not tcp_server.is_listening())
	return tcp_server.listen(port)


func _poll() -> void:
	if not tcp_server.is_listening():
		return

	while tcp_server.is_connection_available():
		var conn: StreamPeerTCP = tcp_server.take_connection()
		assert(conn != null)
		pending_peers.append(PendingPeer.new(conn))

	var to_remove: Array = []
	for p: PendingPeer in pending_peers:
		var status: int = _connect_pending(p)
		if status == CONNECT_OK:
			# websocket opened, wait for authentication
			to_remove.append(p)
			authing_peers.append(p.ws)
		elif (
			status == CONNECT_FAILED
			or p.connect_time + handshake_timeout_msec < Time.get_ticks_msec()
		):
			# websocket closed or timed out, drop connection
			to_remove.append(p)
	for p: PendingPeer in to_remove:
		pending_peers.erase(p)

	to_remove.clear()
	for ws: WebSocketPeer in authing_peers:
		ws.poll()
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			to_remove.append(ws)
			continue
		var conn = auth_connection(ws)
		if conn != null:
			conn.connect_to_socket(ws)
			to_remove.append(ws)
	for ws: WebSocketPeer in to_remove:
		authing_peers.erase(ws)


func _connect_pending(peer: PendingPeer) -> int:
	if peer.ws != null:
		# websocket created, waiting for handshake
		peer.ws.poll()
		var state: int = peer.ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			return CONNECT_OK
		if state == WebSocketPeer.STATE_CONNECTING:
			return CONNECT_PENDING
		return CONNECT_FAILED

	if peer.tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		# TCP disconnected
		return CONNECT_FAILED

	# websocket peer not created yet
	peer.ws = WebSocketPeer.new()
	peer.ws.accept_stream(peer.tcp)
	return CONNECT_PENDING


func _process(_delta: float) -> void:
	_poll()


#endregion


#region Interface for registering authorized connections
func generate_token() -> String:
	var token: String
	while true:
		token = "%08x" % randi()
		if not used_token.has(token):
			break
	return token


func register_connection() -> WebSocketConnection:
	var token = generate_token()
	var conn = WebSocketConnection.new(token)
	used_token[token] = conn
	return conn


func auth_connection(ws: WebSocketPeer) -> WebSocketConnection:
	if ws.get_available_packet_count() <= 0:
		return null
	var pkt: PackedByteArray = ws.get_packet()
	if ws.was_string_packet():
		var token = pkt.get_string_from_utf8()
		if used_token.has(token):
			var conn = used_token[token]
			if is_instance_valid(conn):
				if not conn.is_client_connected():
					ws.send_text("Connection OK. ")
					return conn
				ws.send_text("Already connected.")
				return null
	ws.send_text("Authentication failed.")
	return null


#endregion


#region Command registry + dispatch
# Response builders so handlers stay one-liners. The server fills in "id".
static func ok(data: Variant = null) -> Dictionary:
	return {"status": "ok", "data": data}


static func err(code: int) -> Dictionary:
	return {"status": "error", "code": code}


# Called by game_manager.gd to plug in a command.
func register_command(name: String, handler: Callable) -> void:
	_command_handlers[name] = handler


func unregister_owner(owner: Object) -> void:
	for name: String in _command_handlers.keys():
		if _command_handlers[name].get_object() == owner:
			_command_handlers.erase(name)


func _on_received_text(msg: String, conn: WebSocketConnection) -> void:
	# Deserialize, then look the command up in the registry and call it.
	var data: Variant = JSON.parse_string(msg)
	if typeof(data) != TYPE_DICTIONARY:
		conn.send_text(JSON.stringify(err(400)))
		return

	var req_id: Variant = data.get("id")
	var cmd: String = data.get("cmd", "")
	var args: Variant = data.get("args", {})
	if typeof(args) != TYPE_DICTIONARY:
		args = {}

	# is_valid() also covers a handler whose owning node was freed (scene change).
	var handler: Callable = _command_handlers.get(cmd, Callable())
	var response: Dictionary = handler.call(args) if handler.is_valid() else err(404)
	response["id"] = req_id
	conn.send_text(JSON.stringify(response))
#endregion
