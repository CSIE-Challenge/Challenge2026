class_name TrapRequestScheduler
extends Node

signal request_accepted(request: Dictionary)
signal request_ready(request: Dictionary)

@export var max_queue_size: int = 3
@export var max_requests_per_tick: int = 1

var request_queue: Array = []
var next_request_serial: int = 0


func initialize() -> void:
	request_queue.clear()
	next_request_serial = 0


func submit_request(trap_id: String, params: Dictionary = {}) -> int:
	if not can_accept_request():
		return -1

	var request_id: int = next_request_serial
	next_request_serial += 1

	var request := {
		"request_id": request_id,
		"trap_id": trap_id,
		"params": params,
		"submit_time": Time.get_ticks_msec()
	}

	request_queue.push_back(request)
	request_accepted.emit(request)

	return request_id


func can_accept_request() -> bool:
	return request_queue.size() < max_queue_size


func process_requests() -> void:
	var processed := 0

	while processed < max_requests_per_tick and not request_queue.is_empty():
		var request: Dictionary = request_queue.pop_front()
		request_ready.emit(request)
		processed += 1


func get_queue_size() -> int:
	return request_queue.size()


func clear() -> void:
	request_queue.clear()
