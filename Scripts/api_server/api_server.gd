class_name APIServer
extends Node

enum { CONNECT_FAILED, CONNECT_PENDING, CONNECT_OK }

@export var handshake_timeout_msec: int = 3000
@export var port: int = 7749
var tcp_server: TCPServer = TCPServer.new()
var pending_peers: Array[PendingPeer] = []
var authing_peers: Array[WebSocketPeer] = []
var used_token: Dictionary[String, WebSocketConnection] = {}

#region Initialization


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for _attempt in 50:
		if listen() == OK:
			break
		port = randi_range(20000, 60000)
	assert(tcp_server.is_listening())
	print("[API Server] Listening to port: ", port)


static func cmdline_value(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var arg := str(args[i])
		if arg == name and i + 1 < args.size():
			return str(args[i + 1])
		if arg.begins_with("%s=" % name):
			return arg.substr(name.length() + 1)
	return ""


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


func unregister_connection(token: String) -> void:
	# GameAgent owns the token lifecycle; remove it when the agent node exits.
	if used_token.has(token):
		used_token.erase(token)


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
					ws.send_text("Connection OK.")
					return conn
				ws.send_text("Already connected.")
				return null
	ws.send_text("Authentication failed.")
	return null


#endregion


#region Response envelope helpers
# Builders so command handlers stay one-liners; the agent fills in "id".
# These live here (platform side) because the envelope shape is game-agnostic.
static func ok(data: Variant = null) -> Dictionary:
	return {"status": "ok", "data": data}


static func err(code: int, reason: String = "") -> Dictionary:
	return {"status": "error", "code": code, "reason": reason}
#endregion
