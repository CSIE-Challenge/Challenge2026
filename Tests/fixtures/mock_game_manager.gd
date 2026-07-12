# Test fixture: minimal game_manager-like node for StateSerializer tests.
extends Node

var player: Node
var energy_amount: int = 0
var energy_ball_count: int = 0
var max_energy: Array = [35, 50, 60, 70, 77, 85]
var current_phase: int = 0


func get_current_max_energy_cap() -> int:
	if max_energy.is_empty():
		return 0
	return int(max_energy[min(current_phase, max_energy.size() - 1)])
