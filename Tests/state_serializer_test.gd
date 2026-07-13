extends SceneTree

const StateSerializerScript = preload("res://Scripts/network/state_serializer.gd")
const PUSH_INTERVAL := 1.0 / 30.0

# Fixtures
const MockPlayer = preload("res://Tests/fixtures/mock_player.gd")
const MockGameManager = preload("res://Tests/fixtures/mock_game_manager.gd")
const FixtureMine = preload("res://Tests/fixtures/trap1-mine.gd")
const FixtureElectricRing = preload("res://Tests/fixtures/trap2-electric_ring.gd")
const FixtureTracingBullet = preload("res://Tests/fixtures/trap3-tracing_bullet.gd")
const FixtureConveyor = preload("res://Tests/fixtures/trap4-conveyor.gd")
const FixtureIceFloor = preload("res://Tests/fixtures/trap5-icefloor.gd")
const FixtureScanline = preload("res://Tests/fixtures/trap6-scanline.gd")
const FixtureSpreadingRipples = preload("res://Tests/fixtures/trap7-spreading_ripples.gd")
const FixtureElectricArc = preload("res://Tests/fixtures/trap8-electric_arc.gd")
const FixtureMortar = preload("res://Tests/fixtures/trap9-mortar.gd")
const FixtureShotgun = preload("res://Tests/fixtures/trap10-shotgun.gd")


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	# ── Setup: create StateSerializer node ──────────────────────────
	var serializer: Node = StateSerializerScript.new()
	serializer.name = "StateSerializer"
	root.add_child(serializer)
	await process_frame  # wait for _ready() to execute

	# ── Timer tests ────────────────────────────────────────────────

	# TEST 1: StateSerializer creates a StatePushTimer child
	var timer: Timer = serializer.get_node_or_null("StatePushTimer") as Timer
	_assert(timer != null, "should create a StatePushTimer child")

	# TEST 2: Timer has correct interval (~1/30 second)
	_assert(
		abs(timer.wait_time - PUSH_INTERVAL) < 0.001,
		"timer interval should be 1/30 second (got %.4f)" % timer.wait_time
	)

	# TEST 3: Timer uses physics process callback
	_assert_eq(
		timer.process_callback,
		Timer.TIMER_PROCESS_PHYSICS,
		"timer should use physics process callback"
	)

	# TEST 4: Timer timeout signal is connected
	var connections: Array = timer.timeout.get_connections()
	_assert(connections.size() > 0, "timer timeout should be connected")

	# ── Player serialization tests ─────────────────────────────────

	# TEST 5: _serialize_player returns correct fields from a mock Player node
	var mock_player: CharacterBody2D = MockPlayer.new()
	mock_player.name = "Player"
	mock_player.global_position = Vector2(100, 200)
	mock_player.velocity = Vector2(50, 0)
	mock_player.isjumping = true
	mock_player.current_sprite_y = 15.0
	mock_player.health = 80.0
	mock_player.isinvincible = true
	mock_player.modulate.a = 0.3
	root.add_child(mock_player)

	var player_state: Dictionary = serializer._serialize_player(mock_player)
	_assert_eq(player_state["position"], Vector2(100, 200), "player position")
	_assert_eq(player_state["velocity"], Vector2(50, 0), "player velocity")
	_assert_eq(player_state["is_jumping"], true, "player is_jumping")
	_assert_eq(player_state["sprite_y"], 15.0, "player sprite_y")
	_assert_eq(player_state["health"], 80.0, "player health")
	_assert_eq(player_state["is_invincible"], true, "player is_invincible")
	_assert_float_eq(player_state["modulate_alpha"], 0.3, 0.001, "player modulate_alpha")

	# TEST 6: _serialize_player returns empty dict for null / freed node
	var invalid_state: Dictionary = serializer._serialize_player(null)
	_assert_eq(invalid_state.size(), 0, "null player should return empty dict")

	# ── v2 Trap serialization tests — generic dispatch ────────────

	# TEST 7: _serialize_single_trap returns {} for node without script
	var plain_node := Node2D.new()
	plain_node.name = "PlainNode"
	var plain_data: Dictionary = serializer._serialize_single_trap(plain_node)
	_assert_eq(plain_data.size(), 0, "node without script should return empty dict")

	# TEST 8: _serialize_single_trap returns {} for node without serialize_state
	var noser_node := CharacterBody2D.new()
	noser_node.name = "NoSerNode"
	noser_node.set_script(MockPlayer)
	var noser_data: Dictionary = serializer._serialize_single_trap(noser_node)
	_assert_eq(noser_data.size(), 0, "node w/o serialize_state should return empty dict")

	# TEST 9: _serialize_single_trap dispatches to trap's serialize_state()
	var mine_node := Node2D.new()
	mine_node.name = "MineTrap"
	mine_node.set_script(FixtureMine)
	mine_node.global_position = Vector2(300, 400)
	mine_node.set("is_armed", true)
	root.add_child(mine_node)

	var mine_data: Dictionary = serializer._serialize_single_trap(mine_node)
	# v2: verify the data was produced by serialize_state() dispatch (has _v2 marker)
	# The v1 hardcoded code would NOT set _v2, proving dispatch works.
	var expected_mine: Dictionary = mine_node.serialize_state()
	_assert_eq(mine_data["_v2"], true, "mine has _v2 marker (proof of dispatch)")
	_assert_eq(mine_data["type"], expected_mine["type"], "mine type via dispatch")
	_assert_eq(mine_data["position"], expected_mine["position"], "mine position via dispatch")
	_assert(mine_data.has("id"), "mine data should have id")
	_assert(mine_data["id"] is int, "mine id should be int")

	# TEST 10: same id on second call
	var mine_data2: Dictionary = serializer._serialize_single_trap(mine_node)
	_assert_eq(mine_data2["id"], mine_data["id"], "same node returns same id")

	# ── All 10 trap types dispatch correctly ──────────────────────

	var dispatch_tests := [
		{
			"name": "electric_ring",
			"fixture": FixtureElectricRing,
			"pos": Vector2(150, 250),
			"type": "trap2-electric_ring"
		},
		{
			"name": "tracing_bullet",
			"fixture": FixtureTracingBullet,
			"pos": Vector2(400, 100),
			"type": "trap3-tracing_bullet"
		},
		{
			"name": "conveyor",
			"fixture": FixtureConveyor,
			"pos": Vector2(0, 100),
			"type": "trap4-conveyor"
		},
		{
			"name": "icefloor",
			"fixture": FixtureIceFloor,
			"pos": Vector2(-100, 50),
			"type": "trap5-icefloor"
		},
		{
			"name": "scanline",
			"fixture": FixtureScanline,
			"pos": Vector2(200, 100),
			"type": "trap6-scanline"
		},
		{
			"name": "spreading_ripples",
			"fixture": FixtureSpreadingRipples,
			"pos": Vector2(50, 50),
			"type": "trap7-spreading_ripples"
		},
		{
			"name": "electric_arc",
			"fixture": FixtureElectricArc,
			"pos": Vector2(-50, -50),
			"type": "trap8-electric_arc"
		},
		{
			"name": "mortar",
			"fixture": FixtureMortar,
			"pos": Vector2(100, -100),
			"type": "trap9-mortar"
		},
		{
			"name": "shotgun",
			"fixture": FixtureShotgun,
			"pos": Vector2(200, 300),
			"type": "trap10-shotgun"
		},
	]

	var mock_stage := Node2D.new()
	mock_stage.name = "MockStage"
	root.add_child(mock_stage)
	serializer.stage = mock_stage

	for dt in dispatch_tests:
		var trap_node: Node = dt["fixture"].new()
		trap_node.name = "Trap_%s" % dt["name"]
		trap_node.global_position = dt["pos"]
		mock_stage.add_child(trap_node)

		var data: Dictionary = serializer._serialize_single_trap(trap_node)
		_assert(data.size() > 0, "%s should produce non-empty data" % dt["name"])
		_assert_eq(data["_v2"], true, "%s has _v2 marker (proof of dispatch)" % dt["name"])
		_assert_eq(data["type"], dt["type"], "%s type" % dt["name"])
		_assert_eq(data["position"], dt["pos"], "%s position" % dt["name"])
		_assert(data.has("id"), "%s should have id" % dt["name"])
		_assert(data["id"] is int, "%s id should be int" % dt["name"])

	# TEST 20: _serialize_traps collects all traps from stage
	var all_traps: Array = serializer._serialize_traps()
	_assert(all_traps.size() >= 9, "should find at least 9 traps (got %d)" % all_traps.size())

	# ── Energy ball serialization tests ────────────────────────────

	# TEST 21: _serialize_energy_balls returns empty array without energy ball nodes
	var clean_stage := Node2D.new()
	clean_stage.name = "CleanStage"
	root.add_child(clean_stage)
	serializer.stage = clean_stage
	var no_balls: Array = serializer._serialize_energy_balls()
	_assert_eq(no_balls.size(), 0, "no energy balls should return empty array")

	# TEST 22: energy ball detection skips non-energy-ball scripts
	serializer.stage = mock_stage
	var balls_from_stage: Array = serializer._serialize_energy_balls()
	_assert_eq(balls_from_stage.size(), 0, "stage w/o energy balls returns empty")

	# ── Full state collection test ─────────────────────────────────

	# TEST 23: _collect_state assembles complete state dictionary
	var mock_gm: Node = MockGameManager.new()
	mock_gm.name = "MockGameManager"
	root.add_child(mock_gm)
	mock_gm.player = mock_player
	mock_gm.energy_amount = 42
	mock_gm.energy_ball_count = 3
	mock_gm.current_phase = 2
	mock_gm.max_energy = [35, 50, 60, 70, 77, 85]
	serializer.game_manager = mock_gm
	serializer.stage = mock_stage

	var state: Dictionary = serializer._collect_state()
	_assert(state.has("peer_id"), "state should have peer_id")
	_assert(state.has("tick"), "state should have tick")
	_assert(state.has("player"), "state should have player")
	_assert(state.has("max_energy_cap"), "state should have max_energy_cap")
	_assert(state.has("traps"), "state should have traps")
	_assert(state.has("energy_balls"), "state should have energy_balls")

	var player_section: Dictionary = state["player"]
	_assert_eq(player_section["energy"], 42, "player energy in state")
	_assert_eq(player_section["energy_ball_count"], 3, "energy_ball_count in state")
	_assert_eq(state["max_energy_cap"], 60, "max energy cap in state")
	_assert(state["traps"].size() >= 9, "state should include at least 9 traps")

	# TEST 24: v2 traps in collected state have correct structure
	var collected_traps: Array = state["traps"]
	for trap_data in collected_traps:
		_assert(trap_data.has("type"), "trap state must have type")
		_assert(trap_data.has("position"), "trap state must have position")
		_assert(trap_data.has("id"), "trap state must have id")

	# ── Cleanup ────────────────────────────────────────────────────
	mock_player.queue_free()
	mock_stage.queue_free()
	clean_stage.queue_free()
	mock_gm.queue_free()
	serializer.queue_free()
	for dt in dispatch_tests:
		# Trap nodes are children of root/stage, freed with mock_stage above
		pass
	print("StateSerializer tests passed")
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


func _assert_float_eq(actual: float, expected: float, tolerance: float, message := "") -> void:
	if abs(actual - expected) <= tolerance:
		return
	push_error("%s expected <%s>, got <%s>" % [message, expected, actual])
	quit(1)
