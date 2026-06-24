extends SceneTree

const NetworkManagerScript = preload("res://Scripts/network_manager.gd")


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var network_manager = NetworkManagerScript.new()
	root.add_child(network_manager)

	_assert(network_manager.can_accept_more_clients(0), "server should accept first client")
	_assert(network_manager.can_accept_more_clients(1), "server should accept second client")
	_assert(network_manager.can_accept_more_clients(2), "server should accept third client")
	_assert(not network_manager.can_accept_more_clients(3), "server should reject fourth client")

	_assert_eq(
		network_manager.get_startup_mode(["--server"]),
		"server",
		"--server should start server mode"
	)
	_assert_eq(
		network_manager.get_startup_mode(["--connect", "127.0.0.1"]),
		"client",
		"--connect should start client mode"
	)
	_assert_eq(network_manager.get_server_address(["--connect", "127.0.0.1"]), "127.0.0.1")
	_assert_eq(network_manager.get_server_address(["--connect=192.168.1.10"]), "192.168.1.10")
	_assert_eq(network_manager.get_server_port(["--port", "8888"]), 8888)
	_assert_eq(network_manager.get_server_port(["--port=9999"]), 9999)

	var peer_id: int = network_manager.multiplayer.get_unique_id()
	var rejected_reasons: Array[String] = []
	network_manager.energy_rejected.connect(
		func(_rejected_peer_id: int, reason: String) -> void: rejected_reasons.append(reason)
	)

	network_manager.request_add_energy(10, "test_ball")
	_assert_eq(network_manager.get_energy(peer_id), 10, "energy should increase")
	network_manager.request_add_energy(200, "test_cap")
	_assert_eq(network_manager.get_energy(peer_id), 100, "energy should be capped")
	_assert(network_manager._server_spend_energy(peer_id, 30, "test_trap"), "spend should pass")
	_assert_eq(network_manager.get_energy(peer_id), 70, "energy should decrease")
	_assert(
		not network_manager._server_spend_energy(peer_id, 80, "test_rejection"),
		"overspending should fail"
	)
	_assert_eq(network_manager.get_energy(peer_id), 70, "rejected spend should preserve energy")
	_assert_eq(rejected_reasons.size(), 1, "rejected spend should emit once")

	print("NetworkManager tests passed")
	network_manager.queue_free()
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return

	push_error(message)
	quit(1)


func _assert_eq(actual, expected, message := "") -> void:
	if actual == expected:
		return

	push_error("%s expected <%s>, got <%s>" % [message, expected, actual])
	quit(1)
