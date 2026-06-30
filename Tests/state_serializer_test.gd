extends SceneTree

const StateSerializerScript = preload("res://Scripts/state_serializer.gd")
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

	# ── Trap serialization tests ───────────────────────────────────

	var mock_stage := Node2D.new()
	mock_stage.name = "MockStage"
	root.add_child(mock_stage)
	serializer.stage = mock_stage

	# TEST 7: _serialize_traps returns empty array when no traps
	var empty_traps: Array = serializer._serialize_traps()
	_assert_eq(empty_traps.size(), 0, "no traps should return empty array")

	# TEST 8: non-trap nodes (no script) are skipped
	var wall_node := StaticBody2D.new()
	wall_node.name = "Wall"
	mock_stage.add_child(wall_node)
	var wall_traps: Array = serializer._serialize_traps()
	_assert_eq(wall_traps.size(), 0, "non-trap node should be skipped")

	# TEST 9: _serialize_single_trap returns empty dict for node without trap script
	var plain_node := Node2D.new()
	plain_node.name = "PlainNode"
	var plain_data: Dictionary = serializer._serialize_single_trap(plain_node)
	_assert_eq(plain_data.size(), 0, "node without trap script should return empty dict")

	# TEST 10: mine trap serialization
	var mine_node := Node2D.new()
	mine_node.name = "MineTrap"
	mine_node.set_script(FixtureMine)
	mine_node.global_position = Vector2(300, 400)
	mine_node.visible = false
	mine_node.set("is_armed", true)
	var mine_body := Sprite2D.new()
	mine_body.name = "MineBody"
	mine_body.modulate = Color(1.0, 0.5, 0.2, 0.8)
	mine_node.add_child(mine_body)
	mock_stage.add_child(mine_node)

	var mine_data: Dictionary = serializer._serialize_single_trap(mine_node)
	_assert_eq(mine_data["type"], "mine", "mine type")
	_assert_eq(mine_data["position"], Vector2(300, 400), "mine position")
	_assert_eq(mine_data["visible"], false, "mine visible")
	_assert_eq(mine_data["is_armed"], true, "mine is_armed")
	_assert_eq(mine_data["phase"], "armed", "mine phase when armed")
	_assert_float_eq(mine_data["modulate_r"], 1.0, 0.001, "mine modulate_r")
	_assert_float_eq(mine_data["modulate_g"], 0.5, 0.001, "mine modulate_g")
	_assert_float_eq(mine_data["modulate_b"], 0.2, 0.001, "mine modulate_b")
	_assert_float_eq(mine_data["modulate_a"], 0.8, 0.001, "mine modulate_a")

	# TEST 11: electric_ring trap serialization
	var er_node := Node2D.new()
	er_node.name = "ElectricRingTrap"
	er_node.set_script(FixtureElectricRing)
	er_node.global_position = Vector2(150, 250)
	er_node.visible = true
	er_node.set("radius", 120.0)
	er_node.set("current_fill", 0.5)
	er_node.set("electric_on", false)
	er_node.set("current_stay_time", 2.0)
	var warning_sprite := Sprite2D.new()
	warning_sprite.name = "ElectricRingWarning"
	warning_sprite.visible = true
	er_node.add_child(warning_sprite)
	var ring_sprite := Sprite2D.new()
	ring_sprite.name = "ElectricRing"
	ring_sprite.visible = false
	ring_sprite.scale = Vector2(1.5, 1.5)
	er_node.add_child(ring_sprite)
	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	er_node.add_child(anim)
	mock_stage.add_child(er_node)

	var er_data: Dictionary = serializer._serialize_single_trap(er_node)
	_assert_eq(er_data["type"], "electric_ring", "electric_ring type")
	_assert_eq(er_data["radius"], 120.0, "electric_ring radius")
	_assert_eq(er_data["current_fill"], 0.5, "electric_ring current_fill")
	_assert_eq(er_data["electric_on"], false, "electric_ring electric_on")
	_assert_eq(er_data["current_stay_time"], 2.0, "electric_ring current_stay_time")
	_assert_eq(er_data["scale_x"], 1.5, "electric_ring scale_x")
	_assert_eq(er_data["scale_y"], 1.5, "electric_ring scale_y")
	_assert_eq(er_data["warning_visible"], true, "electric_ring warning_visible")
	_assert_eq(er_data["ring_visible"], false, "electric_ring ring_visible")
	_assert_eq(er_data["phase"], "warning", "electric_ring phase (fill>0, not on)")

	# TEST 12: tracing_bullet trap serialization
	var tb_node := Node2D.new()
	tb_node.name = "TracingBulletTrap"
	tb_node.set_script(FixtureTracingBullet)
	tb_node.global_position = Vector2(400, 100)
	tb_node.rotation = 0.785
	tb_node.set("tracing", true)
	mock_stage.add_child(tb_node)

	var tb_data: Dictionary = serializer._serialize_single_trap(tb_node)
	_assert_eq(tb_data["type"], "tracing_bullet", "tracing_bullet type")
	_assert_eq(tb_data["position"], Vector2(400, 100), "tracing_bullet position")
	_assert_float_eq(tb_data["rotation"], 0.785, 0.001, "tracing_bullet rotation")
	_assert_eq(tb_data["tracing"], true, "tracing_bullet tracing")
	_assert_eq(tb_data["phase"], "homing", "tracing_bullet phase when tracing")

	# TEST 13: conveyor trap serialization
	var cv_node := Node2D.new()
	cv_node.name = "ConveyorTrap"
	cv_node.set_script(FixtureConveyor)
	cv_node.global_position = Vector2(0, 100)
	cv_node.set("direction", Vector2(1, 0))
	mock_stage.add_child(cv_node)

	var cv_data: Dictionary = serializer._serialize_single_trap(cv_node)
	_assert_eq(cv_data["type"], "conveyor", "conveyor type")
	_assert_eq(cv_data["direction"], Vector2(1, 0), "conveyor direction")

	# TEST 14: ice_floor trap serialization
	var if_node := Node2D.new()
	if_node.name = "IceFloorTrap"
	if_node.set_script(FixtureIceFloor)
	if_node.global_position = Vector2(-100, 50)
	mock_stage.add_child(if_node)

	var if_data: Dictionary = serializer._serialize_single_trap(if_node)
	_assert_eq(if_data["type"], "ice_floor", "ice_floor type")
	_assert_eq(if_data["position"], Vector2(-100, 50), "ice_floor position")

	# TEST 15: scanline trap serialization
	var sl_node := Area2D.new()
	sl_node.name = "ScanlineTrap"
	sl_node.set_script(FixtureScanline)
	sl_node.global_position = Vector2(200, 100)
	sl_node.set("line_dir", Vector2(0, 1))
	var hulas := sl_node.get_node_or_null("Hulas")
	if hulas:
		hulas.position = Vector2(5, 0)
	mock_stage.add_child(sl_node)

	var sl_data: Dictionary = serializer._serialize_single_trap(sl_node)
	_assert_eq(sl_data["type"], "scanline", "scanline type")
	_assert_eq(sl_data["phase"], "active", "scanline phase")
	_assert_eq(sl_data["line_dir"], Vector2(0, 1), "scanline line_dir")
	_assert_float_eq(sl_data["oscillation_offset"], 5.0, 0.001, "scanline oscillation_offset")

	# TEST 16: spreading_ripples trap serialization (warning phase)
	var sr_node := Node2D.new()
	sr_node.name = "SpreadingRipplesTrap"
	sr_node.set_script(FixtureSpreadingRipples)
	sr_node.set("is_expanding", false)
	sr_node.set("max_radius", 1000.0)
	mock_stage.add_child(sr_node)

	var sr_data: Dictionary = serializer._serialize_single_trap(sr_node)
	_assert_eq(sr_data["type"], "spreading_ripples", "spreading_ripples type")
	_assert_eq(sr_data["phase"], "warning", "spreading_ripples phase (not expanding, r=0)")
	_assert_float_eq(sr_data["expand_progress"], 0.0, 0.001, "spreading_ripples progress (0)")

	# TEST 17: spreading_ripples expanding phase
	sr_node.set("is_expanding", true)
	var col := sr_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = 500.0
	var sr_data2: Dictionary = serializer._serialize_single_trap(sr_node)
	_assert_eq(sr_data2["phase"], "expanding", "spreading_ripples phase (expanding)")
	_assert_float_eq(sr_data2["expand_progress"], 0.5, 0.001, "spreading_ripples progress (0.5)")

	# TEST 18: electric_arc trap serialization
	var ea_node := Node2D.new()
	ea_node.name = "ElectricArcTrap"
	ea_node.set_script(FixtureElectricArc)
	ea_node.set("activated", false)
	ea_node.visible = true
	mock_stage.add_child(ea_node)

	var ea_data: Dictionary = serializer._serialize_single_trap(ea_node)
	_assert_eq(ea_data["type"], "electric_arc", "electric_arc type")
	_assert_eq(ea_data["phase"], "warning", "electric_arc phase (visible, not activated)")
	var sp := ea_node.get_node_or_null("StartPoint")
	_assert_eq(ea_data["start_pos"], sp.position if sp else Vector2.ZERO, "electric_arc start_pos")
	var ep := ea_node.get_node_or_null("EndPoint")
	_assert_eq(ea_data["end_pos"], ep.position if ep else Vector2.ZERO, "electric_arc end_pos")
	_assert_float_eq(
		ea_data["crack_progress"], 0.0, 0.001, "electric_arc crack_progress (no material)"
	)

	# TEST 19: mortar trap serialization (flying phase)
	var mo_node := Node2D.new()
	mo_node.name = "MortarTrap"
	mo_node.set_script(FixtureMortar)
	mo_node.set("flying", true)
	mo_node.set("exploding", false)
	var shell_shadow := mo_node.get_node_or_null("ShellShadow")
	if shell_shadow:
		shell_shadow.position = Vector2(200, 300)
	var shell := mo_node.get_node_or_null("ShellShadow/Shell")
	if shell:
		shell.position = Vector2(0, -50)
		shell.rotation = 1.57
	mock_stage.add_child(mo_node)

	var mo_data: Dictionary = serializer._serialize_single_trap(mo_node)
	_assert_eq(mo_data["type"], "mortar", "mortar type")
	_assert_eq(mo_data["phase"], "flying", "mortar phase (flying)")
	_assert_eq(mo_data["shell_position"], Vector2(200, 300), "mortar shell_position")
	_assert_float_eq(mo_data["shell_y_offset"], -50.0, 0.001, "mortar shell_y_offset")
	_assert_float_eq(mo_data["shell_rotation"], 1.57, 0.001, "mortar shell_rotation")
	_assert_eq(mo_data["explosion_visible"], false, "mortar explosion_visible")

	# TEST 20: shotgun trap serialization (warning phase)
	var sg_node := Node2D.new()
	sg_node.name = "ShotgunTrap"
	sg_node.set_script(FixtureShotgun)
	sg_node.global_position = Vector2(200, 300)
	sg_node.set("directions", [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)])
	sg_node.set("aiming", true)
	sg_node.set("firing", false)
	sg_node.set("aiming_time", 1.5)
	var sg_timer := sg_node.get_node_or_null("Timer") as Timer
	if sg_timer:
		sg_timer.wait_time = 1.5
		sg_timer.start(1.5)
	mock_stage.add_child(sg_node)

	var sg_data: Dictionary = serializer._serialize_single_trap(sg_node)
	_assert_eq(sg_data["type"], "shotgun", "shotgun type")
	var got_dirs = sg_data["directions"]
	_assert(got_dirs is Array, "shotgun directions should be Array")
	_assert_eq((got_dirs as Array).size(), 3, "shotgun directions count")
	_assert_eq(sg_data["phase"], "warning", "shotgun phase (aiming)")
	# warning_progress should be near 0 since timer just started
	_assert_float_eq(sg_data["warning_progress"], 0.0, 0.1, "shotgun warning_progress (~0)")

	# TEST 21: _serialize_traps collects all traps from stage
	var all_traps: Array = serializer._serialize_traps()
	_assert(all_traps.size() >= 10, "should find at least 10 traps (got %d)" % all_traps.size())

	# ── Energy ball serialization tests ────────────────────────────

	# TEST 22: _serialize_energy_balls returns empty array without energy ball nodes
	var clean_stage := Node2D.new()
	clean_stage.name = "CleanStage"
	root.add_child(clean_stage)
	serializer.stage = clean_stage
	var no_balls: Array = serializer._serialize_energy_balls()
	_assert_eq(no_balls.size(), 0, "no energy balls should return empty array")

	# TEST 23: energy ball detection skips non-energy-ball scripts
	serializer.stage = mock_stage
	var balls_from_stage: Array = serializer._serialize_energy_balls()
	_assert_eq(balls_from_stage.size(), 0, "stage w/o energy balls returns empty")

	# ── Full state collection test ─────────────────────────────────

	# TEST 24: _collect_state assembles complete state dictionary
	var mock_gm: Node = MockGameManager.new()
	mock_gm.name = "MockGameManager"
	root.add_child(mock_gm)
	mock_gm.player = mock_player
	mock_gm.energy_amount = 42
	mock_gm.energy_ball_count = 3
	serializer.game_manager = mock_gm
	serializer.stage = mock_stage

	var state: Dictionary = serializer._collect_state()
	_assert(state.has("peer_id"), "state should have peer_id")
	_assert(state.has("tick"), "state should have tick")
	_assert(state.has("player"), "state should have player")
	_assert(state.has("traps"), "state should have traps")
	_assert(state.has("energy_balls"), "state should have energy_balls")

	var player_section: Dictionary = state["player"]
	_assert_eq(player_section["energy"], 42, "player energy in state")
	_assert_eq(player_section["energy_ball_count"], 3, "energy_ball_count in state")
	_assert(state["traps"].size() >= 10, "state should include at least 10 traps")

	# ── Cleanup ────────────────────────────────────────────────────
	mock_player.queue_free()
	mock_stage.queue_free()
	clean_stage.queue_free()
	mock_gm.queue_free()
	serializer.queue_free()
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
