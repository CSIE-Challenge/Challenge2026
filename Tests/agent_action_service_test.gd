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

	team_status.initialize_teams([0, 1])
	scheduler.initialize_teams([0, 1])
	agent.setup_services(team_status, scheduler)

	# Team 0 well funded, team 1 too poor for an expensive trap.
	team_status.add_energy(0, START_ENERGY)
	team_status.add_energy(1, 5.0)

	# TEST 1: a valid mine queues but does not spend energy yet.
	var mine_id := agent.submit_trap_request(0, "trap1-mine", {"position": Vector2(100, 200)})
	_assert(mine_id >= 0, "valid mine should be accepted (got id %d)" % mine_id)
	_assert_eq(team_status.get_energy(0), START_ENERGY, "energy must not be spent on submit")
	_assert_eq(scheduler.get_queue_size(0), 1, "mine should sit in the queue")

	# TEST 2: processing the tick approves it, spends energy, starts cooldown.
	scheduler.process_requests()
	_assert_eq(team_status.get_energy(0), START_ENERGY - MINE_COST, "approval should spend cost")
	_assert_eq(scheduler.get_queue_size(0), 0, "queue should drain after processing")

	# TEST 3: resubmitting the same trap during cooldown is rejected before queueing.
	var cd_id := agent.submit_trap_request(0, "trap1-mine", {"position": Vector2(200, 200)})
	_assert_eq(cd_id, -1, "mine on cooldown should be rejected")
	_assert_eq(
		team_status.get_energy(0), START_ENERGY - MINE_COST, "rejection must not spend energy"
	)

	# TEST 4: unknown trap id is rejected.
	_assert_eq(
		agent.submit_trap_request(0, "unknown_trap", {}), -1, "unknown trap should be rejected"
	)

	# TEST 5: a trap the team can't afford is rejected (team 1 has 5, shotgun costs 100).
	_assert_eq(
		agent.submit_trap_request(1, "trap10-shotgun", {}),
		-1,
		"insufficient energy should be rejected"
	)

	# TEST 6: dropping team 0 below zero health flips it into lifesteal mode.
	team_status.damage_team(0, 999.0)
	_assert(team_status.is_team_in_lifesteal(0), "team 0 should enter lifesteal mode")

	# TEST 7: healing is refused while in lifesteal mode.
	_assert(not team_status.try_heal_team(0, 1.0, 10.0), "heal should fail in lifesteal mode")

	# TEST 8: the queue fills at max_queue_size_per_team, then rejects further requests.
	# electric_ring (cost 20) is off cooldown; energy isn't spent until processing,
	# so all three fit before the cap is hit. Spec: electric_ring needs delay_time + radius.
	var ring_params := {"delay_time": 1.0, "radius": 80.0}
	for i in scheduler.max_queue_size_per_team:
		var rid := agent.submit_trap_request(0, "trap2-electric_ring", ring_params)
		_assert(rid >= 0, "electric_ring #%d should queue" % i)
	_assert_eq(
		scheduler.get_queue_size(0), scheduler.max_queue_size_per_team, "queue should be full"
	)
	_assert_eq(
		agent.submit_trap_request(0, "trap2-electric_ring", ring_params),
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
