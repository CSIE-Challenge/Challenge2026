class_name AgentActionService
extends Node

signal trap_request_submitted(request: Dictionary)
signal trap_request_rejected(request: Dictionary, reason: String)
signal trap_approved(request: Dictionary, energy_cost: float)
signal trap_rejected(request: Dictionary, reason: String)
signal heal_used(heal_amount: int, energy_cost: int, heal_uses_left: int)

var game
var trap_request_scheduler: TrapRequestScheduler

var game_data := GameData.new()
var default_heal_uses: int = game_data.get_int("heal", "uses", 2)
var default_heal_amount: int = game_data.get_int("heal", "amount", 2)
var default_heal_energy_cost: int = game_data.get_int("heal", "energy_cost", 40)
var heal_uses_left: int = default_heal_uses

var trap_data = TrapData.new().data

var trap_energy_costs := {
	"trap1-mine": trap_data["trap1-mine"]["energy_costs"],
	"trap2-electric_ring": trap_data["trap2-electric_ring"]["energy_costs"],
	"trap3-tracing_bullet": trap_data["trap3-tracing_bullet"]["energy_costs"],
	"trap4-conveyor": trap_data["trap4-conveyor"]["energy_costs"],
	"trap5-icefloor": trap_data["trap5-icefloor"]["energy_costs"],
	"trap6-scanline": trap_data["trap6-scanline"]["energy_costs"],
	"trap7-spreading_ripples": trap_data["trap7-spreading_ripples"]["energy_costs"],
	"trap8-electric_arc": trap_data["trap8-electric_arc"]["energy_costs"],
	"trap9-mortar": trap_data["trap9-mortar"]["energy_costs"],
	"trap10-shotgun": trap_data["trap10-shotgun"]["energy_costs"],
}

var trap_cooldown_times := {
	"trap1-mine": trap_data["trap1-mine"]["cooldown_times"],
	"trap2-electric_ring": trap_data["trap2-electric_ring"]["cooldown_times"],
	"trap3-tracing_bullet": trap_data["trap3-tracing_bullet"]["cooldown_times"],
	"trap4-conveyor": trap_data["trap4-conveyor"]["cooldown_times"],
	"trap5-icefloor": trap_data["trap5-icefloor"]["cooldown_times"],
	"trap6-scanline": trap_data["trap6-scanline"]["cooldown_times"],
	"trap7-spreading_ripples": trap_data["trap7-spreading_ripples"]["cooldown_times"],
	"trap8-electric_arc": trap_data["trap8-electric_arc"]["cooldown_times"],
	"trap9-mortar": trap_data["trap9-mortar"]["cooldown_times"],
	"trap10-shotgun": trap_data["trap10-shotgun"]["cooldown_times"],
}

# trap_cooldowns[trap_id] = remaining_seconds
var trap_cooldowns: Dictionary = {}

var _is_connected_to_scheduler := false


func setup_services(game_node, scheduler: TrapRequestScheduler) -> void:
	game = game_node
	trap_request_scheduler = scheduler
	_connect_scheduler_signal_once()


func _connect_scheduler_signal_once() -> void:
	if _is_connected_to_scheduler:
		return

	if trap_request_scheduler == null:
		push_error("AgentActionService: trap_request_scheduler is not assigned.")
		return

	trap_request_scheduler.request_ready.connect(_on_request_ready)
	_is_connected_to_scheduler = true
	print("AgentActionService connected to TrapRequestScheduler.request_ready")


# gdlint: disable=max-returns
# For Game Manager tests
func submit_trap_request(trap_id: String, params: Dictionary = {}) -> int:
	var rejected_request := _make_request(-1, trap_id, params)

	if game == null:
		push_error("AgentActionService: game is not assigned.")
		trap_request_rejected.emit(rejected_request, "game_not_assigned")
		return -1

	if trap_request_scheduler == null:
		push_error("AgentActionService: trap_request_scheduler is not assigned.")
		trap_request_rejected.emit(rejected_request, "trap_request_scheduler_not_assigned")
		return -1

	if not _is_known_trap(trap_id):
		trap_request_rejected.emit(rejected_request, "unknown_trap")
		return -1

	if _is_trap_on_cooldown(trap_id):
		trap_request_rejected.emit(rejected_request, "cooldown_active")
		return -1

	if not _has_enough_energy(trap_id):
		trap_request_rejected.emit(rejected_request, "insufficient_energy")
		return -1

	if not trap_request_scheduler.can_accept_request():
		trap_request_rejected.emit(rejected_request, "scheduler_cannot_accept_request")
		return -1

	var request_id := trap_request_scheduler.submit_request(trap_id, params)

	if request_id == -1:
		trap_request_rejected.emit(rejected_request, "scheduler_submit_failed")
		return -1

	var submitted_request := _make_request(request_id, trap_id, params)
	trap_request_submitted.emit(submitted_request)

	return request_id


# For Python API Server Calling
func submit_trap_request_result(trap_id: String, params: Dictionary = {}) -> Dictionary:
	var rejected_request := _make_request(-1, trap_id, params)

	if game == null:
		trap_request_rejected.emit(rejected_request, "game_not_assigned")
		return _make_submit_result(false, -1, trap_id, "game_not_assigned")

	if trap_request_scheduler == null:
		trap_request_rejected.emit(rejected_request, "trap_request_scheduler_not_assigned")
		return _make_submit_result(false, -1, trap_id, "trap_request_scheduler_not_assigned")

	if not _is_known_trap(trap_id):
		trap_request_rejected.emit(rejected_request, "unknown_trap")
		return _make_submit_result(false, -1, trap_id, "unknown_trap")

	if _is_trap_on_cooldown(trap_id):
		trap_request_rejected.emit(rejected_request, "cooldown_active")
		return _make_submit_result(false, -1, trap_id, "cooldown_active")

	if not _has_enough_energy(trap_id):
		trap_request_rejected.emit(rejected_request, "insufficient_energy")
		return _make_submit_result(false, -1, trap_id, "insufficient_energy")

	if not trap_request_scheduler.can_accept_request():
		trap_request_rejected.emit(rejected_request, "scheduler_cannot_accept_request")
		return _make_submit_result(false, -1, trap_id, "scheduler_cannot_accept_request")

	var request_id := trap_request_scheduler.submit_request(trap_id, params)

	if request_id == -1:
		trap_request_rejected.emit(rejected_request, "scheduler_submit_failed")
		return _make_submit_result(false, -1, trap_id, "scheduler_submit_failed")

	var submitted_request := _make_request(request_id, trap_id, params)
	trap_request_submitted.emit(submitted_request)

	return _make_submit_result(true, request_id, trap_id, "")


# gdlint: enable=max-returns


func update_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return

	for trap_id in trap_cooldowns.keys():
		trap_cooldowns[trap_id] = max(trap_cooldowns[trap_id] - delta, 0.0)


func _on_request_ready(request: Dictionary) -> void:
	print("AgentActionService received request_ready: ", request)

	var trap_id: String = request["trap_id"]

	if game == null:
		push_error("AgentActionService: game is not assigned.")
		trap_rejected.emit(request, "game_not_assigned")
		return

	if not _is_known_trap(trap_id):
		trap_rejected.emit(request, "unknown_trap")
		return

	if _is_trap_on_cooldown(trap_id):
		trap_rejected.emit(request, "cooldown_active")
		return

	var cost := _get_trap_cost(trap_id)

	if game.get_my_energy() < cost:
		trap_rejected.emit(request, "insufficient_energy")
		return

	game.request_spend_energy(int(cost), "trap:" + trap_id)
	_start_cooldown(trap_id)
	trap_approved.emit(request, cost)


func _is_known_trap(trap_id: String) -> bool:
	return trap_energy_costs.has(trap_id)


func _get_trap_cost(trap_id: String) -> float:
	if not trap_energy_costs.has(trap_id):
		return -1.0

	return trap_energy_costs[trap_id]


func _get_trap_cooldown_time(trap_id: String) -> float:
	if not trap_cooldown_times.has(trap_id):
		return 0.0

	return trap_cooldown_times[trap_id]


func _is_trap_on_cooldown(trap_id: String) -> bool:
	return _get_cooldown_remaining(trap_id) > 0.0


func _get_cooldown_remaining(trap_id: String) -> float:
	if not trap_cooldowns.has(trap_id):
		return 0.0

	return trap_cooldowns[trap_id]


func _start_cooldown(trap_id: String) -> void:
	trap_cooldowns[trap_id] = _get_trap_cooldown_time(trap_id)


func _has_enough_energy(trap_id: String) -> bool:
	var cost := _get_trap_cost(trap_id)

	if cost < 0.0:
		return false

	return game.get_my_energy() >= cost


func _make_request(request_id: int, trap_id: String, params: Dictionary) -> Dictionary:
	return {
		"request_id": request_id,
		"trap_id": trap_id,
		"params": params,
		"submit_time": Time.get_ticks_msec()
	}


func _make_submit_result(ok: bool, request_id: int, trap_id: String, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"stage": "queued" if ok else "rejected",
		"request_id": request_id,
		"trap_id": trap_id,
		"reason": reason,
	}


func request_heal() -> Dictionary:
	if heal_uses_left <= 0:
		return _make_heal_result(false, "no_heal_uses_left")

	if game.get_my_energy() < default_heal_energy_cost:
		return _make_heal_result(false, "insufficient_energy")

	game.request_spend_energy(default_heal_energy_cost, "heal")
	game.player.health = min(game.player.health + default_heal_amount, game.player.max_health)
	heal_uses_left -= 1

	heal_used.emit(default_heal_amount, default_heal_energy_cost, heal_uses_left)
	return _make_heal_result(true, "")


func _make_heal_result(ok: bool, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"health": game.player.health,
		"max_health": game.player.max_health,
		"energy": game.get_my_energy(),
		"heal_uses_left": heal_uses_left,
		"reason": reason,
	}
