extends SceneTree

const TEST_ENERGY := 20
const TEST_SPEND := 5
const EXPECTED_ENERGY := TEST_ENERGY - TEST_SPEND
const TEST_DAMAGE := 7
const TEST_HEAL := 3
const EXPECTED_DAMAGED_HEALTH := NetworkManager.MAX_HEALTH - TEST_DAMAGE
const EXPECTED_HEALED_HEALTH := EXPECTED_DAMAGED_HEALTH + TEST_HEAL
const TEST_TIMEOUT_SECONDS := 10.0

var network_manager: Node
var role := ""
var target_peer_id := -1
var saw_spent_energy := false
var saw_damaged_health := false
var finished := false


func _init() -> void:
	_start_test.call_deferred()


func _start_test() -> void:
	var api_server := root.get_node_or_null("ApiServer")
	if api_server != null and api_server.tcp_server.is_listening():
		api_server.tcp_server.stop()

	network_manager = root.get_node("NetworkManager")
	role = _find_arg_value(OS.get_cmdline_user_args(), "--test-role")
	if role not in ["server", "target", "actor"]:
		_fail("missing or invalid --test-role")
		return

	network_manager.energy_changed.connect(_on_energy_changed)
	network_manager.health_changed.connect(_on_health_changed)
	network_manager.connection_succeeded.connect(_on_connection_succeeded)

	var timeout := Timer.new()
	timeout.one_shot = true
	timeout.wait_time = TEST_TIMEOUT_SECONDS
	timeout.timeout.connect(func() -> void: _fail("timed out as %s" % role))
	root.add_child(timeout)
	timeout.start()

	if role == "target" and _is_connected():
		_on_connection_succeeded()


func _on_connection_succeeded() -> void:
	if role == "target":
		network_manager.request_add_energy(TEST_ENERGY, "peer_control_test")


func _on_energy_changed(peer_id: int, energy: int) -> void:
	var local_peer_id: int = network_manager.multiplayer.get_unique_id()
	if role == "actor" and peer_id != local_peer_id and energy == TEST_ENERGY:
		target_peer_id = peer_id
		network_manager.request_spend_opponent_energy(TEST_SPEND, "peer_control_test")
	elif role == "actor" and peer_id == target_peer_id and energy == EXPECTED_ENERGY:
		saw_spent_energy = true
		network_manager.request_damage_opponent_health(TEST_DAMAGE, "peer_control_test")
	elif role == "target" and peer_id == local_peer_id and energy == EXPECTED_ENERGY:
		saw_spent_energy = true
	elif role == "server" and energy == EXPECTED_ENERGY:
		saw_spent_energy = true


func _on_health_changed(peer_id: int, health: int) -> void:
	var local_peer_id: int = network_manager.multiplayer.get_unique_id()
	if role == "actor" and peer_id == target_peer_id and health == EXPECTED_DAMAGED_HEALTH:
		saw_damaged_health = true
		network_manager.request_heal_opponent_health(TEST_HEAL, "peer_control_test")
	elif role == "actor" and peer_id == target_peer_id and health == EXPECTED_HEALED_HEALTH:
		_pass()
	elif role == "target" and peer_id == local_peer_id and health == EXPECTED_DAMAGED_HEALTH:
		saw_damaged_health = true
	elif (
		role == "target"
		and peer_id == local_peer_id
		and health == EXPECTED_HEALED_HEALTH
		and saw_spent_energy
		and saw_damaged_health
	):
		_pass()
	elif role == "server" and health == EXPECTED_HEALED_HEALTH and saw_spent_energy:
		_finish_after_broadcast.call_deferred(1.0)


func _finish_after_broadcast(delay: float) -> void:
	await create_timer(delay).timeout
	_pass()


func _is_connected() -> bool:
	var peer: MultiplayerPeer = network_manager.multiplayer.multiplayer_peer
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _pass() -> void:
	if finished:
		return
	finished = true
	print("Network peer-control integration test passed: %s" % role)
	quit(0)


func _fail(message: String) -> void:
	if finished:
		return
	finished = true
	push_error("Network peer-control integration test failed: %s" % message)
	quit(1)


func _find_arg_value(args: Array, name: String) -> String:
	for index in args.size():
		var argument := str(args[index])
		if argument == name and index + 1 < args.size():
			return str(args[index + 1])
		if argument.begins_with("%s=" % name):
			return argument.substr(name.length() + 1)
	return ""
