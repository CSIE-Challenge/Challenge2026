class_name AgentActionService
extends Node

signal trap_approved(request: Dictionary, energy_cost: float)

var game
var trap_request_scheduler: TrapRequestScheduler

var game_data := GameData.new()
var default_heal_uses: int = game_data.data["heal"]["uses"]
var default_heal_amount: int = game_data.data["heal"]["amount"]
var default_heal_energy_cost: int = game_data.data["heal"]["energy_costs"][0]
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

var max_stock := {
	"trap1-mine": trap_data["trap1-mine"].get("max_stock", 1),
	"trap2-electric_ring": trap_data["trap2-electric_ring"].get("max_stock", 1),
	"trap3-tracing_bullet": trap_data["trap3-tracing_bullet"].get("max_stock", 1),
	"trap4-conveyor": trap_data["trap4-conveyor"].get("max_stock", 1),
	"trap5-icefloor": trap_data["trap5-icefloor"].get("max_stock", 1),
	"trap6-scanline": trap_data["trap6-scanline"].get("max_stock", 1),
	"trap7-spreading_ripples": trap_data["trap7-spreading_ripples"].get("max_stock", 1),
	"trap8-electric_arc": trap_data["trap8-electric_arc"].get("max_stock", 1),
	"trap9-mortar": trap_data["trap9-mortar"].get("max_stock", 1),
	"trap10-shotgun": trap_data["trap10-shotgun"].get("max_stock", 1)
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


func reset_for_scene_exit() -> void:
	if trap_request_scheduler != null and _is_connected_to_scheduler:
		if trap_request_scheduler.request_ready.is_connected(_on_request_ready):
			trap_request_scheduler.request_ready.disconnect(_on_request_ready)
	_is_connected_to_scheduler = false
	trap_request_scheduler = null
	game = null
	trap_cooldowns.clear()
	heal_uses_left = default_heal_uses


# gdlint: disable=max-returns
# For Game Manager tests
func submit_trap_request(trap_id: String, params: Dictionary = {}) -> int:
	if game == null:
		push_error("AgentActionService: game is not assigned.")
		return -1

	if trap_request_scheduler == null:
		push_error("AgentActionService: trap_request_scheduler is not assigned.")
		return -1

	if not _is_known_trap(trap_id):
		return -1

	if _is_trap_on_cooldown(trap_id):
		return -1

	if not _has_enough_energy(trap_id):
		return -1

	if not trap_request_scheduler.can_accept_request():
		return -1

	return trap_request_scheduler.submit_request(trap_id, params)


# For Python API Server Calling
func submit_trap_request_result(trap_id: String, params: Dictionary = {}) -> Dictionary:
	if game == null:
		return _make_submit_result(false, -1, trap_id, "game_not_assigned")

	if trap_request_scheduler == null:
		return _make_submit_result(false, -1, trap_id, "trap_request_scheduler_not_assigned")

	if not _is_known_trap(trap_id):
		return _make_submit_result(false, -1, trap_id, "unknown_trap")

	if _is_trap_on_cooldown(trap_id):
		return _make_submit_result(false, -1, trap_id, "cooldown_active")

	if not _has_enough_energy(trap_id):
		return _make_submit_result(false, -1, trap_id, "insufficient_energy")

	if not trap_request_scheduler.can_accept_request():
		return _make_submit_result(false, -1, trap_id, "scheduler_cannot_accept_request")

	var request_id := trap_request_scheduler.submit_request(trap_id, params)

	if request_id == -1:
		return _make_submit_result(false, -1, trap_id, "scheduler_submit_failed")

	return _make_submit_result(true, request_id, trap_id, "")


# gdlint: enable=max-returns


func get_available_traps() -> Array:
	var available_traps: Array = []
	if game == null or trap_request_scheduler == null:
		return available_traps

	for trap_id in trap_energy_costs.keys():
		if not _is_known_trap(trap_id):
			continue
		if _is_trap_on_cooldown(trap_id):
			continue
		if not _has_enough_energy(trap_id):
			continue
		if not trap_request_scheduler.can_accept_request():
			continue
		available_traps.append(trap_id)

	available_traps.sort()
	return available_traps


func get_cooldown_time(trap_id: String) -> float:
	if not _is_known_trap(trap_id):
		return -1.0

	return _get_cooldown_remaining(trap_id)


func get_current_stock(trap_id: String) -> int:
	if not _is_known_trap(trap_id):
		return -1
	return _get_trap_stock_left(trap_id)


func _get_trap_stock_left(trap_id: String) -> int:
	var max_stock_count := _get_trap_max_stock(trap_id)
	var cooldown_remaining := _get_cooldown_remaining(trap_id)
	if max_stock_count <= 1:
		return max_stock_count if cooldown_remaining <= 0.0 else 0

	var cooldown_time := _get_trap_cooldown_time(trap_id)
	if cooldown_time <= 0.0:
		return max_stock_count

	var used_stocks := int(ceilf(cooldown_remaining / cooldown_time))
	var current_stock := max_stock_count - used_stocks
	return clamp(current_stock, 0, max_stock_count)


func update_cooldowns(delta: float) -> void:
	if delta <= 0.0:
		return

	for trap_id in trap_cooldowns.keys():
		trap_cooldowns[trap_id] = max(trap_cooldowns[trap_id] - delta, 0.0)


func _on_request_ready(request: Dictionary) -> void:
	var trap_id: String = request["trap_id"]

	if game == null:
		push_error("AgentActionService: game is not assigned.")
		return

	if not _is_known_trap(trap_id):
		return

	if _is_trap_on_cooldown(trap_id):
		return

	var cost := _get_trap_cost(trap_id)

	# Script A runs on the opponent's client, so a trap is paid for by the
	# opponent's energy (aliases to self in offline mode).
	if NetworkManager.get_energy(NetworkManager.get_opponent_peer_id()) < cost:
		return

	NetworkManager.request_spend_opponent_energy(cost)
	_start_cooldown(trap_id)
	trap_approved.emit(request, cost)


func _is_known_trap(trap_id: String) -> bool:
	return trap_energy_costs.has(trap_id)


func _get_trap_cost(trap_id: String) -> int:
	if not trap_energy_costs.has(trap_id):
		return -1

	return trap_energy_costs[trap_id]


func _get_trap_cooldown_time(trap_id: String) -> float:
	if not trap_cooldown_times.has(trap_id):
		return 0.0
	return trap_cooldown_times[trap_id]


func _is_trap_on_cooldown(trap_id: String) -> bool:
	if _get_trap_max_stock(trap_id) <= 1:
		return _get_cooldown_remaining(trap_id) > 0.0

	return _get_trap_stock_left(trap_id) <= 0


func _get_trap_max_stock(trap_id: String) -> int:
	if not max_stock.has(trap_id):
		return 0
	return max_stock[trap_id]


func _get_cooldown_remaining(trap_id: String) -> float:
	if not trap_cooldowns.has(trap_id):
		return 0.0

	return trap_cooldowns[trap_id]


func _start_cooldown(trap_id: String) -> void:
	if _get_trap_max_stock(trap_id) > 1:
		if not trap_cooldowns.has(trap_id):
			trap_cooldowns[trap_id] = clampf(
				0.0 + _get_trap_cooldown_time(trap_id),
				0,
				_get_trap_cooldown_time(trap_id) * _get_trap_max_stock(trap_id)
			)
		else:
			trap_cooldowns[trap_id] = clampf(
				trap_cooldowns[trap_id] + _get_trap_cooldown_time(trap_id),
				0,
				_get_trap_cooldown_time(trap_id) * _get_trap_max_stock(trap_id)
			)
	else:
		trap_cooldowns[trap_id] = _get_trap_cooldown_time(trap_id)


func _has_enough_energy(trap_id: String) -> bool:
	var cost := _get_trap_cost(trap_id)

	if cost < 0:
		return false

	# A trap is paid for by the opponent's energy (NetworkManager peer energy),
	# so the submit-time gate must check the same wallet as the actual spend.
	return NetworkManager.get_energy(NetworkManager.get_opponent_peer_id()) >= cost


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

	var owner_peer_id := NetworkManager.get_opponent_peer_id()
	if NetworkManager.get_energy(owner_peer_id) < default_heal_energy_cost:
		return _make_heal_result(false, "insufficient_energy")

	NetworkManager.request_spend_opponent_energy(default_heal_energy_cost)
	NetworkManager.request_heal_opponent_health(default_heal_amount)
	heal_uses_left -= 1

	return _make_heal_result(true, "")


func _make_heal_result(ok: bool, reason: String) -> Dictionary:
	var owner_peer_id := NetworkManager.get_opponent_peer_id()
	return {
		"ok": ok,
		"health": NetworkManager.get_health(owner_peer_id),
		"energy": NetworkManager.get_energy(owner_peer_id),
		"heal_uses_left": heal_uses_left,
		"reason": reason,
	}


func update_heal_cost(new_cost: int) -> void:
	default_heal_amount = new_cost
