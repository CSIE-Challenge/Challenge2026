extends SceneTree

const NetworkManagerScript = preload("res://Scripts/network_manager.gd")


func _init() -> void:
	var network_manager = NetworkManagerScript.new()

	_assert(network_manager.can_accept_more_clients(0), "server should accept first client")
	_assert(network_manager.can_accept_more_clients(1), "server should accept second client")
	_assert(not network_manager.can_accept_more_clients(2), "server should reject third client")

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

	print("NetworkManager tests passed")
	network_manager.free()
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
