extends SceneTree

# Logic test for the trap-request pipeline:
#   AgentActionService + TrapRequestScheduler + TeamStatusService
# Runs headless: godot --headless --script res://Tests/agent_action_service_test.gd
# Pure service-level checks; no trap scenes are instantiated.

const TeamStatusServiceScript = preload("res://Scripts/team_status_service.gd")
const TrapRequestSchedulerScript = preload("res://Scripts/trap_request_scheduler.gd")
const AgentActionServiceScript = preload("res://Scripts/agent_action_service.gd")

const MINE_COST := 10.0
const START_ENERGY := 100.0


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var team_status: TeamStatusService = TeamStatusServiceScript.new()
	var scheduler: TrapRequestScheduler = TrapRequestSchedulerScript.new()
	var agent: AgentActionService = AgentActionServiceScript.new()
	root.add_child(team_status)
	root.add_child(scheduler)
	root.add_child(agent)
	await process_frame

	team_status.initialize()
	scheduler.initialize()
	agent.setup_services(team_status, scheduler)

	# Fund the player enough for cheap traps but not the expensive shotgun.
	team_status.add_energy(START_ENERGY)

	# TEST 1: a valid mine queues but does not spend energy yet.
	var mine_id := agent.submit_trap_request("trap1-mine", {"position": Vector2(100, 200)})
	_assert(mine_id >= 0, "valid mine should be accepted (got id %d)" % mine_id)
	_assert_eq(team_status.get_energy(), START_ENERGY, "energy must not be spent on submit")
	_assert_eq(scheduler.get_queue_size(), 1, "mine should sit in the queue")

	# TEST 2: processing the tick approves it, spends energy, starts cooldown.
	scheduler.process_requests()
	_assert_eq(team_status.get_energy(), START_ENERGY - MINE_COST, "approval should spend cost")
	_assert_eq(scheduler.get_queue_size(), 0, "queue should drain after processing")

	# TEST 3: resubmitting the same trap during cooldown is rejected before queueing.
	var cd_id := agent.submit_trap_request("trap1-mine", {"position": Vector2(200, 200)})
	_assert_eq(cd_id, -1, "mine on cooldown should be rejected")
	_assert_eq(
		team_status.get_energy(), START_ENERGY - MINE_COST, "rejection must not spend energy"
	)

	# TEST 4: unknown trap id is rejected.
	_assert_eq(agent.submit_trap_request("unknown_trap", {}), -1, "unknown trap should be rejected")

	# TEST 5: a trap the player can't afford is rejected. Drain to empty, then refund.
	team_status.try_spend_energy(team_status.get_energy())
	_assert_eq(
		agent.submit_trap_request("trap5-icefloor", {}),
		-1,
		"insufficient energy should be rejected"
	)
	team_status.add_energy(START_ENERGY)

	# TEST 6: dropping below zero health flips into lifesteal mode.
	team_status.take_damage(999.0)
	_assert(team_status.is_in_lifesteal(), "player should enter lifesteal mode")

	# TEST 7: healing is refused while in lifesteal mode.
	_assert(not team_status.try_heal(1.0, 10.0), "heal should fail in lifesteal mode")

	# TEST 8: the queue fills at max_queue_size, then rejects further requests.
	# electric_ring (cost 20) is off cooldown; energy isn't spent until processing,
	# so all three fit before the cap is hit. Spec: electric_ring needs delay_time + radius.
	var ring_params := {"delay_time": 1.0, "radius": 80.0}
	for i in scheduler.max_queue_size:
		var rid := agent.submit_trap_request("trap2-electric_ring", ring_params)
		_assert(rid >= 0, "electric_ring #%d should queue" % i)
	_assert_eq(scheduler.get_queue_size(), scheduler.max_queue_size, "queue should be full")
	_assert_eq(
		agent.submit_trap_request("trap2-electric_ring", ring_params),
		-1,
		"request beyond queue capacity should be rejected"
	)

	print("AgentActionService tests passed")
	team_status.queue_free()
	scheduler.queue_free()
	agent.queue_free()
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
