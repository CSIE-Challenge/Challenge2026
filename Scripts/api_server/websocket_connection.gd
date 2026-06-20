class_name WebSocketConnection
extends Node

signal received_text(msg: String)
signal client_connected
signal client_disconnected

var _socket: WebSocketPeer
var _token: String


func _init(token: String) -> void:
	_token = token
	_socket = null


func get_token() -> String:
	return _token


func connect_to_socket(socket: WebSocketPeer) -> void:
	_socket = socket
	client_connected.emit()


func disconnect_from_socket() -> void:
	if _socket != null:
		var state = _socket.get_ready_state()
		if state != WebSocketPeer.STATE_CLOSING and state != WebSocketPeer.STATE_CLOSED:
			_socket.close()
		if state == WebSocketPeer.STATE_CLOSED:
			_socket = null
			client_disconnected.emit()


func is_client_connected() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN


func send_text(msg: String) -> Error:
	if _socket == null:
		return ERR_UNAVAILABLE
	return _socket.send_text(msg)


func _has_message() -> bool:
	return _socket != null and _socket.get_available_packet_count() > 0


func _poll() -> void:
	if _socket == null:
		return
	_socket.poll()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		disconnect_from_socket()
		return
	while _has_message():
		var pkt: PackedByteArray = _socket.get_packet()
		if _socket.was_string_packet():
			received_text.emit(pkt.get_string_from_utf8())


func _process(_delta: float) -> void:
	_poll()
