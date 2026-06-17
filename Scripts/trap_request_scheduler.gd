class_name TrapRequestScheduler
extends Node

signal request_accepted(request: Dictionary)
signal request_ready(request: Dictionary)

@export var max_queue_size_per_team: int = 3
@export var max_requests_per_team_per_tick: int = 1

var known_teams: Array[int] = []
var request_queues: Dictionary = {}
var next_request_serial: int = 0


func initialize_teams(teams: Array[int]) -> void:
	known_teams.clear()
	request_queues.clear()
	next_request_serial = 0

	for team_id in teams:
		if team_id in known_teams:
			continue

		known_teams.append(team_id)
		request_queues[team_id] = []


func submit_request(team_id: int, trap_id: String, params: Dictionary = {}) -> int:
	if not can_accept_request(team_id):
		return -1

	var request_id: int = next_request_serial
	next_request_serial += 1

	var request := {
		"request_id": request_id,
		"team_id": team_id,
		"trap_id": trap_id,
		"params": params,
		"submit_time": Time.get_ticks_msec()
	}

	request_queues[team_id].push_back(request)
	request_accepted.emit(request)

	return request_id


func can_accept_request(team_id: int) -> bool:
	if team_id not in known_teams:
		return false

	if not request_queues.has(team_id):
		return false

	if request_queues[team_id].size() >= max_queue_size_per_team:
		return false

	return true


func process_requests() -> void:
	for team_id in known_teams:
		if not request_queues.has(team_id):
			continue

		var queue: Array = request_queues[team_id]
		var processed := 0

		while processed < max_requests_per_team_per_tick and not queue.is_empty():
			var request: Dictionary = queue.pop_front()
			request_ready.emit(request)
			processed += 1


func get_queue_size(team_id: int) -> int:
	if not request_queues.has(team_id):
		return -1

	return request_queues[team_id].size()


func clear_team_queue(team_id: int) -> void:
	if not request_queues.has(team_id):
		return

	request_queues[team_id].clear()


func clear_all() -> void:
	for team_id in request_queues.keys():
		request_queues[team_id].clear()
