class_name TeamStatusService
extends Node

signal energy_changed(team_id: int, current_energy: float, max_energy: float)
signal health_changed(team_id: int, current_health: float, max_health: float)
signal mode_changed(team_id: int, old_mode: String, new_mode: String)
signal heal_used(team_id: int, heal_amount: float, energy_cost: float, heal_uses_left: int)

const MODE_NORMAL := "normal"
const MODE_LIFESTEAL := "lifesteal"

@export var default_max_health: float = 5.0
@export var default_start_health: float = 5.0

@export var default_max_energy: float = 100.0
@export var default_start_energy: float = 0.0
@export var default_energy_regen_rate: float = 5.0

@export var default_heal_uses: int = 2
@export var lifesteal_regen_multiplier: float = 2.0

var team_status: Dictionary = {}


func initialize_teams(team_ids: Array[int]) -> void:
	team_status.clear()

	for team_id in team_ids:
		team_status[team_id] = {
			"team_id": team_id,
			"health": default_start_health,
			"max_health": default_max_health,
			"energy": default_start_energy,
			"max_energy": default_max_energy,
			"energy_regen_rate": default_energy_regen_rate,
			"energy_regen_multiplier": 1.0,
			"mode": MODE_NORMAL,
			"heal_uses_left": default_heal_uses,
			"is_eliminated": false
		}

		energy_changed.emit(team_id, default_start_energy, default_max_energy)
		health_changed.emit(team_id, default_start_health, default_max_health)


func has_team(team_id: int) -> bool:
	return team_status.has(team_id)


func get_energy(team_id: int) -> float:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return -1.0

	return team_status[team_id]["energy"]


func get_health(team_id: int) -> float:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return -1.0

	return team_status[team_id]["health"]


func get_team_status(team_id: int) -> Dictionary:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return {}

	return team_status[team_id].duplicate(true)


func add_energy(team_id: int, amount: float) -> void:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return

	if amount <= 0.0:
		return

	var team: Dictionary = team_status[team_id]
	team["energy"] = min(team["energy"] + amount, team["max_energy"])

	energy_changed.emit(team_id, team["energy"], team["max_energy"])


func try_spend_energy(team_id: int, amount: float) -> bool:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return false

	if amount < 0.0:
		print("Cannot spend negative energy!")
		return false

	var team: Dictionary = team_status[team_id]

	if team["energy"] < amount:
		print("Not enough energy!")
		return false

	team["energy"] -= amount
	energy_changed.emit(team_id, team["energy"], team["max_energy"])

	return true


func damage_team(team_id: int, damage: float) -> void:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return

	if damage <= 0.0:
		return

	var team: Dictionary = team_status[team_id]
	var old_health: float = team["health"]
	var old_mode: String = team["mode"]

	team["health"] -= damage

	health_changed.emit(team_id, team["health"], team["max_health"])

	if old_health > 0.0 and team["health"] <= 0.0 and old_mode == MODE_NORMAL:
		team["mode"] = MODE_LIFESTEAL
		team["energy_regen_multiplier"] = lifesteal_regen_multiplier
		mode_changed.emit(team_id, MODE_NORMAL, MODE_LIFESTEAL)


# gdlint: disable=max-returns
func try_heal_team(team_id: int, heal_amount: float, energy_cost: float) -> bool:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return false

	if heal_amount <= 0.0:
		print("Heal amount must be positive!")
		return false

	if energy_cost < 0.0:
		print("Energy cost cannot be negative!")
		return false

	var team: Dictionary = team_status[team_id]

	if team["mode"] == MODE_LIFESTEAL:
		print("In lifesteal mode!")
		return false

	if team["heal_uses_left"] <= 0:
		print("No heal uses left!")
		return false

	if team["energy"] < energy_cost:
		print("Not enough energy!")
		return false

	team["energy"] -= energy_cost
	team["health"] = min(team["health"] + heal_amount, team["max_health"])
	team["heal_uses_left"] -= 1

	energy_changed.emit(team_id, team["energy"], team["max_energy"])
	health_changed.emit(team_id, team["health"], team["max_health"])
	heal_used.emit(team_id, heal_amount, energy_cost, team["heal_uses_left"])

	return true


# gdlint: enable=max-returns


func update_energy_regen(delta: float) -> void:
	if delta <= 0.0:
		return

	for team_id in team_status.keys():
		var team: Dictionary = team_status[team_id]

		if team["is_eliminated"]:
			continue

		var energy_gain: float = team["energy_regen_rate"] * team["energy_regen_multiplier"] * delta
		add_energy(team_id, energy_gain)


func set_energy_regen_multiplier(team_id: int, multiplier: float) -> void:
	if not has_team(team_id):
		print("Team ", team_id, " does not exist!")
		return

	team_status[team_id]["energy_regen_multiplier"] = max(multiplier, 0.0)


func is_team_in_lifesteal(team_id: int) -> bool:
	if not has_team(team_id):
		return false

	return team_status[team_id]["mode"] == MODE_LIFESTEAL


# ----------------------------------------------------------------------
# API result helpers
# These functions are additive wrappers for GameAgent/API calls only.
# They do not replace the existing gameplay methods.
# ----------------------------------------------------------------------


func get_team_status_api(team_id: int) -> Dictionary:
	if not has_team(team_id):
		return {
			"ok": false,
			"team_id": team_id,
			"reason": "unknown_team_id",
		}

	var team: Dictionary = team_status[team_id]

	return {
		"ok": true,
		"team_id": team_id,
		"health": team["health"],
		"max_health": team["max_health"],
		"energy": team["energy"],
		"max_energy": team["max_energy"],
		"energy_regen_rate": team["energy_regen_rate"],
		"energy_regen_multiplier": team["energy_regen_multiplier"],
		"mode": team["mode"],
		"heal_uses_left": team["heal_uses_left"],
		"is_eliminated": team["is_eliminated"],
		"reason": "",
	}


func get_team_energy_api(team_id: int) -> Dictionary:
	if not has_team(team_id):
		return {
			"ok": false,
			"team_id": team_id,
			"energy": 0.0,
			"max_energy": 0.0,
			"reason": "unknown_team_id",
		}

	var team: Dictionary = team_status[team_id]

	return {
		"ok": true,
		"team_id": team_id,
		"energy": team["energy"],
		"max_energy": team["max_energy"],
		"reason": "",
	}


func get_team_health_api(team_id: int) -> Dictionary:
	if not has_team(team_id):
		return {
			"ok": false,
			"team_id": team_id,
			"health": 0.0,
			"max_health": 0.0,
			"mode": "",
			"reason": "unknown_team_id",
		}

	var team: Dictionary = team_status[team_id]

	return {
		"ok": true,
		"team_id": team_id,
		"health": team["health"],
		"max_health": team["max_health"],
		"mode": team["mode"],
		"reason": "",
	}


# gdlint: disable=max-returns
func request_heal_api(team_id: int, heal_amount: float, energy_cost: float) -> Dictionary:
	if not has_team(team_id):
		return _make_heal_api_result(false, team_id, "unknown_team_id")

	if heal_amount <= 0.0:
		return _make_heal_api_result(false, team_id, "invalid_heal_amount")

	if energy_cost < 0.0:
		return _make_heal_api_result(false, team_id, "invalid_energy_cost")

	var team: Dictionary = team_status[team_id]

	if team["mode"] == MODE_LIFESTEAL:
		return _make_heal_api_result(false, team_id, "lifesteal_mode_cannot_heal")

	if team["heal_uses_left"] <= 0:
		return _make_heal_api_result(false, team_id, "no_heal_uses_left")

	if team["energy"] < energy_cost:
		return _make_heal_api_result(false, team_id, "insufficient_energy")

	var ok := try_heal_team(team_id, heal_amount, energy_cost)
	if not ok:
		return _make_heal_api_result(false, team_id, "heal_failed")

	return _make_heal_api_result(true, team_id, "")  # gdlint: ignore=max-returns


# gdlint: enable=max-returns


func _make_heal_api_result(ok: bool, team_id: int, reason: String) -> Dictionary:
	if not has_team(team_id):
		return {
			"ok": ok,
			"team_id": team_id,
			"health": 0.0,
			"max_health": 0.0,
			"energy": 0.0,
			"max_energy": 0.0,
			"mode": "",
			"heal_uses_left": 0,
			"reason": reason,
		}

	var team: Dictionary = team_status[team_id]

	return {
		"ok": ok,
		"team_id": team_id,
		"health": team["health"],
		"max_health": team["max_health"],
		"energy": team["energy"],
		"max_energy": team["max_energy"],
		"mode": team["mode"],
		"heal_uses_left": team["heal_uses_left"],
		"reason": reason,
