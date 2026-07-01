class_name AgentActionService
extends Node

signal trap_request_submitted(request: Dictionary)
signal trap_request_rejected(request: Dictionary, reason: String)
signal trap_approved(request: Dictionary, energy_cost: float)
signal trap_rejected(request: Dictionary, reason: String)

var team_status_service: TeamStatusService
var trap_request_scheduler: TrapRequestScheduler

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

# trap_cooldowns[team_id][trap_id] = remaining_seconds
var trap_cooldowns: Dictionary = {}

var _is_connected_to_scheduler := false


func setup_services(team_status: TeamStatusService, scheduler: TrapRequestScheduler) -> void:
	team_status_service = team_status
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
func submit_trap_request(team_id: int, trap_id: String, params: Dictionary = {}) -> int:
	var rejected_request := _make_request(-1, team_id, trap_id, params)

	if team_status_service == null:
		push_error("AgentActionService: team_status_service is not assigned.")
		trap_request_rejected.emit(rejected_request, "team_status_service_not_assigned")
		return -1

	if trap_request_scheduler == null:
		push_error("AgentActionService: trap_request_scheduler is not assigned.")
		trap_request_rejected.emit(rejected_request, "trap_request_scheduler_not_assigned")
		return -1

	if not _is_known_trap(trap_id):
		trap_request_rejected.emit(rejected_request, "unknown_trap")
		return -1

	if _is_trap_on_cooldown(team_id, trap_id):
		trap_request_rejected.emit(rejected_request, "cooldown_active")
		return -1

	if not _has_enough_energy(team_id, trap_id):
		trap_request_rejected.emit(rejected_request, "insufficient_energy")
		return -1

	if not trap_request_scheduler.can_accept_request(team_id):
		trap_request_rejected.emit(rejected_request, "scheduler_cannot_accept_request")
		return -1

	var request_id := trap_request_scheduler.submit_request(team_id, trap_id, params)

	if request_id == -1:
		trap_request_rejected.emit(rejected_request, "scheduler_submit_failed")
		return -1

	var submitted_request := _make_request(request_id, team_id, trap_id, params)
	trap_request_submitted.emit(submitted_request)

	return request_id


# For Python API Server Calling
func submit_trap_request_result(
	team_id: int, trap_id: String, params: Dictionary = {}
) -> Dictionary:
	var rejected_request := _make_request(-1, team_id, trap_id, params)

	if team_status_service == null:
		trap_request_rejected.emit(rejected_request, "team_status_service_not_assigned")
		return _make_submit_result(false, -1, team_id, trap_id, "team_status_service_not_assigned")

	if trap_request_scheduler == null:
		trap_request_rejected.emit(rejected_request, "trap_request_scheduler_not_assigned")
		return _make_submit_result(
			false, -1, team_id, trap_id, "trap_request_scheduler_not_assigned"
		)

	if not _is_known_trap(trap_id):
		trap_request_rejected.emit(rejected_request, "unknown_trap")
		return _make_submit_result(false, -1, team_id, trap_id, "unknown_trap")

	if _is_trap_on_cooldown(team_id, trap_id):
		trap_request_rejected.emit(rejected_request, "cooldown_active")
		return _make_submit_result(false, -1, team_id, trap_id, "cooldown_active")

	if not _has_enough_energy(team_id, trap_id):
		trap_request_rejected.emit(rejected_request, "insufficient_energy")
		return _make_submit_result(false, -1, team_id, trap_id, "insufficient_energy")

	if not trap_request_scheduler.can_accept_request(team_id):
		trap_request_rejected.emit(rejected_request, "scheduler_cannot_accept_request")
		return _make_submit_result(false, -1, team_id, trap_id, "scheduler_cannot_accept_request")

	var request_id := trap_request_scheduler.submit_request(team_id, trap_id, params)

	if request_id == -1:
		trap_request_rejected.emit(rejected_request, "scheduler_submit_failed")
		return _make_submit_result(false, -1, team_id, trap_id, "scheduler_submit_failed")

	var submitted_request := _make_request(request_id, team_id, trap_id, params)
	trap_request_submitted.emit(submitted_request)

	return _make_submit_result(true, request_id, team_id, trap_id, "")


# gdlint: enable=max-returns


func update_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return

	for team_id in trap_cooldowns.keys():
		var team_cooldowns: Dictionary = trap_cooldowns[team_id]

		for trap_id in team_cooldowns.keys():
			team_cooldowns[trap_id] = max(team_cooldowns[trap_id] - delta, 0.0)


func _on_request_ready(request: Dictionary) -> void:
	print("AgentActionService received request_ready: ", request)

	var team_id: int = request["team_id"]
	var trap_id: String = request["trap_id"]

	if team_status_service == null:
		push_error("AgentActionService: team_status_service is not assigned.")
		trap_rejected.emit(request, "team_status_service_not_assigned")
		return

	if not _is_known_trap(trap_id):
		trap_rejected.emit(request, "unknown_trap")
		return

	if _is_trap_on_cooldown(team_id, trap_id):
		trap_rejected.emit(request, "cooldown_active")
		return

	var cost := _get_trap_cost(trap_id)

	if not team_status_service.try_spend_energy(team_id, cost):
		trap_rejected.emit(request, "insufficient_energy")
		return

	_start_cooldown(team_id, trap_id)
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


func _is_trap_on_cooldown(team_id: int, trap_id: String) -> bool:
	return _get_cooldown_remaining(team_id, trap_id) > 0.0


func _get_cooldown_remaining(team_id: int, trap_id: String) -> float:
	if not trap_cooldowns.has(team_id):
		return 0.0

	if not trap_cooldowns[team_id].has(trap_id):
		return 0.0

	return trap_cooldowns[team_id][trap_id]


func _start_cooldown(team_id: int, trap_id: String) -> void:
	if not trap_cooldowns.has(team_id):
		trap_cooldowns[team_id] = {}

	trap_cooldowns[team_id][trap_id] = _get_trap_cooldown_time(trap_id)


func _has_enough_energy(team_id: int, trap_id: String) -> bool:
	var cost := _get_trap_cost(trap_id)

	if cost < 0.0:
		return false

	return team_status_service.get_energy(team_id) >= cost


func _make_request(
	request_id: int, team_id: int, trap_id: String, params: Dictionary
) -> Dictionary:
	return {
		"request_id": request_id,
		"team_id": team_id,
		"trap_id": trap_id,
		"params": params,
		"submit_time": Time.get_ticks_msec()
	}


func _make_submit_result(
	ok: bool, request_id: int, _team_id: int, trap_id: String, reason: String
) -> Dictionary:
	return {
		"ok": ok,
		"stage": "queued" if ok else "rejected",
		"request_id": request_id,
		"trap_id": trap_id,
		"reason": reason,
	}
