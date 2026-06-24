extends SceneTree

const TEST_TIMEOUT_SECONDS := 8.0
const TEST_STATE := {
	"position": Vector2(12, 34),
	"velocity": Vector2(5, 0),
	"health": 87,
	"energy": 42,
	"energy_balls": 3,
}

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
	if role not in ["server", "player", "spectator"]:
		_fail("missing or invalid --test-role")
		return

	network_manager.broadcast_state_changed.connect(_on_broadcast_state_changed)
	network_manager.connection_succeeded.connect(_on_connection_succeeded)

	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = TEST_TIMEOUT_SECONDS
	timeout.timeout.connect(func() -> void: _fail("timed out as %s" % role))
	root.add_child(timeout)
	timeout.start()

	if role == "player" and _is_connected():
		_on_connection_succeeded()


func _on_connection_succeeded() -> void:
	if role == "player":
		_send_state_until_finished.call_deferred()
		_finish_after_broadcast.call_deferred(4.0)


func _send_state_until_finished() -> void:
	var deadline_msec := Time.get_ticks_msec() + int(TEST_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline_msec:
		network_manager.request_update_broadcast_state(TEST_STATE)
		await create_timer(1.0 / 30.0).timeout


func _on_broadcast_state_changed(_peer_id: int, state: Dictionary) -> void:
	if not _state_matches_test(state):
		return

	if role == "spectator":
		_pass()
	elif role == "server":
		_finish_after_broadcast.call_deferred(2.0)


func _finish_after_broadcast(delay: float) -> void:
	await create_timer(delay).timeout
	_pass()


func _is_connected() -> bool:
	var peer: MultiplayerPeer = network_manager.multiplayer.multiplayer_peer
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _state_matches_test(state: Dictionary) -> bool:
	return (
		state.get("position") == TEST_STATE["position"]
		and state.get("velocity") == TEST_STATE["velocity"]
		and int(state.get("health", 0)) == TEST_STATE["health"]
		and int(state.get("energy", 0)) == TEST_STATE["energy"]
		and int(state.get("energy_balls", 0)) == TEST_STATE["energy_balls"]
	)


func _pass() -> void:
	if finished:
		return
	finished = true
	print("Network broadcast integration test passed: %s" % role)
	quit(0)


func _fail(message: String) -> void:
	if finished:
		return
	finished = true
	push_error("Network broadcast integration test failed: %s" % message)
	quit(1)


func _find_arg_value(args: Array, name: String) -> String:
	for index in args.size():
		var argument := str(args[index])
		if argument == name and index + 1 < args.size():
			return str(args[index + 1])
		if argument.begins_with("%s=" % name):
			return argument.substr(name.length() + 1)
	return ""
