extends SceneTree

# Logic test for the agent-action service:
#   AgentActionService (traps + heal) + TrapRequestScheduler
# Runs headless: godot --headless --script res://Tests/agent_action_service_test.gd
# Pure service-level checks; no trap scenes are instantiated.

const TrapRequestSchedulerScript = preload("res://Scripts/trap_request_scheduler.gd")
const AgentActionServiceScript = preload("res://Scripts/agent_action_service.gd")

const MINE_COST := 10.0
const START_ENERGY := 100


# Stand-in for the player node (health authority) used by heal tests.
class FakePlayer:
	extends RefCounted
	var health: int = 0
	var max_health: int = 0


# Duck-typed stand-in for game_manager: energy authority (via NetworkManager) + player node.
# Autoloads are invisible to `godot --script`, so the service takes an injected `game`, not the
# NetworkManager global.
class FakeGame:
	extends RefCounted
	var player := FakePlayer.new()
	var energy: int = 0

	func get_my_energy() -> int:
		return energy

	func request_spend_energy(amount: int) -> void:
		energy = max(energy - amount, 0)

	func add(amount: int) -> void:
		energy += amount


func _init() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var scheduler: TrapRequestScheduler = TrapRequestSchedulerScript.new()
	var agent: AgentActionService = AgentActionServiceScript.new()
	var game := FakeGame.new()
	root.add_child(scheduler)
	root.add_child(agent)
	await process_frame

	scheduler.initialize()
	agent.setup_services(game, scheduler)

	# Fund the player enough for cheap traps but not the expensive shotgun.
	game.add(int(START_ENERGY))

	# TEST 1: a valid mine queues but does not spend energy yet.
	var mine_id := agent.submit_trap_request("trap1-mine", {"position": Vector2(100, 200)})
	_assert(mine_id >= 0, "valid mine should be accepted (got id %d)" % mine_id)
	_assert_eq(game.get_my_energy(), START_ENERGY, "energy must not be spent on submit")
	_assert_eq(scheduler.get_queue_size(), 1, "mine should sit in the queue")

	# TEST 2: processing the tick approves it, spends energy, starts cooldown.
	scheduler.process_requests()
	_assert_eq(game.get_my_energy(), START_ENERGY - MINE_COST, "approval should spend cost")
	_assert_eq(scheduler.get_queue_size(), 0, "queue should drain after processing")

	# TEST 3: resubmitting the same trap during cooldown is rejected before queueing.
	var cd_id := agent.submit_trap_request("trap1-mine", {"position": Vector2(200, 200)})
	_assert_eq(cd_id, -1, "mine on cooldown should be rejected")
	_assert_eq(game.get_my_energy(), START_ENERGY - MINE_COST, "rejection must not spend energy")

	# TEST 4: unknown trap id is rejected.
	_assert_eq(agent.submit_trap_request("unknown_trap", {}), -1, "unknown trap should be rejected")

	# TEST 5: a trap the player can't afford is rejected. Drain to empty, then refund.
	NetworkManager.request_spend_energy(game.get_my_energy())
	_assert_eq(
		agent.submit_trap_request("trap5-icefloor", {}),
		-1,
		"insufficient energy should be rejected"
	)
	game.add(int(START_ENERGY))

	# TEST 6: the queue fills at max_queue_size, then rejects further requests.
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

	# TEST 7: heal spends real (NetworkManager) energy and restores real (player) health.
	agent.default_heal_amount = 2
	agent.default_heal_energy_cost = 40
	agent.heal_uses_left = 1
	game.player.health = 1
	game.player.max_health = 5
	NetworkManager.request_spend_energy(game.get_my_energy())
	game.add(100)

	var heal_ok: Dictionary = agent.request_heal()
	_assert(heal_ok["ok"], "heal should succeed with energy and uses")
	_assert_eq(game.get_my_energy(), 60, "heal should spend 40 energy via NetworkManager")
	_assert_eq(game.player.health, 3, "heal should restore player health toward max")
	_assert_eq(agent.heal_uses_left, 0, "heal should consume a use")

	# TEST 8: heal is refused with no uses, then with insufficient energy.
	_assert_eq(agent.request_heal()["reason"], "no_heal_uses_left", "heal without uses is rejected")
	agent.heal_uses_left = 1
	NetworkManager.request_spend_energy(game.get_my_energy())
	_assert_eq(
		agent.request_heal()["reason"], "insufficient_energy", "heal without energy is rejected"
	)

	print("AgentActionService tests passed")
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
