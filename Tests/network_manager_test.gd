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
	var rejected_health_reasons: Array[String] = []
	network_manager.energy_rejected.connect(
		func(_rejected_peer_id: int, reason: String) -> void: rejected_reasons.append(reason)
	)
	network_manager.health_rejected.connect(
		func(_rejected_peer_id: int, reason: String) -> void: rejected_health_reasons.append(reason)
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

	network_manager.energy_by_peer_id[42] = 50
	network_manager.request_spend_peer_energy(42, 15, "test_enemy_spend")
	_assert_eq(network_manager.get_energy(42), 35, "peer energy spend should affect target peer")

	_assert_eq(network_manager.get_health(peer_id), 100, "default health should be max health")
	network_manager.request_damage_health(25, "test_damage")
	_assert_eq(network_manager.get_health(peer_id), 75, "damage should lower local health")
	network_manager.request_heal_health(10, "test_heal")
	_assert_eq(network_manager.get_health(peer_id), 85, "heal should raise local health")
	network_manager.request_change_peer_health(peer_id, 1000, "test_health_cap")
	_assert_eq(network_manager.get_health(peer_id), 100, "health should be capped")
	network_manager.request_change_peer_health(999, -1, "test_unknown_peer")
	_assert_eq(rejected_health_reasons.size(), 1, "unknown health peer should reject once")

	_assert_eq(
		network_manager.get_opponent_peer_id(),
		peer_id,
		"offline opponent should fall back to local peer"
	)
	var energy_before_offline_opponent := network_manager.get_energy(peer_id)
	network_manager.request_add_energy(20, "test_offline_opponent_seed")
	network_manager.request_spend_opponent_energy(5, "test_offline_opponent_spend")
	_assert_eq(
		network_manager.get_energy(peer_id),
		min(energy_before_offline_opponent + 20, network_manager.MAX_ENERGY) - 5,
		"offline opponent spend should affect self"
	)
	network_manager.request_damage_opponent_health(5, "test_offline_opponent_damage")
	_assert_eq(
		network_manager.get_health(peer_id), 95, "offline opponent damage should affect self"
	)
	network_manager.request_heal_opponent_health(3, "test_offline_opponent_heal")
	_assert_eq(network_manager.get_health(peer_id), 98, "offline opponent heal should affect self")

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
