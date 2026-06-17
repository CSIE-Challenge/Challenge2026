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
