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

	# Connect our test callback
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

	# Cleanup
	nm.queue_free()
	print("NetworkManager demo signal tests passed")
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
