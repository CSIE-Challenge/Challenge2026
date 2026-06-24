extends SceneTree

const NetworkManagerScript = preload("res://Scripts/network_manager.gd")


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
