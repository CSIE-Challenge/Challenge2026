extends SceneTree

const NetworkManagerScript = preload("res://Scripts/network/network_manager.gd")


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var nm := NetworkManagerScript.new()
	root.add_child(nm)

	# ── _store_client_state ──────────────────────────────────────

	# TEST 1: stores state from a connected peer
	nm.connected_peer_ids.append(2)
	var state_a := {"peer_id": 2, "tick": 1, "player": {"health": 100}}
	nm._store_client_state(2, state_a)
	_assert_eq(nm._client_states[2], state_a, "should store state for connected peer")

	# TEST 2: replaces old state for the same peer
	var state_b := {"peer_id": 2, "tick": 2, "player": {"health": 90}}
	nm._store_client_state(2, state_b)
	_assert_eq(nm._client_states[2], state_b, "should replace old state for same peer")

	# TEST 3: ignores state from unknown peer (not in connected_peer_ids)
	nm._store_client_state(99, {"peer_id": 99, "tick": 1})
	_assert(not nm._client_states.has(99), "should ignore state from unknown peer")

	# TEST 4: can store state from multiple peers
	nm.connected_peer_ids.append(3)
	var state_c := {"peer_id": 3, "tick": 5}
	nm._store_client_state(3, state_c)
	_assert_eq(nm._client_states[3], state_c, "should store state for second peer")
	_assert_eq(nm._client_states.size(), 2, "should have states from two peers")

	# ── _register_demo / _unregister_demo ────────────────────────

	# TEST 5: registering a demo sets demo_peer_id and emits signal
	var demo_events: Array[String] = []
	nm.demo_connected.connect(func(pid: int) -> void: demo_events.append("connected %d" % pid))
	var ok: bool = nm._register_demo(4)
	_assert(ok, "should accept first demo")
	_assert_eq(nm.demo_peer_id, 4, "demo_peer_id should be set")
	_assert_eq(demo_events.size(), 1, "should emit demo_connected once")

	# TEST 6: registering a second demo is rejected
	var ok2: bool = nm._register_demo(5)
	_assert(not ok2, "should reject second demo")
	_assert_eq(nm.demo_peer_id, 4, "demo_peer_id should remain unchanged")

	# TEST 7: unregistering the demo resets and emits signal
	nm.demo_disconnected.connect(func() -> void: demo_events.append("disconnected"))
	nm._unregister_demo()
	_assert_eq(nm.demo_peer_id, -1, "demo_peer_id should reset to -1")
	_assert_eq(demo_events.size(), 2, "should emit demo_disconnected")

	# TEST 8: unregistering when no demo is connected is a no-op
	nm._unregister_demo()  # should not crash
	_assert_eq(demo_events.size(), 2, "should not emit duplicate disconnect")

	# ── disconnect cleanup ────────────────────────────────────────

	# TEST 9: demo peer disconnect clears _client_states
	nm._client_states[2] = {"tick": 10}
	nm._client_states[3] = {"tick": 10}
	nm.demo_peer_id = 4
	nm._on_peer_disconnected(4)
	_assert_eq(nm.demo_peer_id, -1, "demo disconnect should reset demo_peer_id")
	_assert_eq(nm._client_states.size(), 0, "demo disconnect should clear client states")

	# ── _build_demo_state ─────────────────────────────────────────

	# TEST 10: returns empty screens when no client states
	var empty_state: Dictionary = nm._build_demo_state()
	_assert(empty_state.has("tick"), "should have tick key")
	_assert_eq((empty_state["screens"] as Array).size(), 0, "should have zero screens")

	# TEST 11: includes states from connected peers
	nm._client_states[2] = {"peer_id": 2, "tick": 42, "player": {"health": 80}}
	nm._client_states[3] = {"peer_id": 3, "tick": 42, "player": {"health": 60}}
	var combined: Dictionary = nm._build_demo_state()
	var screens: Array = combined["screens"]
	_assert_eq(screens.size(), 2, "should have two screens")
	# Order is not guaranteed (Dictionary iteration), so check by content
	var peer_ids: Array[int] = []
	for screen in screens:
		peer_ids.append(screen["peer_id"])
	_assert(peer_ids.has(2), "should contain peer 2 state")
	_assert(peer_ids.has(3), "should contain peer 3 state")

	print("State sync tests passed")
	nm.queue_free()
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
