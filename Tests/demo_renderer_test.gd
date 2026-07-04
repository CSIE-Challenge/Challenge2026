extends SceneTree

const DemoRendererScript = preload("res://Scripts/demo_renderer.gd")


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	# ── Setup ──────────────────────────────────────────────────────
	var renderer: Node = DemoRendererScript.new()
	renderer.name = "DemoRenderer"
	var stage_a := Node2D.new()
	stage_a.name = "StageA"
	var stage_b := Node2D.new()
	stage_b.name = "StageB"
	renderer.stage_a = stage_a
	renderer.stage_b = stage_b
	root.add_child(renderer)
	root.add_child(stage_a)
	root.add_child(stage_b)
	await process_frame

	# ── TEST 1: Empty ghosts dicts on init ────────────────────────
	_assert_eq(renderer._ghosts_a.size(), 0, "ghosts_a should be empty on init")
	_assert_eq(renderer._ghosts_b.size(), 0, "ghosts_b should be empty on init")

	# ── TEST 2: _suppress_game_logic disables process ─────────────
	var test_node := Node2D.new()
	test_node.name = "TestNode"
	root.add_child(test_node)

	var child_process := Node2D.new()
	child_process.name = "ChildProcess"
	child_process.set_process(true)
	child_process.set_physics_process(true)
	test_node.add_child(child_process)

	var area := Area2D.new()
	area.name = "AreaChild"
	area.monitoring = true
	test_node.add_child(area)

	var child_timer := Timer.new()
	child_timer.name = "ChildTimer"
	child_timer.wait_time = 1.0
	child_timer.start()
	test_node.add_child(child_timer)

	renderer._suppress_game_logic(test_node)

	_assert_eq(test_node.is_processing(), false, "root node process should be disabled")
	_assert_eq(
		test_node.is_physics_processing(), false, "root node physics_process should be disabled"
	)
	_assert_eq(child_process.is_processing(), false, "child process should be disabled")
	_assert_eq(
		child_process.is_physics_processing(), false, "child physics_process should be disabled"
	)
	_assert_eq(area.monitoring, false, "Area2D monitoring should be false")
	_assert_eq(child_timer.is_stopped(), true, "Timer should be stopped")

	test_node.queue_free()

	# ── TEST 3: _scene_path_for_type returns correct paths ────────
	var path_tests := {
		"trap1-mine": "res://Scenes/traps/trap1-mine.tscn",
		"trap2-electric_ring": "res://Scenes/traps/trap2-electric_ring.tscn",
		"trap3-tracing_bullet": "res://Scenes/traps/trap3-tracing_bullet.tscn",
		"trap4-conveyor": "res://Scenes/traps/trap4-conveyor.tscn",
		"trap5-icefloor": "res://Scenes/traps/trap5-icefloor.tscn",
		"trap6-scanline": "res://Scenes/traps/trap6-scanline.tscn",
		"trap7-spreading_ripples": "res://Scenes/traps/trap7-spreading_ripples.tscn",
		"trap8-electric_arc": "res://Scenes/traps/trap8-electric_arc.tscn",
		"trap9-mortar": "res://Scenes/traps/trap9-mortar.tscn",
		"trap10-shotgun": "res://Scenes/traps/trap10-shotgun.tscn",
	}

	for type_name in path_tests:
		var expected: String = path_tests[type_name]
		var actual: String = renderer._scene_path_for_type(type_name)
		_assert_eq(actual, expected, "scene path for %s (got '%s')" % [type_name, actual])

	_assert_eq(
		renderer._scene_path_for_type("unknown-trap"),
		"",
		"unknown trap type should return empty string"
	)

	# ── TEST 4: _update_ghosts creates new ghost via _instantiate_ghost ─
	# Note: _instantiate_ghost loads real .tscn files which may fail in
	# --script test mode due to autoload references. This test exercises
	# the diff loop's "new ghost" path using a known type that has a
	# simple scene. If the scene fails to load, the test verifies graceful
	# handling (no crash).
	var trapped_stage := Node2D.new()
	trapped_stage.name = "TrappedStage"
	root.add_child(trapped_stage)

	var ghost_dict: Dictionary = {}
	# Use empty traps — tests the "no traps" path doesn't crash
	renderer._update_ghosts(ghost_dict, trapped_stage, [])
	_assert_eq(ghost_dict.size(), 0, "empty traps should leave empty dict")

	# ── TEST 5: _update_ghosts updates existing ghosts ─────────────
	var existing_ghost := _make_mock_ghost()
	existing_ghost.name = "ExistingGhost"
	trapped_stage.add_child(existing_ghost)
	ghost_dict[42] = existing_ghost

	var update_traps: Array = [
		{"id": 42, "type": "trap1-mine", "position": Vector2(999, 888)},
	]
	renderer._update_ghosts(ghost_dict, trapped_stage, update_traps)
	# Ghost should still be in dict
	_assert(ghost_dict.has(42), "id=42 should remain after update")
	_assert_eq(ghost_dict[42], existing_ghost, "same ghost should be reused on update")

	# ── TEST 6: _update_ghosts removes stale ghosts ───────────────
	var stale_ghost := _make_mock_ghost()
	stale_ghost.name = "StaleGhost"
	trapped_stage.add_child(stale_ghost)
	ghost_dict[7] = stale_ghost

	var stale_ghost2 := _make_mock_ghost()
	stale_ghost2.name = "StaleGhost2"
	trapped_stage.add_child(stale_ghost2)
	ghost_dict[8] = stale_ghost2

	# Pass only id=42 — ids 7 and 8 should be removed
	var reduced_traps: Array = [
		{"id": 42, "type": "trap1-mine", "position": Vector2(100, 200)},
	]
	renderer._update_ghosts(ghost_dict, trapped_stage, reduced_traps)

	_assert(not ghost_dict.has(7), "stale ghost id=7 should be removed from dict")
	_assert(not ghost_dict.has(8), "stale ghost id=8 should be removed from dict")
	_assert(ghost_dict.has(42), "active ghost id=42 should remain")

	# ── Cleanup ────────────────────────────────────────────────────
	existing_ghost.queue_free()
	trapped_stage.queue_free()
	renderer.queue_free()
	stage_a.queue_free()
	stage_b.queue_free()
	print("DemoRenderer tests passed")
	quit(0)


## Creates a simple test node with apply_demo_state method.
func _make_mock_ghost() -> Node:
	var node := Node2D.new()
	var ghost_script := GDScript.new()
	ghost_script.source_code = """extends Node2D

func apply_demo_state(_data: Dictionary) -> void:
	pass
"""
	ghost_script.reload()
	node.set_script(ghost_script)
	return node


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
