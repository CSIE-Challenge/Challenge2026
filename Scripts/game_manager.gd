extends Node2D

#const RESULT_SCREEN_TEST_DELAY := 10.0
# Seats driven by a remote agent. The human plays directly on the keyboard, so
# only agent seats need wiring: add a name here to add an agent (1 agent for now).
const AGENT_SEATS: Array[String] = ["Agent1"]

@export var player: CharacterBody2D
@export var camera: Camera2D
@export var health_label: Label
@export var energy_balls_label: Label
@export var energy_bar_label: Label
@export var opponent_energy_bar_label: Label
@export var result_screen: ResultScreen
@export var energy_increase_period: float
@export var player_invincibility_time: float
@export var energy_gain_per_ball: int = 10

var energy_ball_count := 0
var energy_amount := 0
var total_energy_spent := 0
var rng := RandomNumberGenerator.new()
var player_invincible := false
var game_over := false
var survival_started_msec := 0

@onready var player_invincibility_timer = $PlayerInvincibilityTimer
@onready var energy_increase_timer = $EnergyIncreaseTimer

@onready var team_status_service: TeamStatusService = $"../TeamStatusService"
@onready var trap_request_scheduler: TrapRequestScheduler = $"../TrapRequestScheduler"
@onready var agent_action_service: AgentActionService = $"../AgentActionService"


func _ready() -> void:
	survival_started_msec = Time.get_ticks_msec()
	Global.player_hit.connect(on_player_hit)
	Global.energyball_collected.connect(_on_energyball_collected)
	Global.game_manager = self
	player_invincibility_timer.timeout.connect(_on_player_invincibility_timer_timeout)
	NetworkManager.energy_changed.connect(_on_network_energy_changed)
	health_label.text = "Health: %d" % player.max_health
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	_update_energy_label()
	_update_opponent_energy_label(0, 0)
	_connect_team_status_signals()
	_connect_agent_action_signals()

	agent_action_service.setup_services(team_status_service, trap_request_scheduler)

	energy_increase_timer.wait_time = energy_increase_period

	player_invincible = false

	_begin_agents()

	#_show_test_result_after_delay()


func _begin_agents() -> void:
	var bundle := ApiServer.cmdline_value("--agent-bundle")
	if bundle == "":
		_spawn_agents("", "")
		return
	var override := ApiServer.cmdline_value("--agent-file")
	if override != "":
		_spawn_agents(bundle, override)
	else:
		_prompt_agent_file(bundle)


func _prompt_agent_file(bundle: String) -> void:
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.add_filter("*.py", "Python agent")
	# Cancel falls back to the bundle's baked agent.py (empty agent_file).
	dialog.file_selected.connect(func(path: String): _spawn_agents(bundle, path))
	dialog.canceled.connect(func(): _spawn_agents(bundle, ""))
	add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _spawn_agents(bundle: String, agent_file: String) -> void:
	for seat_name: String in AGENT_SEATS:
		var agent := GameAgent.new()
		agent.name = seat_name
		agent.game = self
		agent.bundle_dir = bundle
		agent.agent_file = agent_file
		add_child(agent)


# tests/examples/Api usage of Agent Action Service/Team Status Service/Trap Request Scheduler
func get_agent_action_service() -> AgentActionService:
	return agent_action_service


func get_team_status_service() -> TeamStatusService:
	return team_status_service


func _connect_team_status_signals() -> void:
	team_status_service.energy_changed.connect(_on_team_energy_changed)
	team_status_service.health_changed.connect(_on_team_health_changed)
	team_status_service.mode_changed.connect(_on_team_mode_changed)
	team_status_service.heal_used.connect(_on_team_heal_used)


func _connect_agent_action_signals() -> void:
	agent_action_service.trap_request_submitted.connect(_on_trap_request_submitted)
	agent_action_service.trap_request_rejected.connect(_on_trap_request_rejected)
	agent_action_service.trap_approved.connect(_on_trap_approved)
	agent_action_service.trap_rejected.connect(_on_trap_rejected)


func _on_team_energy_changed(team_id: int, current: float, max_energy: float) -> void:
	print("ENERGY_CHANGED team=", team_id, " energy=", current, "/", max_energy)


func _on_team_health_changed(team_id: int, current: float, max_health: float) -> void:
	print("HEALTH_CHANGED team=", team_id, " health=", current, "/", max_health)


func _on_team_mode_changed(team_id: int, old_mode: String, new_mode: String) -> void:
	print("MODE_CHANGED team=", team_id, " ", old_mode, " -> ", new_mode)


func _on_team_heal_used(
	team_id: int, heal_amount: float, energy_cost: float, heal_uses_left: int
) -> void:
	print(
		"HEAL_USED team=",
		team_id,
		" heal=",
		heal_amount,
		" cost=",
		energy_cost,
		" uses_left=",
		heal_uses_left
	)


func _on_trap_request_submitted(request: Dictionary) -> void:
	print(
		"SUBMITTED request_id=",
		request["request_id"],
		" team=",
		request["team_id"],
		" trap=",
		request["trap_id"]
	)


func _on_trap_request_rejected(request: Dictionary, reason: String) -> void:
	print(
		"SUBMIT_REJECTED team=",
		request["team_id"],
		" trap=",
		request["trap_id"],
		" reason=",
		reason
	)


func _on_trap_approved(request: Dictionary, energy_cost: float) -> void:
	print(
		"APPROVED request_id=",
		request["request_id"],
		" team=",
		request["team_id"],
		" trap=",
		request["trap_id"],
		" cost=",
		energy_cost
	)
	_spawn_trap_from_request(request)


func _on_trap_rejected(request: Dictionary, reason: String) -> void:
	print(
		"FINAL_REJECTED request_id=",
		request["request_id"],
		" team=",
		request["team_id"],
		" trap=",
		request["trap_id"],
		" reason=",
		reason
	)


# gdlint: disable=max-returns
func _spawn_trap_from_request(request: Dictionary) -> void:
	var trap_id: String = request["trap_id"]
	var params: Dictionary = request["params"]

	match trap_id:
		"trap1-mine":
			if not params.has("position"):
				push_error("Missing position for mine trap")
				return
			Trap1Mine.initialize(params["position"])
		"trap2-electric_ring":
			if not (params.has("delay_time") and params.has("radius")):
				push_error("Missing delay_time or radius for electric_ring trap")
				return
			Trap2ElectricRing.initialize(params["delay_time"], params["radius"])
		"trap3-tracing_bullet":
			if not (params.has("position") and params.has("direction") and params.has("speed")):
				push_error("Missing position/direction/speed for tracing_bullet trap")
				return
			Trap3TracingBullet.initialize(params["position"], params["direction"], params["speed"])
		"trap4-conveyor":
			if not (params.has("position") and params.has("direction")):
				push_error("Missing position or direction for conveyor trap")
				return
			Trap4Conveyor.initialize(params["position"], params["direction"])
		"trap5-icefloor":
			if not params.has("position"):
				push_error("Missing position for icefloor trap")
				return
			Trap5IceFloor.initialize(params["position"])
		"trap6-scanline":
			if not params.has("direction"):
				push_error("Missing direction for scanline trap")
				return
			Trap6Scanline.initialize(params["direction"], params.get("speed", 5.0))
		"trap8-electric_arc":
			if not (params.has("start_position") and params.has("end_position")):
				push_error("Missing start_position or end_position for electric_arc trap")
				return
			Trap8ElectricArc.initialize(params["start_position"], params["end_position"])
		"trap9-mortar":
			if not (params.has("start_position") and params.has("end_position")):
				push_error("Missing start_position or end_position for mortar trap")
				return
			Trap9Mortar.initialize(
				params["start_position"], params["end_position"], params.get("air_time", 2.0)
			)
		"trap7-spreading_ripples":
			if not (params.has("position") and params.has("expand_rate")):
				push_error("Missing position or expand_rate for spreading_ripples trap")
				return
			Trap7SpreadingRipples.initialize(params["position"], params["expand_rate"])
		"trap10-shotgun":
			if not (
				params.has("position")
				and params.has("dir1")
				and params.has("dir2")
				and params.has("dir3")
			):
				push_error("Missing position or shoot directions for shotgun trap")
				return
			Trap10Shotgun.initialize(
				params["position"], params["dir1"], params["dir2"], params["dir3"]
			)
		_:
			push_error("Unsupported trap id in approved request: %s" % trap_id)
	# gdlint: enable=max-returns


#----------------------------------------------------------------------


func on_player_hit(damage: int) -> void:
	if game_over or player_invincible:
		return
	_player_become_invincible()
	print("玩家受到了", damage, "點傷害")
	camera.shake_cam()
	player.health = max(player.health - damage, 0.0)
	health_label.text = "Health: %d" % player.health
	if player.health <= 0.0:
		finish_game()


#func _show_test_result_after_delay() -> void:
#await get_tree().create_timer(RESULT_SCREEN_TEST_DELAY).timeout
#finish_game()


func finish_game(authoritative_stats: Dictionary = {}) -> void:
	if game_over:
		return
	game_over = true
	energy_increase_timer.stop()
	player_invincibility_timer.stop()
	player.set_physics_process(false)
	player.collision_layer = 0
	player.collision_mask = 0

	var survival_time := (Time.get_ticks_msec() - survival_started_msec) / 1000.0
	(
		result_screen
		. show_results(
			{
				"energy_spent": authoritative_stats.get("energy_spent", total_energy_spent),
				"energy_balls": energy_ball_count,
				"jump_count": player.jump_count,
				"distance_traveled": player.distance_traveled,
				"survival_time": survival_time,
				"remaining_health": player.health,
				"trap_count": authoritative_stats.get("trap_count", 0),
			}
		)
	)


func _on_energyball_collected() -> void:
	energy_ball_count += 1
	energy_balls_label.text = "Energy Balls: %d" % energy_ball_count
	NetworkManager.request_add_energy(energy_gain_per_ball, "energy_ball")


func _player_become_invincible() -> void:
	player_invincible = true
	player.invincibility_toggle(true)
	player_invincibility_timer.start(player_invincibility_time)


func _on_player_invincibility_timer_timeout() -> void:
	player_invincible = false
	player.invincibility_toggle(false)


func _on_energy_increase_timer_timeout() -> void:
	NetworkManager.request_add_energy(1, "passive_regeneration")


func _on_network_energy_changed(peer_id: int, energy: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		if energy < energy_amount:
			total_energy_spent += energy_amount - energy
		energy_amount = energy
		_update_energy_label()
		return

	_update_opponent_energy_label(peer_id, energy)


func _update_energy_label() -> void:
	energy_bar_label.text = "My Energy: %d" % energy_amount


func _update_opponent_energy_label(peer_id: int, energy: int) -> void:
	if peer_id == 0:
		opponent_energy_bar_label.text = "Opponent Energy: waiting"
		return
	opponent_energy_bar_label.text = "Opponent Energy (%d): %d" % [peer_id, energy]
