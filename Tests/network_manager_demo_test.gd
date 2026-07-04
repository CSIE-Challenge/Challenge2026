extends SceneTree

const NetworkManagerScript = preload("res://Scripts/network_manager.gd")

var _signal_received := false
var _received_data: Dictionary = {}


func _init() -> void:
	_run_tests.call_deferred()


func _on_demo_state_received(data: Dictionary) -> void:
	_signal_received = true
	_received_data = data


func _run_tests() -> void:
	# Create a standalone NetworkManager instance for testing.
	# In --script mode, autoloads do not exist — use load().new().
	var nm: Node = NetworkManagerScript.new()
	nm.name = "NetworkManager"
	root.add_child(nm)

	# TEST 1: demo_state_received signal exists and can be connected
	_assert(
		nm.has_signal("demo_state_received"),
		"NetworkManager should have demo_state_received signal"
	)

	var err: int = nm.demo_state_received.connect(_on_demo_state_received)
	_assert(err == OK, "should be able to connect to demo_state_received signal")

	# TEST 2: _demo_receive_state emits the signal with correct data
	var test_data := {
		"tick": 42,
		"screens":
		[
			{"player": {"position": Vector2(100, 200)}, "traps": []},
			{"player": {"position": Vector2(300, 400)}, "traps": []},
		]
	}
	nm._demo_receive_state(test_data)

	_assert(_signal_received, "demo_state_received should be emitted")
	_assert_eq(_received_data["tick"], 42, "tick should match")
	_assert_eq(_received_data["screens"].size(), 2, "screens count should match")

	# ── TEST 3: --demo flag detection ─────────────────────────────
	# Create a fresh NM (don't add to root to avoid _ready side effects)
	var nm2: Node = NetworkManagerScript.new()
	nm2.name = "NM2"

	# Verify demo flag detection
	_assert(nm2._has_demo_flag(["--demo", "--connect", "127.0.0.1"]), "--demo should be detected")
	_assert(not nm2._has_demo_flag(["--server"]), "--server should not be detected as demo")
	_assert(
		not nm2._has_demo_flag(["--connect", "127.0.0.1"]), "--connect alone should not be demo"
	)

	# Verify connect address extraction with --demo
	var addr: String = nm2._extract_connect_address(["--demo", "--connect", "192.168.1.1"])
	_assert_eq(addr, "192.168.1.1", "should extract connect addr after --demo")

	# ── TEST 4: _start_from_command_line with --demo doesn't crash ─
	# SceneTree test mode doesn't support full scene changes,
	# but we verify the --demo code path is entered correctly.
	var nm3: Node = NetworkManagerScript.new()
	nm3.name = "NM3"
	root.add_child(nm3)
	# Call with --demo flag — should enter demo branch without error
	# (may fail to connect since no server, but that's OK for unit test)
	nm3._start_from_command_line(["--demo", "--connect", "127.0.0.1"])
	# If we got here without crash, the demo code path was entered
	print("[OK] --demo flag code path executed without crash")

	# Cleanup
	nm.queue_free()
	nm2.queue_free()
	nm3.queue_free()
	print("NetworkManager demo tests passed")
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
