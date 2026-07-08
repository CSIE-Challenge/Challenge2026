extends SceneTree

const TEST_TIMEOUT_SECONDS := 10.0

var network_manager: Node
var role := ""
var finished := false


func _init() -> void:
	_start_test.call_deferred()


func _start_test() -> void:
	var api_server := root.get_node_or_null("ApiServer")
	if api_server != null and api_server.tcp_server.is_listening():
		api_server.tcp_server.stop()

	network_manager = root.get_node("NetworkManager")
	role = _find_arg_value(OS.get_cmdline_user_args(), "--test-role")
	if role not in ["server", "client_a", "client_b"]:
		_fail("missing or invalid --test-role")
		return

	network_manager.connection_succeeded.connect(_on_connection_succeeded)
	network_manager.multiplayer_match_started.connect(_on_match_started)

	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = TEST_TIMEOUT_SECONDS
	timeout.timeout.connect(func() -> void: _fail("timed out as %s" % role))
	root.add_child(timeout)
	timeout.start()

	if role != "server" and _is_connected():
		_on_connection_succeeded()


func _on_connection_succeeded() -> void:
	if role == "server":
		return

	network_manager.request_multiplayer_ready()


func _on_match_started() -> void:
	_pass()


func _is_connected() -> bool:
	var peer: MultiplayerPeer = network_manager.multiplayer.multiplayer_peer
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _pass() -> void:
	if finished:
		return
	finished = true
	print("Network ready integration test passed: %s" % role)
	quit(0)


func _fail(message: String) -> void:
	if finished:
		return
	finished = true
	push_error("Network ready integration test failed: %s" % message)
	quit(1)


func _find_arg_value(args: Array, name: String) -> String:
	for index in args.size():
		var argument := str(args[index])
		if argument == name and index + 1 < args.size():
			return str(args[index + 1])
		if argument.begins_with("%s=" % name):
			return argument.substr(name.length() + 1)
	return ""
