extends SceneTree

const TEST_ENERGY := 10
const TEST_SPEND := 4
const EXPECTED_ENERGY_AFTER_SPEND := TEST_ENERGY - TEST_SPEND
const TEST_TIMEOUT_SECONDS := 8.0

var network_manager: Node
var role := ""
var observed_added_energy := false


func _init() -> void:
	_start_test.call_deferred()


func _start_test() -> void:
	var api_server := root.get_node_or_null("ApiServer")
	if api_server != null and api_server.tcp_server.is_listening():
		api_server.tcp_server.stop()

	network_manager = root.get_node("NetworkManager")
	role = _find_arg_value(OS.get_cmdline_user_args(), "--test-role")
	if role not in ["server", "add", "observe"]:
		_fail("missing or invalid --test-role")
		return

	network_manager.energy_changed.connect(_on_energy_changed)
	network_manager.connection_succeeded.connect(_on_connection_succeeded)

	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = TEST_TIMEOUT_SECONDS
	timeout.timeout.connect(func() -> void: _fail("timed out as %s" % role))
	root.add_child(timeout)
	timeout.start()

	if role == "add" and _is_connected():
		_on_connection_succeeded()


func _on_connection_succeeded() -> void:
	if role == "add":
		network_manager.request_add_energy(TEST_ENERGY, "integration_test")


func _is_connected() -> bool:
	var peer: MultiplayerPeer = network_manager.multiplayer.multiplayer_peer
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _on_energy_changed(peer_id: int, energy: int) -> void:
	var local_peer_id: int = network_manager.multiplayer.get_unique_id()
	if role == "add" and peer_id == local_peer_id and energy == TEST_ENERGY:
		_spend_after_observer_connects.call_deferred()
	elif role == "add" and peer_id == local_peer_id and energy == EXPECTED_ENERGY_AFTER_SPEND:
		_finish_after_broadcast.call_deferred(2.0)
	elif role == "observe" and peer_id != local_peer_id and energy == TEST_ENERGY:
		observed_added_energy = true
	elif (
		role == "observe"
		and peer_id != local_peer_id
		and energy == EXPECTED_ENERGY_AFTER_SPEND
		and observed_added_energy
	):
		_pass()
	elif role == "server" and energy == EXPECTED_ENERGY_AFTER_SPEND:
		_finish_after_broadcast.call_deferred(3.0)


func _spend_after_observer_connects() -> void:
	await create_timer(1.0).timeout
	network_manager.request_spend_energy(TEST_SPEND, "integration_test")


func _finish_after_broadcast(delay: float) -> void:
	await create_timer(delay).timeout
	_pass()


func _pass() -> void:
	print("Network energy integration test passed: %s" % role)
	quit(0)


func _fail(message: String) -> void:
	push_error("Network energy integration test failed: %s" % message)
	quit(1)


func _find_arg_value(args: Array, name: String) -> String:
	for index in args.size():
		var argument := str(args[index])
		if argument == name and index + 1 < args.size():
			return str(args[index + 1])
		if argument.begins_with("%s=" % name):
			return argument.substr(name.length() + 1)
	return ""
