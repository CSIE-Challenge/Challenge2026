class_name TeamStatusService
extends Node

signal energy_changed(current_energy: float, max_energy: float)
signal health_changed(current_health: float, max_health: float)
signal mode_changed(old_mode: String, new_mode: String)
signal heal_used(heal_amount: float, energy_cost: float, heal_uses_left: int)

const MODE_NORMAL := "normal"
const MODE_LIFESTEAL := "lifesteal"

var default_max_health: int = 5
var default_start_health: int = 5

var default_max_energy: int = 100
var default_start_energy: int = 0
var default_energy_regen_rate: int = 5

var default_heal_uses: int = 2
var default_heal_amount: int = 2
var default_heal_energy_cost: int = 40
var lifesteal_regen_multiplier: float = 2.0

var health: float = 0.0
var max_health: float = 0.0
var energy: float = 0.0
var max_energy: float = 0.0
var energy_regen_rate: float = 0.0
var energy_regen_multiplier: float = 1.0
var mode: String = MODE_NORMAL
var heal_uses_left: int = 0
var is_eliminated: bool = false


func _ready() -> void:
	_reload_from_game_data()


func initialize() -> void:
	_reload_from_game_data()

	health = default_start_health
	max_health = default_max_health
	energy = default_start_energy
	max_energy = default_max_energy
	energy_regen_rate = default_energy_regen_rate
	energy_regen_multiplier = 1.0
	mode = MODE_NORMAL
	heal_uses_left = default_heal_uses
	is_eliminated = false

	energy_changed.emit(energy, max_energy)
	health_changed.emit(health, max_health)


func _reload_from_game_data() -> void:
	var game_data := GameData.new()
	default_max_health = game_data.get_float(
		"team_status_service", "default_max_health", default_max_health
	)
	default_start_health = game_data.get_float(
		"team_status_service", "default_start_health", default_start_health
	)
	default_max_energy = game_data.get_float(
		"team_status_service", "default_max_energy", default_max_energy
	)
	default_start_energy = game_data.get_float(
		"team_status_service", "default_start_energy", default_start_energy
	)
	default_energy_regen_rate = game_data.get_float(
		"team_status_service", "default_energy_regen_rate", default_energy_regen_rate
	)
	default_heal_uses = game_data.get_int(
		"team_status_service", "default_heal_uses", default_heal_uses
	)
	default_heal_amount = game_data.get_int(
		"team_status_service", "default_heal_amount", default_heal_amount
	)
	default_heal_energy_cost = game_data.get_float(
		"team_status_service", "default_heal_energy_cost", default_heal_energy_cost
	)
	lifesteal_regen_multiplier = game_data.get_float(
		"team_status_service", "lifesteal_regen_multiplier", lifesteal_regen_multiplier
	)


func get_energy() -> float:
	return energy


func get_health() -> float:
	return health


func get_status() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"energy": energy,
		"max_energy": max_energy,
		"energy_regen_rate": energy_regen_rate,
		"energy_regen_multiplier": energy_regen_multiplier,
		"mode": mode,
		"heal_uses_left": heal_uses_left,
		"is_eliminated": is_eliminated,
	}


func add_energy(amount: int) -> void:
	if amount <= 0.0:
		return

	energy = min(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)


func try_spend_energy(amount: int) -> bool:
	if amount < 0.0:
		print("Cannot spend negative energy!")
		return false

	if energy < amount:
		print("Not enough energy!")
		return false

	energy -= amount
	energy_changed.emit(energy, max_energy)

	return true


func take_damage(damage: float) -> void:
	if damage <= 0.0:
		return

	var old_health := health
	var old_mode := mode

	health -= damage
	health_changed.emit(health, max_health)

	if old_health > 0.0 and health <= 0.0 and old_mode == MODE_NORMAL:
		mode = MODE_LIFESTEAL
		energy_regen_multiplier = lifesteal_regen_multiplier
		mode_changed.emit(MODE_NORMAL, MODE_LIFESTEAL)


# gdlint: disable=max-returns
func try_heal(heal_amount: float, energy_cost: float) -> bool:
	if heal_amount <= 0.0:
		print("Heal amount must be positive!")
		return false

	if energy_cost < 0.0:
		print("Energy cost cannot be negative!")
		return false

	if mode == MODE_LIFESTEAL:
		print("In lifesteal mode!")
		return false

	if heal_uses_left <= 0:
		print("No heal uses left!")
		return false

	if energy < energy_cost:
		print("Not enough energy!")
		return false

	energy -= energy_cost
	health = min(health + heal_amount, max_health)
	heal_uses_left -= 1

	energy_changed.emit(energy, max_energy)
	health_changed.emit(health, max_health)
	heal_used.emit(heal_amount, energy_cost, heal_uses_left)

	return true


# gdlint: enable=max-returns


func update_energy_regen(delta: float) -> void:
	if delta <= 0.0:
		return

	if is_eliminated:
		return

	var energy_gain := energy_regen_rate * energy_regen_multiplier * delta
	add_energy(energy_gain)


func set_energy_regen_multiplier(multiplier: float) -> void:
	energy_regen_multiplier = max(multiplier, 0.0)


func is_in_lifesteal() -> bool:
	return mode == MODE_LIFESTEAL


# ----------------------------------------------------------------------
# API result helpers
# These functions are additive wrappers for GameAgent/API calls only.
# They do not replace the existing gameplay methods.
# ----------------------------------------------------------------------


# Heal amount and energy cost are fixed in game.json; the caller passes nothing.
func request_heal_api() -> Dictionary:
	if mode == MODE_LIFESTEAL:
		return _make_heal_api_result(false, "lifesteal_mode_cannot_heal")

	if heal_uses_left <= 0:
		return _make_heal_api_result(false, "no_heal_uses_left")

	if energy < default_heal_energy_cost:
		return _make_heal_api_result(false, "insufficient_energy")

	if not try_heal(default_heal_amount, default_heal_energy_cost):
		return _make_heal_api_result(false, "heal_failed")

	return _make_heal_api_result(true, "")


func _make_heal_api_result(ok: bool, reason: String) -> Dictionary:
	return {
		"ok": ok,
		"health": health,
		"max_health": max_health,
		"energy": energy,
		"max_energy": max_energy,
		"mode": mode,
		"heal_uses_left": heal_uses_left,
		"reason": reason,
	}
